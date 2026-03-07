using Gym.Core.Enums;

namespace Gym.Core.Entities;

public class User
{
    public int Id { get; set; }
    public string FirstName { get; set; } = null!;
    public string LastName { get; set; } = null!;
    public string Email { get; set; } = null!;
    public string Username { get; set; } = null!;
    public byte[] PasswordHash { get; set; } = null!;
    public byte[] PasswordSalt { get; set; } = null!;
    public string? PhoneNumber { get; set; }
    public DateTime? DateOfBirth { get; set; }
    public string? ProfileImageUrl { get; set; }
    public UserRole Role { get; set; } = UserRole.Member;
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public int? CityId { get; set; }
    public City? City { get; set; }

    public int? PrimaryGymId { get; set; }
    public GymFacility? PrimaryGym { get; set; }

    public ICollection<UserMembership> Memberships { get; set; } = new List<UserMembership>();
    public ICollection<CheckIn> CheckIns { get; set; } = new List<CheckIn>();
    public ICollection<TrainerApplication> TrainerApplications { get; set; } = new List<TrainerApplication>();
    public ICollection<TrainingSession> TrainingSessions { get; set; } = new List<TrainingSession>();
    public ICollection<SessionReservation> Reservations { get; set; } = new List<SessionReservation>();
    public ICollection<ProgressMeasurement> ProgressMeasurements { get; set; } = new List<ProgressMeasurement>();
    public ICollection<UserBadge> UserBadges { get; set; } = new List<UserBadge>();
    public ICollection<Payment> Payments { get; set; } = new List<Payment>();
}
