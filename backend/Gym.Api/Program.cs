using System.Text;
using Gym.Api.Messaging;
using Gym.Api.Services;
using Gym.Infrastructure.Data;
using Gym.Infrastructure.Repositories;
using Gym.Infrastructure.Seed;
using Gym.Core.Interfaces;
using Gym.Services.Interfaces;
using Gym.Services.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using Microsoft.IdentityModel.Tokens;
using Stripe;
using System.Threading.RateLimiting;

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

builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.OnRejected = async (context, token) =>
    {
        context.HttpContext.Response.ContentType = "application/json";
        await context.HttpContext.Response.WriteAsJsonAsync(new
        {
            message = "Previše zahtjeva. Pokušajte ponovo za nekoliko trenutaka."
        }, cancellationToken: token);
    };

    options.AddPolicy("auth", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 10,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            }));

    options.AddPolicy("payments", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            partitionKey: httpContext.User.Identity?.Name
                ?? httpContext.Connection.RemoteIpAddress?.ToString()
                ?? "unknown",
            factory: _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 20,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            }));
});

// Swagger with JWT support
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Notification publisher (RabbitMQ)
builder.Services.AddSingleton<INotificationPublisher, RabbitMqNotificationPublisher>();
builder.Services.AddScoped<IStripePaymentSyncService, StripePaymentSyncService>();

// CORS – allow Flutter apps
builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy =>
        policy.AllowAnyOrigin().AllowAnyMethod().AllowAnyHeader());
});

// Stripe configuration
var stripeSecretKey = builder.Configuration["Stripe:SecretKey"];
if (!string.IsNullOrWhiteSpace(stripeSecretKey))
{
    Stripe.StripeConfiguration.ApiKey = stripeSecretKey;
}

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

const string CheckoutPageStyles = """
<style>
body {
    margin: 0;
    font-family: Arial, sans-serif;
    background: #f4f7fb;
    color: #1f2937;
}
.wrap {
    min-height: 100vh;
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 24px;
}
.card {
    width: 100%;
    max-width: 520px;
    background: #ffffff;
    border-radius: 18px;
    box-shadow: 0 18px 40px rgba(15, 23, 42, 0.12);
    padding: 28px;
}
.badge {
    display: inline-block;
    padding: 6px 12px;
    border-radius: 999px;
    font-size: 12px;
    font-weight: 700;
    margin-bottom: 14px;
}
.badge.ok {
    background: #dcfce7;
    color: #166534;
}
.badge.warn {
    background: #fef3c7;
    color: #92400e;
}
h1 {
    margin: 0 0 10px;
    font-size: 28px;
}
p {
    margin: 0 0 12px;
    line-height: 1.5;
}
.muted {
    color: #64748b;
    font-size: 14px;
}
</style>
""";

app.MapGet("/checkout/success", (HttpContext httpContext) =>
{
    var sessionId = httpContext.Request.Query["session_id"].ToString();
    var encodedSessionId = System.Net.WebUtility.HtmlEncode(sessionId);
    var html = $"""
<!DOCTYPE html>
<html lang="bs">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Uplata uspješna</title>
  {CheckoutPageStyles}
</head>
<body>
  <div class="wrap">
    <div class="card">
      <div class="badge ok">UPLATA USPJEŠNA</div>
      <h1>Stripe uplata je završena.</h1>
      <p>Možete se vratiti u mobilnu aplikaciju. Status uplate će se automatski osvježiti.</p>
      <p class="muted">Ako se status ne prikaže odmah, otvorite aplikaciju ponovo i sačekajte nekoliko sekundi.</p>
      {(string.IsNullOrWhiteSpace(encodedSessionId) ? "" : $"<p class=\"muted\">Session: {encodedSessionId}</p>")}
    </div>
  </div>
</body>
</html>
""";

    return Results.Content(html, "text/html; charset=utf-8");
});

app.MapGet("/checkout/cancel", () =>
{
    var html = $"""
<!DOCTYPE html>
<html lang="bs">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <title>Uplata otkazana</title>
  {CheckoutPageStyles}
</head>
<body>
  <div class="wrap">
    <div class="card">
      <div class="badge warn">UPLATA OTKAZANA</div>
      <h1>Plaćanje nije dovršeno.</h1>
      <p>Možete se vratiti u mobilnu aplikaciju i pokušati ponovo kada budete spremni.</p>
      <p class="muted">Ako ste zatvorili Stripe checkout namjerno, nije potrebna dodatna akcija.</p>
    </div>
  </div>
</body>
</html>
""";

    return Results.Content(html, "text/html; charset=utf-8");
});

app.MapGet("/health", async (GymDbContext db) =>
{
    var databaseAvailable = await db.Database.CanConnectAsync();
    return Results.Ok(new
    {
        status = databaseAvailable ? "ok" : "degraded",
        database = databaseAvailable,
        timestampUtc = DateTime.UtcNow
    });
});

app.UseCors();
app.UseRateLimiter();
app.UseAuthentication();
app.UseAuthorization();
app.MapControllers();
app.Run();
