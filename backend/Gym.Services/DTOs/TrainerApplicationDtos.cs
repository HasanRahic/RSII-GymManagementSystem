using System.ComponentModel.DataAnnotations;
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
    [property: Required, StringLength(2000, MinimumLength = 20)]
    string Biography,
    [property: Required, StringLength(2000, MinimumLength = 10)]
    string Experience,
    [property: StringLength(1000)]
    string? Certifications,
    [property: StringLength(1000)]
    string? Availability
);

public record ReviewApplicationDto(
    ApplicationStatus Status,
    [property: StringLength(1000)]
    string? AdminNote
);
