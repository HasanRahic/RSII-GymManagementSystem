using Gym.Api.Extensions;
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
    IStripePaymentSyncService stripePaymentSyncService,
    IMembershipAccessService membershipAccessService) : ControllerBase
{
    [HttpGet("plans")]
    [AllowAnonymous]
    public async Task<IActionResult> GetPlans([FromQuery] int? gymId, [FromQuery] int page = 1, [FromQuery] int pageSize = 100)
        => Ok(await membershipService.GetPlansAsync(gymId, page, pageSize));

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
    public async Task<IActionResult> GetAll([FromQuery] int? userId, [FromQuery] int page = 1, [FromQuery] int pageSize = 100)
        => Ok(userId.HasValue
            ? await membershipService.GetUserMembershipsAsync(userId.Value, page, pageSize)
            : await membershipService.GetAllMembershipsAsync(page, pageSize));

    [HttpGet("my")]
    public async Task<IActionResult> GetMine([FromQuery] int page = 1, [FromQuery] int pageSize = 100)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();

        await stripePaymentSyncService.ReconcileLatestMembershipPaymentsAsync(userId.Value);
        return Ok(await membershipService.GetUserMembershipsAsync(userId.Value, page, pageSize));
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

    [HttpPost("{id:int}/cancel")]
    public async Task<IActionResult> Cancel(int id)
    {
        var userId = User.GetUserId();
        if (!userId.HasValue) return Unauthorized();

        var result = await membershipService.CancelMembershipAsync(userId.Value, id);
        return result is null ? NotFound(new { message = "Clanarina nije pronadjena." }) : Ok(result);
    }
}
