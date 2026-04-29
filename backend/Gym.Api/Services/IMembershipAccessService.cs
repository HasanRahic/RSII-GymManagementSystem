using Gym.Services.DTOs;

namespace Gym.Api.Services;

public interface IMembershipAccessService
{
    Task<AccessStatusDto> GetAccessStatusAsync(int userId);
}
