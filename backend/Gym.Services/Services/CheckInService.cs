using Gym.Core.Entities;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Gym.Services.Services;

public class CheckInService : ICheckInService
{
    private readonly GymDbContext _context;

    public CheckInService(GymDbContext context) => _context = context;

    public async Task<CheckInDto> CheckInAsync(int userId, CheckInRequestDto dto)
    {
        var active = await _context.CheckIns
            .FirstOrDefaultAsync(c => c.UserId == userId && c.CheckOutTime == null);
        if (active is not null)
            throw new InvalidOperationException("Već ste prijavljeni u teretani. Najprije se odjavite.");

        var gym = await _context.Gyms.FindAsync(dto.GymId)
            ?? throw new KeyNotFoundException("Teretana nije pronađena.");

        var checkIn = new CheckIn { UserId = userId, GymId = dto.GymId };
        _context.CheckIns.Add(checkIn);
        gym.CurrentOccupancy++;
        await _context.SaveChangesAsync();

        return await LoadDto(checkIn.Id);
    }

    public async Task<CheckInDto> CheckOutAsync(int userId, CheckOutRequestDto dto)
    {
        var checkIn = await _context.CheckIns.Include(c => c.Gym)
            .FirstOrDefaultAsync(c => c.Id == dto.CheckInId && c.UserId == userId)
            ?? throw new KeyNotFoundException("Check-in nije pronađen.");

        if (checkIn.CheckOutTime.HasValue)
            throw new InvalidOperationException("Već ste se odjavili.");

        checkIn.CheckOutTime = DateTime.UtcNow;
        if (checkIn.Gym.CurrentOccupancy > 0)
            checkIn.Gym.CurrentOccupancy--;

        await _context.SaveChangesAsync();

        // Award badges
        await AwardBadgesAsync(userId);

        return await LoadDto(checkIn.Id);
    }

    public async Task<IEnumerable<CheckInDto>> GetUserHistoryAsync(int userId, DateTime? from, DateTime? to)
    {
        var query = _context.CheckIns
            .Include(c => c.User)
            .Include(c => c.Gym)
            .Where(c => c.UserId == userId);

        if (from.HasValue) query = query.Where(c => c.CheckInTime >= from.Value);
        if (to.HasValue)   query = query.Where(c => c.CheckInTime <= to.Value);

        var list = await query.OrderByDescending(c => c.CheckInTime).ToListAsync();
        return list.Select(ToDto);
    }

    public async Task<IEnumerable<CheckInDto>> GetGymCheckInsAsync(int gymId, DateTime? date)
    {
        var query = _context.CheckIns
            .Include(c => c.User)
            .Include(c => c.Gym)
            .Where(c => c.GymId == gymId);

        if (date.HasValue)
            query = query.Where(c => c.CheckInTime.Date == date.Value.Date);

        var list = await query.OrderByDescending(c => c.CheckInTime).ToListAsync();
        return list.Select(ToDto);
    }

    public async Task<CheckInDto?> GetActiveCheckInAsync(int userId)
    {
        var c = await _context.CheckIns
            .Include(c => c.User).Include(c => c.Gym)
            .FirstOrDefaultAsync(c => c.UserId == userId && c.CheckOutTime == null);

        return c is null ? null : ToDto(c);
    }

    private async Task<CheckInDto> LoadDto(int id)
    {
        var c = await _context.CheckIns
            .Include(c => c.User).Include(c => c.Gym)
            .FirstAsync(c => c.Id == id);
        return ToDto(c);
    }

    private async Task AwardBadgesAsync(int userId)
    {
        var totalVisits  = await _context.CheckIns.CountAsync(c => c.UserId == userId && c.CheckOutTime != null);
        var earnedBadges = await _context.UserBadges.Where(ub => ub.UserId == userId).Select(ub => ub.BadgeId).ToListAsync();
        var allBadges    = await _context.Badges.ToListAsync();

        foreach (var badge in allBadges.Where(b => b.RequiredCount <= totalVisits && !earnedBadges.Contains(b.Id)))
        {
            _context.UserBadges.Add(new Core.Entities.UserBadge { UserId = userId, BadgeId = badge.Id });
        }
        await _context.SaveChangesAsync();
    }

    private static CheckInDto ToDto(CheckIn c)
    {
        var duration = c.CheckOutTime.HasValue
            ? (int)(c.CheckOutTime.Value - c.CheckInTime).TotalMinutes
            : (int?)null;

        return new CheckInDto(c.Id, c.UserId, $"{c.User.FirstName} {c.User.LastName}",
            c.GymId, c.Gym.Name, c.CheckInTime, c.CheckOutTime, duration);
    }
}
