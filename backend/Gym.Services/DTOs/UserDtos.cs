using System.ComponentModel.DataAnnotations;
using Gym.Core.Enums;

namespace Gym.Services.DTOs;

public record RegisterDto(
    [Required, StringLength(50, MinimumLength = 2)]
    string FirstName,
    [Required, StringLength(50, MinimumLength = 2)]
    string LastName,
    [Required, StringLength(50, MinimumLength = 3)]
    string Username,
    [Required, EmailAddress, StringLength(256)]
    string Email,
    [Required, MinLength(8)]
    string Password,
    [Phone]
    string? PhoneNumber,
    DateTime? DateOfBirth,
    int? CityId
);

public record LoginDto(
    [Required]
    string Username,
    [Required]
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
    [Required, StringLength(50, MinimumLength = 2)]
    string FirstName,
    [Required, StringLength(50, MinimumLength = 2)]
    string LastName,
    [Required, EmailAddress, StringLength(256)]
    string Email,
    [Phone]
    string? PhoneNumber,
    DateTime? DateOfBirth,
    int? CityId,
    int? PrimaryGymId,
    string? ProfileImageUrl
);

public record ChangePasswordDto(
    string? OldPassword,
    [Required, MinLength(8)]
    string NewPassword,
    [Required, MinLength(8)]
    string ConfirmPassword
);
