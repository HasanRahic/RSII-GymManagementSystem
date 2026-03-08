using System.Text;
using System.Text.Json;
using Gym.Notifications.Models;
using MailKit.Net.Smtp;
using MailKit.Security;
using MimeKit;
using RabbitMQ.Client;
using RabbitMQ.Client.Events;

namespace Gym.Notifications.Workers;

public class NotificationWorker(IConfiguration configuration, ILogger<NotificationWorker> logger)
    : BackgroundService
{
    private IConnection? _connection;
    private IChannel? _channel;

    private readonly string _queue    = configuration["RabbitMQ:NotificationsQueue"] ?? "gym.notifications";
    private readonly string _host     = configuration["RabbitMQ:Host"]     ?? "localhost";
    private readonly int    _port     = int.Parse(configuration["RabbitMQ:Port"] ?? "5672");
    private readonly string _user     = configuration["RabbitMQ:Username"] ?? "guest";
    private readonly string _password = configuration["RabbitMQ:Password"] ?? "guest";

    public override async Task StartAsync(CancellationToken cancellationToken)
    {
        var factory = new ConnectionFactory
        {
            HostName = _host,
            Port     = _port,
            UserName = _user,
            Password = _password
        };

        // Retry connection up to 10 times (RabbitMQ may not be ready yet)
        for (int attempt = 1; attempt <= 10; attempt++)
        {
            try
            {
                _connection = await factory.CreateConnectionAsync(cancellationToken);
                _channel    = await _connection.CreateChannelAsync(cancellationToken: cancellationToken);
                await _channel.QueueDeclareAsync(
                    queue:      _queue,
                    durable:    true,
                    exclusive:  false,
                    autoDelete: false,
                    arguments:  null,
                    cancellationToken: cancellationToken);

                logger.LogInformation("Connected to RabbitMQ on attempt {Attempt}.", attempt);
                break;
            }
            catch (Exception ex)
            {
                logger.LogWarning("RabbitMQ connection attempt {Attempt} failed: {Message}", attempt, ex.Message);
                if (attempt == 10) throw;
                await Task.Delay(TimeSpan.FromSeconds(5), cancellationToken);
            }
        }

        await base.StartAsync(cancellationToken);
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        if (_channel is null) return;

        var consumer = new AsyncEventingBasicConsumer(_channel);
        consumer.ReceivedAsync += async (_, ea) =>
        {
            try
            {
                var json    = Encoding.UTF8.GetString(ea.Body.ToArray());
                var message = JsonSerializer.Deserialize<NotificationMessage>(json);

                if (message is not null)
                    await SendEmailAsync(message);

                await _channel.BasicAckAsync(ea.DeliveryTag, false, stoppingToken);
            }
            catch (Exception ex)
            {
                logger.LogError(ex, "Error processing notification message.");
                await _channel.BasicNackAsync(ea.DeliveryTag, false, requeue: false, stoppingToken);
            }
        };

        await _channel.BasicConsumeAsync(_queue, autoAck: false, consumer, stoppingToken);

        // Keep running until cancellation
        await Task.Delay(Timeout.Infinite, stoppingToken).ConfigureAwait(false);
    }

    private async Task SendEmailAsync(NotificationMessage message)
    {
        var smtpHost     = configuration["SMTP:Host"]     ?? "smtp.gmail.com";
        var smtpPort     = int.Parse(configuration["SMTP:Port"] ?? "587");
        var smtpUser     = configuration["SMTP:Username"] ?? "";
        var smtpPassword = configuration["SMTP:Password"] ?? "";
        var smtpFrom     = configuration["SMTP:From"]     ?? smtpUser;

        var email = new MimeMessage();
        email.From.Add(MailboxAddress.Parse(smtpFrom));
        email.To.Add(MailboxAddress.Parse(message.To));
        email.Subject = message.Subject;
        email.Body    = new TextPart("html") { Text = message.Body };

        using var smtp = new SmtpClient();
        await smtp.ConnectAsync(smtpHost, smtpPort, SecureSocketOptions.StartTls);
        await smtp.AuthenticateAsync(smtpUser, smtpPassword);
        await smtp.SendAsync(email);
        await smtp.DisconnectAsync(true);

        logger.LogInformation("Email sent to {To} – Subject: {Subject}", message.To, message.Subject);
    }

    public override async Task StopAsync(CancellationToken cancellationToken)
    {
        if (_channel is not null) await _channel.CloseAsync(cancellationToken);
        if (_connection is not null) await _connection.CloseAsync(cancellationToken);
        await base.StopAsync(cancellationToken);
    }
}
