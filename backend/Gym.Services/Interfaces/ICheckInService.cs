using Gym.Services.DTOs;

namespace Gym.Services.Interfaces;

public interface ICheckInService
{
    Task<CheckInDto> CheckInAsync(int userId, CheckInRequestDto dto);
    Task<CheckInDto> CheckOutAsync(int userId, CheckOutRequestDto dto);
    Task<IEnumerable<CheckInDto>> GetUserHistoryAsync(int userId, DateTime? from, DateTime? to, int page = 1, int pageSize = 100);
    Task<IEnumerable<CheckInDto>> GetGymCheckInsAsync(int gymId, DateTime? date, int page = 1, int pageSize = 100);
    Task<CheckInDto?> GetActiveCheckInAsync(int userId);
}
