using Gym.Core.Enums;
using Gym.Services.DTOs;

namespace Gym.Services.Interfaces;

public interface ITrainerApplicationService
{
    Task<IEnumerable<TrainerApplicationDto>> GetAllAsync(ApplicationStatus? status, int page = 1, int pageSize = 20);
    Task<TrainerApplicationDto?> GetByIdAsync(int id);
    Task<TrainerApplicationDto> CreateAsync(int userId, CreateTrainerApplicationDto dto);
    Task<TrainerApplicationDto> ReviewAsync(int id, int adminId, ReviewApplicationDto dto);
}
