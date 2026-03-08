using Gym.Core.Enums;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Gym.Services.Services;

public class ReportService : IReportService
{
    private readonly GymDbContext _context;

    public ReportService(GymDbContext context) => _context = context;

    public async Task<DashboardStatsDto> GetDashboardStatsAsync(int? gymId)
    {
        var today = DateTime.UtcNow.Date;
        var monthStart = new DateTime(today.Year, today.Month, 1);

        var membersQ    = _context.Users.Where(u => u.Role == UserRole.Member && u.IsActive);
        var membershipsQ = _context.UserMemberships.Where(m => m.Status == MembershipStatus.Active);
        var checkInsQ   = _context.CheckIns.Where(c => c.CheckInTime.Date == today);
        var revenueQ    = _context.Payments.Where(p => p.Status == PaymentStatus.Succeeded && p.CreatedAt >= monthStart);
        var occupancyQ  = _context.Gyms.AsQueryable();
        var pendingQ    = _context.TrainerApplications.Where(a => a.Status == ApplicationStatus.Pending);

        if (gymId.HasValue)
        {
            membershipsQ = membershipsQ.Where(m => m.GymId == gymId.Value);
            checkInsQ    = checkInsQ.Where(c => c.GymId == gymId.Value);
            // revenueQ - payments are user-level, no gym filter needed
            occupancyQ   = occupancyQ.Where(g => g.Id == gymId.Value);
        }

        return new DashboardStatsDto(
            TotalMembers:               await membersQ.CountAsync(),
            ActiveMemberships:          await membershipsQ.CountAsync(),
            TotalCheckInsToday:         await checkInsQ.CountAsync(),
            CurrentOccupancy:           await occupancyQ.SumAsync(g => g.CurrentOccupancy),
            RevenueThisMonth:           await revenueQ.SumAsync(p => (decimal?)p.Amount) ?? 0m,
            PendingTrainerApplications: await pendingQ.CountAsync()
        );
    }

    public async Task<IEnumerable<CheckInDto>> GetCheckInReportAsync(int? gymId, DateTime from, DateTime to)
    {
        var query = _context.CheckIns
            .Include(c => c.User).Include(c => c.Gym)
            .Where(c => c.CheckInTime >= from && c.CheckInTime <= to);

        if (gymId.HasValue) query = query.Where(c => c.GymId == gymId.Value);

        var list = await query.OrderByDescending(c => c.CheckInTime).ToListAsync();
        return list.Select(c =>
        {
            var dur = c.CheckOutTime.HasValue ? (int)(c.CheckOutTime.Value - c.CheckInTime).TotalMinutes : (int?)null;
            return new CheckInDto(c.Id, c.UserId, $"{c.User.FirstName} {c.User.LastName}",
                c.GymId, c.Gym.Name, c.CheckInTime, c.CheckOutTime, dur);
        });
    }

    public async Task<IEnumerable<UserMembershipDto>> GetMembershipReportAsync(int? gymId, DateTime from, DateTime to)
    {
        var query = _context.UserMemberships
            .Include(m => m.User).Include(m => m.Gym).Include(m => m.MembershipPlan)
            .Where(m => m.StartDate >= from && m.StartDate <= to);

        if (gymId.HasValue) query = query.Where(m => m.GymId == gymId.Value);

        var list = await query.OrderByDescending(m => m.StartDate).ToListAsync();
        return list.Select(m => new UserMembershipDto(
            m.Id, m.UserId, $"{m.User.FirstName} {m.User.LastName}",
            m.MembershipPlanId, m.MembershipPlan.Name,
            m.GymId, m.Gym.Name, m.StartDate, m.EndDate, m.Price, m.DiscountPercent,
            m.Status, Math.Max(0, (int)(m.EndDate - DateTime.UtcNow).TotalDays)));
    }

    public async Task<decimal> GetRevenueAsync(int? gymId, DateTime from, DateTime to)
    {
        var query = _context.Payments
            .Where(p => p.Status == PaymentStatus.Succeeded && p.CreatedAt >= from && p.CreatedAt <= to);

        return await query.SumAsync(p => (decimal?)p.Amount) ?? 0m;
    }
}
