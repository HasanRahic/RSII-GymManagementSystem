using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Gym.Services.Services;

public class UserService : IUserService
{
    private readonly GymDbContext _context;

    public UserService(GymDbContext context) => _context = context;

    public async Task<IEnumerable<UserDto>> GetAllAsync(string? search, string? role, int page = 1, int pageSize = 20)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var query = _context.Users
            .Include(u => u.City).ThenInclude(c => c!.Country)
            .Include(u => u.PrimaryGym)
            .AsQueryable();

        if (!string.IsNullOrWhiteSpace(search))
            query = query.Where(u =>
                u.FirstName.Contains(search) ||
                u.LastName.Contains(search)  ||
                u.Email.Contains(search)     ||
                u.Username.Contains(search));

        if (!string.IsNullOrWhiteSpace(role) &&
            Enum.TryParse<Core.Enums.UserRole>(role, true, out var roleEnum))
            query = query.Where(u => u.Role == roleEnum);

        return (await query
            .OrderBy(u => u.FirstName)
            .ThenBy(u => u.LastName)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync()).Select(ToDto);
    }

    public async Task<UserDto?> GetByIdAsync(int id)
    {
        var user = await _context.Users
            .Include(u => u.City).ThenInclude(c => c!.Country)
            .Include(u => u.PrimaryGym)
            .FirstOrDefaultAsync(u => u.Id == id);

        return user is null ? null : ToDto(user);
    }

    public async Task<UserDto> UpdateAsync(int id, UpdateUserDto dto)
    {
        var user = await _context.Users.FindAsync(id)
            ?? throw new KeyNotFoundException("Korisnik nije pronađen.");

        var normalizedEmail = dto.Email.Trim();
        if (string.IsNullOrWhiteSpace(normalizedEmail))
            throw new InvalidOperationException("Email je obavezan.");

        var emailTaken = await _context.Users
            .AnyAsync(u => u.Id != id && u.Email == normalizedEmail);
        if (emailTaken)
            throw new InvalidOperationException("Email je već zauzet.");

        user.FirstName      = dto.FirstName;
        user.LastName       = dto.LastName;
        user.Email          = normalizedEmail;
        user.PhoneNumber    = dto.PhoneNumber;
        user.DateOfBirth    = dto.DateOfBirth;
        user.CityId         = dto.CityId;
        user.PrimaryGymId   = dto.PrimaryGymId;
        user.ProfileImageUrl = dto.ProfileImageUrl;

        await _context.SaveChangesAsync();
        return (await GetByIdAsync(id))!;
    }

    public async Task SetActiveAsync(int id, bool isActive)
    {
        var user = await _context.Users.FindAsync(id)
            ?? throw new KeyNotFoundException("Korisnik nije pronađen.");

        user.IsActive = isActive;
        await _context.SaveChangesAsync();
    }

    private static UserDto ToDto(Core.Entities.User u) => new(
        u.Id, u.FirstName, u.LastName, u.Username, u.Email,
        u.PhoneNumber, u.DateOfBirth, u.Role, u.IsActive, u.ProfileImageUrl,
        u.CityId, u.City?.Name, u.PrimaryGymId, u.PrimaryGym?.Name);
}
