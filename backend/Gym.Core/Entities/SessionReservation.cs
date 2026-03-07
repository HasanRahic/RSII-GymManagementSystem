using Gym.Core.Enums;

namespace Gym.Core.Entities;

public class SessionReservation
{
    public int Id { get; set; }
    public DateTime ReservedAt { get; set; } = DateTime.UtcNow;
    public ReservationStatus Status { get; set; } = ReservationStatus.Confirmed;

    public int UserId { get; set; }
    public User User { get; set; } = null!;

    public int TrainingSessionId { get; set; }
    public TrainingSession TrainingSession { get; set; } = null!;

    public int? PaymentId { get; set; }
    public Payment? Payment { get; set; }
}
