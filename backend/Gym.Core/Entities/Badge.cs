using Gym.Core.Enums;

namespace Gym.Core.Entities;

public class Badge
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string Description { get; set; } = null!;
    public string? IconUrl { get; set; }
    public BadgeType Type { get; set; }
    public int RequiredCount { get; set; }

    public ICollection<UserBadge> UserBadges { get; set; } = new List<UserBadge>();
}
