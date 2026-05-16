using System.ComponentModel.DataAnnotations;

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
    [DataType(DataType.Date)]
    DateTime Date,
    [Range(0.1, 1000d)]
    double? WeightKg,
    [Range(0d, 100d)]
    double? BodyFatPercent,
    [Range(0d, 500d)]
    double? ChestCm,
    [Range(0d, 500d)]
    double? WaistCm,
    [Range(0d, 500d)]
    double? HipsCm,
    [Range(0d, 200d)]
    double? ArmCm,
    [Range(0d, 300d)]
    double? LegCm,
    [StringLength(1000)]
    string? Notes
);
