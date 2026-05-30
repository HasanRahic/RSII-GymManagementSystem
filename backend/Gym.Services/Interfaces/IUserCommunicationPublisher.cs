namespace Gym.Services.Interfaces;

public interface IUserCommunicationPublisher
{
    Task PublishAsync(string to, string subject, string body);
}
