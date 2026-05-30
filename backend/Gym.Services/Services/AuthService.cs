using System.Globalization;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;
using Gym.Core.Entities;
using Gym.Core.Enums;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.IdentityModel.Tokens;

namespace Gym.Services.Services;

public class AuthService : IAuthService
{
    private static readonly PasswordHasher<User> PasswordHasher = new();

    private readonly GymDbContext _context;
    private readonly IConfiguration _config;

    public AuthService(GymDbContext context, IConfiguration config)
    {
        _context = context;
        _config = config;
    }

    public async Task<AuthResponseDto> RegisterAsync(RegisterDto dto)
    {
        var normalizedEmail = dto.Email.Trim();
        var normalizedUsername = dto.Username.Trim();

        if (dto.CityId.HasValue && !await _context.Cities.AnyAsync(c => c.Id == dto.CityId.Value))
            throw new InvalidOperationException("Odabrani grad ne postoji.");

        if (await _context.Users.AnyAsync(u => u.Email.ToLower() == normalizedEmail.ToLower()))
            throw new InvalidOperationException("Email je vec zauzet.");

        if (await _context.Users.AnyAsync(u => u.Username.ToLower() == normalizedUsername.ToLower()))
            throw new InvalidOperationException("Korisnicko ime je vec zauzeto.");

        var user = new User
        {
            FirstName = dto.FirstName.Trim(),
            LastName = dto.LastName.Trim(),
            Username = normalizedUsername,
            Email = normalizedEmail,
            PhoneNumber = string.IsNullOrWhiteSpace(dto.PhoneNumber) ? null : dto.PhoneNumber.Trim(),
            DateOfBirth = dto.DateOfBirth,
            CityId = dto.CityId,
            Role = UserRole.Member,
            PasswordSalt = Array.Empty<byte>()
        };

        user.PasswordHash = EncodePasswordHash(PasswordHasher.HashPassword(user, dto.Password));

        _context.Users.Add(user);
        await _context.SaveChangesAsync();

        return new AuthResponseDto(user.Id, user.FirstName, user.LastName,
            user.Username, user.Email, user.Role, GenerateToken(user));
    }

    public async Task<AuthResponseDto> LoginAsync(LoginDto dto)
    {
        var identifier = dto.Username.Trim();
        var user = await _context.Users
            .FirstOrDefaultAsync(u =>
                u.IsActive &&
                (u.Username == identifier || u.Email == identifier));

        if (user is null)
            throw new UnauthorizedAccessException("Neispravno korisnicko ime ili lozinka.");

        if (!await VerifyPasswordAsync(user, dto.Password))
            throw new UnauthorizedAccessException("Neispravno korisnicko ime ili lozinka.");

        return new AuthResponseDto(user.Id, user.FirstName, user.LastName,
            user.Username, user.Email, user.Role, GenerateToken(user));
    }

    public async Task ChangePasswordAsync(int userId, ChangePasswordDto dto, bool isAdmin)
    {
        if (dto.NewPassword != dto.ConfirmPassword)
            throw new InvalidOperationException("Lozinke se ne podudaraju.");

        var user = await _context.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException("Korisnik nije pronadjen.");

        if (!isAdmin)
        {
            if (string.IsNullOrEmpty(dto.OldPassword))
                throw new InvalidOperationException("Stara lozinka je obavezna.");

            if (!await VerifyPasswordAsync(user, dto.OldPassword))
                throw new UnauthorizedAccessException("Stara lozinka nije ispravna.");
        }

        user.PasswordHash = EncodePasswordHash(PasswordHasher.HashPassword(user, dto.NewPassword));
        user.PasswordSalt = Array.Empty<byte>();
        await _context.SaveChangesAsync();
    }

    private async Task<bool> VerifyPasswordAsync(User user, string password)
    {
        if (IsIdentityPasswordHash(user))
        {
            var hashed = DecodePasswordHash(user.PasswordHash);
            var verification = PasswordHasher.VerifyHashedPassword(user, hashed, password);
            return verification switch
            {
                PasswordVerificationResult.Success => true,
                PasswordVerificationResult.SuccessRehashNeeded => await RehashPasswordAsync(user, password),
                _ => false
            };
        }

        if (!VerifyLegacyPassword(user, password))
            return false;

        await RehashPasswordAsync(user, password);
        return true;
    }

    private async Task<bool> RehashPasswordAsync(User user, string password)
    {
        user.PasswordHash = EncodePasswordHash(PasswordHasher.HashPassword(user, password));
        user.PasswordSalt = Array.Empty<byte>();
        await _context.SaveChangesAsync();
        return true;
    }

    private static bool VerifyLegacyPassword(User user, string password)
    {
        if (user.PasswordSalt is null || user.PasswordSalt.Length == 0)
            return false;

        using var hmac = new System.Security.Cryptography.HMACSHA512(user.PasswordSalt);
        var computed = hmac.ComputeHash(Encoding.UTF8.GetBytes(password));
        return computed.SequenceEqual(user.PasswordHash);
    }

    private static bool IsIdentityPasswordHash(User user)
    {
        if (user.PasswordHash is null || user.PasswordHash.Length == 0)
            return false;

        try
        {
            var value = DecodePasswordHash(user.PasswordHash);
            return value.StartsWith("AQAAAA", StringComparison.Ordinal);
        }
        catch
        {
            return false;
        }
    }

    private static byte[] EncodePasswordHash(string hash)
        => Encoding.UTF8.GetBytes(hash);

    private static string DecodePasswordHash(byte[] hash)
        => Encoding.UTF8.GetString(hash);

    private string GenerateToken(User user)
    {
        var key = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_config["JWT:Key"]!));
        var creds = new SigningCredentials(key, SecurityAlgorithms.HmacSha512Signature);
        var claims = new List<Claim>
        {
            new(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new(ClaimTypes.Name, user.Username),
            new(ClaimTypes.Email, user.Email),
            new(ClaimTypes.Role, user.Role.ToString()),
            new(JwtRegisteredClaimNames.Jti, Guid.NewGuid().ToString("N"))
        };

        var expires = DateTime.UtcNow.AddMinutes(
            double.Parse(_config["JWT:ExpiresInMinutes"] ?? "60", CultureInfo.InvariantCulture));

        var token = new JwtSecurityToken(
            issuer: _config["JWT:Issuer"],
            audience: _config["JWT:Audience"],
            claims: claims,
            expires: expires,
            signingCredentials: creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }
}
