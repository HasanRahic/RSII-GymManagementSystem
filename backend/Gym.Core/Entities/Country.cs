namespace Gym.Core.Entities;

public class Country
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string Code { get; set; } = null!;

    public ICollection<City> Cities { get; set; } = new List<City>();
}
