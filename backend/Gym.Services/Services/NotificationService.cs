using Gym.Core.Entities;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Gym.Services.Services;

public class NotificationService : INotificationService
{
    private readonly GymDbContext _context;

    public NotificationService(GymDbContext context) => _context = context;

    public async Task<IReadOnlyList<NotificationDto>> GetUserNotificationsAsync(int userId, bool unreadOnly = false, int page = 1, int pageSize = 20)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var query = _context.UserNotifications
            .AsNoTracking()
            .Where(n => n.UserId == userId);

        if (unreadOnly)
            query = query.Where(n => !n.IsRead);

        return await query
            .OrderByDescending(n => n.CreatedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(n => new NotificationDto(
                n.Id,
                n.Title,
                n.Message,
                n.Type,
                n.RelatedEntityType,
                n.RelatedEntityId,
                n.IsRead,
                n.CreatedAt,
                n.ReadAt))
            .ToListAsync();
    }

    public async Task<NotificationDto> CreateAsync(CreateNotificationDto dto)
    {
        var entity = new UserNotification
        {
            UserId = dto.UserId,
            Title = dto.Title.Trim(),
            Message = dto.Message.Trim(),
            Type = dto.Type.Trim(),
            RelatedEntityType = string.IsNullOrWhiteSpace(dto.RelatedEntityType) ? null : dto.RelatedEntityType.Trim(),
            RelatedEntityId = dto.RelatedEntityId,
            IsRead = false
        };

        _context.UserNotifications.Add(entity);
        await _context.SaveChangesAsync();
        return ToDto(entity);
    }

    public async Task<NotificationDto> MarkAsReadAsync(int userId, int notificationId)
    {
        var entity = await _context.UserNotifications
            .FirstOrDefaultAsync(n => n.Id == notificationId && n.UserId == userId)
            ?? throw new KeyNotFoundException("Notifikacija nije pronadjena.");

        if (!entity.IsRead)
        {
            entity.IsRead = true;
            entity.ReadAt = DateTime.UtcNow;
            await _context.SaveChangesAsync();
        }

        return ToDto(entity);
    }

    private static NotificationDto ToDto(UserNotification entity) => new(
        entity.Id,
        entity.Title,
        entity.Message,
        entity.Type,
        entity.RelatedEntityType,
        entity.RelatedEntityId,
        entity.IsRead,
        entity.CreatedAt,
        entity.ReadAt);
}
