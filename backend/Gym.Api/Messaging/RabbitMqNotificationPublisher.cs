using System.Text;
using System.Text.Json;
using RabbitMQ.Client;

namespace Gym.Api.Messaging;

public record NotificationMessage(string To, string Subject, string Body);

public interface INotificationPublisher
{
    Task PublishAsync(NotificationMessage message);
}

public sealed class RabbitMqNotificationPublisher : INotificationPublisher, IAsyncDisposable
{
    private IConnection? _connection;
    private IChannel?    _channel;
    private readonly string _queue;
    private readonly ILogger<RabbitMqNotificationPublisher> _logger;

    public RabbitMqNotificationPublisher(IConfiguration config, ILogger<RabbitMqNotificationPublisher> logger)
    {
        _logger = logger;
        _queue  = config["RabbitMQ:NotificationsQueue"] ?? "gym.notifications";
        _ = InitAsync(config);
    }

    private async Task InitAsync(IConfiguration config)
    {
        try
        {
            var factory = new ConnectionFactory
            {
                HostName = config["RabbitMQ:Host"]     ?? "localhost",
                Port     = int.Parse(config["RabbitMQ:Port"] ?? "5672"),
                UserName = config["RabbitMQ:Username"] ?? "guest",
                Password = config["RabbitMQ:Password"] ?? "guest"
            };
            _connection = await factory.CreateConnectionAsync();
            _channel    = await _connection.CreateChannelAsync();
            await _channel.QueueDeclareAsync(
                queue:      _queue,
                durable:    true,
                exclusive:  false,
                autoDelete: false,
                arguments:  null);
        }
        catch (Exception ex)
        {
            _logger.LogWarning("RabbitMQ not available – notifications disabled. {Message}", ex.Message);
        }
    }

    public async Task PublishAsync(NotificationMessage message)
    {
        if (_channel is null) return;
        try
        {
            var body = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(message));
            var props = new BasicProperties { Persistent = true };
            await _channel.BasicPublishAsync(
                exchange:    string.Empty,
                routingKey:  _queue,
                mandatory:   false,
                basicProperties: props,
                body:        body);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to publish notification to RabbitMQ.");
        }
    }

    public async ValueTask DisposeAsync()
    {
        if (_channel is not null)    await _channel.DisposeAsync();
        if (_connection is not null) await _connection.DisposeAsync();
    }
}
