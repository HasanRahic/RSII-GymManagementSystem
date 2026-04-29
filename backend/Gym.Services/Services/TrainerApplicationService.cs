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
        var a = await _context.TrainerApplications
            .Include(a => a.User)
            .FirstOrDefaultAsync(a => a.Id == id);
        return a is null ? null : ToDto(a);
    }

    public async Task<TrainerApplicationDto> CreateAsync(int userId, CreateTrainerApplicationDto dto)
    {
        var hasPending = await _context.TrainerApplications
            .AnyAsync(a => a.UserId == userId && a.Status == ApplicationStatus.Pending);
        if (hasPending)
            throw new InvalidOperationException("Već imate zahtjev na čekanju.");

        var app = new TrainerApplication
        {
            UserId         = userId,
            Biography      = dto.Biography,
            Experience     = dto.Experience,
            Certifications = dto.Certifications,
            Availability   = dto.Availability
        };
        _context.TrainerApplications.Add(app);
        await _context.SaveChangesAsync();
        await _context.Entry(app).Reference(a => a.User).LoadAsync();
        return ToDto(app);
    }

    public async Task<TrainerApplicationDto> ReviewAsync(int id, int adminId, ReviewApplicationDto dto)
    {
        var app = await _context.TrainerApplications.Include(a => a.User)
            .FirstOrDefaultAsync(a => a.Id == id)
            ?? throw new KeyNotFoundException("Zahtjev nije pronađen.");

        app.Status              = dto.Status;
        app.AdminNote           = dto.AdminNote;
        app.ReviewedByAdminId   = adminId;
        app.ReviewedAt          = DateTime.UtcNow;

        if (dto.Status == ApplicationStatus.Approved)
            app.User.Role = UserRole.Trainer;

        await _context.SaveChangesAsync();
        return ToDto(app);
    }

    private static TrainerApplicationDto ToDto(TrainerApplication a) => new(
        a.Id, a.UserId, $"{a.User.FirstName} {a.User.LastName}", a.User.Email,
        a.Biography, a.Experience, a.Certifications, a.Availability,
        a.Status, a.AdminNote, a.SubmittedAt, a.ReviewedAt);
}
