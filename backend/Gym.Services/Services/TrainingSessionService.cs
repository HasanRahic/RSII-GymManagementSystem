using Gym.Core.Entities;
using Gym.Core.Enums;
using Gym.Infrastructure.Data;
using Gym.Services.DTOs;
using Gym.Services.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace Gym.Services.Services;

public class TrainingSessionService : ITrainingSessionService
{
    private readonly GymDbContext _context;

    public TrainingSessionService(GymDbContext context) => _context = context;

    public async Task<IEnumerable<TrainingSessionDto>> GetAllAsync(int? gymId, int? trainerId, int? typeId)
    {
        var query = _context.TrainingSessions
            .Include(s => s.Trainer)
            .Include(s => s.Gym)
            .Include(s => s.TrainingType)
            .Include(s => s.Reservations)
            .Where(s => s.IsActive)
            .AsQueryable();

        if (gymId.HasValue)     query = query.Where(s => s.GymId == gymId.Value);
        if (trainerId.HasValue) query = query.Where(s => s.TrainerId == trainerId.Value);
        if (typeId.HasValue)    query = query.Where(s => s.TrainingTypeId == typeId.Value);

        return (await query.OrderBy(s => s.Date).ThenBy(s => s.StartTime).ToListAsync()).Select(ToDto);
    }

    public async Task<TrainingSessionDto?> GetByIdAsync(int id)
    {
        var s = await _context.TrainingSessions
            .Include(s => s.Trainer).Include(s => s.Gym)
            .Include(s => s.TrainingType).Include(s => s.Reservations)
            .FirstOrDefaultAsync(s => s.Id == id);
        return s is null ? null : ToDto(s);
    }

    public async Task<TrainingSessionDto> CreateAsync(int trainerId, CreateTrainingSessionDto dto)
    {
        var session = new TrainingSession
        {
            Title          = dto.Title,
            Description    = dto.Description,
            Type           = dto.Type,
            Date           = dto.Date,
            StartTime      = dto.StartTime,
            EndTime        = dto.EndTime,
            MaxParticipants = dto.MaxParticipants,
            Price          = dto.Price,
            TrainerId      = trainerId,
            GymId          = dto.GymId,
            TrainingTypeId = dto.TrainingTypeId
        };

        _context.TrainingSessions.Add(session);
        await _context.SaveChangesAsync();
        return (await GetByIdAsync(session.Id))!;
    }

    public async Task DeleteAsync(int id, int trainerId)
    {
        var session = await _context.TrainingSessions.FindAsync(id)
            ?? throw new KeyNotFoundException("Sesija nije pronađena.");

        if (session.TrainerId != trainerId)
            throw new UnauthorizedAccessException("Nemate pravo brisati ovu sesiju.");

        session.IsActive = false;
        await _context.SaveChangesAsync();
    }

    public async Task<SessionReservationDto> ReserveAsync(int userId, int sessionId)
    {
        var session = await _context.TrainingSessions
            .Include(s => s.Reservations)
            .FirstOrDefaultAsync(s => s.Id == sessionId && s.IsActive)
            ?? throw new KeyNotFoundException("Sesija nije pronađena.");

        if (session.Type == SessionType.Group)
        {
            var hasGroupAccess = await HasActiveGroupProgramAccessAsync(userId, session);
            if (!hasGroupAccess)
            {
                throw new InvalidOperationException("Za rezervaciju grupnog treninga potrebna je aktivna grupna članarina za ovaj program.");
            }
        }

        var activeCount = session.Reservations.Count(r => r.Status == ReservationStatus.Confirmed);
        if (activeCount >= session.MaxParticipants)
            throw new InvalidOperationException("Sesija je popunjena.");

        if (session.Reservations.Any(r => r.UserId == userId && r.Status == ReservationStatus.Confirmed))
            throw new InvalidOperationException("Već ste rezervisali ovu sesiju.");

        var reservation = new SessionReservation { UserId = userId, TrainingSessionId = sessionId };
        _context.SessionReservations.Add(reservation);
        await _context.SaveChangesAsync();
        return await LoadReservationDto(reservation.Id);
    }

    public async Task CancelReservationAsync(int userId, int reservationId)
    {
        var reservation = await _context.SessionReservations
            .FirstOrDefaultAsync(r =>
                r.TrainingSessionId == reservationId &&
                r.UserId == userId &&
                r.Status == ReservationStatus.Confirmed)
            ?? throw new KeyNotFoundException("Rezervacija nije pronađena.");

        reservation.Status = ReservationStatus.Cancelled;
        await _context.SaveChangesAsync();
    }

    public async Task<IEnumerable<SessionReservationDto>> GetUserReservationsAsync(int userId)
    {
        var list = await _context.SessionReservations
            .Include(r => r.User).Include(r => r.TrainingSession)
            .Where(r => r.UserId == userId)
            .OrderByDescending(r => r.ReservedAt)
            .ToListAsync();
        return list.Select(ToReservationDto);
    }

