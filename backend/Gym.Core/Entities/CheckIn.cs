namespace Gym.Core.Entities;

public class CheckIn
{
    public int Id { get; set; }
    public DateTime CheckInTime { get; set; } = DateTime.UtcNow;
    public DateTime? CheckOutTime { get; set; }

    public int UserId { get; set; }
    public User User { get; set; } = null!;

    public int GymId { get; set; }
    public GymFacility Gym { get; set; } = null!;

    public int? DurationMinutes =>
        CheckOutTime.HasValue
            ? (int)(CheckOutTime.Value - CheckInTime).TotalMinutes
            : null;
}
