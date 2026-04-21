using Gym.Core.Entities;
using Gym.Core.Enums;
using Gym.Infrastructure.Data;
using Microsoft.EntityFrameworkCore;
using System.Security.Cryptography;
using System.Text;

namespace Gym.Infrastructure.Seed;

public static class DbSeeder
{
    public static async Task SeedAsync(GymDbContext context)
    {
        await context.Database.MigrateAsync();

        if (await context.Countries.AnyAsync())
        {
            await EnsureGymCatalogAsync(context);
            await EnsureMembershipPlanCatalogAsync(context);
            return;
        }

        // ── Countries & Cities ──────────────────────────────────────────────
        var bih = new Country { Name = "Bosna i Hercegovina", Code = "BA" };
        var hrv = new Country { Name = "Hrvatska", Code = "HR" };
        context.Countries.AddRange(bih, hrv);
        await context.SaveChangesAsync();

        var sarajevo = new City { Name = "Sarajevo", PostalCode = "71000", CountryId = bih.Id };
        var mostar   = new City { Name = "Mostar",   PostalCode = "88000", CountryId = bih.Id };
        var banja    = new City { Name = "Banja Luka", PostalCode = "78000", CountryId = bih.Id };
        var zagreb   = new City { Name = "Zagreb",   PostalCode = "10000", CountryId = hrv.Id };
        context.Cities.AddRange(sarajevo, mostar, banja, zagreb);
        await context.SaveChangesAsync();

        // ── Training Types ──────────────────────────────────────────────────
        var trainingTypes = new List<TrainingType>
        {
            new() { Name = "Kardio",   Description = "Kardiovaskularni trening" },
            new() { Name = "Utezi",    Description = "Trening snage sa utezima" },
            new() { Name = "Yoga",     Description = "Yoga i meditacija" },
            new() { Name = "Pilates",  Description = "Pilates vježbe" },
            new() { Name = "CrossFit", Description = "Funkcionalni trening visokog intenziteta" },
            new() { Name = "HIIT",     Description = "Intervalni trening visokog intenziteta" },
            new() { Name = "Box",      Description = "Boks i MMA trening" },
        };
        context.TrainingTypes.AddRange(trainingTypes);
        await context.SaveChangesAsync();

        // ── Users ───────────────────────────────────────────────────────────
        var admin   = CreateUser("Admin",   "Adminović",  "admin",   "admin@gym.ba",   "test", UserRole.Admin,    sarajevo.Id);
        var member  = CreateUser("Member",  "Memberović", "member",  "member@gym.ba",  "test", UserRole.Member,   sarajevo.Id);
        var trainer = CreateUser("Trainer", "Trenerović", "trainer", "trainer@gym.ba", "test", UserRole.Trainer,  mostar.Id);
        var member2 = CreateUser("Amel",    "Hodžić",     "amel",    "amel@gym.ba",    "test", UserRole.Member,   mostar.Id);
        var member3 = CreateUser("Lejla",   "Karić",      "lejla",   "lejla@gym.ba",   "test", UserRole.Member,   banja.Id);
        context.Users.AddRange(admin, member, trainer, member2, member3);
        await context.SaveChangesAsync();

        // ── Gyms ────────────────────────────────────────────────────────────
        var gym1 = new GymFacility
        {
            Name = "FitZone Sarajevo", Address = "Ferhadija 12", CityId = sarajevo.Id,
            OpenTime = new TimeOnly(6, 0), CloseTime = new TimeOnly(22, 0),
            Capacity = 80, Status = GymStatus.Open,
            PhoneNumber = "033-111-222", Email = "fitzone@gym.ba",
            Latitude = 43.8563, Longitude = 18.4131
        };
        var gym2 = new GymFacility
        {
            Name = "PowerHouse Mostar", Address = "Bulevar 5", CityId = mostar.Id,
            OpenTime = new TimeOnly(7, 0), CloseTime = new TimeOnly(21, 0),
            Capacity = 60, Status = GymStatus.Open,
            PhoneNumber = "036-222-333", Email = "powerhouse@gym.ba",
            Latitude = 43.3438, Longitude = 17.8078
        };
        var gym3 = new GymFacility
        {
            Name = "IronGym Banja Luka", Address = "Kralja Petra 3", CityId = banja.Id,
            OpenTime = new TimeOnly(6, 30), CloseTime = new TimeOnly(22, 30),
            Capacity = 100, Status = GymStatus.Open,
            PhoneNumber = "051-333-444", Email = "irongym@gym.ba",
            Latitude = 44.7722, Longitude = 17.1910
        };
        var gym4 = new GymFacility
        {
            Name = "Arena Mostar", Address = "Kneza Domagoja 9", CityId = mostar.Id,
            OpenTime = new TimeOnly(6, 0), CloseTime = new TimeOnly(23, 0),
            Capacity = 70, Status = GymStatus.Open,
            PhoneNumber = "036-555-777", Email = "arena@gym.ba",
            Latitude = 43.3400, Longitude = 17.8120
        };
        var gym5 = new GymFacility
        {
            Name = "Titan Zagreb", Address = "Savska cesta 40", CityId = zagreb.Id,
            OpenTime = new TimeOnly(5, 30), CloseTime = new TimeOnly(23, 30),
            Capacity = 120, Status = GymStatus.Open,
            PhoneNumber = "+385-1-777-888", Email = "titan@gym.hr",
            Latitude = 45.8040, Longitude = 15.9670
        };
        context.Gyms.AddRange(gym1, gym2, gym3, gym4, gym5);
        await context.SaveChangesAsync();

        // Postavi primarnu teretanu
        member.PrimaryGymId  = gym1.Id;
        trainer.PrimaryGymId = gym2.Id;
        member2.PrimaryGymId = gym2.Id;
        member3.PrimaryGymId = gym3.Id;
        await context.SaveChangesAsync();

        // ── Membership Plans ────────────────────────────────────────────────
        var plans = new List<MembershipPlan>
        {
            new() { Name = "Mjesečna",    DurationDays = 30,  Price = 40m,  GymId = gym1.Id },
            new() { Name = "Tromjesečna", DurationDays = 90,  Price = 110m, GymId = gym1.Id },
            new() { Name = "Polugodišnja", DurationDays = 180, Price = 210m, GymId = gym1.Id },
            new() { Name = "Godišnja",    DurationDays = 365, Price = 380m, GymId = gym1.Id },
            new() { Name = "Mjesečna",    DurationDays = 30,  Price = 35m,  GymId = gym2.Id },
            new() { Name = "Tromjesečna", DurationDays = 90,  Price = 95m,  GymId = gym2.Id },
            new() { Name = "Polugodišnja", DurationDays = 180, Price = 190m, GymId = gym2.Id },
            new() { Name = "Godišnja",    DurationDays = 365, Price = 340m, GymId = gym2.Id },
            new() { Name = "Mjesečna",    DurationDays = 30,  Price = 38m,  GymId = gym3.Id },
            new() { Name = "Polugodišnja", DurationDays = 180, Price = 200m, GymId = gym3.Id },
            new() { Name = "Godišnja",    DurationDays = 365, Price = 360m, GymId = gym3.Id },
            new() { Name = "Mjesečna",    DurationDays = 30,  Price = 37m,  GymId = gym4.Id },
            new() { Name = "Tromjesečna", DurationDays = 90,  Price = 102m, GymId = gym4.Id },
            new() { Name = "Polugodišnja", DurationDays = 180, Price = 195m, GymId = gym4.Id },
            new() { Name = "Godišnja",    DurationDays = 365, Price = 350m, GymId = gym4.Id },
            new() { Name = "Mjesečna",    DurationDays = 30,  Price = 45m,  GymId = gym5.Id },
            new() { Name = "Tromjesečna", DurationDays = 90,  Price = 125m, GymId = gym5.Id },
            new() { Name = "Polugodišnja", DurationDays = 180, Price = 235m, GymId = gym5.Id },
            new() { Name = "Godišnja",    DurationDays = 365, Price = 420m, GymId = gym5.Id },
        };
        context.MembershipPlans.AddRange(plans);
        await context.SaveChangesAsync();

        // ── Active Memberships ──────────────────────────────────────────────
        var now = DateTime.UtcNow;
        context.UserMemberships.AddRange(
            new UserMembership
            {
                UserId = member.Id, MembershipPlanId = plans[0].Id, GymId = gym1.Id,
                StartDate = now.AddDays(-10), EndDate = now.AddDays(20),
                Price = 40m, Status = MembershipStatus.Active
            },
            new UserMembership
            {
                UserId = trainer.Id, MembershipPlanId = plans[3].Id, GymId = gym2.Id,
                StartDate = now.AddDays(-5), EndDate = now.AddDays(25),
                Price = 35m, Status = MembershipStatus.Active
            },
            new UserMembership
            {
                UserId = member2.Id, MembershipPlanId = plans[4].Id, GymId = gym2.Id,
                StartDate = now.AddDays(-60), EndDate = now.AddDays(30),
                Price = 95m, Status = MembershipStatus.Active
            }
        );
        await context.SaveChangesAsync();

        // ── Check-ins ───────────────────────────────────────────────────────
        var checkIns = new List<CheckIn>();
        for (int i = 14; i >= 0; i--)
        {
            if (i % 2 == 0)
            {
                var ci = new CheckIn
                {
                    UserId = member.Id, GymId = gym1.Id,
                    CheckInTime  = now.AddDays(-i).AddHours(8),
                    CheckOutTime = now.AddDays(-i).AddHours(9).AddMinutes(30)
                };
                checkIns.Add(ci);
            }
        }
        checkIns.Add(new CheckIn { UserId = member2.Id, GymId = gym2.Id, CheckInTime = now.AddDays(-3).AddHours(10), CheckOutTime = now.AddDays(-3).AddHours(11).AddMinutes(15) });
        checkIns.Add(new CheckIn { UserId = trainer.Id, GymId = gym2.Id, CheckInTime = now.AddDays(-1).AddHours(9), CheckOutTime = now.AddDays(-1).AddHours(11) });
        context.CheckIns.AddRange(checkIns);
        await context.SaveChangesAsync();

        // ── Trainer Application ──────────────────────────────────────────────
        context.TrainerApplications.Add(new TrainerApplication
        {
            UserId = trainer.Id,
            Biography = "Profesionalni fitness trener sa 5 godina iskustva.",
            Experience = "Personal trainer u više fitness centara.",
            Certifications = "ACE Personal Trainer, CrossFit Level 1",
            Availability = "Pon-Pet 08:00-18:00",
            Status = ApplicationStatus.Approved,
            ReviewedByAdminId = admin.Id,
            ReviewedAt = now.AddDays(-30),
            AdminNote = "Odličan kandidat, odobren."
        });

        // Pending application
        context.TrainerApplications.Add(new TrainerApplication
        {
            UserId = member.Id,
            Biography = "Vježbam 3 godine i želi postati trener.",
            Experience = "Domaći trening i grupne sesije.",
            Certifications = "NASM CPT",
            Availability = "Vikend 09:00-17:00",
            Status = ApplicationStatus.Pending
        });
        await context.SaveChangesAsync();

        // ── Training Sessions ────────────────────────────────────────────────
        var sessions = new List<TrainingSession>
        {
            new()
            {
                Title = "HIIT Jutarnji", Type = SessionType.Group,
                Date = now.AddDays(2), StartTime = new TimeOnly(8, 0), EndTime = new TimeOnly(9, 0),
                MaxParticipants = 10, Price = 15m, TrainerId = trainer.Id,
                GymId = gym2.Id, TrainingTypeId = trainingTypes[5].Id
            },
            new()
            {
                Title = "Privatni Kardio", Type = SessionType.Private,
                Date = now.AddDays(3), StartTime = new TimeOnly(10, 0), EndTime = new TimeOnly(11, 0),
                MaxParticipants = 1, Price = 40m, TrainerId = trainer.Id,
                GymId = gym2.Id, TrainingTypeId = trainingTypes[0].Id
            },
            new()
            {
                Title = "CrossFit Grupni", Type = SessionType.Group,
                Date = now.AddDays(4), StartTime = new TimeOnly(17, 0), EndTime = new TimeOnly(18, 0),
                MaxParticipants = 12, Price = 20m, TrainerId = trainer.Id,
                GymId = gym2.Id, TrainingTypeId = trainingTypes[4].Id
            }
        };
        context.TrainingSessions.AddRange(sessions);
        await context.SaveChangesAsync();

        // ── Progress Measurements ────────────────────────────────────────────
        var measurements = new List<ProgressMeasurement>
        {
            new() { UserId = member.Id, Date = now.AddDays(-30), WeightKg = 82.5, BodyFatPercent = 18, WaistCm = 88 },
            new() { UserId = member.Id, Date = now.AddDays(-15), WeightKg = 81.0, BodyFatPercent = 17, WaistCm = 86 },
            new() { UserId = member.Id, Date = now,              WeightKg = 79.5, BodyFatPercent = 16, WaistCm = 84 },
        };
        context.ProgressMeasurements.AddRange(measurements);
        await context.SaveChangesAsync();

        // ── Badges ───────────────────────────────────────────────────────────
        var badges = new List<Badge>
        {
            new() { Name = "Prvi dolazak",  Description = "Dobrodošao u teretanu!", Type = BadgeType.FirstVisit, RequiredCount = 1 },
            new() { Name = "5 dolazaka",    Description = "5 posjeta teretani.",     Type = BadgeType.Visits5,   RequiredCount = 5 },
            new() { Name = "10 dolazaka",   Description = "10 posjeta teretani.",    Type = BadgeType.Visits10,  RequiredCount = 10 },
            new() { Name = "25 dolazaka",   Description = "25 posjeta teretani.",    Type = BadgeType.Visits25,  RequiredCount = 25 },
            new() { Name = "Streak 7 dana", Description = "7 uzastopnih sedmica.",   Type = BadgeType.Streak7,   RequiredCount = 7 },
        };
        context.Badges.AddRange(badges);
        await context.SaveChangesAsync();

        context.UserBadges.AddRange(
            new UserBadge { UserId = member.Id, BadgeId = badges[0].Id, EarnedAt = now.AddDays(-14) },
            new UserBadge { UserId = member.Id, BadgeId = badges[1].Id, EarnedAt = now.AddDays(-10) }
        );
        await context.SaveChangesAsync();
    }

