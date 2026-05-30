using System.Text;
using System.Text.Json;
using Gym.Services.Interfaces;
using RabbitMQ.Client;

namespace Gym.Api.Messaging;

public record NotificationMessage(string To, string Subject, string Body);

public interface INotificationPublisher
{
    Task PublishAsync(NotificationMessage message);
}

public sealed class RabbitMqNotificationPublisher : INotificationPublisher, IUserCommunicationPublisher, IAsyncDisposable
{
    private readonly string _queue;
    private readonly IConfiguration _config;
    private readonly ILogger<RabbitMqNotificationPublisher> _logger;
    private readonly SemaphoreSlim _initLock = new(1, 1);

    private IConnection? _connection;
    private IChannel? _channel;
    private bool _initializationAttempted;

    public RabbitMqNotificationPublisher(IConfiguration config, ILogger<RabbitMqNotificationPublisher> logger)
    {
        _config = config;
        _logger = logger;
        _queue = config["RabbitMQ:NotificationsQueue"] ?? "gym.notifications";
    }

    private async Task EnsureInitializedAsync()
    {
        if (_channel is not null || _initializationAttempted)
            return;

        await _initLock.WaitAsync();
        try
        {
            if (_channel is not null || _initializationAttempted)
                return;

            _initializationAttempted = true;

            var factory = new ConnectionFactory
            {
                HostName = _config["RabbitMQ:Host"] ?? "localhost",
                Port = int.Parse(_config["RabbitMQ:Port"] ?? "5672"),
                UserName = _config["RabbitMQ:Username"] ?? "guest",
                Password = _config["RabbitMQ:Password"] ?? "guest"
            };

            _connection = await factory.CreateConnectionAsync();
            _channel = await _connection.CreateChannelAsync();
            await _channel.QueueDeclareAsync(
                queue: _queue,
                durable: true,
                exclusive: false,
                autoDelete: false,
                arguments: null);
        }
        catch (Exception ex)
        {
            _logger.LogWarning("RabbitMQ not available - notifications disabled. {Message}", ex.Message);
        }
        finally
        {
            _initLock.Release();
        }
    }

    public async Task PublishAsync(NotificationMessage message)
    {
        await EnsureInitializedAsync();

        if (_channel is null)
            return;

        try
        {
            var body = Encoding.UTF8.GetBytes(JsonSerializer.Serialize(message));
            var props = new BasicProperties { Persistent = true };
            await _channel.BasicPublishAsync(
                exchange: string.Empty,
                routingKey: _queue,
                mandatory: false,
                basicProperties: props,
                body: body);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to publish notification to RabbitMQ.");
        }
    }

    public Task PublishAsync(string to, string subject, string body)
        => PublishAsync(new NotificationMessage(to, subject, body));

    public async ValueTask DisposeAsync()
    {
        _initLock.Dispose();

        if (_channel is not null)
            await _channel.DisposeAsync();

        if (_connection is not null)
            await _connection.DisposeAsync();
    }
}
