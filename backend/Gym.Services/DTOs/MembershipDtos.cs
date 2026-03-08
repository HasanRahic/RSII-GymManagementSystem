using Gym.Core.Enums;

namespace Gym.Services.DTOs;

public record MembershipPlanDto(
    int Id,
    string Name,
    string? Description,
    int DurationDays,
    decimal Price,
    bool IsActive,
    int GymId,
    string GymName
);

public record CreateMembershipPlanDto(
    string Name,
    string? Description,
    int DurationDays,
    decimal Price,
    int GymId
);

public record UpdateMembershipPlanDto(
    string Name,
    string? Description,
    int DurationDays,
    decimal Price,
    bool IsActive
);

public record UserMembershipDto(
    int Id,
    int UserId,
    string UserFullName,
    int MembershipPlanId,
    string PlanName,
    int GymId,
    string GymName,
    DateTime StartDate,
    DateTime EndDate,
    decimal Price,
    decimal DiscountPercent,
    MembershipStatus Status,
    int DaysRemaining
);

public record RenewMembershipDto(
    int UserId,
    int MembershipPlanId,
    decimal DiscountPercent
);
