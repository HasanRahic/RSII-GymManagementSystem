using Gym.Core.Entities;
using Gym.Core.Enums;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Stripe;

namespace Gym.Api.Services;

public class StripePaymentSyncService(
    GymDbContext context,
    IMembershipService membershipService,
    ILogger<StripePaymentSyncService> logger) : IStripePaymentSyncService
{
    private readonly GymDbContext _context = context;
    private readonly IMembershipService _membershipService = membershipService;
    private readonly ILogger<StripePaymentSyncService> _logger = logger;

    public async Task<Payment?> ReconcilePaymentAsync(int paymentId, int userId, CancellationToken cancellationToken = default)
    {
        var payment = await _context.Payments
            .FirstOrDefaultAsync(p => p.Id == paymentId && p.UserId == userId, cancellationToken);

        if (payment is null)
        {
            return null;
        }

        await ReconcilePaymentInternalAsync(payment, cancellationToken);
        return payment;
    }

    public async Task ReconcileLatestMembershipPaymentsAsync(int userId, CancellationToken cancellationToken = default)
    {
        var candidatePayments = await _context.Payments
            .Where(p => p.UserId == userId
                && p.Type == PaymentType.Membership
                && p.UserMembership == null
                && (p.Status == PaymentStatus.Pending || p.Status == PaymentStatus.Succeeded)
                && p.CreatedAt >= DateTime.UtcNow.AddDays(-7))
            .OrderByDescending(p => p.CreatedAt)
            .Take(3)
            .ToListAsync(cancellationToken);

        foreach (var payment in candidatePayments)
        {
            await ReconcilePaymentInternalAsync(payment, cancellationToken);
        }
    }

    private async Task ReconcilePaymentInternalAsync(Payment payment, CancellationToken cancellationToken)
    {
        if (string.IsNullOrWhiteSpace(StripeConfiguration.ApiKey))
        {
            return;
        }

        Stripe.Checkout.Session? session = null;
        PaymentIntent? paymentIntent = null;

        if (!string.IsNullOrWhiteSpace(payment.StripeSessionId))
        {
            try
            {
                var sessionService = new Stripe.Checkout.SessionService();
                session = await sessionService.GetAsync(
                    payment.StripeSessionId,
                    options: null,
                    requestOptions: null,
                    cancellationToken: cancellationToken);
            }
            catch (StripeException ex)
            {
                _logger.LogWarning(ex, "Unable to fetch Stripe session {SessionId} for payment {PaymentId}.", payment.StripeSessionId, payment.Id);
            }
        }

        if (!string.IsNullOrWhiteSpace(session?.PaymentIntentId))
        {
            payment.StripePaymentIntentId = session.PaymentIntentId;
        }

        if (!string.IsNullOrWhiteSpace(payment.StripePaymentIntentId))
        {
            try
            {
                var paymentIntentService = new PaymentIntentService();
                paymentIntent = await paymentIntentService.GetAsync(
                    payment.StripePaymentIntentId,
                    options: null,
                    requestOptions: null,
                    cancellationToken: cancellationToken);
            }
            catch (StripeException ex)
            {
                _logger.LogWarning(ex, "Unable to fetch Stripe payment intent {PaymentIntentId} for payment {PaymentId}.", payment.StripePaymentIntentId, payment.Id);
            }
        }

        var isPaid =
            string.Equals(session?.PaymentStatus, "paid", StringComparison.OrdinalIgnoreCase) ||
            string.Equals(paymentIntent?.Status, "succeeded", StringComparison.OrdinalIgnoreCase);

        if (!isPaid)
        {
            return;
        }

        var metadata = session?.Metadata ?? paymentIntent?.Metadata;

        if (payment.Type == PaymentType.Membership &&
            TryBuildRenewMembershipDto(payment, metadata, out var renewDto))
        {
            await _membershipService.RenewFromPaymentAsync(payment.Id, renewDto);
        }

        payment.Status = PaymentStatus.Succeeded;
        payment.CompletedAt ??= DateTime.UtcNow;
        await _context.SaveChangesAsync(cancellationToken);
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
}
