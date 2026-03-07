namespace Gym.Core.Entities;

public class MembershipPlan
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string? Description { get; set; }
    public int DurationDays { get; set; }
    public decimal Price { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public int GymId { get; set; }
    public GymFacility Gym { get; set; } = null!;

    public ICollection<UserMembership> UserMemberships { get; set; } = new List<UserMembership>();
}
