using Gym.Core.Enums;
using Gym.Services.DTOs;

namespace Gym.Services.Interfaces;

public interface IGymService
{
    Task<IEnumerable<GymDto>> GetAllAsync(string? search, string? city, GymStatus? status);
    Task<GymDto?> GetByIdAsync(int id);
    Task<GymDto> CreateAsync(CreateGymDto dto);
    Task<GymDto> UpdateAsync(int id, UpdateGymDto dto);
    Task<GymDto> UpdateStatusAsync(int id, GymStatus status);
}
