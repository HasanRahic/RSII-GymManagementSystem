using System.Security.Claims;
using Gym.Api.Services;
using Gym.Core.Entities;
using Gym.Core.Enums;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Stripe;
using Stripe.Checkout;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
[EnableRateLimiting("payments")]
public class PaymentsController(
    GymDbContext context,
    IStripePaymentSyncService stripePaymentSyncService) : ControllerBase
{
    [HttpGet("my")]
    public async Task<IActionResult> GetMyPayments([FromQuery] int take = 20)
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId))
        {
            return Unauthorized();
        }

        await stripePaymentSyncService.ReconcileLatestMembershipPaymentsAsync(userId);

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
                p.CompletedAt,
                p.SessionAccessDays,
                p.SessionAccessUntil
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

        var payment = await stripePaymentSyncService.ReconcilePaymentAsync(paymentId, userId);

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
        var metadata = new Dictionary<string, string>
        {
            ["paymentId"] = payment.Id.ToString(),
            ["userId"] = userId.ToString(),
            ["type"] = "Shop"
        };
        var options = new SessionCreateOptions
        {
            PaymentMethodTypes = new List<string> { "card" },
            LineItems = lineItems,
            Mode = "payment",
            SuccessUrl = $"{domainUrl}/checkout/success?session_id={{CHECKOUT_SESSION_ID}}",
            CancelUrl = $"{domainUrl}/checkout/cancel",
            CustomerEmail = userEmail,
            Metadata = metadata,
            PaymentIntentData = new SessionPaymentIntentDataOptions
            {
                Metadata = new Dictionary<string, string>(metadata)
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

        var metadata = new Dictionary<string, string>
        {
            ["paymentId"] = payment.Id.ToString(),
            ["userId"] = userId.ToString(),
            ["type"] = "Membership",
            ["membershipPlanId"] = plan.Id.ToString(),
            ["discountPercent"] = discountPercent.ToString(System.Globalization.CultureInfo.InvariantCulture)
        };

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
            Metadata = metadata,
            PaymentIntentData = new SessionPaymentIntentDataOptions
            {
                Metadata = new Dictionary<string, string>(metadata)
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

    [HttpPost("session-checkout")]
    public async Task<IActionResult> CreateSessionCheckout([FromBody] CreateCheckoutSessionDto dto)
    {
        if (dto.Type != PaymentType.Session || !dto.TrainingSessionId.HasValue)
        {
            return BadRequest(new { message = "Neispravan tip grupnog treninga." });
        }

        var durationDays = NormalizeSessionDuration(dto.SessionDurationDays);
        if (durationDays is null)
        {
            return BadRequest(new { message = "Neispravno trajanje grupnog treninga. Dozvoljeno: 30, 90, 180, 365 dana." });
        }

        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId))
        {
            return Unauthorized();
        }

        var trainingSession = await context.TrainingSessions
            .Include(s => s.Gym)
            .Include(s => s.Reservations)
            .FirstOrDefaultAsync(s => s.Id == dto.TrainingSessionId.Value && s.IsActive);

        if (trainingSession is null)
        {
            return NotFound(new { message = "Grupni trening nije pronađen." });
        }

        if (trainingSession.Reservations.Any(r => r.UserId == userId && r.Status == ReservationStatus.Confirmed))
        {
            return BadRequest(new { message = "Već ste prijavljeni na ovaj grupni trening." });
        }

        var activeReservations = trainingSession.Reservations.Count(r => r.Status == ReservationStatus.Confirmed);
        if (activeReservations >= trainingSession.MaxParticipants)
        {
            return BadRequest(new { message = "Grupni trening je popunjen." });
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

        var payment = new Payment
        {
            UserId = userId,
            Amount = CalculateSessionMembershipPrice(trainingSession.Price, durationDays.Value),
            Currency = "BAM",
            Type = PaymentType.Session,
            Status = PaymentStatus.Pending,
            CreatedAt = DateTime.UtcNow,
            SessionAccessDays = durationDays.Value,
        };

        context.Payments.Add(payment);
        await context.SaveChangesAsync();

        var metadata = new Dictionary<string, string>
        {
            ["paymentId"] = payment.Id.ToString(),
            ["userId"] = userId.ToString(),
            ["type"] = "Session",
            ["trainingSessionId"] = trainingSession.Id.ToString(),
            ["sessionDurationDays"] = durationDays.Value.ToString(),
        };

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
                            Name = trainingSession.Title,
                            Description = $"Grupni trening u {trainingSession.Gym.Name} ({durationDays} dana)"
                        },
                        UnitAmountDecimal = payment.Amount * 100m
                    },
                    Quantity = 1
                }
            },
            Mode = "payment",
            SuccessUrl = $"{Request.Scheme}://{Request.Host}/checkout/success?session_id={{CHECKOUT_SESSION_ID}}",
            CancelUrl = $"{Request.Scheme}://{Request.Host}/checkout/cancel",
            CustomerEmail = userEmail,
            Metadata = metadata,
            PaymentIntentData = new SessionPaymentIntentDataOptions
            {
                Metadata = new Dictionary<string, string>(metadata)
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

    private static int? NormalizeSessionDuration(int? durationDays)
    {
        return durationDays switch
        {
            30 => 30,
            90 => 90,
            180 => 180,
            365 => 365,
            _ => null,
        };
    }

    [HttpPost("{paymentId:int}/retry-checkout")]
    public async Task<IActionResult> RetryCheckout(int paymentId)
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId))
        {
            return Unauthorized();
        }

        var payment = await context.Payments.FirstOrDefaultAsync(p => p.Id == paymentId && p.UserId == userId);
        if (payment is null)
        {
            return NotFound(new { message = "Uplata nije pronađena." });
        }

        if (payment.Status != PaymentStatus.Failed)
        {
            return BadRequest(new { message = "Samo neuspješne uplate se mogu ponovno pokušati." });
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

        var lineItems = new List<SessionLineItemOptions>
        {
            new()
            {
                PriceData = new SessionLineItemPriceDataOptions
                {
                    Currency = "bam",
                    ProductData = new SessionLineItemPriceDataProductDataOptions
                    {
                        Name = "Pokušaj - Pretprethodna plaćanja",
                        Description = $"Pokušaj neuspješne uplate #{paymentId}"
                    },
                    UnitAmountDecimal = payment.Amount * 100m
                },
                Quantity = 1
            }
        };

        var newPayment = new Payment
        {
            UserId = userId,
            Amount = payment.Amount,
            Currency = payment.Currency,
            Type = payment.Type,
            Status = PaymentStatus.Pending,
            CreatedAt = DateTime.UtcNow,
            SessionAccessDays = payment.SessionAccessDays
        };

        context.Payments.Add(newPayment);
        await context.SaveChangesAsync();

        var metadata = new Dictionary<string, string>
        {
            ["paymentId"] = newPayment.Id.ToString(),
            ["userId"] = userId.ToString(),
            ["type"] = payment.Type.ToString(),
        };

        // Attempt to preserve original metadata for retries
        if (payment.Type == PaymentType.Membership)
        {
            var membershipPlanId = await context.UserMemberships
                .Where(m => m.PaymentId == paymentId)
                .Select(m => m.MembershipPlanId)
                .FirstOrDefaultAsync();

            if (membershipPlanId > 0)
            {
                metadata["membershipPlanId"] = membershipPlanId.ToString();
            }
        }
        else if (payment.Type == PaymentType.Session && payment.SessionAccessDays.HasValue)
        {
            var originalSessionId = await context.SessionReservations
                .Where(r => r.PaymentId == paymentId)
                .Select(r => r.TrainingSessionId)
                .FirstOrDefaultAsync();

            if (originalSessionId > 0)
            {
                metadata["trainingSessionId"] = originalSessionId.ToString();
                metadata["sessionDurationDays"] = payment.SessionAccessDays.Value.ToString();
            }
        }

        var options = new SessionCreateOptions
        {
            PaymentMethodTypes = new List<string> { "card" },
            LineItems = lineItems,
            Mode = "payment",
            SuccessUrl = $"{Request.Scheme}://{Request.Host}/checkout/success?session_id={{CHECKOUT_SESSION_ID}}",
            CancelUrl = $"{Request.Scheme}://{Request.Host}/checkout/cancel",
            CustomerEmail = userEmail,
            Metadata = metadata,
            PaymentIntentData = new SessionPaymentIntentDataOptions
            {
                Metadata = new Dictionary<string, string>(metadata)
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
            newPayment.Status = PaymentStatus.Failed;
            newPayment.CompletedAt = DateTime.UtcNow;
            await context.SaveChangesAsync();
            return BadRequest(new { message = $"Stripe greška: {ex.Message}" });
        }

        newPayment.StripeSessionId = session.Id;
        await context.SaveChangesAsync();

        return Ok(new StripeCheckoutDto(
            newPayment.Id,
            session.Url ?? string.Empty,
            newPayment.Amount
        ));
    }

    private static decimal CalculateSessionMembershipPrice(decimal monthlyBasePrice, int durationDays)
    {
        return durationDays switch
        {
            30 => monthlyBasePrice,
            90 => monthlyBasePrice * 3m * 0.93m,
            180 => monthlyBasePrice * 6m * 0.88m,
            365 => monthlyBasePrice * 12m * 0.80m,
            _ => monthlyBasePrice,
        };
    }
}
