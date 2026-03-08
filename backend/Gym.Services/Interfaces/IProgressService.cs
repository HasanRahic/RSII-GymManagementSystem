using Gym.Services.DTOs;

namespace Gym.Services.Interfaces;

public interface IProgressService
{
    Task<IEnumerable<ProgressMeasurementDto>> GetUserMeasurementsAsync(int userId, DateTime? from, DateTime? to);
    Task<ProgressMeasurementDto> AddMeasurementAsync(int userId, CreateProgressMeasurementDto dto);
    Task DeleteMeasurementAsync(int userId, int measurementId);
    Task<IEnumerable<UserBadgeDto>> GetUserBadgesAsync(int userId);
}
