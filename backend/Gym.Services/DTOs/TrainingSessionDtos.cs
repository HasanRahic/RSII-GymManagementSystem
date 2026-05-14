using System.ComponentModel.DataAnnotations;
using Gym.Core.Enums;

namespace Gym.Services.DTOs;

public record TrainingSessionDto(
    int Id,
    string Title,
    string? Description,
    SessionType Type,
    DateTime Date,
    TimeOnly StartTime,
    TimeOnly EndTime,
    int MaxParticipants,
    int CurrentParticipants,
    decimal Price,
    bool IsActive,
    int TrainerId,
    string TrainerFullName,
    int GymId,
    string GymName,
    int TrainingTypeId,
    string TrainingTypeName
);

public record CreateTrainingSessionDto(
    [property: Required, StringLength(100, MinimumLength = 3)]
    string Title,
    [property: StringLength(500)]
    string? Description,
    SessionType Type,
    [property: DataType(DataType.Date)]
    DateTime Date,
    TimeOnly StartTime,
    TimeOnly EndTime,
    [property: Range(1, 500)]
    int MaxParticipants,
    [property: Range(typeof(decimal), "0", "1000000")]
    decimal Price,
    [property: Range(1, int.MaxValue)]
    int GymId,
    [property: Range(1, int.MaxValue)]
    int TrainingTypeId,
    int? TrainerId = null
);

public record SessionReservationDto(
    int Id,
    int UserId,
    string UserFullName,
    int TrainingSessionId,
    string SessionTitle,
    DateTime SessionDate,
    ReservationStatus Status,
    DateTime ReservedAt
);

public record RecommendedGymDto(
    int GymId,
    string GymName,
    double Score,
    string Reason,
    IReadOnlyList<string> MatchedTrainingTypes
);

public record TrainerProfileDto(
    int TrainerId,
    string FullName,
    string? Biography,
    string? Experience,
    string? Certifications,
    string? Availability,
    string? PhoneNumber,
    string? Email,
    string? CityName,
    double Rating,
    int SessionCount,
    int GroupSessionCount,
    int GymCount,
    int CityCount,
    DateTime? NextAvailableAt,
    IReadOnlyList<string> TrainingTypes,
    IReadOnlyList<string> GymNames,
    IReadOnlyList<string> CityNames
);
