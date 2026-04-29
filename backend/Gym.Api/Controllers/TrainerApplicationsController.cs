using Gym.Api.Extensions;
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
    public async Task<IActionResult> GetAll(
        [FromQuery] ApplicationStatus? status,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
        => Ok(await trainerAppService.GetAllAsync(status, page, pageSize));

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
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();
        try
        {
            var result = await trainerAppService.CreateAsync(userId.Value, dto);
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
        var adminId = User.GetUserId();
        if (!adminId.HasValue) return Unauthorized();
        var result = await trainerAppService.ReviewAsync(id, adminId.Value, dto);
        return result is null ? NotFound() : Ok(result);
    }
}