    private static async Task EnsureGymCatalogAsync(GymDbContext context)
    {
        var cities = await context.Cities.AsNoTracking().ToListAsync();

        var mostarId = cities.FirstOrDefault(c => c.Name == "Mostar")?.Id;
        var zagrebId = cities.FirstOrDefault(c => c.Name == "Zagreb")?.Id;

        var targetGyms = new List<GymFacility>();

        if (mostarId.HasValue)
        {
            targetGyms.Add(new GymFacility
            {
                Name = "Arena Mostar",
                Address = "Kneza Domagoja 9",
                CityId = mostarId.Value,
                OpenTime = new TimeOnly(6, 0),
                CloseTime = new TimeOnly(23, 0),
                Capacity = 70,
                Status = GymStatus.Open,
                PhoneNumber = "036-555-777",
                Email = "arena@gym.ba",
                Latitude = 43.3400,
                Longitude = 17.8120,
            });
        }

        if (zagrebId.HasValue)
        {
            targetGyms.Add(new GymFacility
            {
                Name = "Titan Zagreb",
                Address = "Savska cesta 40",
                CityId = zagrebId.Value,
                OpenTime = new TimeOnly(5, 30),
                CloseTime = new TimeOnly(23, 30),
                Capacity = 120,
                Status = GymStatus.Open,
                PhoneNumber = "+385-1-777-888",
                Email = "titan@gym.hr",
                Latitude = 45.8040,
                Longitude = 15.9670,
            });
        }

        foreach (var gym in targetGyms)
        {
            var exists = await context.Gyms.AnyAsync(g => g.Name == gym.Name);
            if (!exists)
            {
                context.Gyms.Add(gym);
            }
        }

        await context.SaveChangesAsync();
    }

