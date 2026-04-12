using System.Security.Claims;
using Gym.Core.Entities;
using Gym.Core.Enums;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Stripe;
using Stripe.Checkout;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class PaymentsController(GymDbContext context) : ControllerBase
{
    [HttpGet("my")]
    public async Task<IActionResult> GetMyPayments([FromQuery] int take = 20)
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId))
        {
            return Unauthorized();
        }

        take = Math.Clamp(take, 1, 100);

        var items = await context.Payments
            .AsNoTracking()
            .Where(p => p.UserId == userId)
            .OrderByDescending(p => p.CreatedAt)
            .Take(take)
            .Select(p => new PaymentListItemDto(
                p.Id,
                p.Type,
                p.Status,
                p.Amount,
                p.Currency,
                p.CreatedAt,
                p.CompletedAt
            ))
            .ToListAsync();

        return Ok(items);
    }

    [HttpGet("{paymentId:int}/status")]
    public async Task<IActionResult> GetStatus(int paymentId)
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId))
        {
            return Unauthorized();
        }

        var payment = await context.Payments
            .AsNoTracking()
            .FirstOrDefaultAsync(p => p.Id == paymentId && p.UserId == userId);

        if (payment is null)
        {
            return NotFound(new { message = "Uplata nije pronađena." });
        }

        return Ok(new PaymentStatusDto(
            payment.Id,
            payment.Status,
            payment.CreatedAt,
            payment.CompletedAt
        ));
    }

    [HttpPost("shop-order")]
    public async Task<IActionResult> CreateShopOrder([FromBody] CreateShopOrderDto dto)
    {
        if (dto.Items is null || dto.Items.Count == 0)
        {
            return BadRequest(new { message = "Korpa je prazna." });
        }

        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId))
        {
            return Unauthorized();
        }

        var hasInvalidItem = dto.Items.Any(i =>
            string.IsNullOrWhiteSpace(i.Name) || i.UnitPrice <= 0 || i.Quantity <= 0);
        if (hasInvalidItem)
        {
            return BadRequest(new { message = "Artikli u korpi nisu validni." });
        }

        var totalAmount = dto.Items.Sum(i => i.UnitPrice * i.Quantity);

        var userEmail = await context.Users
            .AsNoTracking()
            .Where(u => u.Id == userId)
            .Select(u => u.Email)
            .FirstOrDefaultAsync();

        if (string.IsNullOrWhiteSpace(userEmail))
        {
            return BadRequest(new { message = "Korisnik nema validan email za Stripe checkout." });
        }

        var payment = new Payment
        {
            UserId = userId,
            Amount = totalAmount,
            Currency = "BAM",
            Type = PaymentType.Shop,
            Status = PaymentStatus.Pending,
            CreatedAt = DateTime.UtcNow
        };

        context.Payments.Add(payment);
        await context.SaveChangesAsync();

        // Create Stripe line items from cart items
        var lineItems = dto.Items.Select(item => new SessionLineItemOptions
        {
            PriceData = new SessionLineItemPriceDataOptions
            {
                Currency = "bam", // Stripe uses lowercase for currency codes
                ProductData = new SessionLineItemPriceDataProductDataOptions
                {
                    Name = item.Name,
                    Description = $"Artikal iz shop-a"
                },
                UnitAmountDecimal = item.UnitPrice * 100m // Stripe expects amount in cents
            },
            Quantity = item.Quantity
        }).ToList();

        // Create Stripe Checkout Session
        var domainUrl = $"{Request.Scheme}://{Request.Host}";
        var options = new SessionCreateOptions
        {
            PaymentMethodTypes = new List<string> { "card" },
            LineItems = lineItems,
            Mode = "payment",
            SuccessUrl = $"{domainUrl}/checkout/success?session_id={{CHECKOUT_SESSION_ID}}",
            CancelUrl = $"{domainUrl}/checkout/cancel",
            CustomerEmail = userEmail,
            Metadata = new Dictionary<string, string>
            {
                ["paymentId"] = payment.Id.ToString(),
                ["userId"] = userId.ToString(),
                ["type"] = "Shop"
            }
        };

        Session session;
        try
        {
            var sessionService = new SessionService();
            session = await sessionService.CreateAsync(options);
        }
        catch (StripeException ex)
        {
            payment.Status = PaymentStatus.Failed;
            payment.CompletedAt = DateTime.UtcNow;
            await context.SaveChangesAsync();
            return BadRequest(new { message = $"Stripe greška: {ex.Message}" });
        }

        payment.StripeSessionId = session.Id;
        await context.SaveChangesAsync();

        return Ok(new StripeCheckoutDto(
            payment.Id,
            session.Url ?? string.Empty,
            payment.Amount
        ));
    }

    [HttpPost("membership-checkout")]
    public async Task<IActionResult> CreateMembershipCheckout([FromBody] CreateCheckoutSessionDto dto)
    {
        if (dto.Type != PaymentType.Membership || !dto.MembershipPlanId.HasValue)
        {
            return BadRequest(new { message = "Neispravan tip članarine." });
        }

        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId))
        {
            return Unauthorized();
        }

        var plan = await context.MembershipPlans
            .Include(p => p.Gym)
            .FirstOrDefaultAsync(p => p.Id == dto.MembershipPlanId.Value);

        if (plan is null)
        {
            return NotFound(new { message = "Plan članarine nije pronađen." });
        }

        var userEmail = await context.Users
            .AsNoTracking()
            .Where(u => u.Id == userId)
            .Select(u => u.Email)
            .FirstOrDefaultAsync();

        if (string.IsNullOrWhiteSpace(userEmail))
        {
            return BadRequest(new { message = "Korisnik nema validan email za Stripe checkout." });
        }

        var discountPercent = Math.Clamp(dto.DiscountPercent, 0, 100);
        var totalAmount = plan.Price * (1 - discountPercent / 100m);

        var payment = new Payment
        {
            UserId = userId,
            Amount = totalAmount,
            Currency = "BAM",
            Type = PaymentType.Membership,
            Status = PaymentStatus.Pending,
            CreatedAt = DateTime.UtcNow
        };

        context.Payments.Add(payment);
        await context.SaveChangesAsync();

        var options = new SessionCreateOptions
        {
            PaymentMethodTypes = new List<string> { "card" },
            LineItems = new List<SessionLineItemOptions>
            {
                new()
                {
                    PriceData = new SessionLineItemPriceDataOptions
                    {
                        Currency = "bam",
                        ProductData = new SessionLineItemPriceDataProductDataOptions
                        {
                            Name = plan.Name,
                            Description = $"Članarina za {plan.Gym.Name}"
                        },
                        UnitAmountDecimal = totalAmount * 100m
                    },
                    Quantity = 1
                }
            },
            Mode = "payment",
            SuccessUrl = $"{Request.Scheme}://{Request.Host}/checkout/success?session_id={{CHECKOUT_SESSION_ID}}",
            CancelUrl = $"{Request.Scheme}://{Request.Host}/checkout/cancel",
            CustomerEmail = userEmail,
            Metadata = new Dictionary<string, string>
            {
                ["paymentId"] = payment.Id.ToString(),
                ["userId"] = userId.ToString(),
                ["type"] = "Membership",
                ["membershipPlanId"] = plan.Id.ToString(),
                ["discountPercent"] = discountPercent.ToString(System.Globalization.CultureInfo.InvariantCulture)
            }
        };

        Session session;
        try
        {
            var sessionService = new SessionService();
            session = await sessionService.CreateAsync(options);
        }
        catch (StripeException ex)
        {
            payment.Status = PaymentStatus.Failed;
            payment.CompletedAt = DateTime.UtcNow;
            await context.SaveChangesAsync();
            return BadRequest(new { message = $"Stripe greška: {ex.Message}" });
        }

        payment.StripeSessionId = session.Id;
        await context.SaveChangesAsync();

        return Ok(new StripeCheckoutDto(
            payment.Id,
            session.Url ?? string.Empty,
            payment.Amount
        ));
    }
}
