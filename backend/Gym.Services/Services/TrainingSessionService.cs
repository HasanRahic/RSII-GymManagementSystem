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
            .AsNoTracking()
            .Where(s => s.IsActive)
            .AsQueryable();

        if (gymId.HasValue)     query = query.Where(s => s.GymId == gymId.Value);
        if (trainerId.HasValue) query = query.Where(s => s.TrainerId == trainerId.Value);
        if (typeId.HasValue)    query = query.Where(s => s.TrainingTypeId == typeId.Value);

        return await query
            .OrderBy(s => s.Date)
            .ThenBy(s => s.StartTime)
            .Select(s => new TrainingSessionDto(
                s.Id, s.Title, s.Description, s.Type, s.Date, s.StartTime, s.EndTime,
                s.MaxParticipants,
                s.Reservations.Count(r => r.Status == ReservationStatus.Confirmed),
                s.Price, s.IsActive,
                s.TrainerId, $"{s.Trainer.FirstName} {s.Trainer.LastName}",
                s.GymId, s.Gym.Name, s.TrainingTypeId, s.TrainingType.Name))
            .ToListAsync();
    }

    public async Task<TrainingSessionDto?> GetByIdAsync(int id)
    {
        return await _context.TrainingSessions
            .AsNoTracking()
            .Where(s => s.Id == id)
            .Select(s => new TrainingSessionDto(
                s.Id, s.Title, s.Description, s.Type, s.Date, s.StartTime, s.EndTime,
                s.MaxParticipants,
                s.Reservations.Count(r => r.Status == ReservationStatus.Confirmed),
                s.Price, s.IsActive,
                s.TrainerId, $"{s.Trainer.FirstName} {s.Trainer.LastName}",
                s.GymId, s.Gym.Name, s.TrainingTypeId, s.TrainingType.Name))
            .FirstOrDefaultAsync();
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
            .AsNoTracking()
            .Where(r => r.UserId == userId)
            .OrderByDescending(r => r.ReservedAt)
            .Select(r => new SessionReservationDto(
                r.Id, r.UserId, $"{r.User.FirstName} {r.User.LastName}",
                r.TrainingSessionId, r.TrainingSession.Title, r.TrainingSession.Date,
                r.Status, r.ReservedAt))
            .ToListAsync();
        return list;
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
            .AsNoTracking()
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

    public async Task<IEnumerable<RecommendedGymDto>> GetRecommendedGymsAsync(
        int userId,
        string? city,
        int? trainingTypeId)
    {
        var normalizedCity = city?.Trim().ToLowerInvariant();

        var user = await _context.Users
            .AsNoTracking()
            .Include(u => u.City)
            .Include(u => u.Memberships)
            .FirstOrDefaultAsync(u => u.Id == userId)
            ?? throw new KeyNotFoundException("Korisnik nije pronađen.");

        var checkIns = await _context.CheckIns
            .AsNoTracking()
            .Include(c => c.Gym)
            .Where(c => c.UserId == userId)
            .ToListAsync();

        var reservedSessions = await _context.SessionReservations
            .AsNoTracking()
            .Include(r => r.TrainingSession)
            .ThenInclude(s => s.TrainingType)
            .Where(r => r.UserId == userId && r.Status == ReservationStatus.Confirmed)
            .Select(r => r.TrainingSession)
            .ToListAsync();

        var paidGroupSessions = await _context.Payments
            .AsNoTracking()
            .Include(p => p.SessionReservation)
            .ThenInclude(r => r!.TrainingSession)
            .ThenInclude(s => s.TrainingType)
            .Where(p =>
                p.UserId == userId &&
                p.Status == PaymentStatus.Succeeded &&
                p.SessionReservation != null &&
                p.SessionReservation.TrainingSession.IsActive)
            .Select(p => p.SessionReservation!.TrainingSession)
            .ToListAsync();

        var preferredTypes = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
        foreach (var session in reservedSessions.Concat(paidGroupSessions))
        {
            var key = session.TrainingType.Name.Trim();
            if (string.IsNullOrWhiteSpace(key)) continue;
            preferredTypes[key] = (preferredTypes.TryGetValue(key, out var count) ? count : 0) + 3;
        }

        var visitedGyms = checkIns
            .GroupBy(c => c.Gym.Name.Trim(), StringComparer.OrdinalIgnoreCase)
            .ToDictionary(g => g.Key, g => g.Count(), StringComparer.OrdinalIgnoreCase);

        var gyms = await _context.Gyms
            .AsNoTracking()
            .Include(g => g.City)
            .Include(g => g.TrainingSessions.Where(s => s.IsActive))
            .ThenInclude(s => s.TrainingType)
            .Where(g => string.IsNullOrWhiteSpace(normalizedCity) || g.City.Name.ToLower() == normalizedCity)
            .ToListAsync();

        var results = gyms
            .Select(gym =>
            {
                double score = 0;
                var matchedTypes = new List<string>();

                if (gym.Status == GymStatus.Open) score += 2;
                if (!string.IsNullOrWhiteSpace(user.City?.Name) &&
                    string.Equals(user.City!.Name, gym.City.Name, StringComparison.OrdinalIgnoreCase))
                {
                    score += 1.5;
                }

                if (user.PrimaryGymId == gym.Id)
                {
                    score += 4;
                }

                if (visitedGyms.TryGetValue(gym.Name.Trim(), out var visitCount))
                {
                    score += visitCount * 2;
                }

                foreach (var session in gym.TrainingSessions)
                {
                    if (trainingTypeId.HasValue && session.TrainingTypeId == trainingTypeId.Value)
                    {
                        score += 3;
                    }

                    var typeName = session.TrainingType.Name.Trim();
                    if (preferredTypes.TryGetValue(typeName, out var weight))
                    {
                        score += weight * 1.25;
                        matchedTypes.Add(typeName);
                    }
                }

                var occupancyRatio = gym.Capacity == 0 ? 0 : (double)gym.CurrentOccupancy / gym.Capacity;
                if (occupancyRatio >= 0.35 && occupancyRatio <= 0.85) score += 1.2;
                else if (occupancyRatio < 0.2) score += 0.5;

                score += gym.TrainingSessions.Count * 0.15;

                var reason = trainingTypeId.HasValue
                    ? "Podudaranje s odabranim tipom treninga"
                    : matchedTypes.Count > 0
                        ? $"Na osnovu vaše aktivnosti: {string.Join(", ", matchedTypes.Distinct().Take(2))}"
                        : user.PrimaryGymId == gym.Id
                            ? "Preporuka na osnovu vaše aktivne teretane"
                            : "Dobra dostupnost termina i posjećenosti";

                return new RecommendedGymDto(
                    gym.Id,
                    gym.Name,
                    Math.Round(score, 2),
                    reason,
                    matchedTypes
                        .Distinct(StringComparer.OrdinalIgnoreCase)
                        .Take(4)
                        .ToList());
            })
            .OrderByDescending(x => x.Score)
            .ThenBy(x => x.GymName)
            .Take(8)
            .ToList();

        return results;
    }

    public async Task<IEnumerable<TrainerProfileDto>> GetTrainerProfilesAsync(
        string? city,
        int? trainingTypeId,
        string? search)
    {
        var normalizedCity = city?.Trim().ToLowerInvariant();
        var normalizedSearch = search?.Trim().ToLowerInvariant();
        var now = DateTime.UtcNow;

        var sessions = await _context.TrainingSessions
            .AsNoTracking()
            .Include(s => s.Trainer)
            .ThenInclude(t => t.City)
            .Include(s => s.Gym)
            .ThenInclude(g => g.City)
            .Include(s => s.TrainingType)
            .Include(s => s.Reservations)
            .Where(s => s.IsActive && (!trainingTypeId.HasValue || s.TrainingTypeId == trainingTypeId.Value))
            .ToListAsync();

        var trainerIds = sessions.Select(s => s.TrainerId).Distinct().ToList();
        var trainerApplications = await _context.TrainerApplications
            .AsNoTracking()
            .Where(a => trainerIds.Contains(a.UserId))
            .GroupBy(a => a.UserId)
            .Select(g => g.OrderByDescending(a => a.SubmittedAt).First())
            .ToListAsync();

        var applicationByTrainerId = trainerApplications.ToDictionary(a => a.UserId);

        var profiles = sessions
            .GroupBy(s => s.TrainerId)
            .Select(group =>
            {
                var first = group.First();
                var trainer = first.Trainer;
                if (!string.IsNullOrWhiteSpace(normalizedCity) &&
                    !group.Any(s => string.Equals(s.Gym.City.Name, normalizedCity, StringComparison.OrdinalIgnoreCase)))
                {
                    return null;
                }

                var trainingTypes = group
                    .Select(s => s.TrainingType.Name.Trim())
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .OrderBy(x => x)
                    .ToList();
                var gymNames = group
                    .Select(s => s.Gym.Name.Trim())
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .OrderBy(x => x)
                    .ToList();
                var cityNames = group
                    .Select(s => s.Gym.City.Name.Trim())
                    .Where(x => !string.IsNullOrWhiteSpace(x))
                    .Distinct(StringComparer.OrdinalIgnoreCase)
                    .OrderBy(x => x)
                    .ToList();

                var nextAvailableAt = group
                    .Select(s => s.Date.Date + s.StartTime.ToTimeSpan())
                    .Where(x => x >= now)
                    .OrderBy(x => x)
                    .Cast<DateTime?>()
                    .FirstOrDefault();

                var avgOccupancy = group.Any()
                    ? group.Average(s => s.MaxParticipants == 0
                        ? 0
                        : (double)s.Reservations.Count(r => r.Status == ReservationStatus.Confirmed) / s.MaxParticipants)
                    : 0;
                var rating = Math.Round(Math.Clamp(4.0 + (avgOccupancy * 0.9) + (group.Count() >= 5 ? 0.1 : 0), 4.0, 5.0), 1);

                applicationByTrainerId.TryGetValue(group.Key, out var application);

                var fullName = $"{trainer.FirstName} {trainer.LastName}".Trim();
                var haystack = string.Join(" ", new[]
                {
                    fullName,
                    application?.Biography,
                    application?.Experience,
                    string.Join(" ", trainingTypes),
                    string.Join(" ", gymNames),
                    string.Join(" ", cityNames),
                }).ToLowerInvariant();

                if (!string.IsNullOrWhiteSpace(normalizedSearch) && !haystack.Contains(normalizedSearch))
                {
                    return null;
                }

                return new TrainerProfileDto(
                    trainer.Id,
                    fullName,
                    application?.Biography,
                    application?.Experience,
                    application?.Certifications,
                    application?.Availability,
                    trainer.PhoneNumber,
                    trainer.Email,
                    trainer.City?.Name,
                    rating,
                    group.Count(),
                    group.Count(s => s.Type == SessionType.Group),
                    gymNames.Count,
                    cityNames.Count,
                    nextAvailableAt,
                    trainingTypes,
                    gymNames,
                    cityNames);
            })
            .Where(x => x is not null)
            .Cast<TrainerProfileDto>()
            .OrderByDescending(x => x.Rating)
            .ThenBy(x => x.FullName)
            .ToList();

        return profiles;
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
