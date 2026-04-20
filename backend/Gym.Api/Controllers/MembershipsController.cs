using System.Security.Claims;
using Gym.Api.Services;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class MembershipsController(
    IMembershipService membershipService,
    IStripePaymentSyncService stripePaymentSyncService) : ControllerBase
{
    // ----- Plans -----

    [HttpGet("plans")]
    [AllowAnonymous]
    public async Task<IActionResult> GetPlans([FromQuery] int? gymId)
        => Ok(await membershipService.GetPlansAsync(gymId));

    [HttpPost("plans")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> CreatePlan([FromBody] CreateMembershipPlanDto dto)
        => Ok(await membershipService.CreatePlanAsync(dto));

    [HttpPut("plans/{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdatePlan(int id, [FromBody] UpdateMembershipPlanDto dto)
    {
        var result = await membershipService.UpdatePlanAsync(id, dto);
        return result is null ? NotFound() : Ok(result);
    }

    // ----- User memberships -----

    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAll([FromQuery] int? userId)
        => Ok(userId.HasValue
            ? await membershipService.GetUserMembershipsAsync(userId.Value)
            : await membershipService.GetAllMembershipsAsync());

    [HttpGet("my")]
    public async Task<IActionResult> GetMine()
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId)) return Unauthorized();
        await stripePaymentSyncService.ReconcileLatestMembershipPaymentsAsync(userId);
        return Ok(await membershipService.GetUserMembershipsAsync(userId));
    }

    [HttpGet("my/active")]
    public async Task<IActionResult> GetMyActive()
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId)) return Unauthorized();
        await stripePaymentSyncService.ReconcileLatestMembershipPaymentsAsync(userId);
        var membership = await membershipService.GetActiveMembershipAsync(userId);
        return membership is null ? NotFound() : Ok(membership);
    }

    [HttpPost("renew")]
    public async Task<IActionResult> Renew([FromBody] RenewMembershipDto dto)
    {
        var result = await membershipService.RenewAsync(dto);
        return result is null ? BadRequest(new { message = "Plan not found." }) : Ok(result);
    }

    [HttpPost("{id:int}/cancel")]
    public async Task<IActionResult> Cancel(int id)
    {
        var idClaim = User.FindFirstValue(ClaimTypes.NameIdentifier);
        if (!int.TryParse(idClaim, out var userId)) return Unauthorized();

        var result = await membershipService.CancelMembershipAsync(userId, id);
        return result is null ? NotFound(new { message = "Članarina nije pronađena." }) : Ok(result);
    }
}
