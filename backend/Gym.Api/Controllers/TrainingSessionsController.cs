using System.Security.Claims;
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
        [FromQuery] int? trainingTypeId)
        => Ok(await sessionService.GetAllAsync(gymId, trainerId, trainingTypeId));

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
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var trainerId)) return Unauthorized();
        var session = await sessionService.CreateAsync(trainerId, dto);
        return CreatedAtAction(nameof(GetById), new { id = session.Id }, session);
    }

    [HttpDelete("{id:int}")]
    [Authorize(Roles = "Admin,Trainer")]
    public async Task<IActionResult> Delete(int id)
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var trainerId)) return Unauthorized();
        await sessionService.DeleteAsync(id, trainerId);
        return NoContent();
    }

    [HttpPost("{id:int}/reserve")]
    public async Task<IActionResult> Reserve(int id)
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId)) return Unauthorized();

        var result = await sessionService.ReserveAsync(userId, id);
        return result is null
            ? BadRequest(new { message = "Session full or already reserved." })
            : Ok(result);
    }

    [HttpDelete("{id:int}/reserve")]
    public async Task<IActionResult> CancelReservation(int id)
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId)) return Unauthorized();

        await sessionService.CancelReservationAsync(userId, id);
        return NoContent();
    }

    [HttpGet("my-reservations")]
    public async Task<IActionResult> GetMyReservations()
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId)) return Unauthorized();
        return Ok(await sessionService.GetUserReservationsAsync(userId));
    }

    [HttpGet("my-paid-group-schedule")]
    public async Task<IActionResult> GetMyPaidGroupSchedule()
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId)) return Unauthorized();
        return Ok(await sessionService.GetUserPaidGroupScheduleAsync(userId));
    }
}
