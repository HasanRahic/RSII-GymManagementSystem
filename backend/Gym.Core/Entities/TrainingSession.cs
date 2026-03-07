using Gym.Core.Enums;

namespace Gym.Core.Entities;

public class TrainingSession
{
    public int Id { get; set; }
    public string Title { get; set; } = null!;
    public string? Description { get; set; }
    public SessionType Type { get; set; }
    public DateTime Date { get; set; }
    public TimeOnly StartTime { get; set; }
    public TimeOnly EndTime { get; set; }
    public int MaxParticipants { get; set; }
    public decimal Price { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public int TrainerId { get; set; }
    public User Trainer { get; set; } = null!;

    public int GymId { get; set; }
    public GymFacility Gym { get; set; } = null!;

    public int TrainingTypeId { get; set; }
    public TrainingType TrainingType { get; set; } = null!;

    public ICollection<SessionReservation> Reservations { get; set; } = new List<SessionReservation>();
}
