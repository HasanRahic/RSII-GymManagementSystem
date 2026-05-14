using System.ComponentModel.DataAnnotations;
using Gym.Core.Enums;

namespace Gym.Services.DTOs;

public record RegisterDto(
    [property: Required, StringLength(50, MinimumLength = 2)]
    string FirstName,
    [property: Required, StringLength(50, MinimumLength = 2)]
    string LastName,
    [property: Required, StringLength(50, MinimumLength = 3)]
    string Username,
    [property: Required, EmailAddress, StringLength(256)]
    string Email,
    [property: Required, MinLength(8)]
    string Password,
    [property: Phone]
    string? PhoneNumber,
    DateTime? DateOfBirth,
    int? CityId
);

public record LoginDto(
    [property: Required]
    string Username,
    [property: Required]
    string Password);

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
    [property: Required, StringLength(50, MinimumLength = 2)]
    string FirstName,
    [property: Required, StringLength(50, MinimumLength = 2)]
    string LastName,
    [property: Required, EmailAddress, StringLength(256)]
    string Email,
    [property: Phone]
    string? PhoneNumber,
    DateTime? DateOfBirth,
    int? CityId,
    int? PrimaryGymId,
    string? ProfileImageUrl
);

public record ChangePasswordDto(
    string? OldPassword,
    [property: Required, MinLength(8)]
    string NewPassword,
    [property: Required, MinLength(8)]
    string ConfirmPassword
);
