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
            .Include(g => g.City).ThenInclude(c => c.Country)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(g => g.Name.Contains(search) || g.Address.Contains(search));

        if (!string.IsNullOrWhiteSpace(city))
            query = query.Where(g => g.City.Name.Contains(city));

        if (status.HasValue)
            query = query.Where(g => g.Status == status.Value);

        return (await query.ToListAsync()).Select(ToDto);
    }

    public async Task<GymDto?> GetByIdAsync(int id)
    {
        var gym = await _context.Gyms
            .Include(g => g.City).ThenInclude(c => c.Country)
            .FirstOrDefaultAsync(g => g.Id == id);

        return gym is null ? null : ToDto(gym);
    }

    public async Task<GymDto> CreateAsync(CreateGymDto dto)
    {
        var gym = new GymFacility
        {
            Name        = dto.Name,
            Address     = dto.Address,
            Description = dto.Description,
            PhoneNumber = dto.PhoneNumber,
            Email       = dto.Email,
            OpenTime    = dto.OpenTime,
            CloseTime   = dto.CloseTime,
            Capacity    = dto.Capacity,
            CityId      = dto.CityId,
            Latitude    = dto.Latitude,
            Longitude   = dto.Longitude
        };

        _context.Gyms.Add(gym);
        await _context.SaveChangesAsync();
        return (await GetByIdAsync(gym.Id))!;
    }

    public async Task<GymDto> UpdateAsync(int id, UpdateGymDto dto)
    {
        var gym = await _context.Gyms.FindAsync(id)
            ?? throw new KeyNotFoundException("Teretana nije pronađena.");

        gym.Name        = dto.Name;
        gym.Address     = dto.Address;
        gym.Description = dto.Description;
        gym.PhoneNumber = dto.PhoneNumber;
        gym.Email       = dto.Email;
        gym.OpenTime    = dto.OpenTime;
        gym.CloseTime   = dto.CloseTime;
        gym.Capacity    = dto.Capacity;
        gym.CityId      = dto.CityId;
        gym.Status      = dto.Status;
        gym.Latitude    = dto.Latitude;
        gym.Longitude   = dto.Longitude;

        await _context.SaveChangesAsync();
        return (await GetByIdAsync(id))!;
    }

    public async Task<GymDto> UpdateStatusAsync(int id, GymStatus status)
    {
        var gym = await _context.Gyms.FindAsync(id)
            ?? throw new KeyNotFoundException("Teretana nije pronađena.");

        gym.Status = status;
        await _context.SaveChangesAsync();
        return (await GetByIdAsync(id))!;
    }

    private static GymDto ToDto(GymFacility g) => new(
        g.Id, g.Name, g.Address, g.Description, g.PhoneNumber, g.Email, g.ImageUrl,
        g.OpenTime, g.CloseTime, g.Capacity, g.CurrentOccupancy, g.Status,
        g.Latitude, g.Longitude, g.CityId, g.City.Name, g.City.Country.Name);
}
