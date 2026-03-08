using System.Security.Claims;
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
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId)) return Unauthorized();
        return Ok(await progressService.GetUserMeasurementsAsync(userId, from, to));
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
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId)) return Unauthorized();
        return Ok(await progressService.AddMeasurementAsync(userId, dto));
    }

    [HttpDelete("{id:int}")]
    public async Task<IActionResult> DeleteMeasurement(int id)
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId)) return Unauthorized();
        await progressService.DeleteMeasurementAsync(userId, id);
        return NoContent();
    }

    [HttpGet("badges")]
    public async Task<IActionResult> GetMyBadges()
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId)) return Unauthorized();
        return Ok(await progressService.GetUserBadgesAsync(userId));
    }

    [HttpGet("badges/user/{userId:int}")]
    [Authorize(Roles = "Admin,Trainer")]
    public async Task<IActionResult> GetUserBadges(int userId)
        => Ok(await progressService.GetUserBadgesAsync(userId));
}
