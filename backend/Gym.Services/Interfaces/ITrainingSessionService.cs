using Gym.Services.DTOs;

namespace Gym.Services.Interfaces;

public interface ITrainingSessionService
{
    Task<IEnumerable<TrainingSessionDto>> GetAllAsync(int? gymId, int? trainerId, int? typeId, int page = 1, int pageSize = 20);
    Task<TrainingSessionDto?> GetByIdAsync(int id);
    Task<TrainingSessionDto> CreateAsync(int trainerId, CreateTrainingSessionDto dto);
    Task DeleteAsync(int id, int trainerId);
    Task<SessionReservationDto> ReserveAsync(int userId, int sessionId);
    Task CancelReservationAsync(int userId, int reservationId);
    Task<IEnumerable<SessionReservationDto>> GetUserReservationsAsync(int userId, int page = 1, int pageSize = 20);
    Task<IEnumerable<TrainingSessionDto>> GetUserPaidGroupScheduleAsync(int userId, int page = 1, int pageSize = 20);
    Task<IEnumerable<RecommendedGymDto>> GetRecommendedGymsAsync(int userId, string? city, int? trainingTypeId);
    Task<IEnumerable<TrainerProfileDto>> GetTrainerProfilesAsync(string? city, int? trainingTypeId, string? search, int page = 1, int pageSize = 20);
}
