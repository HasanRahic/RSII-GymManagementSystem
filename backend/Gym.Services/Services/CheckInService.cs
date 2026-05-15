using Gym.Core.Entities;
using Gym.Core.Enums;
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
        var now = DateTime.UtcNow;

        var active = await _context.CheckIns
            .FirstOrDefaultAsync(c => c.UserId == userId && c.CheckOutTime == null);
        if (active is not null)
            throw new InvalidOperationException("Vec ste prijavljeni u teretani. Najprije se odjavite.");

        var gym = await _context.Gyms.FindAsync(dto.GymId)
            ?? throw new KeyNotFoundException("Teretana nije pronadjena.");

        if (gym.Status != GymStatus.Open)
            throw new InvalidOperationException("Check-in nije dozvoljen jer teretana trenutno nije otvorena.");

        var currentTime = TimeOnly.FromDateTime(now.ToLocalTime());
        if (currentTime < gym.OpenTime || currentTime > gym.CloseTime)
            throw new InvalidOperationException("Check-in nije dozvoljen van radnog vremena teretane.");

        if (gym.CurrentOccupancy >= gym.Capacity)
            throw new InvalidOperationException("Check-in nije dozvoljen jer je teretana popunjena.");

        var hasActiveMembership = await _context.UserMemberships
            .AnyAsync(m =>
                m.UserId == userId &&
                m.GymId == dto.GymId &&
                m.Status == MembershipStatus.Active &&
                m.StartDate <= now &&
                m.EndDate > now);

        if (!hasActiveMembership)
            throw new InvalidOperationException("Za check-in je potrebna aktivna clanarina za odabranu teretanu.");

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
            ?? throw new KeyNotFoundException("Check-in nije pronadjen.");

        if (checkIn.CheckOutTime.HasValue)
            throw new InvalidOperationException("Vec ste se odjavili.");

        checkIn.CheckOutTime = DateTime.UtcNow;
        if (checkIn.Gym.CurrentOccupancy > 0)
            checkIn.Gym.CurrentOccupancy--;

        await _context.SaveChangesAsync();
        await AwardBadgesAsync(userId);

        return await LoadDto(checkIn.Id);
    }

    public async Task<IEnumerable<CheckInDto>> GetUserHistoryAsync(int userId, DateTime? from, DateTime? to, int page = 1, int pageSize = 100)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 200);

        var query = _context.CheckIns
            .Include(c => c.User)
            .Include(c => c.Gym)
            .Where(c => c.UserId == userId);

        if (from.HasValue) query = query.Where(c => c.CheckInTime >= from.Value);
        if (to.HasValue) query = query.Where(c => c.CheckInTime <= to.Value);

        var list = await query
            .OrderByDescending(c => c.CheckInTime)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();
        return list.Select(ToDto);
    }

    public async Task<IEnumerable<CheckInDto>> GetGymCheckInsAsync(int gymId, DateTime? date, int page = 1, int pageSize = 100)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 200);

        var query = _context.CheckIns
            .Include(c => c.User)
            .Include(c => c.Gym)
            .Where(c => c.GymId == gymId);

        if (date.HasValue)
            query = query.Where(c => c.CheckInTime.Date == date.Value.Date);

        var list = await query
            .OrderByDescending(c => c.CheckInTime)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();
        return list.Select(ToDto);
    }

    public async Task<CheckInDto?> GetActiveCheckInAsync(int userId)
    {
        var c = await _context.CheckIns
            .Include(c => c.User)
            .Include(c => c.Gym)
            .FirstOrDefaultAsync(c => c.UserId == userId && c.CheckOutTime == null);

        return c is null ? null : ToDto(c);
    }

    private async Task<CheckInDto> LoadDto(int id)
    {
        var c = await _context.CheckIns
            .Include(c => c.User)
            .Include(c => c.Gym)
            .FirstAsync(c => c.Id == id);
        return ToDto(c);
    }

    private async Task AwardBadgesAsync(int userId)
    {
        var completedCheckIns = await _context.CheckIns
            .Where(c => c.UserId == userId && c.CheckOutTime != null)
            .OrderBy(c => c.CheckInTime)
            .Select(c => c.CheckInTime)
            .ToListAsync();

        var totalVisits = completedCheckIns.Count;
        var longestStreak = CalculateLongestDailyStreak(completedCheckIns);
        var earnedBadges = await _context.UserBadges
            .Where(ub => ub.UserId == userId)
            .Select(ub => ub.BadgeId)
            .ToListAsync();
        var allBadges = await _context.Badges.ToListAsync();

        foreach (var badge in allBadges.Where(b => !earnedBadges.Contains(b.Id)))
        {
            if (!HasBadgeRequirementMet(badge, totalVisits, longestStreak))
                continue;

            _context.UserBadges.Add(new UserBadge
            {
                UserId = userId,
                BadgeId = badge.Id,
                EarnedAt = DateTime.UtcNow
            });
        }

        await _context.SaveChangesAsync();
    }

    private static bool HasBadgeRequirementMet(Badge badge, int totalVisits, int longestStreak)
        => badge.Type switch
        {
            BadgeType.FirstVisit or
            BadgeType.Visits5 or
            BadgeType.Visits10 or
            BadgeType.Visits25 or
            BadgeType.Visits50 or
            BadgeType.Visits100 => totalVisits >= badge.RequiredCount,
            BadgeType.Streak7 or
            BadgeType.Streak30 or
            BadgeType.Streak90 => longestStreak >= badge.RequiredCount,
            _ => false
        };

    private static int CalculateLongestDailyStreak(IEnumerable<DateTime> checkInTimes)
    {
        var distinctDays = checkInTimes
            .Select(time => time.ToLocalTime().Date)
            .Distinct()
            .OrderBy(day => day)
            .ToList();

        if (distinctDays.Count == 0)
            return 0;

        var longest = 1;
        var current = 1;

        for (var i = 1; i < distinctDays.Count; i++)
        {
            current = distinctDays[i] == distinctDays[i - 1].AddDays(1)
                ? current + 1
                : 1;

            if (current > longest)
                longest = current;
        }

        return longest;
    }

    private static CheckInDto ToDto(CheckIn c)
    {
        var duration = c.CheckOutTime.HasValue
            ? (int)(c.CheckOutTime.Value - c.CheckInTime).TotalMinutes
            : (int?)null;

        return new CheckInDto(
            c.Id,
            c.UserId,
            $"{c.User.FirstName} {c.User.LastName}",
            c.GymId,
            c.Gym.Name,
            c.CheckInTime,
            c.CheckOutTime,
            duration);
    }
}
