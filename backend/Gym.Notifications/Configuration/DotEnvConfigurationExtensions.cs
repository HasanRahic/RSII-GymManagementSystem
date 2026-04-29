using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Hosting;

namespace Gym.Notifications.Configuration;

internal static class DotEnvConfigurationExtensions
{
    public static HostApplicationBuilder AddProjectDotEnvConfiguration(this HostApplicationBuilder builder)
    {
        var rootPath = Path.GetFullPath(Path.Combine(builder.Environment.ContentRootPath, "..", ".."));
        var envPath = ResolveEnvPath(rootPath);
        if (envPath is null)
        {
            return builder;
        }

        var values = ParseDotEnv(envPath);
        if (values.Count == 0)
        {
            return builder;
        }

        builder.Configuration.AddInMemoryCollection(values);
        return builder;
    }

    private static string? ResolveEnvPath(string rootPath)
    {
        var primary = Path.Combine(rootPath, ".env");
        if (File.Exists(primary))
        {
            return primary;
        }

        var fallback = Path.Combine(rootPath, ".env.example");
        return File.Exists(fallback) ? fallback : null;
    }

    private static Dictionary<string, string?> ParseDotEnv(string envPath)
    {
        var values = new Dictionary<string, string?>(StringComparer.OrdinalIgnoreCase);

        foreach (var rawLine in File.ReadAllLines(envPath))
        {
            var line = rawLine.Trim();
            if (string.IsNullOrWhiteSpace(line) || line.StartsWith('#'))
            {
                continue;
            }

            var separatorIndex = line.IndexOf('=');
            if (separatorIndex <= 0)
            {
                continue;
            }

            var key = line[..separatorIndex].Trim();
            var value = line[(separatorIndex + 1)..].Trim();

            if (value.Length >= 2 && value.StartsWith('"') && value.EndsWith('"'))
            {
                value = value[1..^1];
            }

            MapValue(values, key, value);
        }

        return values;
    }

    private static void MapValue(IDictionary<string, string?> values, string key, string value)
    {
        values[key] = value;

        switch (key)
        {
            case "RABBITMQ_HOST":
                values["RabbitMQ:Host"] = value;
                break;
            case "RABBITMQ_PORT":
                values["RabbitMQ:Port"] = value;
                break;
            case "RABBITMQ_USERNAME":
                values["RabbitMQ:Username"] = value;
                break;
            case "RABBITMQ_PASSWORD":
                values["RabbitMQ:Password"] = value;
                break;
            case "RABBITMQ_NOTIFICATIONS_QUEUE":
                values["RabbitMQ:NotificationsQueue"] = value;
                break;
            case "SMTP_HOST":
                values["SMTP:Host"] = value;
                break;
            case "SMTP_PORT":
                values["SMTP:Port"] = value;
                break;
            case "SMTP_USERNAME":
                values["SMTP:Username"] = value;
                break;
            case "SMTP_PASSWORD":
                values["SMTP:Password"] = value;
                break;
            case "SMTP_FROM":
                values["SMTP:From"] = value;
                break;
        }
    }
}
