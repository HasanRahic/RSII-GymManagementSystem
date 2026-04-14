using Gym.Core.Enums;

namespace Gym.Services.DTOs;

public record RegisterDto(
    string FirstName,
    string LastName,
    string Username,
    string Email,
    string Password,
    string? PhoneNumber,
    DateTime? DateOfBirth,
    int? CityId
);

public record LoginDto(string Username, string Password);

public record AuthResponseDto(
    int Id,
    string FirstName,
    string LastName,
    string Username,
    string Email,
    UserRole Role,
    string Token
);

public record UserDto(
    int Id,
    string FirstName,
    string LastName,
    string Username,
    string Email,
    string? PhoneNumber,
    DateTime? DateOfBirth,
    UserRole Role,
    bool IsActive,
    string? ProfileImageUrl,
    int? CityId,
    string? CityName,
    int? PrimaryGymId,
    string? PrimaryGymName
);

public record UpdateUserDto(
    string FirstName,
    string LastName,
    string Email,
    string? PhoneNumber,
    DateTime? DateOfBirth,
    int? CityId,
    int? PrimaryGymId,
    string? ProfileImageUrl
);

public record ChangePasswordDto(
    string? OldPassword,
    string NewPassword,
    string ConfirmPassword
);
