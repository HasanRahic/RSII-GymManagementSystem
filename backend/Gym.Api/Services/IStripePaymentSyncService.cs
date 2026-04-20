using Gym.Core.Entities;

namespace Gym.Api.Services;

public interface IStripePaymentSyncService
{
    Task<Payment?> ReconcilePaymentAsync(int paymentId, int userId, CancellationToken cancellationToken = default);
    Task ReconcileLatestMembershipPaymentsAsync(int userId, CancellationToken cancellationToken = default);
}
