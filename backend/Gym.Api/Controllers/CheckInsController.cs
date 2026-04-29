using Gym.Api.Extensions;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CheckInsController(ICheckInService checkInService) : ControllerBase
{
    [HttpPost]
    public async Task<IActionResult> CheckIn([FromBody] CheckInRequestDto dto)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();
        var result = await checkInService.CheckInAsync(userId.Value, dto);
        return result is null
            ? BadRequest(new { message = "Already checked in or gym not found." })
            : Ok(result);
    }

    [HttpPost("checkout")]
    public async Task<IActionResult> CheckOut([FromBody] CheckOutRequestDto dto)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();
        var result = await checkInService.CheckOutAsync(userId.Value, dto);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpGet("my")]
    public async Task<IActionResult> GetMyHistory(
        [FromQuery] DateTime? from,
        [FromQuery] DateTime? to)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();
        return Ok(await checkInService.GetUserHistoryAsync(userId.Value, from, to));
    }

    [HttpGet("gym/{gymId:int}")]
    [Authorize(Roles = "Admin,Trainer")]
    public async Task<IActionResult> GetGymCheckIns(
        int gymId,
        [FromQuery] DateTime? date)
        => Ok(await checkInService.GetGymCheckInsAsync(gymId, date));

    [HttpGet("active/{userId:int}")]
    [Authorize(Roles = "Admin,Trainer")]
    public async Task<IActionResult> GetActiveCheckIn(int userId)
    {
        var checkIn = await checkInService.GetActiveCheckInAsync(userId);
        return checkIn is null ? NotFound() : Ok(checkIn);
    }
}
