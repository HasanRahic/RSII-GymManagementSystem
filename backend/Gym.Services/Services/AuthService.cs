using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;
using Gym.Core.Entities;
using Gym.Core.Enums;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace Gym.Services.Services;

public class AuthService : IAuthService
{
    private readonly GymDbContext _context;
    private readonly IConfiguration _config;

    public AuthService(GymDbContext context, IConfiguration config)
    {
        _context = context;
        _config = config;
    }

    public async Task<AuthResponseDto> RegisterAsync(RegisterDto dto)
    {
        if (await _context.Users.AnyAsync(u => u.Email == dto.Email))
            throw new InvalidOperationException("Email je već zauzet.");

        if (await _context.Users.AnyAsync(u => u.Username == dto.Username))
            throw new InvalidOperationException("Korisničko ime je već zauzeto.");

        using var hmac = new HMACSHA512();
        var user = new User
        {
            FirstName    = dto.FirstName,
            LastName     = dto.LastName,
            Username     = dto.Username,
            Email        = dto.Email,
            PhoneNumber  = dto.PhoneNumber,
            DateOfBirth  = dto.DateOfBirth,
            CityId       = dto.CityId,
            Role         = UserRole.Member,
            PasswordSalt = hmac.Key,
            PasswordHash = hmac.ComputeHash(Encoding.UTF8.GetBytes(dto.Password))
        };

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        return new AuthResponseDto(user.Id, user.FirstName, user.LastName,
            user.Username, user.Email, user.Role, GenerateToken(user));
    }

    public async Task<AuthResponseDto> LoginAsync(LoginDto dto)
    {
        var user = await _context.Users
            .FirstOrDefaultAsync(u => u.Username == dto.Username && u.IsActive);

        if (user is null)
            throw new UnauthorizedAccessException("Neispravno korisničko ime ili lozinka.");

        using var hmac = new HMACSHA512(user.PasswordSalt);
        var computed = hmac.ComputeHash(Encoding.UTF8.GetBytes(dto.Password));

        if (!computed.SequenceEqual(user.PasswordHash))
            throw new UnauthorizedAccessException("Neispravno korisničko ime ili lozinka.");

        return new AuthResponseDto(user.Id, user.FirstName, user.LastName,
            user.Username, user.Email, user.Role, GenerateToken(user));
    }

    public async Task ChangePasswordAsync(int userId, ChangePasswordDto dto, bool isAdmin)
    {
        if (dto.NewPassword != dto.ConfirmPassword)
            throw new InvalidOperationException("Lozinke se ne podudaraju.");

        var user = await _context.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException("Korisnik nije pronađen.");

        if (!isAdmin)
        {
            if (string.IsNullOrEmpty(dto.OldPassword))
                throw new InvalidOperationException("Stara lozinka je obavezna.");

            using var hmacCheck = new HMACSHA512(user.PasswordSalt);
            var computed = hmacCheck.ComputeHash(Encoding.UTF8.GetBytes(dto.OldPassword));
            if (!computed.SequenceEqual(user.PasswordHash))
                throw new UnauthorizedAccessException("Stara lozinka nije ispravna.");
        }

        using var hmac = new HMACSHA512();
        user.PasswordSalt = hmac.Key;
        user.PasswordHash = hmac.ComputeHash(Encoding.UTF8.GetBytes(dto.NewPassword));
        await _context.SaveChangesAsync();
    }

    private string GenerateToken(User user)
    {
        var key    = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_config["JWT:Key"]!));
        var creds  = new SigningCredentials(key, SecurityAlgorithms.HmacSha512Signature);
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Name,           user.Username),
            new(ClaimTypes.Email,          user.Email),
            new(ClaimTypes.Role,           user.Role.ToString())
        };

        var expires = DateTime.UtcNow.AddMinutes(
            double.Parse(_config["JWT:ExpiresInMinutes"] ?? "60"));

        var token = new JwtSecurityToken(
            issuer:              _config["JWT:Issuer"],
            audience:            _config["JWT:Audience"],
            claims:              claims,
            expires:             expires,
            signingCredentials:  creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
