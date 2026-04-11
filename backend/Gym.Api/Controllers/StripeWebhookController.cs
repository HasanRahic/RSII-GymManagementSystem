using Gym.Core.Enums;
using Gym.Infrastructure.Data;
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
    private readonly ILogger<StripeWebhookController> _logger;
    private readonly IConfiguration _configuration;

    public StripeWebhookController(
        GymDbContext context,
        ILogger<StripeWebhookController> logger,
        IConfiguration configuration)
    {
        _context = context;
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

        var payment = await _context.Payments.FirstOrDefaultAsync(p =>
            p.StripeSessionId == session.Id ||
            (!string.IsNullOrWhiteSpace(session.PaymentIntentId) && p.StripePaymentIntentId == session.PaymentIntentId));

        if (payment is null &&
            session.Metadata is not null &&
            session.Metadata.TryGetValue("paymentId", out var paymentIdRaw) &&
            int.TryParse(paymentIdRaw, out var paymentId))
        {
            payment = await _context.Payments.FirstOrDefaultAsync(p => p.Id == paymentId);
        }

        if (payment is null)
        {
            _logger.LogInformation("Stripe checkout session {SessionId} completed but no payment record was found.", session.Id);
            return;
        }

        payment.StripeSessionId = session.Id;
        payment.StripePaymentIntentId = session.PaymentIntentId ?? payment.StripePaymentIntentId;
        payment.Status = PaymentStatus.Succeeded;
        payment.CompletedAt ??= DateTime.UtcNow;

        await _context.SaveChangesAsync();
    }

    private async Task HandlePaymentIntentSucceededAsync(Event stripeEvent)
    {
        var paymentIntent = stripeEvent.Data.Object as PaymentIntent;
        if (paymentIntent is null)
        {
            return;
        }

        var payment = await _context.Payments.FirstOrDefaultAsync(p => p.StripePaymentIntentId == paymentIntent.Id);
        if (payment is null &&
            paymentIntent.Metadata is not null &&
            paymentIntent.Metadata.TryGetValue("paymentId", out var paymentIdRaw) &&
            int.TryParse(paymentIdRaw, out var paymentId))
        {
            payment = await _context.Payments.FirstOrDefaultAsync(p => p.Id == paymentId);
        }
        if (payment is null)
        {
            _logger.LogInformation("Stripe payment intent {PaymentIntentId} succeeded but no payment record was found.", paymentIntent.Id);
            return;
        }

        payment.StripePaymentIntentId = paymentIntent.Id;
        payment.Status = PaymentStatus.Succeeded;
        payment.CompletedAt ??= DateTime.UtcNow;

        await _context.SaveChangesAsync();
    }

    private async Task HandlePaymentIntentFailedAsync(Event stripeEvent)
    {
        var paymentIntent = stripeEvent.Data.Object as PaymentIntent;
        if (paymentIntent is null)
        {
            return;
        }

        var payment = await _context.Payments.FirstOrDefaultAsync(p => p.StripePaymentIntentId == paymentIntent.Id);
        if (payment is null &&
            paymentIntent.Metadata is not null &&
            paymentIntent.Metadata.TryGetValue("paymentId", out var paymentIdRaw) &&
            int.TryParse(paymentIdRaw, out var paymentId))
        {
            payment = await _context.Payments.FirstOrDefaultAsync(p => p.Id == paymentId);
        }
        if (payment is null)
        {
            _logger.LogInformation("Stripe payment intent {PaymentIntentId} failed but no payment record was found.", paymentIntent.Id);
            return;
        }

        payment.StripePaymentIntentId = paymentIntent.Id;
        payment.Status = PaymentStatus.Failed;

        await _context.SaveChangesAsync();
    }
}