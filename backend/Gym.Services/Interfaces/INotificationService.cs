using Gym.Services.DTOs;

namespace Gym.Services.Interfaces;

public interface INotificationService
{
    Task<IReadOnlyList<NotificationDto>> GetUserNotificationsAsync(int userId, bool unreadOnly = false, int page = 1, int pageSize = 20);
    Task<NotificationDto> CreateAsync(CreateNotificationDto dto);
    Task<NotificationDto> MarkAsReadAsync(int userId, int notificationId);
}
