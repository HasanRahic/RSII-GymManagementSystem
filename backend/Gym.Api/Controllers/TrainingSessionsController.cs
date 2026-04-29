using Gym.Api.Extensions;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/training-sessions")]
[Authorize]
public class TrainingSessionsController(ITrainingSessionService sessionService) : ControllerBase
{
    [HttpGet]
    public async Task<IActionResult> GetAll(
        [FromQuery] int? gymId,
        [FromQuery] int? trainerId,
        [FromQuery] int? trainingTypeId,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
        => Ok(await sessionService.GetAllAsync(gymId, trainerId, trainingTypeId, page, pageSize));

    [HttpGet("recommendations")]
    public async Task<IActionResult> GetRecommendations(
        [FromQuery] string? city,
        [FromQuery] int? trainingTypeId)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();
        return Ok(await sessionService.GetRecommendedGymsAsync(userId.Value, city, trainingTypeId));
    }

    [HttpGet("trainers")]
    public async Task<IActionResult> GetTrainerProfiles(
        [FromQuery] string? city,
        [FromQuery] int? trainingTypeId,
        [FromQuery] string? search,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
        => Ok(await sessionService.GetTrainerProfilesAsync(city, trainingTypeId, search, page, pageSize));

    [HttpGet("{id:int}")]
    public async Task<IActionResult> GetById(int id)
    {
        var session = await sessionService.GetByIdAsync(id);
        return session is null ? NotFound() : Ok(session);
    }

    [HttpPost]
    [Authorize(Roles = "Admin,Trainer")]
    public async Task<IActionResult> Create([FromBody] CreateTrainingSessionDto dto)
    {
        var trainerId = User.GetUserId();
        if (!trainerId.HasValue) return Unauthorized();
        var session = await sessionService.CreateAsync(trainerId.Value, dto);
        return CreatedAtAction(nameof(GetById), new { id = session.Id }, session);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Admin,Trainer")]
    public async Task<IActionResult> Delete(int id)
    {
        var trainerId = User.GetUserId();
        if (!trainerId.HasValue) return Unauthorized();
        await sessionService.DeleteAsync(id, trainerId.Value);
        return NoContent();
    }

    [HttpPost("{id:int}/reserve")]
    public async Task<IActionResult> Reserve(int id)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();

        var result = await sessionService.ReserveAsync(userId.Value, id);
        return result is null
            ? BadRequest(new { message = "Session full or already reserved." })
            : Ok(result);
    }

    [HttpDelete("{id:int}/reserve")]
    public async Task<IActionResult> CancelReservation(int id)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();

        await sessionService.CancelReservationAsync(userId.Value, id);
        return NoContent();
    }

    [HttpGet("my-reservations")]
    public async Task<IActionResult> GetMyReservations([FromQuery] int page = 1, [FromQuery] int pageSize = 20)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();
        return Ok(await sessionService.GetUserReservationsAsync(userId.Value, page, pageSize));
    }

    [HttpGet("my-paid-group-schedule")]
    public async Task<IActionResult> GetMyPaidGroupSchedule([FromQuery] int page = 1, [FromQuery] int pageSize = 20)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();
        return Ok(await sessionService.GetUserPaidGroupScheduleAsync(userId.Value, page, pageSize));
    }
}
