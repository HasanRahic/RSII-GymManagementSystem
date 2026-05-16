namespace Gym.Core.Entities;

public class ShopProduct
{
    public int Id { get; set; }
    public string Name { get; set; } = null!;
    public string Category { get; set; } = null!;
    public string? Description { get; set; }
    public decimal Price { get; set; }
    public int StockQuantity { get; set; }
    public string? Emoji { get; set; }
    public bool IsActive { get; set; } = true;
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    public int GymId { get; set; }
    public GymFacility Gym { get; set; } = null!;

    public ICollection<ShopOrderItem> OrderItems { get; set; } = new List<ShopOrderItem>();
}
