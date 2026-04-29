using Gym.Api.DTOs;
using Gym.Services.DTOs;

namespace Gym.Api.Services;

public interface IPaymentAppService
{
    Task<IReadOnlyList<PaymentListItemDto>> GetMyPaymentsAsync(int userId, int page, int pageSize, int? take = null);
    Task<StripeCheckoutDto> CreateShopOrderAsync(int userId, CreateShopOrderDto dto, string domainUrl);
    Task<StripeCheckoutDto> CreateMembershipCheckoutAsync(int userId, CreateCheckoutSessionDto dto, string domainUrl);
    Task<StripeCheckoutDto> CreateSessionCheckoutAsync(int userId, CreateCheckoutSessionDto dto, string domainUrl);
    Task<StripeCheckoutDto> RetryCheckoutAsync(int userId, int paymentId, string domainUrl);
    Task<PaymentStatusDto> RefundPaymentAsync(int userId, int paymentId, string? reason);
}
