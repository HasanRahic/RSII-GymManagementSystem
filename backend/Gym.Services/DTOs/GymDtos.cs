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
    string Name,
    string Address,
    string? Description,
    string? PhoneNumber,
    string? Email,
    TimeOnly OpenTime,
    TimeOnly CloseTime,
    int Capacity,
    int CityId,
    double? Latitude,
    double? Longitude
);

public record UpdateGymDto(
    string Name,
    string Address,
    string? Description,
    string? PhoneNumber,
    string? Email,
    TimeOnly OpenTime,
    TimeOnly CloseTime,
    int Capacity,
    int CityId,
    GymStatus Status,
    double? Latitude,
    double? Longitude
);
