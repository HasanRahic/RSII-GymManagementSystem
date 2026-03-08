using Gym.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize(Roles = "Admin")]
public class ReportsController(IReportService reportService) : ControllerBase
{
    [HttpGet("dashboard")]
    public async Task<IActionResult> GetDashboard([FromQuery] int? gymId)
        => Ok(await reportService.GetDashboardStatsAsync(gymId));

    [HttpGet("checkins")]
    public async Task<IActionResult> GetCheckInReport(
        [FromQuery] DateTime from,
        [FromQuery] DateTime to,
        [FromQuery] int? gymId)
        => Ok(await reportService.GetCheckInReportAsync(gymId, from, to));

    [HttpGet("memberships")]
    public async Task<IActionResult> GetMembershipReport(
        [FromQuery] DateTime from,
        [FromQuery] DateTime to,
        [FromQuery] int? gymId)
        => Ok(await reportService.GetMembershipReportAsync(gymId, from, to));

    [HttpGet("revenue")]
    public async Task<IActionResult> GetRevenue(
        [FromQuery] DateTime from,
        [FromQuery] DateTime to,
        [FromQuery] int? gymId)
        => Ok(await reportService.GetRevenueAsync(gymId, from, to));
}
