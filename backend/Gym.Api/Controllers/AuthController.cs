using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using Gym.Api.Services;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.AspNetCore.Mvc;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[EnableRateLimiting("auth")]
public class AuthController(
    IAuthService authService,
    ITokenRevocationService tokenRevocationService) : ControllerBase
{
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterDto dto)
    {
        var result = await authService.RegisterAsync(dto);
        if (result is null)
            return BadRequest(new { message = "Username or email already exists." });
        return Ok(result);
    }

    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto dto)
    {
        var result = await authService.LoginAsync(dto);
        if (result is null)
            return Unauthorized(new { message = "Invalid username or password." });
        return Ok(result);
    }

    [Authorize]
    [HttpPost("logout")]
    public IActionResult Logout()
    {
        var tokenId = User.FindFirstValue(JwtRegisteredClaimNames.Jti);
        if (string.IsNullOrWhiteSpace(tokenId))
        {
            return BadRequest(new { message = "Token identifier nije dostupan." });
        }

        var expiresAt = User.FindFirstValue(JwtRegisteredClaimNames.Exp);
        var expiresAtUtc = DateTime.UtcNow.AddHours(1);
        if (long.TryParse(expiresAt, out var expUnixSeconds))
        {
            expiresAtUtc = DateTimeOffset.FromUnixTimeSeconds(expUnixSeconds).UtcDateTime;
        }

        tokenRevocationService.Revoke(tokenId, expiresAtUtc);
        return Ok(new { message = "Odjava uspjesno evidentirana." });
    }
}
