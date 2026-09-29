using System;
using System.Security.Claims;
using Microsoft.AspNetCore.Http;

namespace HavenApi.Shared.Extensions;

public static class UserClaimsExtensions
{
    public static bool TryGetUserId(this ClaimsPrincipal user, out Guid userId)
    {
        userId = Guid.Empty;
        if (user == null)
        {
            return false;
        }

        var userIdClaim = user.FindFirst(ClaimTypes.NameIdentifier)?.Value
                          ?? user.FindFirst("sub")?.Value;

        if (string.IsNullOrWhiteSpace(userIdClaim))
        {
            return false;
        }

        return Guid.TryParse(userIdClaim, out userId);
    }

    public static string GetBearerToken(this HttpRequest request)
    {
        if (request == null || !request.Headers.ContainsKey("Authorization"))
        {
            return string.Empty;
        }

        var authHeader = request.Headers["Authorization"].ToString();
        if (string.IsNullOrWhiteSpace(authHeader))
        {
            return string.Empty;
        }

        if (authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase))
        {
            return authHeader.Substring("Bearer ".Length).Trim();
        }

        return authHeader.Replace("Bearer ", "").Trim();
    }
}
