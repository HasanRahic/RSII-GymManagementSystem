using Gym.Core.Entities;
using Gym.Core.Enums;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Stripe;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/stripe")]
[AllowAnonymous]
public class StripeWebhookController : ControllerBase
{
    private readonly GymDbContext _context;
    private readonly IMembershipService _membershipService;
    private readonly ILogger<StripeWebhookController> _logger;
    private readonly IConfiguration _configuration;

    public StripeWebhookController(
        GymDbContext context,
        IMembershipService membershipService,
        ILogger<StripeWebhookController> logger,
        IConfiguration configuration)
    {
        _context = context;
        _membershipService = membershipService;
        _logger = logger;
        _configuration = configuration;
    }

    [HttpPost("webhook")]
    public async Task<IActionResult> Webhook()
    {
        var webhookSecret = _configuration["Stripe:WebhookSecret"];
        if (string.IsNullOrWhiteSpace(webhookSecret))
        {
            return StatusCode(StatusCodes.Status500InternalServerError, new { message = "Stripe webhook secret is not configured." });
        }

        var signatureHeader = Request.Headers["Stripe-Signature"].ToString();
        if (string.IsNullOrWhiteSpace(signatureHeader))
        {
            return BadRequest(new { message = "Missing Stripe-Signature header." });
        }

        string payload;
        using (var reader = new StreamReader(Request.Body))
        {
            payload = await reader.ReadToEndAsync();
        }

        Event stripeEvent;
        try
        {
            stripeEvent = EventUtility.ConstructEvent(payload, signatureHeader, webhookSecret);
        }
        catch (StripeException ex)
        {
            _logger.LogWarning(ex, "Invalid Stripe webhook signature.");
            return BadRequest(new { message = "Invalid Stripe webhook signature." });
        }

        switch (stripeEvent.Type)
        {
            case "checkout.session.completed":
                await HandleCheckoutSessionCompletedAsync(stripeEvent);
                break;
            case "payment_intent.succeeded":
                await HandlePaymentIntentSucceededAsync(stripeEvent);
                break;
            case "payment_intent.payment_failed":
                await HandlePaymentIntentFailedAsync(stripeEvent);
                break;
            default:
                _logger.LogInformation("Ignored Stripe event type {EventType}.", stripeEvent.Type);
                break;
        }

        return Ok();
    }

    private async Task HandleCheckoutSessionCompletedAsync(Event stripeEvent)
    {
        var session = stripeEvent.Data.Object as Stripe.Checkout.Session;
        if (session is null)
        {
            return;
        }

        var payment = await FindPaymentAsync(session.Id, session.PaymentIntentId, session.Metadata);
        if (payment is null)
        {
            _logger.LogInformation("Stripe checkout session {SessionId} completed but no payment record was found.", session.Id);
            return;
        }

        payment.StripeSessionId = session.Id;
        payment.StripePaymentIntentId = session.PaymentIntentId ?? payment.StripePaymentIntentId;

        await FulfillMembershipAsync(payment, session.Metadata, $"checkout session {session.Id}");
        await FulfillSessionReservationAsync(payment, session.Metadata, $"checkout session {session.Id}");

        payment.Status = PaymentStatus.Succeeded;
        payment.CompletedAt ??= DateTime.UtcNow;
        ApplySessionAccessWindow(payment, session.Metadata);

        await _context.SaveChangesAsync();
    }

    private async Task HandlePaymentIntentSucceededAsync(Event stripeEvent)
    {
        var paymentIntent = stripeEvent.Data.Object as PaymentIntent;
        if (paymentIntent is null)
        {
            return;
        }

        var payment = await FindPaymentAsync(
            stripeSessionId: null,
            stripePaymentIntentId: paymentIntent.Id,
            metadata: paymentIntent.Metadata);
        if (payment is null)
        {
            _logger.LogInformation("Stripe payment intent {PaymentIntentId} succeeded but no payment record was found.", paymentIntent.Id);
            return;
        }

        payment.StripePaymentIntentId = paymentIntent.Id;
        await FulfillMembershipAsync(payment, paymentIntent.Metadata, $"payment intent {paymentIntent.Id}");
        await FulfillSessionReservationAsync(payment, paymentIntent.Metadata, $"payment intent {paymentIntent.Id}");
        payment.Status = PaymentStatus.Succeeded;
        payment.CompletedAt ??= DateTime.UtcNow;
        ApplySessionAccessWindow(payment, paymentIntent.Metadata);

        await _context.SaveChangesAsync();
    }

    private async Task HandlePaymentIntentFailedAsync(Event stripeEvent)
    {
        var paymentIntent = stripeEvent.Data.Object as PaymentIntent;
        if (paymentIntent is null)
        {
            return;
        }

        var payment = await FindPaymentAsync(
            stripeSessionId: null,
            stripePaymentIntentId: paymentIntent.Id,
            metadata: paymentIntent.Metadata);
        if (payment is null)
        {
            _logger.LogInformation("Stripe payment intent {PaymentIntentId} failed but no payment record was found.", paymentIntent.Id);
            return;
        }

        payment.StripePaymentIntentId = paymentIntent.Id;
        payment.Status = PaymentStatus.Failed;

        await _context.SaveChangesAsync();
    }

