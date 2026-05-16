namespace Gym.Core.Entities;

public class ShopOrderItem
{
    public int Id { get; set; }
    public string ProductNameSnapshot { get; set; } = null!;
    public decimal UnitPrice { get; set; }
    public int Quantity { get; set; }

    public int ShopOrderId { get; set; }
    public ShopOrder ShopOrder { get; set; } = null!;

    public int ShopProductId { get; set; }
    public ShopProduct ShopProduct { get; set; } = null!;
}
