namespace Gym.Core.Entities;

public class UserBadge
{
    public int Id { get; set; }
    public DateTime EarnedAt { get; set; } = DateTime.UtcNow;

    public int UserId { get; set; }
    public User User { get; set; } = null!;

    public int BadgeId { get; set; }
    public Badge Badge { get; set; } = null!;
}
