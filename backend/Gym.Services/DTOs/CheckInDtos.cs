namespace Gym.Services.DTOs;

public record CheckInDto(
    int Id,
    int UserId,
    string UserFullName,
    int GymId,
    string GymName,
    DateTime CheckInTime,
    DateTime? CheckOutTime,
    int? DurationMinutes
);

public record CheckInRequestDto(int GymId);

public record CheckOutRequestDto(int CheckInId);
