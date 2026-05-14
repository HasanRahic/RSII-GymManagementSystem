namespace Gym.Services.DTOs;

public record NotificationDto(
    int Id,
    string Title,
    string Message,
    string Type,
    string? RelatedEntityType,
    int? RelatedEntityId,
    bool IsRead,
    DateTime CreatedAt,
    DateTime? ReadAt
);

public record CreateNotificationDto(
    int UserId,
    string Title,
    string Message,
    string Type,
    string? RelatedEntityType = null,
    int? RelatedEntityId = null
);
