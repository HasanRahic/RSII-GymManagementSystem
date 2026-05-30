using System.ComponentModel.DataAnnotations;
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
    [Required, StringLength(100, MinimumLength = 2)]
    string Name,
    [StringLength(500)]
    string? Description,
    [Range(1, 3650)]
    int DurationDays,
    [Range(typeof(decimal), "0.01", "1000000")]
    decimal Price,
    [Range(1, int.MaxValue)]
    int GymId
);

public record UpdateMembershipPlanDto(
    [Required, StringLength(100, MinimumLength = 2)]
    string Name,
    [StringLength(500)]
    string? Description,
    [Range(1, 3650)]
    int DurationDays,
    [Range(typeof(decimal), "0.01", "1000000")]
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
    int MembershipPlanId
);
