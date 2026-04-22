using Gym.Core.Enums;

namespace Gym.Services.DTOs;

public record PaymentDto(
    int Id,
    int UserId,
    string UserFullName,
    decimal Amount,
    string Currency,
    PaymentType Type,
    PaymentStatus Status,
    string? StripeSessionId,
    DateTime CreatedAt,
    DateTime? CompletedAt
);

public record CreateCheckoutSessionDto(
    PaymentType Type,
    int? MembershipPlanId,
    int? TrainingSessionId,
    decimal DiscountPercent,
    int? SessionDurationDays
);

public record CheckoutSessionResultDto(
    string SessionId,
    string Url
);

public record ShopOrderItemDto(
    string Name,
    decimal UnitPrice,
    int Quantity
);

public record CreateShopOrderDto(
    List<ShopOrderItemDto> Items
);

public record ShopOrderResultDto(
    int PaymentId,
    decimal TotalAmount,
    PaymentStatus Status,
    DateTime CreatedAt,
    DateTime? CompletedAt
);

public record StripeCheckoutDto(
    int PaymentId,
    string SessionUrl,
    decimal Amount
);

public record PaymentStatusDto(
    int PaymentId,
    PaymentStatus Status,
    DateTime CreatedAt,
    DateTime? CompletedAt
);

public record PaymentListItemDto(
    int PaymentId,
    PaymentType Type,
    PaymentStatus Status,
    decimal Amount,
    string Currency,
    DateTime CreatedAt,
    DateTime? CompletedAt,
    int? SessionAccessDays,
    DateTime? SessionAccessUntil
);

public record AccessStatusDto(
    bool HasActiveMembership,
    bool HasActiveGroupTrainingAccess,
    bool HasGymAccess,
    DateTime? GroupAccessUntil
);

// Reference DTOs
public record CityDto(int Id, string Name, string? PostalCode, int CountryId, string CountryName);
public record CountryDto(int Id, string Name, string Code);
public record TrainingTypeDto(int Id, string Name, string? Description);
public record BadgeDto(int Id, string Name, string Description, string? IconUrl, string Type, int RequiredCount);
public record UserBadgeDto(int BadgeId, string BadgeName, string BadgeDescription, string? IconUrl, DateTime EarnedAt);

public record DashboardStatsDto(
    int TotalMembers,
    int ActiveMemberships,
    int TotalCheckInsToday,
    int CurrentOccupancy,
    decimal RevenueThisMonth,
    int PendingTrainerApplications
);
