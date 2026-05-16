using System.ComponentModel.DataAnnotations;
using Gym.Core.Enums;

namespace Gym.Services.DTOs;

public record GymDto(
    int Id,
    string Name,
    string Address,
    string? Description,
    string? PhoneNumber,
    string? Email,
    string? ImageUrl,
    TimeOnly OpenTime,
    TimeOnly CloseTime,
    int Capacity,
    int CurrentOccupancy,
    GymStatus Status,
    double? Latitude,
    double? Longitude,
    int CityId,
    string CityName,
    string CountryName
);

public record CreateGymDto(
    [Required, StringLength(100, MinimumLength = 2)]
    string Name,
    [Required, StringLength(200, MinimumLength = 5)]
    string Address,
    [StringLength(1000)]
    string? Description,
    [Phone]
    string? PhoneNumber,
    [EmailAddress]
    string? Email,
    TimeOnly OpenTime,
    TimeOnly CloseTime,
    [Range(1, 100000)]
    int Capacity,
    [Range(1, int.MaxValue)]
    int CityId,
    double? Latitude,
    double? Longitude
);

public record UpdateGymDto(
    [Required, StringLength(100, MinimumLength = 2)]
    string Name,
    [Required, StringLength(200, MinimumLength = 5)]
    string Address,
    [StringLength(1000)]
    string? Description,
    [Phone]
    string? PhoneNumber,
    [EmailAddress]
    string? Email,
    TimeOnly OpenTime,
    TimeOnly CloseTime,
    [Range(1, 100000)]
    int Capacity,
    [Range(1, int.MaxValue)]
    int CityId,
    GymStatus Status,
    double? Latitude,
    double? Longitude
);
