using Gym.Api.Extensions;
using Gym.Api.Services;
using Gym.Core.Enums;
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
    IStripePaymentSyncService stripePaymentSyncService,
    IMembershipAccessService membershipAccessService) : ControllerBase
{
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

    [HttpGet]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> GetAll([FromQuery] int? userId)
        => Ok(userId.HasValue
            ? await membershipService.GetUserMembershipsAsync(userId.Value)
            : await membershipService.GetAllMembershipsAsync());

    [HttpGet("my")]
    public async Task<IActionResult> GetMine()
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();

        await stripePaymentSyncService.ReconcileLatestMembershipPaymentsAsync(userId.Value);
        return Ok(await membershipService.GetUserMembershipsAsync(userId.Value));
    }

    [HttpGet("my/active")]
    public async Task<IActionResult> GetMyActive()
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();

        await stripePaymentSyncService.ReconcileLatestMembershipPaymentsAsync(userId.Value);
        var membership = await membershipService.GetActiveMembershipAsync(userId.Value);
        return membership is null ? NotFound() : Ok(membership);
    }

    [HttpGet("my/access-status")]
    public async Task<IActionResult> GetMyAccessStatus()
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();

        await stripePaymentSyncService.ReconcileLatestMembershipPaymentsAsync(userId.Value);
        return Ok(await membershipAccessService.GetAccessStatusAsync(userId.Value));
    }

    [HttpPost("renew")]
    public async Task<IActionResult> Renew([FromBody] RenewMembershipDto dto)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();

        var result = await membershipService.RenewAsync(dto with { UserId = userId.Value });
        return result is null ? BadRequest(new { message = "Plan not found." }) : Ok(result);
    }

    [HttpPost("{id:int}/cancel")]
    public async Task<IActionResult> Cancel(int id)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();

        var result = await membershipService.CancelMembershipAsync(userId.Value, id);
        return result is null ? NotFound(new { message = "Članarina nije pronađena." }) : Ok(result);
    }
}
