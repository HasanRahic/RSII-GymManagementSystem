using Gym.Core.Enums;

namespace Gym.Core.Entities;

public class GymFacility
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string Address { get; set; } = null!;
    public string? Description { get; set; }
    public string? PhoneNumber { get; set; }
    public string? Email { get; set; }
    public string? ImageUrl { get; set; }
    public TimeOnly OpenTime { get; set; }
    public TimeOnly CloseTime { get; set; }
    public int Capacity { get; set; }
    public int CurrentOccupancy { get; set; } = 0;
    public GymStatus Status { get; set; } = GymStatus.Open;
    public double? Latitude { get; set; }
    public double? Longitude { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public int CityId { get; set; }
    public City City { get; set; } = null!;

    public ICollection<MembershipPlan> MembershipPlans { get; set; } = new List<MembershipPlan>();
    public ICollection<UserMembership> UserMemberships { get; set; } = new List<UserMembership>();
    public ICollection<CheckIn> CheckIns { get; set; } = new List<CheckIn>();
    public ICollection<TrainingSession> TrainingSessions { get; set; } = new List<TrainingSession>();
    public ICollection<User> PrimaryMembers { get; set; } = new List<User>();
}
