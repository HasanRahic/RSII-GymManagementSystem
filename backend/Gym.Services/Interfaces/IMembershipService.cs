using Gym.Services.DTOs;

namespace Gym.Services.Interfaces;

public interface IMembershipService
{
    Task<IEnumerable<MembershipPlanDto>> GetPlansAsync(int? gymId);
    Task<MembershipPlanDto> CreatePlanAsync(CreateMembershipPlanDto dto);
    Task<MembershipPlanDto> UpdatePlanAsync(int id, UpdateMembershipPlanDto dto);
    Task<IEnumerable<UserMembershipDto>> GetAllMembershipsAsync();
    Task<IEnumerable<UserMembershipDto>> GetUserMembershipsAsync(int userId);
    Task<UserMembershipDto?> GetActiveMembershipAsync(int userId);
    Task<UserMembershipDto> RenewAsync(RenewMembershipDto dto);
    Task<UserMembershipDto?> CancelMembershipAsync(int userId, int membershipId);
}
