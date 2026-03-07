namespace Gym.Core.Entities;

public class City
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string? PostalCode { get; set; }

    public int CountryId { get; set; }
    public Country Country { get; set; } = null!;

    public ICollection<User> Users { get; set; } = new List<User>();
    public ICollection<GymFacility> Gyms { get; set; } = new List<GymFacility>();
}
