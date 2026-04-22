using Gym.Services.DTOs;

namespace Gym.Services.Interfaces;

public interface ITrainingSessionService
{
    Task<IEnumerable<TrainingSessionDto>> GetAllAsync(int? gymId, int? trainerId, int? typeId);
    Task<TrainingSessionDto?> GetByIdAsync(int id);
    Task<TrainingSessionDto> CreateAsync(int trainerId, CreateTrainingSessionDto dto);
    Task DeleteAsync(int id, int trainerId);
    Task<SessionReservationDto> ReserveAsync(int userId, int sessionId);
    Task CancelReservationAsync(int userId, int reservationId);
    Task<IEnumerable<SessionReservationDto>> GetUserReservationsAsync(int userId);
    Task<IEnumerable<TrainingSessionDto>> GetUserPaidGroupScheduleAsync(int userId);
}
