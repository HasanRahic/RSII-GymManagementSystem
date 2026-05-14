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
    [property: DataType(DataType.Date)]
    DateTime Date,
    [property: Range(0.1, 1000d)]
    double? WeightKg,
    [property: Range(0d, 100d)]
    double? BodyFatPercent,
    [property: Range(0d, 500d)]
    double? ChestCm,
    [property: Range(0d, 500d)]
    double? WaistCm,
    [property: Range(0d, 500d)]
    double? HipsCm,
    [property: Range(0d, 200d)]
    double? ArmCm,
    [property: Range(0d, 300d)]
    double? LegCm,
    [property: StringLength(1000)]
    string? Notes
);
