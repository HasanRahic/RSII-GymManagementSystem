namespace Gym.Notifications.Models;

public record NotificationMessage(
    string To,
    string Subject,
    string Body,
    NotificationType Type = NotificationType.Email
);

public enum NotificationType
{
    Email
}
