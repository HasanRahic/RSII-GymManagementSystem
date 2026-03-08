using Gym.Core.Enums;

namespace Gym.Services.DTOs;

public record TrainerApplicationDto(
    int Id,
    int UserId,
    string UserFullName,
    string UserEmail,
    string Biography,
    string Experience,
    string? Certifications,
    string? Availability,
    ApplicationStatus Status,
    string? AdminNote,
    DateTime SubmittedAt,
    DateTime? ReviewedAt
);

public record CreateTrainerApplicationDto(
    string Biography,
    string Experience,
    string? Certifications,
    string? Availability
);

public record ReviewApplicationDto(
    ApplicationStatus Status,
    string? AdminNote
);
