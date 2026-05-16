using Gym.Services.DTOs;

namespace Gym.Api.Services;

public interface IReferenceService
{
    Task<IReadOnlyList<CountryDto>> GetCountriesAsync(int page, int pageSize);
    Task<IReadOnlyList<CityDto>> GetCitiesAsync(int? countryId, int page, int pageSize);
    Task<IReadOnlyList<TrainingTypeDto>> GetTrainingTypesAsync(int page, int pageSize);
    Task<IReadOnlyList<ShopProductDto>> GetShopProductsAsync(int? gymId, bool activeOnly, int page, int pageSize);
    Task<CountryDto> CreateCountryAsync(CreateCountryDto dto);
    Task<CountryDto> UpdateCountryAsync(int id, UpdateCountryDto dto);
    Task DeleteCountryAsync(int id);
    Task<CityDto> CreateCityAsync(CreateCityDto dto);
    Task<CityDto> UpdateCityAsync(int id, UpdateCityDto dto);
    Task DeleteCityAsync(int id);
    Task<TrainingTypeDto> CreateTrainingTypeAsync(CreateTrainingTypeDto dto);
    Task<TrainingTypeDto> UpdateTrainingTypeAsync(int id, UpdateTrainingTypeDto dto);
    Task DeleteTrainingTypeAsync(int id);
    Task<ShopProductDto> CreateShopProductAsync(CreateShopProductDto dto);
    Task<ShopProductDto> UpdateShopProductAsync(int id, UpdateShopProductDto dto);
    Task DeleteShopProductAsync(int id);
}
