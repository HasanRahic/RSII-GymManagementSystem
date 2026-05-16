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
            query = query.Where(c => c.CountryId == countryId.Value);

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

    public async Task<IReadOnlyList<ShopProductDto>> GetShopProductsAsync(int? gymId, bool activeOnly, int page, int pageSize)
    {
        var (skip, take) = Normalize(page, pageSize, 200);
        var query = db.ShopProducts
            .AsNoTracking()
            .Include(p => p.Gym)
            .AsQueryable();

        if (gymId.HasValue)
            query = query.Where(p => p.GymId == gymId.Value);

        if (activeOnly)
            query = query.Where(p => p.IsActive);

        return await query
            .OrderBy(p => p.Gym.Name)
            .ThenBy(p => p.Category)
            .ThenBy(p => p.Name)
            .Skip(skip)
            .Take(take)
            .Select(p => new ShopProductDto(
                p.Id,
                p.Name,
                p.Category,
                p.Description,
                p.Price,
                p.StockQuantity,
                p.Emoji,
                p.IsActive,
                p.GymId,
                p.Gym.Name))
            .ToListAsync();
    }

    public async Task<CountryDto> CreateCountryAsync(CreateCountryDto dto)
    {
        await EnsureCountryUniqueAsync(dto.Name, dto.Code);

        var entity = new Gym.Core.Entities.Country
        {
            Name = dto.Name.Trim(),
            Code = dto.Code.Trim().ToUpperInvariant()
        };

        db.Countries.Add(entity);
        await db.SaveChangesAsync();
        return new CountryDto(entity.Id, entity.Name, entity.Code);
    }

    public async Task<CountryDto> UpdateCountryAsync(int id, UpdateCountryDto dto)
    {
        var entity = await db.Countries.FirstOrDefaultAsync(c => c.Id == id)
            ?? throw new KeyNotFoundException("Drzava nije pronadjena.");

        await EnsureCountryUniqueAsync(dto.Name, dto.Code, id);

        entity.Name = dto.Name.Trim();
        entity.Code = dto.Code.Trim().ToUpperInvariant();
        await db.SaveChangesAsync();
        return new CountryDto(entity.Id, entity.Name, entity.Code);
    }

    public async Task DeleteCountryAsync(int id)
    {
        var entity = await db.Countries
            .Include(c => c.Cities)
            .FirstOrDefaultAsync(c => c.Id == id)
            ?? throw new KeyNotFoundException("Drzava nije pronadjena.");

        if (entity.Cities.Any())
            throw new InvalidOperationException("Drzava se ne moze obrisati jer postoje povezani gradovi.");

        db.Countries.Remove(entity);
        await db.SaveChangesAsync();
    }

    public async Task<CityDto> CreateCityAsync(CreateCityDto dto)
    {
        var country = await db.Countries.FirstOrDefaultAsync(c => c.Id == dto.CountryId)
            ?? throw new KeyNotFoundException("Drzava nije pronadjena.");

        await EnsureCityUniqueAsync(dto.Name, dto.CountryId);

        var entity = new Gym.Core.Entities.City
        {
            Name = dto.Name.Trim(),
            PostalCode = string.IsNullOrWhiteSpace(dto.PostalCode) ? null : dto.PostalCode.Trim(),
            CountryId = dto.CountryId,
            Country = country
        };

        db.Cities.Add(entity);
        await db.SaveChangesAsync();
        return new CityDto(entity.Id, entity.Name, entity.PostalCode, entity.CountryId, country.Name);
    }

    public async Task<CityDto> UpdateCityAsync(int id, UpdateCityDto dto)
    {
        var entity = await db.Cities.Include(c => c.Country).FirstOrDefaultAsync(c => c.Id == id)
            ?? throw new KeyNotFoundException("Grad nije pronadjen.");

        var country = await db.Countries.FirstOrDefaultAsync(c => c.Id == dto.CountryId)
            ?? throw new KeyNotFoundException("Drzava nije pronadjena.");

        await EnsureCityUniqueAsync(dto.Name, dto.CountryId, id);

        entity.Name = dto.Name.Trim();
        entity.PostalCode = string.IsNullOrWhiteSpace(dto.PostalCode) ? null : dto.PostalCode.Trim();
        entity.CountryId = dto.CountryId;
        entity.Country = country;
        await db.SaveChangesAsync();

        return new CityDto(entity.Id, entity.Name, entity.PostalCode, entity.CountryId, country.Name);
    }

    public async Task DeleteCityAsync(int id)
    {
        var entity = await db.Cities
            .Include(c => c.Users)
            .Include(c => c.Gyms)
            .FirstOrDefaultAsync(c => c.Id == id)
            ?? throw new KeyNotFoundException("Grad nije pronadjen.");

        if (entity.Users.Any() || entity.Gyms.Any())
            throw new InvalidOperationException("Grad se ne moze obrisati jer se koristi u drugim podacima.");

        db.Cities.Remove(entity);
        await db.SaveChangesAsync();
    }

    public async Task<TrainingTypeDto> CreateTrainingTypeAsync(CreateTrainingTypeDto dto)
    {
        await EnsureTrainingTypeUniqueAsync(dto.Name);

        var entity = new Gym.Core.Entities.TrainingType
        {
            Name = dto.Name.Trim(),
            Description = string.IsNullOrWhiteSpace(dto.Description) ? null : dto.Description.Trim()
        };

        db.TrainingTypes.Add(entity);
        await db.SaveChangesAsync();
        return new TrainingTypeDto(entity.Id, entity.Name, entity.Description);
    }

    public async Task<TrainingTypeDto> UpdateTrainingTypeAsync(int id, UpdateTrainingTypeDto dto)
    {
        var entity = await db.TrainingTypes.FirstOrDefaultAsync(t => t.Id == id)
            ?? throw new KeyNotFoundException("Tip treninga nije pronadjen.");

        await EnsureTrainingTypeUniqueAsync(dto.Name, id);

        entity.Name = dto.Name.Trim();
        entity.Description = string.IsNullOrWhiteSpace(dto.Description) ? null : dto.Description.Trim();
        await db.SaveChangesAsync();
        return new TrainingTypeDto(entity.Id, entity.Name, entity.Description);
    }

    public async Task DeleteTrainingTypeAsync(int id)
    {
        var entity = await db.TrainingTypes
            .Include(t => t.TrainingSessions)
            .FirstOrDefaultAsync(t => t.Id == id)
            ?? throw new KeyNotFoundException("Tip treninga nije pronadjen.");

        if (entity.TrainingSessions.Any())
            throw new InvalidOperationException("Tip treninga se ne moze obrisati jer je povezan sa terminima.");

        db.TrainingTypes.Remove(entity);
        await db.SaveChangesAsync();
    }

    public async Task<ShopProductDto> CreateShopProductAsync(CreateShopProductDto dto)
    {
        ValidateShopProduct(dto.Price, dto.StockQuantity);

        var gym = await db.Gyms.FirstOrDefaultAsync(g => g.Id == dto.GymId)
            ?? throw new KeyNotFoundException("Teretana nije pronadjena.");

        await EnsureShopProductUniqueAsync(dto.Name, dto.GymId);

        var entity = new Gym.Core.Entities.ShopProduct
        {
            Name = dto.Name.Trim(),
            Category = dto.Category.Trim(),
            Description = string.IsNullOrWhiteSpace(dto.Description) ? null : dto.Description.Trim(),
            Price = decimal.Round(dto.Price, 2, MidpointRounding.AwayFromZero),
            StockQuantity = dto.StockQuantity,
            Emoji = string.IsNullOrWhiteSpace(dto.Emoji) ? null : dto.Emoji.Trim(),
            GymId = dto.GymId,
            Gym = gym,
            IsActive = dto.IsActive
        };

        db.ShopProducts.Add(entity);
        await db.SaveChangesAsync();
        return new ShopProductDto(entity.Id, entity.Name, entity.Category, entity.Description, entity.Price, entity.StockQuantity, entity.Emoji, entity.IsActive, entity.GymId, gym.Name);
    }

    public async Task<ShopProductDto> UpdateShopProductAsync(int id, UpdateShopProductDto dto)
    {
        ValidateShopProduct(dto.Price, dto.StockQuantity);

        var entity = await db.ShopProducts
            .Include(p => p.Gym)
            .FirstOrDefaultAsync(p => p.Id == id)
            ?? throw new KeyNotFoundException("Shop proizvod nije pronadjen.");

        var gym = await db.Gyms.FirstOrDefaultAsync(g => g.Id == dto.GymId)
            ?? throw new KeyNotFoundException("Teretana nije pronadjena.");

        await EnsureShopProductUniqueAsync(dto.Name, dto.GymId, id);

        entity.Name = dto.Name.Trim();
        entity.Category = dto.Category.Trim();
        entity.Description = string.IsNullOrWhiteSpace(dto.Description) ? null : dto.Description.Trim();
        entity.Price = decimal.Round(dto.Price, 2, MidpointRounding.AwayFromZero);
        entity.StockQuantity = dto.StockQuantity;
        entity.Emoji = string.IsNullOrWhiteSpace(dto.Emoji) ? null : dto.Emoji.Trim();
        entity.GymId = dto.GymId;
        entity.Gym = gym;
        entity.IsActive = dto.IsActive;
        await db.SaveChangesAsync();

        return new ShopProductDto(entity.Id, entity.Name, entity.Category, entity.Description, entity.Price, entity.StockQuantity, entity.Emoji, entity.IsActive, entity.GymId, gym.Name);
    }

    public async Task DeleteShopProductAsync(int id)
    {
        var entity = await db.ShopProducts
            .Include(p => p.OrderItems)
            .FirstOrDefaultAsync(p => p.Id == id)
            ?? throw new KeyNotFoundException("Shop proizvod nije pronadjen.");

        if (entity.OrderItems.Any())
            throw new InvalidOperationException("Shop proizvod se ne moze obrisati jer postoji u narudzbama.");

        db.ShopProducts.Remove(entity);
        await db.SaveChangesAsync();
    }

    private async Task EnsureCountryUniqueAsync(string name, string code, int? existingId = null)
    {
        var normalizedName = name.Trim().ToLower();
        var normalizedCode = code.Trim().ToUpperInvariant();

        var exists = await db.Countries.AnyAsync(c =>
            (!existingId.HasValue || c.Id != existingId.Value) &&
            (c.Name.ToLower() == normalizedName || c.Code.ToUpper() == normalizedCode));

        if (exists)
            throw new InvalidOperationException("Drzava sa istim nazivom ili kodom vec postoji.");
    }

    private async Task EnsureCityUniqueAsync(string name, int countryId, int? existingId = null)
    {
        var normalizedName = name.Trim().ToLower();

        var exists = await db.Cities.AnyAsync(c =>
            (!existingId.HasValue || c.Id != existingId.Value) &&
            c.CountryId == countryId &&
            c.Name.ToLower() == normalizedName);

        if (exists)
            throw new InvalidOperationException("Grad sa istim nazivom vec postoji za odabranu drzavu.");
    }

    private async Task EnsureTrainingTypeUniqueAsync(string name, int? existingId = null)
    {
        var normalizedName = name.Trim().ToLower();

        var exists = await db.TrainingTypes.AnyAsync(t =>
            (!existingId.HasValue || t.Id != existingId.Value) &&
            t.Name.ToLower() == normalizedName);

        if (exists)
            throw new InvalidOperationException("Tip treninga sa istim nazivom vec postoji.");
    }

    private async Task EnsureShopProductUniqueAsync(string name, int gymId, int? existingId = null)
    {
        var normalizedName = name.Trim().ToLower();

        var exists = await db.ShopProducts.AnyAsync(p =>
            (!existingId.HasValue || p.Id != existingId.Value) &&
            p.GymId == gymId &&
            p.Name.ToLower() == normalizedName);

        if (exists)
            throw new InvalidOperationException("Shop proizvod sa istim nazivom vec postoji za odabranu teretanu.");
    }

    private static void ValidateShopProduct(decimal price, int stockQuantity)
    {
        if (price <= 0m)
            throw new InvalidOperationException("Cijena shop proizvoda mora biti veca od nule.");

        if (stockQuantity < 0)
            throw new InvalidOperationException("Stanje zaliha ne moze biti negativno.");
    }

    private static (int skip, int take) Normalize(int page, int pageSize, int maxPageSize)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, maxPageSize);
        return ((page - 1) * pageSize, pageSize);
    }
}