    private static async Task EnsureMembershipPlanCatalogAsync(GymDbContext context)
    {
        var gyms = await context.Gyms
            .AsNoTracking()
            .Select(g => new { g.Id, g.Name })
            .ToListAsync();

        if (gyms.Count == 0)
        {
            return;
        }

        var targetPlans = new List<(string GymName, string Name, int DurationDays, decimal Price)>
        {
            ("FitZone Sarajevo", "Polugodišnja", 180, 210m),
            ("PowerHouse Mostar", "Polugodišnja", 180, 190m),
            ("IronGym Banja Luka", "Polugodišnja", 180, 200m),
            ("Arena Mostar", "Polugodišnja", 180, 195m),
            ("Titan Zagreb", "Polugodišnja", 180, 235m),
        };

        foreach (var target in targetPlans)
        {
            var gymId = gyms.FirstOrDefault(g => g.Name == target.GymName)?.Id;
            if (!gymId.HasValue)
            {
                continue;
            }

            var exists = await context.MembershipPlans.AnyAsync(p =>
                p.GymId == gymId.Value &&
                p.DurationDays == target.DurationDays &&
                p.IsActive);

            if (!exists)
            {
                context.MembershipPlans.Add(new MembershipPlan
                {
                    Name = target.Name,
                    DurationDays = target.DurationDays,
                    Price = target.Price,
                    GymId = gymId.Value,
                    IsActive = true,
                });
            }
        }

        await context.SaveChangesAsync();
    }

    private static User CreateUser(string firstName, string lastName, string username,
        string email, string password, UserRole role, int cityId)
    {
        using var hmac = new HMACSHA512();
        return new User
        {
            FirstName    = firstName,
            LastName     = lastName,
            Username     = username,
            Email        = email,
            Role         = role,
            CityId       = cityId,
            IsActive     = true,
            PasswordSalt = hmac.Key,
            PasswordHash = hmac.ComputeHash(Encoding.UTF8.GetBytes(password))
        };
    }
}
