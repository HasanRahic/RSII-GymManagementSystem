using Gym.Services.DTOs;

namespace Gym.Api.Services;

public interface IReferenceService
{
    Task<IReadOnlyList<CountryDto>> GetCountriesAsync(int page, int pageSize);
    Task<IReadOnlyList<CityDto>> GetCitiesAsync(int? countryId, int page, int pageSize);
    Task<IReadOnlyList<TrainingTypeDto>> GetTrainingTypesAsync(int page, int pageSize);
}
