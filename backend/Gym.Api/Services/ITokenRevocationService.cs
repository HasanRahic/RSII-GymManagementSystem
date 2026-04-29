namespace Gym.Api.Services;

public interface ITokenRevocationService
{
    bool IsRevoked(string tokenId);
    void Revoke(string tokenId, DateTime expiresAtUtc);
    void CleanupExpired();
}
