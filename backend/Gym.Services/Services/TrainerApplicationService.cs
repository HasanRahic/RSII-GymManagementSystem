using Gym.Core.Entities;
using Gym.Core.Enums;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Gym.Services.Services;

public class TrainerApplicationService : ITrainerApplicationService
{
    private readonly GymDbContext _context;

    public TrainerApplicationService(GymDbContext context) => _context = context;

    public async Task<IEnumerable<TrainerApplicationDto>> GetAllAsync(ApplicationStatus? status, int page = 1, int pageSize = 20)
    {
        page = Math.Max(page, 1);
        pageSize = Math.Clamp(pageSize, 1, 100);

        var query = _context.TrainerApplications
            .Include(a => a.User)
            .AsQueryable();

        if (status.HasValue)
            query = query.Where(a => a.Status == status.Value);

        return (await query
            .OrderByDescending(a => a.SubmittedAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync()).Select(ToDto);
    }

    public async Task<TrainerApplicationDto?> GetByIdAsync(int id)
    {
        var application = await _context.TrainerApplications
            .Include(a => a.User)
            .FirstOrDefaultAsync(a => a.Id == id);

        return application is null ? null : ToDto(application);
    }

    public async Task<TrainerApplicationDto> CreateAsync(int userId, CreateTrainerApplicationDto dto)
    {
        var user = await _context.Users.FindAsync(userId)
            ?? throw new KeyNotFoundException("Korisnik nije pronadjen.");

        if (user.Role == UserRole.Trainer)
            throw new InvalidOperationException("Korisnik vec ima trener ulogu.");

        var hasPending = await _context.TrainerApplications
            .AnyAsync(a => a.UserId == userId && a.Status == ApplicationStatus.Pending);
        if (hasPending)
            throw new InvalidOperationException("Vec imate zahtjev na cekanju.");

        var application = new TrainerApplication
        {
            UserId = userId,
            User = user,
            Biography = dto.Biography.Trim(),
            Experience = dto.Experience.Trim(),
            Certifications = string.IsNullOrWhiteSpace(dto.Certifications) ? null : dto.Certifications.Trim(),
            Availability = string.IsNullOrWhiteSpace(dto.Availability) ? null : dto.Availability.Trim()
        };

        _context.TrainerApplications.Add(application);
        await _context.SaveChangesAsync();
        return ToDto(application);
    }

    public async Task<TrainerApplicationDto> ReviewAsync(int id, int adminId, ReviewApplicationDto dto)
    {
        var application = await _context.TrainerApplications
            .Include(a => a.User)
            .FirstOrDefaultAsync(a => a.Id == id)
            ?? throw new KeyNotFoundException("Zahtjev nije pronadjen.");

        if (application.Status != ApplicationStatus.Pending)
            throw new InvalidOperationException("Dozvoljena je obrada samo zahtjeva koji su trenutno na cekanju.");

        if (dto.Status == ApplicationStatus.Pending)
            throw new InvalidOperationException("Review mora zavrsiti zahtjev odobravanjem ili odbijanjem.");

        if (dto.Status == ApplicationStatus.Rejected && string.IsNullOrWhiteSpace(dto.AdminNote))
            throw new InvalidOperationException("Kod odbijanja zahtjeva admin napomena je obavezna.");

        application.Status = dto.Status;
        application.AdminNote = string.IsNullOrWhiteSpace(dto.AdminNote) ? null : dto.AdminNote.Trim();
        application.ReviewedByAdminId = adminId;
        application.ReviewedAt = DateTime.UtcNow;

        if (dto.Status == ApplicationStatus.Approved)
            application.User.Role = UserRole.Trainer;

        await _context.SaveChangesAsync();
        return ToDto(application);
    }

    private static TrainerApplicationDto ToDto(TrainerApplication a) => new(
        a.Id,
        a.UserId,
        $"{a.User.FirstName} {a.User.LastName}",
        a.User.Email,
        a.Biography,
        a.Experience,
        a.Certifications,
        a.Availability,
        a.Status,
        a.AdminNote,
        a.SubmittedAt,
        a.ReviewedAt);
}
