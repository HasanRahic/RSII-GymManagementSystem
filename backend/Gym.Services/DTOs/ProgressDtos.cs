namespace Gym.Services.DTOs;

public record ProgressMeasurementDto(
    int Id,
    int UserId,
    DateTime Date,
    double? WeightKg,
    double? BodyFatPercent,
    double? ChestCm,
    double? WaistCm,
    double? HipsCm,
    double? ArmCm,
    double? LegCm,
    string? Notes
);

public record CreateProgressMeasurementDto(
    DateTime Date,
    double? WeightKg,
    double? BodyFatPercent,
    double? ChestCm,
    double? WaistCm,
    double? HipsCm,
    double? ArmCm,
    double? LegCm,
    string? Notes
);
