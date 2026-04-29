using Gym.Api.Extensions;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ProgressController(IProgressService progressService) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetMeasurements(
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();
        return Ok(await progressService.GetUserMeasurementsAsync(userId.Value, from, to));
    }

    [HttpGet("user/{userId:int}")]
    [Authorize(Roles = "Admin,Trainer")]
    public async Task<IActionResult> GetUserMeasurements(
        int userId,
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to)
        => Ok(await progressService.GetUserMeasurementsAsync(userId, from, to));

    [HttpPost]
    public async Task<IActionResult> AddMeasurement([FromBody] CreateProgressMeasurementDto dto)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();
        return Ok(await progressService.AddMeasurementAsync(userId.Value, dto));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeleteMeasurement(int id)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();
        await progressService.DeleteMeasurementAsync(userId.Value, id);
        return NoContent();
    }

    [HttpGet("badges")]
    public async Task<IActionResult> GetMyBadges()
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();
        return Ok(await progressService.GetUserBadgesAsync(userId.Value));
    }

    [HttpGet("badges/user/{userId:int}")]
    [Authorize(Roles = "Admin,Trainer")]
    public async Task<IActionResult> GetUserBadges(int userId)
        => Ok(await progressService.GetUserBadgesAsync(userId));
}
