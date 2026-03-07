using Gym.Core.Enums;

namespace Gym.Core.Entities;

public class UserMembership
{
    public int Id { get; set; }
    public DateTime StartDate { get; set; }
    public DateTime EndDate { get; set; }
    public decimal Price { get; set; }
    public decimal DiscountPercent { get; set; } = 0;
    public MembershipStatus Status { get; set; } = MembershipStatus.Active;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public int UserId { get; set; }
    public User User { get; set; } = null!;

    public int MembershipPlanId { get; set; }
    public MembershipPlan MembershipPlan { get; set; } = null!;

    public int GymId { get; set; }
    public GymFacility Gym { get; set; } = null!;

    public int? PaymentId { get; set; }
    public Payment? Payment { get; set; }
}
