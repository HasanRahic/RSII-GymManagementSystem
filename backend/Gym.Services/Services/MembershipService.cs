using Gym.Core.Entities;
using Gym.Core.Enums;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Gym.Services.Services;

public class MembershipService : IMembershipService
{
    private readonly GymDbContext _context;

    public MembershipService(GymDbContext context) => _context = context;

    public async Task<IEnumerable<MembershipPlanDto>> GetPlansAsync(int? gymId)
    {
        var query = _context.MembershipPlans.Include(p => p.Gym).AsQueryable();
        if (gymId.HasValue) query = query.Where(p => p.GymId == gymId.Value);
        return (await query.ToListAsync()).Select(ToPlanDto);
    }

    public async Task<MembershipPlanDto> CreatePlanAsync(CreateMembershipPlanDto dto)
    {
        var plan = new MembershipPlan
        {
            Name         = dto.Name,
            Description  = dto.Description,
            DurationDays = dto.DurationDays,
            Price        = dto.Price,
            GymId        = dto.GymId
        };
        _context.MembershipPlans.Add(plan);
        await _context.SaveChangesAsync();
        await _context.Entry(plan).Reference(p => p.Gym).LoadAsync();
        return ToPlanDto(plan);
    }

    public async Task<MembershipPlanDto> UpdatePlanAsync(int id, UpdateMembershipPlanDto dto)
    {
        var plan = await _context.MembershipPlans.Include(p => p.Gym).FirstOrDefaultAsync(p => p.Id == id)
            ?? throw new KeyNotFoundException("Plan nije pronadjen.");

        plan.Name         = dto.Name;
        plan.Description  = dto.Description;
        plan.DurationDays = dto.DurationDays;
        plan.Price        = dto.Price;
        plan.IsActive     = dto.IsActive;
        await _context.SaveChangesAsync();
        return ToPlanDto(plan);
    }

    public async Task<IEnumerable<UserMembershipDto>> GetAllMembershipsAsync()
    {
        var memberships = await _context.UserMemberships
            .Include(m => m.MembershipPlan)
            .Include(m => m.Gym)
            .Include(m => m.User)
            .OrderByDescending(m => m.StartDate)
            .ToListAsync();
        return memberships.Select(ToMembershipDto);
    }

    public async Task<IEnumerable<UserMembershipDto>> GetUserMembershipsAsync(int userId)
    {
        var memberships = await _context.UserMemberships
            .Include(m => m.MembershipPlan)
            .Include(m => m.Gym)
            .Include(m => m.User)
            .Where(m => m.UserId == userId)
            .OrderByDescending(m => m.StartDate)
            .ToListAsync();

        return memberships.Select(ToMembershipDto);
    }

    public async Task<UserMembershipDto?> GetActiveMembershipAsync(int userId)
    {
        var m = await _context.UserMemberships
            .Include(m => m.MembershipPlan)
            .Include(m => m.Gym)
            .Include(m => m.User)
            .FirstOrDefaultAsync(m => m.UserId == userId && m.Status == MembershipStatus.Active);

        return m is null ? null : ToMembershipDto(m);
    }

    public Task<UserMembershipDto> RenewAsync(RenewMembershipDto dto)
        => RenewInternalAsync(dto, paymentId: null);

    public Task<UserMembershipDto> RenewFromPaymentAsync(int paymentId, RenewMembershipDto dto)
        => RenewInternalAsync(dto, paymentId);

    private async Task<UserMembershipDto> RenewInternalAsync(RenewMembershipDto dto, int? paymentId)
    {
        var plan = await _context.MembershipPlans.Include(p => p.Gym).FirstOrDefaultAsync(p => p.Id == dto.MembershipPlanId)
            ?? throw new KeyNotFoundException("Plan nije pronadjen.");

        var user = await _context.Users.FindAsync(dto.UserId)
            ?? throw new KeyNotFoundException("Korisnik nije pronadjen.");

        if (paymentId.HasValue)
        {
            var existingMembership = await _context.UserMemberships
                .Include(m => m.MembershipPlan)
                .Include(m => m.Gym)
                .Include(m => m.User)
                .FirstOrDefaultAsync(m => m.PaymentId == paymentId.Value);

            if (existingMembership is not null)
            {
                return ToMembershipDto(existingMembership);
            }
        }

        var activeMemberships = await _context.UserMemberships
            .Where(m => m.UserId == dto.UserId && m.Status == MembershipStatus.Active)
            .OrderByDescending(m => m.EndDate)
            .ToListAsync();

        var now = DateTime.UtcNow;
        var carryForwardUntil = activeMemberships
            .Select(m => m.EndDate)
            .Where(endDate => endDate > now)
            .DefaultIfEmpty(now)
            .Max();

        foreach (var activeMembership in activeMemberships)
        {
            activeMembership.Status = MembershipStatus.Expired;
        }

        var discounted = plan.Price * (1 - dto.DiscountPercent / 100);
        var membership = new UserMembership
        {
            UserId           = dto.UserId,
            User             = user,
            MembershipPlanId = plan.Id,
            MembershipPlan   = plan,
            GymId            = plan.GymId,
            Gym              = plan.Gym,
            StartDate        = now,
            EndDate          = carryForwardUntil.AddDays(plan.DurationDays),
            Price            = discounted,
            DiscountPercent  = dto.DiscountPercent,
            Status           = MembershipStatus.Active,
            PaymentId        = paymentId
        };

        _context.UserMemberships.Add(membership);
        await _context.SaveChangesAsync();

        return ToMembershipDto(membership);
    }

    public async Task<UserMembershipDto?> CancelMembershipAsync(int userId, int membershipId)
    {
        var membership = await _context.UserMemberships
            .Include(m => m.MembershipPlan)
            .Include(m => m.Gym)
            .Include(m => m.User)
            .FirstOrDefaultAsync(m => m.Id == membershipId && m.UserId == userId);

        if (membership is null)
        {
            return null;
        }

        if (membership.Status != MembershipStatus.Active)
        {
            return ToMembershipDto(membership);
        }

        membership.Status = MembershipStatus.Cancelled;
        await _context.SaveChangesAsync();
        return ToMembershipDto(membership);
    }

    private static MembershipPlanDto ToPlanDto(MembershipPlan p) =>
        new(p.Id, p.Name, p.Description, p.DurationDays, p.Price, p.IsActive, p.GymId, p.Gym.Name);

    private static UserMembershipDto ToMembershipDto(UserMembership m) => new(
        m.Id, m.UserId, $"{m.User.FirstName} {m.User.LastName}",
        m.MembershipPlanId, m.MembershipPlan.Name,
        m.GymId, m.Gym.Name, m.StartDate, m.EndDate, m.Price, m.DiscountPercent,
        m.Status, GetDaysRemaining(m.EndDate));

    private static int GetDaysRemaining(DateTime endDate)
    {
        var remainingDays = (endDate - DateTime.UtcNow).TotalDays;
        return remainingDays <= 0 ? 0 : (int)Math.Ceiling(remainingDays);
    }
}
