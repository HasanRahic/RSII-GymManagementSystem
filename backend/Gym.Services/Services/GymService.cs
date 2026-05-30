using Gym.Core.Entities;
using Gym.Core.Enums;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Gym.Services.Services;

public class GymService : IGymService
{
    private readonly GymDbContext _context;

    public GymService(GymDbContext context) => _context = context;

    public async Task<IEnumerable<GymDto>> GetAllAsync(string? search, string? city, GymStatus? status)
    {
        var query = _context.Gyms
            .AsNoTracking()
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(g => g.Name.Contains(search) || g.Address.Contains(search));

        if (!string.IsNullOrWhiteSpace(city))
            query = query.Where(g => g.City.Name.Contains(city));

        if (status.HasValue)
            query = query.Where(g => g.Status == status.Value);

        return await query
            .Select(g => new GymDto(
                g.Id, g.Name, g.Address, g.Description, g.PhoneNumber, g.Email, g.ImageUrl,
                g.OpenTime, g.CloseTime, g.Capacity, g.CurrentOccupancy, g.Status,
                g.Latitude, g.Longitude, g.CityId, g.City.Name, g.City.Country.Name))
            .ToListAsync();
    }

    public async Task<GymDto?> GetByIdAsync(int id)
    {
        return await _context.Gyms
            .AsNoTracking()
            .Where(g => g.Id == id)
            .Select(g => new GymDto(
                g.Id, g.Name, g.Address, g.Description, g.PhoneNumber, g.Email, g.ImageUrl,
                g.OpenTime, g.CloseTime, g.Capacity, g.CurrentOccupancy, g.Status,
                g.Latitude, g.Longitude, g.CityId, g.City.Name, g.City.Country.Name))
            .FirstOrDefaultAsync();
    }

    public async Task<GymDto> CreateAsync(CreateGymDto dto)
    {
        await ValidateGymAsync(dto.CityId, dto.OpenTime, dto.CloseTime, dto.Capacity, dto.Latitude, dto.Longitude);

        var gym = new GymFacility
        {
            Name = dto.Name.Trim(),
            Address = dto.Address.Trim(),
            Description = string.IsNullOrWhiteSpace(dto.Description) ? null : dto.Description.Trim(),
            PhoneNumber = string.IsNullOrWhiteSpace(dto.PhoneNumber) ? null : dto.PhoneNumber.Trim(),
            Email = string.IsNullOrWhiteSpace(dto.Email) ? null : dto.Email.Trim(),
            OpenTime = dto.OpenTime,
            CloseTime = dto.CloseTime,
            Capacity = dto.Capacity,
            CityId = dto.CityId,
            Latitude = dto.Latitude,
            Longitude = dto.Longitude
        };

        _context.Gyms.Add(gym);
        await _context.SaveChangesAsync();
        return (await GetByIdAsync(gym.Id))!;
    }

    public async Task<GymDto> UpdateAsync(int id, UpdateGymDto dto)
    {
        var gym = await _context.Gyms.FindAsync(id)
            ?? throw new KeyNotFoundException("Teretana nije pronadjena.");

        await ValidateGymAsync(dto.CityId, dto.OpenTime, dto.CloseTime, dto.Capacity, dto.Latitude, dto.Longitude);

        gym.Name = dto.Name.Trim();
        gym.Address = dto.Address.Trim();
        gym.Description = string.IsNullOrWhiteSpace(dto.Description) ? null : dto.Description.Trim();
        gym.PhoneNumber = string.IsNullOrWhiteSpace(dto.PhoneNumber) ? null : dto.PhoneNumber.Trim();
        gym.Email = string.IsNullOrWhiteSpace(dto.Email) ? null : dto.Email.Trim();
        gym.OpenTime = dto.OpenTime;
        gym.CloseTime = dto.CloseTime;
        gym.Capacity = dto.Capacity;
        gym.CityId = dto.CityId;
        gym.Status = dto.Status;
        gym.Latitude = dto.Latitude;
        gym.Longitude = dto.Longitude;

        await _context.SaveChangesAsync();
        return (await GetByIdAsync(id))!;
    }

    public async Task<GymDto> UpdateStatusAsync(int id, GymStatus status)
    {
        var gym = await _context.Gyms.FindAsync(id)
            ?? throw new KeyNotFoundException("Teretana nije pronadjena.");

        gym.Status = status;
        await _context.SaveChangesAsync();
        return (await GetByIdAsync(id))!;
    }

    private async Task ValidateGymAsync(
        int cityId,
        TimeOnly openTime,
        TimeOnly closeTime,
        int capacity,
        double? latitude,
        double? longitude)
    {
        if (capacity <= 0)
            throw new InvalidOperationException("Kapacitet mora biti veci od nule.");

        if (closeTime <= openTime)
            throw new InvalidOperationException("Vrijeme zatvaranja mora biti nakon vremena otvaranja.");

        if (latitude.HasValue && (latitude.Value < -90 || latitude.Value > 90))
            throw new InvalidOperationException("Latitude mora biti izmedju -90 i 90.");

        if (longitude.HasValue && (longitude.Value < -180 || longitude.Value > 180))
            throw new InvalidOperationException("Longitude mora biti izmedju -180 i 180.");

        var cityExists = await _context.Cities.AnyAsync(c => c.Id == cityId);
        if (!cityExists)
            throw new InvalidOperationException("Odabrani grad ne postoji.");
    }
}
