using System.ComponentModel.DataAnnotations;
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
    int? SessionDurationDays
);

public record CheckoutSessionResultDto(
    string SessionId,
    string Url
);

public record ShopOrderItemDto(
    int? ProductId,
    [Required, StringLength(120, MinimumLength = 2)] string Name,
    decimal UnitPrice,
    [Range(1, 99)] int Quantity
);

public record CreateShopOrderDto(
    [Required, MinLength(1)] List<ShopOrderItemDto> Items
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

public record ShopProductDto(
    int Id,
    string Name,
    string Category,
    string? Description,
    decimal Price,
    int StockQuantity,
    string? Emoji,
    bool IsActive,
    int GymId,
    string GymName
);

public record CreateShopProductDto(
    [Required, StringLength(120, MinimumLength = 2)] string Name,
    [Required, StringLength(80, MinimumLength = 2)] string Category,
    [StringLength(500)] string? Description,
    decimal Price,
    [Range(0, 100000)] int StockQuantity,
    [StringLength(16)] string? Emoji,
    [Range(1, int.MaxValue)] int GymId,
    bool IsActive = true
);

public record UpdateShopProductDto(
    [Required, StringLength(120, MinimumLength = 2)] string Name,
    [Required, StringLength(80, MinimumLength = 2)] string Category,
    [StringLength(500)] string? Description,
    decimal Price,
    [Range(0, 100000)] int StockQuantity,
    [StringLength(16)] string? Emoji,
    [Range(1, int.MaxValue)] int GymId,
    bool IsActive
);

// Reference DTOs
public record CityDto(int Id, string Name, string? PostalCode, int CountryId, string CountryName);
public record CountryDto(int Id, string Name, string Code);
public record TrainingTypeDto(int Id, string Name, string? Description);
public record CreateCountryDto(
    [Required, StringLength(100, MinimumLength = 2)] string Name,
    [Required, StringLength(10, MinimumLength = 2)] string Code);
public record UpdateCountryDto(
    [Required, StringLength(100, MinimumLength = 2)] string Name,
    [Required, StringLength(10, MinimumLength = 2)] string Code);
public record CreateCityDto(
    [Required, StringLength(100, MinimumLength = 2)] string Name,
    [StringLength(20)] string? PostalCode,
    [Range(1, int.MaxValue)] int CountryId);
public record UpdateCityDto(
    [Required, StringLength(100, MinimumLength = 2)] string Name,
    [StringLength(20)] string? PostalCode,
    [Range(1, int.MaxValue)] int CountryId);
public record CreateTrainingTypeDto(
    [Required, StringLength(100, MinimumLength = 2)] string Name,
    [StringLength(500)] string? Description);
public record UpdateTrainingTypeDto(
    [Required, StringLength(100, MinimumLength = 2)] string Name,
    [StringLength(500)] string? Description);
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
