namespace Gym.Core.Entities;

public class ProgressMeasurement
{
    public int Id { get; set; }
    public DateTime Date { get; set; } = DateTime.UtcNow;
    public double? WeightKg { get; set; }
    public double? BodyFatPercent { get; set; }
    public double? ChestCm { get; set; }
    public double? WaistCm { get; set; }
    public double? HipsCm { get; set; }
    public double? ArmCm { get; set; }
    public double? LegCm { get; set; }
    public string? Notes { get; set; }

    public int UserId { get; set; }
    public User User { get; set; } = null!;
}
