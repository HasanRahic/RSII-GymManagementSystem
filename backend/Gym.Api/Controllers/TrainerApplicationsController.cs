using System.Security.Claims;
using Gym.Core.Enums;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/trainer-applications")]
[Authorize]
public class TrainerApplicationsController(ITrainerApplicationService trainerAppService) : ControllerBase
{
    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAll([FromQuery] ApplicationStatus? status)
        => Ok(await trainerAppService.GetAllAsync(status));

    [HttpGet("{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetById(int id)
    {
        var app = await trainerAppService.GetByIdAsync(id);
        return app is null ? NotFound() : Ok(app);
    }

    [HttpPost]
    public async Task<IActionResult> Apply([FromBody] CreateTrainerApplicationDto dto)
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId)) return Unauthorized();
        try
        {
            var result = await trainerAppService.CreateAsync(userId, dto);
            return Ok(result);
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(new { message = ex.Message });
        }
    }

    [HttpPatch("{id:int}/review")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Review(int id, [FromBody] ReviewApplicationDto dto)
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var adminId)) return Unauthorized();
        var result = await trainerAppService.ReviewAsync(id, adminId, dto);
        return result is null ? NotFound() : Ok(result);
    }
}
