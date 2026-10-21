using System.Security.Claims;
using System.Text.Json;
using HavenApi.Shared.Extensions;

namespace Pagos.Api.Authentication;

public static class TokenClaimsExtractor
{
    public static bool TryGetUserId(ClaimsPrincipal user, out Guid userId)
    {
        return user.TryGetUserId(out userId);
    }

    public static bool TryGetCondominioId(ClaimsPrincipal user, out Guid condominioId)
    {
        condominioId = Guid.Empty;
        if (user == null) return false;

        // 1. Probar claims directos
        var directClaim = user.FindFirst("condominio_id")?.Value 
                          ?? user.FindFirst("app_metadata.condominio_id")?.Value;

        if (!string.IsNullOrWhiteSpace(directClaim) && Guid.TryParse(directClaim, out condominioId))
        {
            return true;
        }

        // 2. Probar dentro del claim app_metadata como JSON
        var appMetadataClaim = user.FindFirst("app_metadata")?.Value;
        if (!string.IsNullOrWhiteSpace(appMetadataClaim))
        {
            try
            {
                using var doc = JsonDocument.Parse(appMetadataClaim);
                if (doc.RootElement.TryGetProperty("condominio_id", out var condProp) &&
                    condProp.ValueKind == JsonValueKind.String &&
                    Guid.TryParse(condProp.GetString(), out condominioId))
                {
                    return true;
                }
            }
            catch (JsonException)
            {
                // Formato no JSON, ignorar
            }
        }

        return false;
    }

    public static string? GetRol(ClaimsPrincipal user)
    {
        if (user == null) return null;

        // 1. Probar claims directos
        var directRol = user.FindFirst(ClaimTypes.Role)?.Value
                        ?? user.FindFirst("role")?.Value
                        ?? user.FindFirst("rol")?.Value
                        ?? user.FindFirst("app_metadata.rol")?.Value
                        ?? user.FindFirst("app_metadata.role")?.Value;

        if (!string.IsNullOrWhiteSpace(directRol))
        {
            return directRol;
        }

        // 2. Probar dentro del claim app_metadata como JSON
        var appMetadataClaim = user.FindFirst("app_metadata")?.Value;
        if (!string.IsNullOrWhiteSpace(appMetadataClaim))
        {
            try
            {
                using var doc = JsonDocument.Parse(appMetadataClaim);
                if (doc.RootElement.TryGetProperty("rol", out var rolProp) && rolProp.ValueKind == JsonValueKind.String)
                {
                    return rolProp.GetString();
                }
                if (doc.RootElement.TryGetProperty("role", out var roleProp) && roleProp.ValueKind == JsonValueKind.String)
                {
                    return roleProp.GetString();
                }
            }
            catch (JsonException)
            {
                // Formato no JSON, ignorar
            }
        }

        return null;
    }
}
