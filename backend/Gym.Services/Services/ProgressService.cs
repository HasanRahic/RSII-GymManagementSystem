using Gym.Core.Entities;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Gym.Services.Services;

public class ProgressService : IProgressService
{
    private readonly GymDbContext _context;

    public ProgressService(GymDbContext context) => _context = context;

    public async Task<IEnumerable<ProgressMeasurementDto>> GetUserMeasurementsAsync(int userId, DateTime? from, DateTime? to)
    {
        var query = _context.ProgressMeasurements.Where(m => m.UserId == userId);
        if (from.HasValue) query = query.Where(m => m.Date >= from.Value);
        if (to.HasValue)   query = query.Where(m => m.Date <= to.Value);

        return (await query.OrderBy(m => m.Date).ToListAsync()).Select(ToDto);
    }

    public async Task<ProgressMeasurementDto> AddMeasurementAsync(int userId, CreateProgressMeasurementDto dto)
    {
        var measurement = new ProgressMeasurement
        {
            UserId         = userId,
            Date           = dto.Date,
            WeightKg       = dto.WeightKg,
            BodyFatPercent = dto.BodyFatPercent,
            ChestCm        = dto.ChestCm,
            WaistCm        = dto.WaistCm,
            HipsCm         = dto.HipsCm,
            ArmCm          = dto.ArmCm,
            LegCm          = dto.LegCm,
            Notes          = dto.Notes
        };
        _context.ProgressMeasurements.Add(measurement);
        await _context.SaveChangesAsync();
        return ToDto(measurement);
    }

    public async Task DeleteMeasurementAsync(int userId, int measurementId)
    {
        var m = await _context.ProgressMeasurements
            .FirstOrDefaultAsync(m => m.Id == measurementId && m.UserId == userId)
            ?? throw new KeyNotFoundException("Mjerenje nije pronađeno.");

        _context.ProgressMeasurements.Remove(m);
        await _context.SaveChangesAsync();
    }

    public async Task<IEnumerable<UserBadgeDto>> GetUserBadgesAsync(int userId)
    {
        var badges = await _context.UserBadges
            .Include(ub => ub.Badge)
            .Where(ub => ub.UserId == userId)
            .OrderBy(ub => ub.EarnedAt)
            .ToListAsync();

        return badges.Select(ub => new UserBadgeDto(
            ub.BadgeId, ub.Badge.Name, ub.Badge.Description, ub.Badge.IconUrl, ub.EarnedAt));
    }

    private static ProgressMeasurementDto ToDto(ProgressMeasurement m) => new(
        m.Id, m.UserId, m.Date, m.WeightKg, m.BodyFatPercent,
        m.ChestCm, m.WaistCm, m.HipsCm, m.ArmCm, m.LegCm, m.Notes);
}