    private async Task<Payment?> FindPaymentAsync(
        string? stripeSessionId,
        string? stripePaymentIntentId,
        IDictionary<string, string>? metadata)
    {
        Payment? payment = null;

        if (!string.IsNullOrWhiteSpace(stripeSessionId) || !string.IsNullOrWhiteSpace(stripePaymentIntentId))
        {
            payment = await _context.Payments.FirstOrDefaultAsync(p =>
                (!string.IsNullOrWhiteSpace(stripeSessionId) && p.StripeSessionId == stripeSessionId) ||
                (!string.IsNullOrWhiteSpace(stripePaymentIntentId) && p.StripePaymentIntentId == stripePaymentIntentId));
        }

        if (payment is not null)
        {
            return payment;
        }

        if (!TryGetPaymentId(metadata, out var paymentId))
        {
            return null;
        }

        return await _context.Payments.FirstOrDefaultAsync(p => p.Id == paymentId);
    }

    private async Task FulfillMembershipAsync(
        Payment payment,
        IDictionary<string, string>? metadata,
        string source)
    {
        if (payment.Type != PaymentType.Membership)
        {
            return;
        }

        if (!TryBuildRenewMembershipDto(payment, metadata, out var dto))
        {
            _logger.LogWarning(
                "Stripe membership payment {PaymentId} from {Source} is missing membership metadata.",
                payment.Id,
                source);
            return;
        }

        await _membershipService.RenewFromPaymentAsync(payment.Id, dto);
    }

    private async Task FulfillSessionReservationAsync(
        Payment payment,
        IDictionary<string, string>? metadata,
        string source)
    {
        if (payment.Type != PaymentType.Session)
        {
            return;
        }

        var existingReservation = await _context.SessionReservations
            .AsNoTracking()
            .FirstOrDefaultAsync(r => r.PaymentId == payment.Id);

        if (existingReservation is not null)
        {
            return;
        }

        if (metadata is null ||
            !metadata.TryGetValue("trainingSessionId", out var sessionIdRaw) ||
            !int.TryParse(sessionIdRaw, out var trainingSessionId))
        {
            _logger.LogWarning(
                "Stripe session payment {PaymentId} from {Source} is missing trainingSessionId metadata.",
                payment.Id,
                source);
            return;
        }

        var session = await _context.TrainingSessions
            .Include(s => s.Reservations)
            .FirstOrDefaultAsync(s => s.Id == trainingSessionId && s.IsActive);

        if (session is null)
        {
            _logger.LogWarning(
                "Training session {TrainingSessionId} for payment {PaymentId} was not found or inactive.",
                trainingSessionId,
                payment.Id);
            return;
        }

        if (session.Reservations.Any(r => r.UserId == payment.UserId && r.Status == ReservationStatus.Confirmed))
        {
            return;
        }

        var confirmedCount = session.Reservations.Count(r => r.Status == ReservationStatus.Confirmed);
        if (confirmedCount >= session.MaxParticipants)
        {
            _logger.LogWarning(
                "Cannot fulfill payment {PaymentId}: training session {TrainingSessionId} is full.",
                payment.Id,
                trainingSessionId);
            return;
        }

        _context.SessionReservations.Add(new SessionReservation
        {
            UserId = payment.UserId,
            TrainingSessionId = trainingSessionId,
            PaymentId = payment.Id,
            Status = ReservationStatus.Confirmed,
            ReservedAt = DateTime.UtcNow,
        });
    }

    private static bool TryGetPaymentId(IDictionary<string, string>? metadata, out int paymentId)
    {
        paymentId = 0;
        return metadata is not null
            && metadata.TryGetValue("paymentId", out var paymentIdRaw)
            && int.TryParse(paymentIdRaw, out paymentId);
    }

    private static bool TryBuildRenewMembershipDto(
        Payment payment,
        IDictionary<string, string>? metadata,
        out RenewMembershipDto dto)
    {
        dto = default!;

        if (metadata is null ||
            !metadata.TryGetValue("membershipPlanId", out var planIdRaw) ||
            !int.TryParse(planIdRaw, out var planId))
        {
            return false;
        }

        var discountPercent = 0m;
        if (metadata.TryGetValue("discountPercent", out var discountRaw))
        {
            decimal.TryParse(
                discountRaw,
                System.Globalization.NumberStyles.Any,
                System.Globalization.CultureInfo.InvariantCulture,
                out discountPercent);
        }

        discountPercent = Math.Clamp(discountPercent, 0m, 100m);
        dto = new RenewMembershipDto(payment.UserId, planId, discountPercent);
        return true;
    }

    private static void ApplySessionAccessWindow(Payment payment, IDictionary<string, string>? metadata)
    {
        if (payment.Type != PaymentType.Session)
        {
            return;
        }

        if (!payment.SessionAccessDays.HasValue &&
            metadata is not null &&
            metadata.TryGetValue("sessionDurationDays", out var durationRaw) &&
            int.TryParse(durationRaw, out var metadataDays))
        {
            payment.SessionAccessDays = metadataDays;
        }

        var durationDays = payment.SessionAccessDays;
        if (!durationDays.HasValue || durationDays.Value <= 0)
        {
            return;
        }

        var start = payment.CompletedAt ?? DateTime.UtcNow;
        payment.SessionAccessUntil = start.AddDays(durationDays.Value);
    }
}
