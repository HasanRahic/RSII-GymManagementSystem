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
    string Title,
    string? Description,
    SessionType Type,
    DateTime Date,
    TimeOnly StartTime,
    TimeOnly EndTime,
    int MaxParticipants,
    decimal Price,
    int GymId,
    int TrainingTypeId
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
