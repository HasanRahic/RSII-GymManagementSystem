using Gym.Api.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Stripe;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/stripe")]
[AllowAnonymous]
public class StripeWebhookController(
    IStripeWebhookService stripeWebhookService,
    ILogger<StripeWebhookController> logger) : ControllerBase
{
    [HttpPost("webhook")]
    public async Task<IActionResult> Webhook()
    {
        var signatureHeader = Request.Headers["Stripe-Signature"].ToString();

        string payload;
        using (var reader = new StreamReader(Request.Body))
        {
            payload = await reader.ReadToEndAsync();
        }

        try
        {
            await stripeWebhookService.HandleAsync(payload, signatureHeader);
            return Ok();
        }
        catch (StripeException ex)
        {
            logger.LogWarning(ex, "Invalid Stripe webhook signature.");
            return BadRequest(new { message = "Invalid Stripe webhook signature." });
        }
    }
}
