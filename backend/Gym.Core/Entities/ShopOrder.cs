namespace Gym.Core.Entities;

public class ShopOrder
{
    public int Id { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? FulfilledAt { get; set; }
    public decimal TotalAmount { get; set; }

    public int UserId { get; set; }
    public User User { get; set; } = null!;

    public int GymId { get; set; }
    public GymFacility Gym { get; set; } = null!;

    public int PaymentId { get; set; }
    public Payment Payment { get; set; } = null!;

    public ICollection<ShopOrderItem> Items { get; set; } = new List<ShopOrderItem>();
}
