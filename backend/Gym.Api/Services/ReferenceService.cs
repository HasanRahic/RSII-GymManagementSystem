using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Microsoft.EntityFrameworkCore;

namespace Gym.Api.Services;

public sealed class ReferenceService(GymDbContext db) : IReferenceService
{
    public async Task<IReadOnlyList<CountryDto>> GetCountriesAsync(int page, int pageSize)
    {
        var (skip, take) = Normalize(page, pageSize, 200);
        return await db.Countries
            .AsNoTracking()
            .OrderBy(c => c.Name)
            .Skip(skip)
            .Take(take)
            .Select(c => new CountryDto(c.Id, c.Name, c.Code))
            .ToListAsync();
    }

    public async Task<IReadOnlyList<CityDto>> GetCitiesAsync(int? countryId, int page, int pageSize)
    {
        var (skip, take) = Normalize(page, pageSize, 200);
        var query = db.Cities
            .AsNoTracking()
            .Include(c => c.Country)
            .AsQueryable();

        if (countryId.HasValue)
        {
            query = query.Where(c => c.CountryId == countryId.Value);
        }

        return await query
            .OrderBy(c => c.Name)
            .Skip(skip)
            .Take(take)
            .Select(c => new CityDto(c.Id, c.Name, c.PostalCode, c.CountryId, c.Country.Name))
            .ToListAsync();
    }

    public async Task<IReadOnlyList<TrainingTypeDto>> GetTrainingTypesAsync(int page, int pageSize)
    {
        var (skip, take) = Normalize(page, pageSize, 200);
        return await db.TrainingTypes
            .AsNoTracking()
            .OrderBy(t => t.Name)
            .Skip(skip)
            .Take(take)
            .Select(t => new TrainingTypeDto(t.Id, t.Name, t.Description))
            .ToListAsync();
    }

    private static (int skip, int take) Normalize(int page, int pageSize, int maxPageSize)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, maxPageSize);
        return ((page - 1) * pageSize, pageSize);
    }
}
