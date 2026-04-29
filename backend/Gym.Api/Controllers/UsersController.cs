using Gym.Api.Extensions;
using Gym.Core.Enums;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class UsersController(IUserService userService, IAuthService authService) : ControllerBase
{
    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAll(
        [FromQuery] string? search,
        [FromQuery] string? role,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 20)
        => Ok(await userService.GetAllAsync(search, role, page, pageSize));

    [HttpGet("{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetById(int id)
    {
        var user = await userService.GetByIdAsync(id);
        return user is null ? NotFound() : Ok(user);
    }

    [HttpGet("me")]
    public async Task<IActionResult> GetMe()
    {
        var userId = User.GetUserId();
        if (!userId.HasValue)
            return Unauthorized();
        var user = await userService.GetByIdAsync(userId.Value);
        return user is null ? NotFound() : Ok(user);
    }

    [HttpPut("{id:int}")]
    public async Task<IActionResult> Update(int id, [FromBody] UpdateUserDto dto)
    {
        var userId = User.GetUserId();
        if (!User.IsInRole("Admin") && userId != id)
            return Forbid();

        var result = await userService.UpdateAsync(id, dto);
        return result is null ? NotFound() : Ok(result);
    }

    [HttpPatch("{id:int}/active")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> SetActive(int id, [FromQuery] bool isActive)
    {
        await userService.SetActiveAsync(id, isActive);
        return NoContent();
    }

    [HttpPost("change-password")]
    public async Task<IActionResult> ChangePassword([FromBody] ChangePasswordDto dto)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue)
            return Unauthorized();
        var isAdmin = User.IsInRole("Admin");
        await authService.ChangePasswordAsync(userId.Value, dto, isAdmin);
        return NoContent();
    }
}
