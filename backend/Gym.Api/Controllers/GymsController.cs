using Gym.Core.Enums;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class GymsController(IGymService gymService) : ControllerBase
{
    [HttpGet]
    [AllowAnonymous]
    public async Task<IActionResult> GetAll(
        [FromQuery] string? search,
        [FromQuery] string? city,
        [FromQuery] GymStatus? status)
        => Ok(await gymService.GetAllAsync(search, city, status));

    [HttpGet("{id:int}")]
    [AllowAnonymous]
    public async Task<IActionResult> GetById(int id)
    {
        var gym = await gymService.GetByIdAsync(id);
        return gym is null ? NotFound() : Ok(gym);
    }

    [HttpPost]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Create([FromBody] CreateGymDto dto)
    {
        var gym = await gymService.CreateAsync(dto);
        return CreatedAtAction(nameof(GetById), new { id = gym.Id }, gym);
    }

    [HttpPut("{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateGymDto dto)
    {
        var result = await gymService.UpdateAsync(id, dto);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpPatch("{id:int}/status")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateStatus(int id, [FromQuery] GymStatus status)
    {
        var result = await gymService.UpdateStatusAsync(id, status);
        return result is null ? NotFound() : Ok(result);
    }
}
