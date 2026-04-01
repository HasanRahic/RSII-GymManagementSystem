using System.Text;
using Gym.Api.Messaging;
using Gym.Infrastructure.Data;
using Gym.Infrastructure.Repositories;
using Gym.Infrastructure.Seed;
using Gym.Core.Interfaces;
using Gym.Services.Interfaces;
using Gym.Services.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddOpenApi();

// EF Core – SQL Server
builder.Services.AddDbContext<GymDbContext>(options =>
    options.UseSqlServer(builder.Configuration.GetConnectionString("DefaultConnection")));

// Generic repository
builder.Services.AddScoped(typeof(IRepository<>), typeof(Repository<>));

// Application services
builder.Services.AddScoped<IAuthService, AuthService>();
builder.Services.AddScoped<IUserService, UserService>();
builder.Services.AddScoped<IGymService, GymService>();
builder.Services.AddScoped<IMembershipService, MembershipService>();
builder.Services.AddScoped<ICheckInService, CheckInService>();
builder.Services.AddScoped<ITrainerApplicationService, TrainerApplicationService>();
builder.Services.AddScoped<ITrainingSessionService, TrainingSessionService>();
builder.Services.AddScoped<IProgressService, ProgressService>();
builder.Services.AddScoped<IReportService, ReportService>();

// JWT Authentication
var jwtKey = builder.Configuration["JWT:Key"]
    ?? throw new InvalidOperationException("JWT:Key is not configured.");

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme    = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuer           = true,
        ValidateAudience         = true,
        ValidateLifetime         = true,
        ValidateIssuerSigningKey = true,
        ValidIssuer              = builder.Configuration["JWT:Issuer"],
        ValidAudience            = builder.Configuration["JWT:Audience"],
        IssuerSigningKey         = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtKey))
    };
});

builder.Services.AddAuthorization();

// Swagger with JWT support
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Notification publisher (RabbitMQ)
builder.Services.AddSingleton<INotificationPublisher, RabbitMqNotificationPublisher>();

// CORS – allow Flutter apps
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
});

var app = builder.Build();

// Seed database on startup
using (var scope = app.Services.CreateScope())
{
    var db = scope.ServiceProvider.GetRequiredService<GymDbContext>();
    await DbSeeder.SeedAsync(db);
}

// Global exception handler – mora biti prvi u pipeline-u
app.UseExceptionHandler(errApp => errApp.Run(async ctx =>
{
    var ex = ctx.Features.Get<Microsoft.AspNetCore.Diagnostics.IExceptionHandlerFeature>()?.Error;
    if (ex is null) return;

    var (status, message) = ex switch
    {
        KeyNotFoundException       => (StatusCodes.Status404NotFound,            ex.Message),
        InvalidOperationException  => (StatusCodes.Status400BadRequest,           ex.Message),
        UnauthorizedAccessException => (StatusCodes.Status401Unauthorized,        ex.Message),
        ArgumentException          => (StatusCodes.Status400BadRequest,           ex.Message),
        _                          => (StatusCodes.Status500InternalServerError,  "Došlo je do greške na serveru.")
    };

    ctx.Response.StatusCode  = status;
    ctx.Response.ContentType = "application/json";
    await ctx.Response.WriteAsJsonAsync(new { message });
}));

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();
