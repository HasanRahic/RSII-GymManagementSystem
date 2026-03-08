using Gym.Infrastructure.Data;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;

namespace Gym.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
public class ReferenceController(GymDbContext db) : ControllerBase
{
    [HttpGet("countries")]
    public async Task<IActionResult> GetCountries()
        => Ok(await db.Countries
            .Select(c => new { c.Id, c.Name, c.Code })
            .ToListAsync());

    [HttpGet("cities")]
    public async Task<IActionResult> GetCities([FromQuery] int? countryId)
    {
        var query = db.Cities.Include(c => c.Country).AsQueryable();
        if (countryId.HasValue)
            query = query.Where(c => c.CountryId == countryId.Value);
        return Ok(await query
            .Select(c => new { c.Id, c.Name, c.PostalCode, CountryName = c.Country.Name })
            .ToListAsync());
    }

    [HttpGet("training-types")]
    public async Task<IActionResult> GetTrainingTypes()
        => Ok(await db.TrainingTypes
            .Select(t => new { t.Id, t.Name, t.Description })
            .ToListAsync());
}
