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
        // Nota: Ignoramos "authenticated" y "anon" porque son roles internos del sistema de Supabase Auth,
        // no roles de la aplicación Haven ("Administrador", "Residente", etc.).
        var candidateClaims = user.FindAll(c =>
            c.Type == ClaimTypes.Role ||
            c.Type == "role" ||
            c.Type == "rol" ||
            c.Type == "app_metadata.rol" ||
            c.Type == "app_metadata.role");

        foreach (var c in candidateClaims)
        {
            if (!string.IsNullOrWhiteSpace(c.Value) &&
                !string.Equals(c.Value, "authenticated", StringComparison.OrdinalIgnoreCase) &&
                !string.Equals(c.Value, "anon", StringComparison.OrdinalIgnoreCase))
            {
                return c.Value;
            }
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
                    var val = rolProp.GetString();
                    if (!string.IsNullOrWhiteSpace(val) &&
                        !string.Equals(val, "authenticated", StringComparison.OrdinalIgnoreCase) &&
                        !string.Equals(val, "anon", StringComparison.OrdinalIgnoreCase))
                    {
                        return val;
                    }
                }
                if (doc.RootElement.TryGetProperty("role", out var roleProp) && roleProp.ValueKind == JsonValueKind.String)
                {
                    var val = roleProp.GetString();
                    if (!string.IsNullOrWhiteSpace(val) &&
                        !string.Equals(val, "authenticated", StringComparison.OrdinalIgnoreCase) &&
                        !string.Equals(val, "anon", StringComparison.OrdinalIgnoreCase))
                    {
                        return val;
                    }
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
