using Gym.Services.DTOs;

namespace Gym.Services.Interfaces;

public interface IReportService
{
    Task<DashboardStatsDto> GetDashboardStatsAsync(int? gymId);
    Task<IEnumerable<CheckInDto>> GetCheckInReportAsync(int? gymId, DateTime from, DateTime to);
    Task<IEnumerable<UserMembershipDto>> GetMembershipReportAsync(int? gymId, DateTime from, DateTime to);
    Task<decimal> GetRevenueAsync(int? gymId, DateTime from, DateTime to);
}
