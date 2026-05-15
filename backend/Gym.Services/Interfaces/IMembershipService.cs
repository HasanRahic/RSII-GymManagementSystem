using Gym.Services.DTOs;

namespace Gym.Services.Interfaces;

public interface IMembershipService
{
    Task<IEnumerable<MembershipPlanDto>> GetPlansAsync(int? gymId, int page = 1, int pageSize = 100);
    Task<MembershipPlanDto> CreatePlanAsync(CreateMembershipPlanDto dto);
    Task<MembershipPlanDto> UpdatePlanAsync(int id, UpdateMembershipPlanDto dto);
    Task<IEnumerable<UserMembershipDto>> GetAllMembershipsAsync(int page = 1, int pageSize = 100);
    Task<IEnumerable<UserMembershipDto>> GetUserMembershipsAsync(int userId, int page = 1, int pageSize = 100);
    Task<UserMembershipDto?> GetActiveMembershipAsync(int userId);
    Task<UserMembershipDto> RenewAsync(RenewMembershipDto dto);
    Task<UserMembershipDto> RenewFromPaymentAsync(int paymentId, RenewMembershipDto dto);
    Task<UserMembershipDto?> CancelMembershipAsync(int userId, int membershipId);
}
