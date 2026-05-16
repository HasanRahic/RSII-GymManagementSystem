using System.Globalization;
using Gym.Api.DTOs;
using Gym.Api.Messaging;
using Gym.Core.Entities;
using Gym.Core.Enums;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Stripe;
using Stripe.Checkout;

namespace Gym.Api.Services;

public sealed class PaymentAppService(
    GymDbContext context,
    IConfiguration configuration,
    INotificationService notificationService,
    INotificationPublisher notificationPublisher) : IPaymentAppService
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

    public async Task<StripeCheckoutDto> CreateMembershipCheckoutAsync(int userId, CreateCheckoutSessionDto dto, string domainUrl)
    {
        EnsureStripeConfigured();

        if (dto.Type != PaymentType.Membership || !dto.MembershipPlanId.HasValue)
            throw new InvalidOperationException("Neispravan tip clanarine.");

        var plan = await context.MembershipPlans
            .Include(p => p.Gym)
            .FirstOrDefaultAsync(p => p.Id == dto.MembershipPlanId.Value && p.IsActive)
            ?? throw new KeyNotFoundException("Plan clanarine nije pronadjen.");

        var userEmail = await RequireUserEmailAsync(userId);
        var totalAmount = plan.Price;

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
            ["membershipPlanId"] = plan.Id.ToString()
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
                            Description = $"Clanarina za {plan.Gym.Name}"
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
            throw new InvalidOperationException("Neispravan tip grupnog treninga.");

        var durationDays = NormalizeSessionDuration(dto.SessionDurationDays)
            ?? throw new InvalidOperationException("Neispravno trajanje grupnog treninga. Dozvoljeno: 30, 90, 180, 365 dana.");

        var trainingSession = await context.TrainingSessions
            .Include(s => s.Gym)
            .FirstOrDefaultAsync(s => s.Id == dto.TrainingSessionId.Value && s.IsActive)
            ?? throw new KeyNotFoundException("Grupni trening nije pronadjen.");

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

    public async Task<StripeCheckoutDto> CreateShopCheckoutAsync(int userId, CreateShopOrderDto dto, string domainUrl)
    {
        EnsureStripeConfigured();

        if (dto.Items is null || dto.Items.Count == 0)
            throw new InvalidOperationException("Narudzba mora sadrzavati barem jedan artikal.");

        var requestedItems = dto.Items
            .Where(item => item.ProductId.HasValue && item.Quantity > 0)
            .Select(item => new { ProductId = item.ProductId!.Value, item.Quantity })
            .ToList();

        if (requestedItems.Count == 0)
            throw new InvalidOperationException("Narudzba ne sadrzi validne artikle.");

        var distinctProductIds = requestedItems.Select(item => item.ProductId).Distinct().ToList();
        var products = await context.ShopProducts
            .Include(p => p.Gym)
            .Where(p => distinctProductIds.Contains(p.Id) && p.IsActive)
            .ToListAsync();

        if (products.Count != distinctProductIds.Count)
            throw new InvalidOperationException("Jedan ili vise proizvoda iz korpe vise nisu dostupni.");

        var gymId = products.First().GymId;
        if (products.Any(p => p.GymId != gymId))
            throw new InvalidOperationException("Shop narudzba moze sadrzavati proizvode samo iz jedne teretane.");

        var checkoutItems = new List<(ShopProduct Product, int Quantity)>();
        foreach (var item in requestedItems)
        {
            var product = products.First(p => p.Id == item.ProductId);
            if (product.StockQuantity < item.Quantity)
                throw new InvalidOperationException($"Proizvod \"{product.Name}\" nema dovoljno zaliha.");

            checkoutItems.Add((product, item.Quantity));
        }

        var totalAmount = checkoutItems.Sum(item => item.Product.Price * item.Quantity);
        if (totalAmount <= 0m)
            throw new InvalidOperationException("Ukupan iznos shop narudzbe mora biti veci od nule.");

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

        var order = new ShopOrder
        {
            PaymentId = payment.Id,
            Payment = payment,
            UserId = userId,
            GymId = gymId,
            TotalAmount = totalAmount,
            Items = checkoutItems.Select(item => new ShopOrderItem
            {
                ShopProductId = item.Product.Id,
                ProductNameSnapshot = item.Product.Name,
                UnitPrice = item.Product.Price,
                Quantity = item.Quantity
            }).ToList()
        };

        context.ShopOrders.Add(order);
        await context.SaveChangesAsync();

        var itemSummary = string.Join(", ", checkoutItems.Select(item => $"{item.Product.Name} x{item.Quantity}"));
        var metadata = new Dictionary<string, string>
        {
            ["paymentId"] = payment.Id.ToString(),
            ["userId"] = userId.ToString(),
            ["type"] = PaymentType.Shop.ToString(),
            ["shopOrderId"] = order.Id.ToString(),
            ["shopGymId"] = gymId.ToString(),
            ["shopItemCount"] = checkoutItems.Count.ToString(CultureInfo.InvariantCulture),
            ["shopSummary"] = itemSummary.Length <= 500 ? itemSummary : itemSummary[..500]
        };

        var session = await CreateCheckoutSessionAsync(
            payment,
            userEmail,
            domainUrl,
            checkoutItems.Select(item => new SessionLineItemOptions
            {
                PriceData = new SessionLineItemPriceDataOptions
                {
                    Currency = "bam",
                    ProductData = new SessionLineItemPriceDataProductDataOptions
                    {
                        Name = item.Product.Name,
                        Description = "Shop artikal iz teretane"
                    },
                    UnitAmountDecimal = item.Product.Price * 100m
                },
                Quantity = item.Quantity
            }).ToList(),
            metadata);

        return new StripeCheckoutDto(payment.Id, session.Url ?? string.Empty, payment.Amount);
    }

    public async Task<StripeCheckoutDto> RetryCheckoutAsync(int userId, int paymentId, string domainUrl)
    {
        EnsureStripeConfigured();

        var payment = await context.Payments.FirstOrDefaultAsync(p => p.Id == paymentId && p.UserId == userId)
            ?? throw new KeyNotFoundException("Uplata nije pronadjena.");

        if (payment.Status != PaymentStatus.Failed)
            throw new InvalidOperationException("Samo neuspjesne uplate se mogu ponovno pokusati.");

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
                metadata["membershipPlanId"] = membershipPlanId.ToString();
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
        else if (payment.Type == PaymentType.Shop)
        {
            var originalOrder = await context.ShopOrders
                .Include(o => o.Items)
                .FirstOrDefaultAsync(o => o.PaymentId == paymentId);

            if (originalOrder is not null)
            {
                var clonedOrder = new ShopOrder
                {
                    PaymentId = newPayment.Id,
                    UserId = originalOrder.UserId,
                    GymId = originalOrder.GymId,
                    TotalAmount = originalOrder.TotalAmount,
                    Items = originalOrder.Items.Select(item => new ShopOrderItem
                    {
                        ShopProductId = item.ShopProductId,
                        ProductNameSnapshot = item.ProductNameSnapshot,
                        UnitPrice = item.UnitPrice,
                        Quantity = item.Quantity
                    }).ToList()
                };

                context.ShopOrders.Add(clonedOrder);
                await context.SaveChangesAsync();

                metadata["shopOrderId"] = clonedOrder.Id.ToString();
                metadata["shopGymId"] = clonedOrder.GymId.ToString();
                metadata["shopItemCount"] = clonedOrder.Items.Count.ToString(CultureInfo.InvariantCulture);
                var summary = string.Join(", ", clonedOrder.Items.Select(item => $"{item.ProductNameSnapshot} x{item.Quantity}"));
                metadata["shopSummary"] = summary.Length <= 500 ? summary : summary[..500];
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
                            Name = "Pokusaj - prethodna placanja",
                            Description = $"Pokusaj neuspjesne uplate #{paymentId}"
                        },
                        UnitAmountDecimal = payment.Amount * 100m
                    },
                    Quantity = 1
                }
            ],
            metadata);

        return new StripeCheckoutDto(newPayment.Id, session.Url ?? string.Empty, newPayment.Amount);
    }

    public async Task<PaymentStatusDto> RefundPaymentAsync(int paymentId, int adminUserId, string? reason)
    {
        EnsureStripeConfigured();

        var payment = await context.Payments
            .Include(p => p.UserMembership)
            .Include(p => p.SessionReservation)
            .FirstOrDefaultAsync(p => p.Id == paymentId)
            ?? throw new KeyNotFoundException("Uplata nije pronadjena.");

        if (payment.Status != PaymentStatus.Succeeded)
            throw new InvalidOperationException("Refund je dozvoljen samo za uspjesno zavrsene uplate.");

        if (string.IsNullOrWhiteSpace(payment.StripePaymentIntentId))
            throw new InvalidOperationException("Za ovu uplatu nije evidentiran Stripe payment intent.");

        var refundService = new RefundService();
        await refundService.CreateAsync(new RefundCreateOptions
        {
            PaymentIntent = payment.StripePaymentIntentId,
            Reason = "requested_by_customer",
            Metadata = new Dictionary<string, string>
            {
                ["paymentId"] = payment.Id.ToString(),
                ["userId"] = payment.UserId.ToString(),
                ["adminUserId"] = adminUserId.ToString(),
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

        await notificationService.CreateAsync(new CreateNotificationDto(
            payment.UserId,
            "Uplata refundirana",
            $"Vasa uplata #{payment.Id} je refundirana.",
            "PaymentRefunded",
            "Payment",
            payment.Id));

        await SendEmailNotificationAsync(
            payment.UserId,
            "Refundirana uplata",
            $"Vasa uplata #{payment.Id} je refundirana i status je azuriran u sistemu.");

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
            throw new InvalidOperationException("Korisnik nema validan email za Stripe checkout.");

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

    private async Task SendEmailNotificationAsync(int userId, string subject, string body)
    {
        var user = await context.Users
            .AsNoTracking()
            .Where(u => u.Id == userId)
            .Select(u => new { u.Email, FullName = u.FirstName + " " + u.LastName })
            .FirstOrDefaultAsync();

        if (user is null || string.IsNullOrWhiteSpace(user.Email))
            return;

        await notificationPublisher.PublishAsync(new NotificationMessage(
            user.Email,
            subject,
            $"Pozdrav {user.FullName},\n\n{body}"));
    }
}
