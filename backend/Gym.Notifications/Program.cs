using Gym.Notifications.Configuration;
using Gym.Notifications.Workers;

var builder = Host.CreateApplicationBuilder(args);
builder.AddProjectDotEnvConfiguration();
builder.Services.AddHostedService<NotificationWorker>();

var host = builder.Build();
host.Run();
