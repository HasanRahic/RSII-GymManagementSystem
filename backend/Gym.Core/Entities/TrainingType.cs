namespace Gym.Core.Entities;

public class TrainingType
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string? Description { get; set; }

    public ICollection<TrainingSession> TrainingSessions { get; set; } = new List<TrainingSession>();
}
