using System.Globalization;
using Gym.Api.DTOs;
using Gym.Core.Entities;
using Gym.Core.Enums;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Microsoft.EntityFrameworkCore;
using Stripe;
using Stripe.Checkout;

namespace Gym.Api.Services;

public sealed class PaymentAppService(
    GymDbContext context,
    IConfiguration configuration) : IPaymentAppService
{
    public async Task<IReadOnlyList<PaymentListItemDto>> GetMyPaymentsAsync(int userId, int page, int pageSize, int? take = null)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(take ?? pageSize, 1, 100);
        var skip = (page - 1) * pageSize;

        return await context.Payments
            .AsNoTracking()
            .Where(p => p.UserId == userId)
            .OrderByDescending(p => p.CreatedAt)
            .Skip(skip)
            .Take(pageSize)
            .Select(p => new PaymentListItemDto(
                p.Id,
                p.Type,
                p.Status,
                p.Amount,
                p.Currency,
                p.CreatedAt,
                p.CompletedAt,
                p.SessionAccessDays,
                p.SessionAccessUntil))
            .ToListAsync();
    }

    public async Task<StripeCheckoutDto> CreateShopOrderAsync(int userId, CreateShopOrderDto dto, string domainUrl)
    {
        EnsureStripeConfigured();

        if (dto.Items is null || dto.Items.Count == 0)
        {
            throw new InvalidOperationException("Korpa je prazna.");
        }

        var hasInvalidItem = dto.Items.Any(i =>
            string.IsNullOrWhiteSpace(i.Name) || i.UnitPrice <= 0 || i.Quantity <= 0);
        if (hasInvalidItem)
        {
            throw new InvalidOperationException("Artikli u korpi nisu validni.");
        }

        var totalAmount = dto.Items.Sum(i => i.UnitPrice * i.Quantity);
        var userEmail = await RequireUserEmailAsync(userId);

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

        var lineItems = dto.Items.Select(item => new SessionLineItemOptions
        {
            PriceData = new SessionLineItemPriceDataOptions
            {
                Currency = "bam",
                ProductData = new SessionLineItemPriceDataProductDataOptions
                {
                    Name = item.Name,
                    Description = "Artikal iz shop-a"
                },
                UnitAmountDecimal = item.UnitPrice * 100m
            },
            Quantity = item.Quantity
        }).ToList();

        var metadata = new Dictionary<string, string>
        {
            ["paymentId"] = payment.Id.ToString(),
            ["userId"] = userId.ToString(),
            ["type"] = "Shop"
        };

        var session = await CreateCheckoutSessionAsync(payment, userEmail, domainUrl, lineItems, metadata);
        return new StripeCheckoutDto(payment.Id, session.Url ?? string.Empty, payment.Amount);
    }

    public async Task<StripeCheckoutDto> CreateMembershipCheckoutAsync(int userId, CreateCheckoutSessionDto dto, string domainUrl)
    {
        EnsureStripeConfigured();

        if (dto.Type != PaymentType.Membership || !dto.MembershipPlanId.HasValue)
        {
            throw new InvalidOperationException("Neispravan tip članarine.");
        }

        var plan = await context.MembershipPlans
            .Include(p => p.Gym)
            .FirstOrDefaultAsync(p => p.Id == dto.MembershipPlanId.Value)
            ?? throw new KeyNotFoundException("Plan članarine nije pronađen.");

        var userEmail = await RequireUserEmailAsync(userId);
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
            ["discountPercent"] = discountPercent.ToString(CultureInfo.InvariantCulture)
        };

        var session = await CreateCheckoutSessionAsync(
            payment,
            userEmail,
            domainUrl,
            [
                new SessionLineItemOptions
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
            ],
            metadata);

        return new StripeCheckoutDto(payment.Id, session.Url ?? string.Empty, payment.Amount);
    }

    public async Task<StripeCheckoutDto> CreateSessionCheckoutAsync(int userId, CreateCheckoutSessionDto dto, string domainUrl)
    {
        EnsureStripeConfigured();

        if (dto.Type != PaymentType.Session || !dto.TrainingSessionId.HasValue)
        {
            throw new InvalidOperationException("Neispravan tip grupnog treninga.");
        }

        var durationDays = NormalizeSessionDuration(dto.SessionDurationDays)
            ?? throw new InvalidOperationException("Neispravno trajanje grupnog treninga. Dozvoljeno: 30, 90, 180, 365 dana.");

        var trainingSession = await context.TrainingSessions
            .Include(s => s.Gym)
            .FirstOrDefaultAsync(s => s.Id == dto.TrainingSessionId.Value && s.IsActive)
            ?? throw new KeyNotFoundException("Grupni trening nije pronađen.");

        var userEmail = await RequireUserEmailAsync(userId);

        var payment = new Payment
        {
            UserId = userId,
            Amount = CalculateSessionMembershipPrice(trainingSession.Price, durationDays),
            Currency = "BAM",
            Type = PaymentType.Session,
            Status = PaymentStatus.Pending,
            CreatedAt = DateTime.UtcNow,
            SessionAccessDays = durationDays
        };

        context.Payments.Add(payment);
        await context.SaveChangesAsync();

        var metadata = new Dictionary<string, string>
        {
            ["paymentId"] = payment.Id.ToString(),
            ["userId"] = userId.ToString(),
            ["type"] = "Session",
            ["trainingSessionId"] = trainingSession.Id.ToString(),
            ["sessionDurationDays"] = durationDays.ToString(CultureInfo.InvariantCulture)
        };

        var session = await CreateCheckoutSessionAsync(
            payment,
            userEmail,
            domainUrl,
            [
                new SessionLineItemOptions
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
            ],
            metadata);

        return new StripeCheckoutDto(payment.Id, session.Url ?? string.Empty, payment.Amount);
    }

    public async Task<StripeCheckoutDto> RetryCheckoutAsync(int userId, int paymentId, string domainUrl)
    {
        EnsureStripeConfigured();

        var payment = await context.Payments.FirstOrDefaultAsync(p => p.Id == paymentId && p.UserId == userId)
            ?? throw new KeyNotFoundException("Uplata nije pronađena.");

        if (payment.Status != PaymentStatus.Failed)
        {
            throw new InvalidOperationException("Samo neuspješne uplate se mogu ponovno pokušati.");
        }

        var userEmail = await RequireUserEmailAsync(userId);

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
            ["type"] = payment.Type.ToString()
        };

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
                metadata["sessionDurationDays"] = payment.SessionAccessDays.Value.ToString(CultureInfo.InvariantCulture);
            }
        }

        var session = await CreateCheckoutSessionAsync(
            newPayment,
            userEmail,
            domainUrl,
            [
                new SessionLineItemOptions
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
            ],
            metadata);

        return new StripeCheckoutDto(newPayment.Id, session.Url ?? string.Empty, newPayment.Amount);
    }

    public async Task<PaymentStatusDto> RefundPaymentAsync(int userId, int paymentId, string? reason)
    {
        EnsureStripeConfigured();

        var payment = await context.Payments
            .Include(p => p.UserMembership)
            .Include(p => p.SessionReservation)
            .FirstOrDefaultAsync(p => p.Id == paymentId && p.UserId == userId)
            ?? throw new KeyNotFoundException("Uplata nije pronađena.");

        if (payment.Status != PaymentStatus.Succeeded)
        {
            throw new InvalidOperationException("Refund je dozvoljen samo za uspješno završene uplate.");
        }

        if (string.IsNullOrWhiteSpace(payment.StripePaymentIntentId))
        {
            throw new InvalidOperationException("Za ovu uplatu nije evidentiran Stripe payment intent.");
        }

        var refundService = new RefundService();
        await refundService.CreateAsync(new RefundCreateOptions
        {
            PaymentIntent = payment.StripePaymentIntentId,
            Reason = "requested_by_customer",
            Metadata = new Dictionary<string, string>
            {
                ["paymentId"] = payment.Id.ToString(),
                ["userId"] = payment.UserId.ToString(),
                ["note"] = string.IsNullOrWhiteSpace(reason) ? "Manual refund" : reason
            }
        });

        payment.Status = PaymentStatus.Refunded;
        payment.CompletedAt ??= DateTime.UtcNow;
        payment.SessionAccessUntil = null;

        if (payment.UserMembership is not null)
        {
            payment.UserMembership.Status = MembershipStatus.Cancelled;
            payment.UserMembership.EndDate = DateTime.UtcNow;
        }

        if (payment.SessionReservation is not null)
        {
            payment.SessionReservation.Status = ReservationStatus.Cancelled;
        }

        await context.SaveChangesAsync();

        return new PaymentStatusDto(payment.Id, payment.Status, payment.CreatedAt, payment.CompletedAt);
    }

    private async Task<string> RequireUserEmailAsync(int userId)
    {
        var userEmail = await context.Users
            .AsNoTracking()
            .Where(u => u.Id == userId)
            .Select(u => u.Email)
            .FirstOrDefaultAsync();

        if (string.IsNullOrWhiteSpace(userEmail))
        {
            throw new InvalidOperationException("Korisnik nema validan email za Stripe checkout.");
        }

        return userEmail;
    }

    private void EnsureStripeConfigured()
    {
        var secretKey = configuration["Stripe:SecretKey"];
        if (string.IsNullOrWhiteSpace(secretKey) ||
            secretKey.Contains("your_key_here", StringComparison.OrdinalIgnoreCase) ||
            secretKey.Contains("placeholder", StringComparison.OrdinalIgnoreCase))
        {
            throw new InvalidOperationException(
                "Stripe nije konfigurisan. Postavi pravi STRIPE_SECRET_KEY u root .env fajl prije testiranja checkout-a.");
        }
    }

    private async Task<Session> CreateCheckoutSessionAsync(
        Payment payment,
        string userEmail,
        string domainUrl,
        List<SessionLineItemOptions> lineItems,
        Dictionary<string, string> metadata)
    {
        var options = new SessionCreateOptions
        {
            PaymentMethodTypes = ["card"],
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

        try
        {
            var sessionService = new SessionService();
            var session = await sessionService.CreateAsync(options);
            payment.StripeSessionId = session.Id;
            await context.SaveChangesAsync();
            return session;
        }
        catch (StripeException)
        {
            payment.Status = PaymentStatus.Failed;
            payment.CompletedAt = DateTime.UtcNow;
            await context.SaveChangesAsync();
            throw;
        }
    }

    private static int? NormalizeSessionDuration(int? durationDays) => durationDays switch
    {
        30 => 30,
        90 => 90,
        180 => 180,
        365 => 365,
        _ => null
    };

    private static decimal CalculateSessionMembershipPrice(decimal monthlyBasePrice, int durationDays) => durationDays switch
    {
        30 => monthlyBasePrice,
        90 => monthlyBasePrice * 3m * 0.93m,
        180 => monthlyBasePrice * 6m * 0.88m,
        365 => monthlyBasePrice * 12m * 0.80m,
        _ => monthlyBasePrice
    };
}
