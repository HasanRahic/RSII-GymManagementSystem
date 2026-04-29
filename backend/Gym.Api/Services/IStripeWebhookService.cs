namespace Gym.Api.Services;

public interface IStripeWebhookService
{
    Task HandleAsync(string payload, string signatureHeader);
}
