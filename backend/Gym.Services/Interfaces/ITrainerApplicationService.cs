using Gym.Core.Enums;
using Gym.Services.DTOs;

namespace Gym.Services.Interfaces;

public interface ITrainerApplicationService
{
    Task<IEnumerable<TrainerApplicationDto>> GetAllAsync(ApplicationStatus? status);
    Task<TrainerApplicationDto?> GetByIdAsync(int id);
    Task<TrainerApplicationDto> CreateAsync(int userId, CreateTrainerApplicationDto dto);
    Task<TrainerApplicationDto> ReviewAsync(int id, int adminId, ReviewApplicationDto dto);
}
