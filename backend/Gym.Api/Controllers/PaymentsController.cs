using Gym.Api.DTOs;
using Gym.Api.Extensions;
using Gym.Api.Services;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Mvc;
using Stripe;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
[EnableRateLimiting("payments")]
public class PaymentsController(
    IPaymentAppService paymentAppService,
    IStripePaymentSyncService stripePaymentSyncService) : ControllerBase
{
    [HttpGet("my")]
    public async Task<IActionResult> GetMyPayments(
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20,
        [FromQuery] int? take = null)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue)
        {
            return Unauthorized();
        }

        await stripePaymentSyncService.ReconcileLatestMembershipPaymentsAsync(userId.Value);
        return Ok(await paymentAppService.GetMyPaymentsAsync(userId.Value, page, pageSize, take));
    }

    [HttpGet("{paymentId:int}/status")]
    public async Task<IActionResult> GetStatus(int paymentId)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue)
        {
            return Unauthorized();
        }

        var payment = await stripePaymentSyncService.ReconcilePaymentAsync(paymentId, userId.Value);
        if (payment is null)
        {
            return NotFound(new { message = "Uplata nije pronađena." });
        }

        return Ok(new PaymentStatusDto(payment.Id, payment.Status, payment.CreatedAt, payment.CompletedAt));
    }

    [HttpPost("shop-order")]
    public async Task<IActionResult> CreateShopOrder([FromBody] CreateShopOrderDto dto)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue)
        {
            return Unauthorized();
        }

        try
        {
            var result = await paymentAppService.CreateShopOrderAsync(userId.Value, dto, GetDomainUrl());
            return Ok(result);
        }
        catch (StripeException ex)
        {
            return BadRequest(new { message = $"Stripe greška: {ex.Message}" });
        }
    }

    [HttpPost("membership-checkout")]
    public async Task<IActionResult> CreateMembershipCheckout([FromBody] CreateCheckoutSessionDto dto)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue)
        {
            return Unauthorized();
        }

        try
        {
            var result = await paymentAppService.CreateMembershipCheckoutAsync(userId.Value, dto, GetDomainUrl());
            return Ok(result);
        }
        catch (StripeException ex)
        {
            return BadRequest(new { message = $"Stripe greška: {ex.Message}" });
        }
    }

    [HttpPost("session-checkout")]
    public async Task<IActionResult> CreateSessionCheckout([FromBody] CreateCheckoutSessionDto dto)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue)
        {
            return Unauthorized();
        }

        try
        {
            var result = await paymentAppService.CreateSessionCheckoutAsync(userId.Value, dto, GetDomainUrl());
            return Ok(result);
        }
        catch (StripeException ex)
        {
            return BadRequest(new { message = $"Stripe greška: {ex.Message}" });
        }
    }

    [HttpPost("{paymentId:int}/retry-checkout")]
    public async Task<IActionResult> RetryCheckout(int paymentId)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue)
        {
            return Unauthorized();
        }

        try
        {
            var result = await paymentAppService.RetryCheckoutAsync(userId.Value, paymentId, GetDomainUrl());
            return Ok(result);
        }
        catch (StripeException ex)
        {
            return BadRequest(new { message = $"Stripe greška: {ex.Message}" });
        }
    }

    [HttpPost("{paymentId:int}/refund")]
    public async Task<IActionResult> RefundPayment(int paymentId, [FromBody] RefundPaymentDto? dto)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue)
        {
            return Unauthorized();
        }

        try
        {
            var result = await paymentAppService.RefundPaymentAsync(userId.Value, paymentId, dto?.Reason);
            return Ok(result);
        }
        catch (StripeException ex)
        {
            return BadRequest(new { message = $"Stripe refund greška: {ex.Message}" });
        }
    }

    private string GetDomainUrl() => $"{Request.Scheme}://{Request.Host}";
}
