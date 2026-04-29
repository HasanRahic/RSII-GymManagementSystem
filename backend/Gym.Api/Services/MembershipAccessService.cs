using Gym.Core.Enums;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Gym.Api.Services;

public sealed class MembershipAccessService(
    GymDbContext context,
    IMembershipService membershipService) : IMembershipAccessService
{
    public async Task<AccessStatusDto> GetAccessStatusAsync(int userId)
    {
        var now = DateTime.UtcNow;
        var activeMembership = await membershipService.GetActiveMembershipAsync(userId);

        var latestGroupAccessUntil = await context.Payments
            .AsNoTracking()
            .Where(p =>
                p.UserId == userId &&
                p.Type == PaymentType.Session &&
                p.Status == PaymentStatus.Succeeded &&
                p.SessionAccessUntil.HasValue)
            .MaxAsync(p => p.SessionAccessUntil);

        var hasGroupAccess = latestGroupAccessUntil.HasValue && latestGroupAccessUntil.Value > now;
        var hasMembershipAccess = activeMembership is not null;

        return new AccessStatusDto(
            hasMembershipAccess,
            hasGroupAccess,
            hasMembershipAccess || hasGroupAccess,
            latestGroupAccessUntil);
    }
}
