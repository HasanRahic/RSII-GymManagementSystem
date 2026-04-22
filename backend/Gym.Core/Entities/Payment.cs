using Gym.Core.Enums;

namespace Gym.Core.Entities;

public class Payment
{
    public int Id { get; set; }
    public decimal Amount { get; set; }
    public string Currency { get; set; } = "BAM";
    public PaymentType Type { get; set; }
    public PaymentStatus Status { get; set; } = PaymentStatus.Pending;
    public string? StripePaymentIntentId { get; set; }
    public string? StripeSessionId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? CompletedAt { get; set; }
    public int? SessionAccessDays { get; set; }
    public DateTime? SessionAccessUntil { get; set; }

    public int UserId { get; set; }
    public User User { get; set; } = null!;

    public UserMembership? UserMembership { get; set; }
    public SessionReservation? SessionReservation { get; set; }
}