    public async Task<IEnumerable<TrainingSessionDto>> GetUserPaidGroupScheduleAsync(int userId)
    {
        var now = DateTime.UtcNow;

        var paidGroupPrograms = await _context.Payments
            .AsNoTracking()
            .Include(p => p.SessionReservation)
            .ThenInclude(r => r!.TrainingSession)
            .Where(p =>
                p.UserId == userId &&
                p.Type == PaymentType.Session &&
                p.Status == PaymentStatus.Succeeded &&
                p.SessionAccessUntil.HasValue &&
                p.SessionAccessUntil.Value > now &&
                p.SessionReservation != null &&
                p.SessionReservation.TrainingSession.Type == SessionType.Group)
            .Select(p => new
            {
                p.SessionReservation!.TrainingSession.GymId,
                p.SessionReservation.TrainingSession.TrainerId,
                p.SessionReservation.TrainingSession.TrainingTypeId,
                p.SessionReservation.TrainingSession.Title,
                p.SessionReservation.TrainingSession.StartTime,
                p.SessionReservation.TrainingSession.EndTime,
            })
            .Distinct()
            .ToListAsync();

        if (paidGroupPrograms.Count == 0)
        {
            return Enumerable.Empty<TrainingSessionDto>();
        }

        var programKeys = paidGroupPrograms
            .Select(pg => BuildProgramKey(
                pg.GymId,
                pg.TrainerId,
                pg.TrainingTypeId,
                pg.Title,
                pg.StartTime,
                pg.EndTime))
            .ToHashSet();

        var candidateSessions = await _context.TrainingSessions
            .Include(s => s.Trainer)
            .Include(s => s.Gym)
            .Include(s => s.TrainingType)
            .Include(s => s.Reservations)
            .Where(s =>
                s.IsActive &&
                s.Type == SessionType.Group &&
                s.Date >= now.Date)
            .ToListAsync();

        var sessions = candidateSessions
            .Where(s => programKeys.Contains(BuildProgramKey(
                s.GymId,
                s.TrainerId,
                s.TrainingTypeId,
                s.Title,
                s.StartTime,
                s.EndTime)))
            .OrderBy(s => s.Date)
            .ThenBy(s => s.StartTime)
            .Take(30)
            .ToList();

        return sessions.Select(ToDto);
    }

    private static string BuildProgramKey(
        int gymId,
        int trainerId,
        int trainingTypeId,
        string title,
        TimeOnly startTime,
        TimeOnly endTime)
        => $"{gymId}|{trainerId}|{trainingTypeId}|{title}|{startTime}|{endTime}";

    private async Task<bool> HasActiveGroupProgramAccessAsync(int userId, TrainingSession session)
    {
        var now = DateTime.UtcNow;
        var key = BuildProgramKey(
            session.GymId,
            session.TrainerId,
            session.TrainingTypeId,
            session.Title,
            session.StartTime,
            session.EndTime);

        var paidPrograms = await _context.Payments
            .AsNoTracking()
            .Include(p => p.SessionReservation)
            .ThenInclude(r => r!.TrainingSession)
            .Where(p =>
                p.UserId == userId &&
                p.Type == PaymentType.Session &&
                p.Status == PaymentStatus.Succeeded &&
                p.SessionAccessUntil.HasValue &&
                p.SessionAccessUntil.Value > now &&
                p.SessionReservation != null &&
                p.SessionReservation.TrainingSession.Type == SessionType.Group)
            .Select(p => BuildProgramKey(
                p.SessionReservation!.TrainingSession.GymId,
                p.SessionReservation.TrainingSession.TrainerId,
                p.SessionReservation.TrainingSession.TrainingTypeId,
                p.SessionReservation.TrainingSession.Title,
                p.SessionReservation.TrainingSession.StartTime,
                p.SessionReservation.TrainingSession.EndTime))
            .ToListAsync();

        return paidPrograms.Contains(key);
    }

    private async Task<SessionReservationDto> LoadReservationDto(int id)
    {
        var r = await _context.SessionReservations
            .Include(r => r.User).Include(r => r.TrainingSession)
            .FirstAsync(r => r.Id == id);
        return ToReservationDto(r);
    }

    private static TrainingSessionDto ToDto(TrainingSession s) => new(
        s.Id, s.Title, s.Description, s.Type, s.Date, s.StartTime, s.EndTime,
        s.MaxParticipants,
        s.Reservations.Count(r => r.Status == ReservationStatus.Confirmed),
        s.Price, s.IsActive,
        s.TrainerId, $"{s.Trainer.FirstName} {s.Trainer.LastName}",
        s.GymId, s.Gym.Name, s.TrainingTypeId, s.TrainingType.Name);

    private static SessionReservationDto ToReservationDto(SessionReservation r) => new(
        r.Id, r.UserId, $"{r.User.FirstName} {r.User.LastName}",
        r.TrainingSessionId, r.TrainingSession.Title, r.TrainingSession.Date,
        r.Status, r.ReservedAt);
}
