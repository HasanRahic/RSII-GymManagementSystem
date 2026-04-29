using Gym.Services.DTOs;

namespace Gym.Services.Interfaces;

public interface IUserService
{
    Task<IEnumerable<UserDto>> GetAllAsync(string? search, string? role, int page = 1, int pageSize = 20);
    Task<UserDto?> GetByIdAsync(int id);
    Task<UserDto> UpdateAsync(int id, UpdateUserDto dto);
    Task SetActiveAsync(int id, bool isActive);
}
