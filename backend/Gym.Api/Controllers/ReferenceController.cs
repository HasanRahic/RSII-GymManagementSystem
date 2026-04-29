using Gym.Api.Services;
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
}
