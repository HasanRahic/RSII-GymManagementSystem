using Gym.Core.Entities;
using Microsoft.EntityFrameworkCore;

namespace Gym.Infrastructure.Data;

public class GymDbContext : DbContext
{
    public GymDbContext(DbContextOptions<GymDbContext> options) : base(options) { }

    public DbSet<Country> Countries => Set<Country>();
    public DbSet<City> Cities => Set<City>();
    public DbSet<TrainingType> TrainingTypes => Set<TrainingType>();
    public DbSet<User> Users => Set<User>();
    public DbSet<GymFacility> Gyms => Set<GymFacility>();
    public DbSet<MembershipPlan> MembershipPlans => Set<MembershipPlan>();
    public DbSet<UserMembership> UserMemberships => Set<UserMembership>();
    public DbSet<CheckIn> CheckIns => Set<CheckIn>();
    public DbSet<TrainerApplication> TrainerApplications => Set<TrainerApplication>();
    public DbSet<TrainingSession> TrainingSessions => Set<TrainingSession>();
    public DbSet<SessionReservation> SessionReservations => Set<SessionReservation>();
    public DbSet<ProgressMeasurement> ProgressMeasurements => Set<ProgressMeasurement>();
    public DbSet<Badge> Badges => Set<Badge>();
    public DbSet<UserBadge> UserBadges => Set<UserBadge>();
    public DbSet<Payment> Payments => Set<Payment>();

    protected override void OnModelCreating(ModelBuilder modelBuilder)
    {
        base.OnModelCreating(modelBuilder);

        // User
        modelBuilder.Entity<User>(e =>
        {
            e.HasIndex(u => u.Email).IsUnique();
            e.HasIndex(u => u.Username).IsUnique();
            e.Property(u => u.Role).HasConversion<string>();

            e.HasOne(u => u.PrimaryGym)
             .WithMany(g => g.PrimaryMembers)
             .HasForeignKey(u => u.PrimaryGymId)
             .OnDelete(DeleteBehavior.ClientSetNull);

            e.HasOne(u => u.City)
             .WithMany(c => c.Users)
             .HasForeignKey(u => u.CityId)
             .OnDelete(DeleteBehavior.ClientSetNull);
        });

        // GymFacility
        modelBuilder.Entity<GymFacility>(e =>
        {
            e.Property(g => g.Status).HasConversion<string>();
            e.Property(g => g.Capacity).HasDefaultValue(50);
        });

        // MembershipPlan
        modelBuilder.Entity<MembershipPlan>(e =>
        {
            e.Property(m => m.Price).HasPrecision(10, 2);
        });

        // UserMembership
        modelBuilder.Entity<UserMembership>(e =>
        {
            e.Property(m => m.Status).HasConversion<string>();
            e.Property(m => m.Price).HasPrecision(10, 2);
            e.Property(m => m.DiscountPercent).HasPrecision(5, 2);

            e.HasOne(m => m.Payment)
             .WithOne(p => p.UserMembership)
             .HasForeignKey<UserMembership>(m => m.PaymentId)
             .OnDelete(DeleteBehavior.ClientSetNull);

            e.HasOne(m => m.Gym)
             .WithMany(g => g.UserMemberships)
             .HasForeignKey(m => m.GymId)
             .OnDelete(DeleteBehavior.Restrict);
        });

        // CheckIn
        modelBuilder.Entity<CheckIn>(e =>
        {
            e.HasOne(c => c.Gym)
             .WithMany(g => g.CheckIns)
             .HasForeignKey(c => c.GymId)
             .OnDelete(DeleteBehavior.Restrict);

            e.HasOne(c => c.User)
             .WithMany(u => u.CheckIns)
             .HasForeignKey(c => c.UserId)
             .OnDelete(DeleteBehavior.Restrict);

            e.Ignore(c => c.DurationMinutes);
        });

        // TrainerApplication
        modelBuilder.Entity<TrainerApplication>(e =>
        {
            e.Property(a => a.Status).HasConversion<string>();

            e.HasOne(a => a.ReviewedByAdmin)
             .WithMany()
             .HasForeignKey(a => a.ReviewedByAdminId)
             .OnDelete(DeleteBehavior.ClientSetNull);

            e.HasOne(a => a.User)
             .WithMany(u => u.TrainerApplications)
             .HasForeignKey(a => a.UserId)
             .OnDelete(DeleteBehavior.Restrict);
        });

        // TrainingSession
        modelBuilder.Entity<TrainingSession>(e =>
        {
            e.Property(s => s.Type).HasConversion<string>();
            e.Property(s => s.Price).HasPrecision(10, 2);

            e.HasOne(s => s.Trainer)
             .WithMany(u => u.TrainingSessions)
             .HasForeignKey(s => s.TrainerId)
             .OnDelete(DeleteBehavior.Restrict);

            e.HasOne(s => s.Gym)
             .WithMany(g => g.TrainingSessions)
             .HasForeignKey(s => s.GymId)
             .OnDelete(DeleteBehavior.Restrict);
        });

        // SessionReservation
        modelBuilder.Entity<SessionReservation>(e =>
        {
            e.Property(r => r.Status).HasConversion<string>();

            e.HasOne(r => r.Payment)
             .WithOne(p => p.SessionReservation)
             .HasForeignKey<SessionReservation>(r => r.PaymentId)
             .OnDelete(DeleteBehavior.ClientSetNull);
        });

        // Payment
        modelBuilder.Entity<Payment>(e =>
        {
            e.Property(p => p.Amount).HasPrecision(10, 2);
            e.Property(p => p.Type).HasConversion<string>();
            e.Property(p => p.Status).HasConversion<string>();
        });

        // Badge
        modelBuilder.Entity<Badge>(e =>
        {
            e.Property(b => b.Type).HasConversion<string>();
        });

        // UserBadge – unique constraint (jedan korisnik ne može dva puta dobiti isti badge)
        modelBuilder.Entity<UserBadge>(e =>
        {
            e.HasIndex(ub => new { ub.UserId, ub.BadgeId }).IsUnique();
        });
    }
}
