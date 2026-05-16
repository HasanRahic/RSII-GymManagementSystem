using Gym.Api.Services;
using Gym.Services.DTOs;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReferenceController(IReferenceService referenceService) : ControllerBase
{
    [HttpGet("countries")]
    public async Task<IActionResult> GetCountries([FromQuery] int page = 1, [FromQuery] int pageSize = 50)
        => Ok(await referenceService.GetCountriesAsync(page, pageSize));

    [HttpGet("cities")]
    public async Task<IActionResult> GetCities([FromQuery] int? countryId, [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
        => Ok(await referenceService.GetCitiesAsync(countryId, page, pageSize));

    [HttpGet("training-types")]
    public async Task<IActionResult> GetTrainingTypes([FromQuery] int page = 1, [FromQuery] int pageSize = 50)
        => Ok(await referenceService.GetTrainingTypesAsync(page, pageSize));

    [HttpGet("shop-products")]
    public async Task<IActionResult> GetShopProducts(
        [FromQuery] int? gymId,
        [FromQuery] bool activeOnly = true,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50)
        => Ok(await referenceService.GetShopProductsAsync(gymId, activeOnly, page, pageSize));

    [HttpPost("countries")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> CreateCountry([FromBody] CreateCountryDto dto)
        => Ok(await referenceService.CreateCountryAsync(dto));

    [HttpPut("countries/{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateCountry(int id, [FromBody] UpdateCountryDto dto)
        => Ok(await referenceService.UpdateCountryAsync(id, dto));

    [HttpDelete("countries/{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteCountry(int id)
    {
        await referenceService.DeleteCountryAsync(id);
        return NoContent();
    }

    [HttpPost("cities")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> CreateCity([FromBody] CreateCityDto dto)
        => Ok(await referenceService.CreateCityAsync(dto));

    [HttpPut("cities/{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateCity(int id, [FromBody] UpdateCityDto dto)
        => Ok(await referenceService.UpdateCityAsync(id, dto));

    [HttpDelete("cities/{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteCity(int id)
    {
        await referenceService.DeleteCityAsync(id);
        return NoContent();
    }

    [HttpPost("training-types")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> CreateTrainingType([FromBody] CreateTrainingTypeDto dto)
        => Ok(await referenceService.CreateTrainingTypeAsync(dto));

    [HttpPut("training-types/{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateTrainingType(int id, [FromBody] UpdateTrainingTypeDto dto)
        => Ok(await referenceService.UpdateTrainingTypeAsync(id, dto));

    [HttpDelete("training-types/{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteTrainingType(int id)
    {
        await referenceService.DeleteTrainingTypeAsync(id);
        return NoContent();
    }

    [HttpPost("shop-products")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> CreateShopProduct([FromBody] CreateShopProductDto dto)
        => Ok(await referenceService.CreateShopProductAsync(dto));

    [HttpPut("shop-products/{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> UpdateShopProduct(int id, [FromBody] UpdateShopProductDto dto)
        => Ok(await referenceService.UpdateShopProductAsync(id, dto));

    [HttpDelete("shop-products/{id:int}")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> DeleteShopProduct(int id)
    {
        await referenceService.DeleteShopProductAsync(id);
        return NoContent();
    }
}
