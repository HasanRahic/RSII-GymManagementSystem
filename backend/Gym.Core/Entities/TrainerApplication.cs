using Gym.Core.Enums;

namespace Gym.Core.Entities;

public class TrainerApplication
{
    public int Id { get; set; }
    public string Biography { get; set; } = null!;
    public string Experience { get; set; } = null!;
    public string? Certifications { get; set; }
    public string? Availability { get; set; }
    public ApplicationStatus Status { get; set; } = ApplicationStatus.Pending;
    public string? AdminNote { get; set; }
    public DateTime SubmittedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ReviewedAt { get; set; }

    public int UserId { get; set; }
    public User User { get; set; } = null!;

    public int? ReviewedByAdminId { get; set; }
    public User? ReviewedByAdmin { get; set; }
}
