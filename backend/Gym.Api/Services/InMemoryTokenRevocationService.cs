using System.Collections.Concurrent;

namespace Gym.Api.Services;

public sealed class InMemoryTokenRevocationService : ITokenRevocationService
{
    private readonly ConcurrentDictionary<string, DateTime> _revokedTokens = new(StringComparer.Ordinal);

    public bool IsRevoked(string tokenId)
    {
        CleanupExpired();

        return _revokedTokens.TryGetValue(tokenId, out var expiresAtUtc)
            && expiresAtUtc > DateTime.UtcNow;
    }

    public void Revoke(string tokenId, DateTime expiresAtUtc)
    {
        CleanupExpired();
        _revokedTokens[tokenId] = expiresAtUtc;
    }

    public void CleanupExpired()
    {
        var now = DateTime.UtcNow;
        foreach (var pair in _revokedTokens)
        {
            if (pair.Value <= now)
            {
                _revokedTokens.TryRemove(pair.Key, out _);
            }
        }
    }
}
