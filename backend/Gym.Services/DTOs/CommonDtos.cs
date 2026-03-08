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
    decimal DiscountPercent
);

public record CheckoutSessionResultDto(
    string SessionId,
    string Url
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
