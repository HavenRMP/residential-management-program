using System.Security.Claims;
using System.Text.Json;

namespace Pagos.Api.Tests;

public static class TestTokenGenerator
{
    public static string GenerateToken(
        Guid userId, 
        Guid? condominioId = null, 
        string? rol = null)
    {
        var headerObj = new { alg = "none", typ = "JWT" };
        var headerJson = JsonSerializer.Serialize(headerObj);
        var headerBase64 = Base64UrlEncode(headerJson);

        var payloadDict = new Dictionary<string, object>
        {
            { "sub", userId.ToString() },
            { "http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier", userId.ToString() },
            { "aud", "authenticated" }
        };

        var appMetadata = new Dictionary<string, object>();
        if (condominioId.HasValue)
        {
            appMetadata["condominio_id"] = condominioId.Value.ToString();
            payloadDict["condominio_id"] = condominioId.Value.ToString();
        }

        if (!string.IsNullOrEmpty(rol))
        {
            appMetadata["rol"] = rol;
            appMetadata["role"] = rol;
            payloadDict["http://schemas.microsoft.com/ws/2008/06/identity/claims/role"] = rol;
            payloadDict["role"] = rol;
            payloadDict["rol"] = rol;
        }

        if (appMetadata.Count > 0)
        {
            payloadDict["app_metadata"] = appMetadata;
        }

        var payloadJson = JsonSerializer.Serialize(payloadDict);
        var payloadBase64 = Base64UrlEncode(payloadJson);

        return $"{headerBase64}.{payloadBase64}.";
    }

    public static string GenerateAdminToken(Guid? userId = null, Guid? condominioId = null)
    {
        return GenerateToken(
            userId ?? Guid.NewGuid(),
            condominioId ?? Guid.NewGuid(),
            "Administrador");
    }

    public static string GenerateInquilinoToken(Guid? userId = null, Guid? condominioId = null)
    {
        return GenerateToken(
            userId ?? Guid.NewGuid(),
            condominioId ?? Guid.NewGuid(),
            "Residente");
    }

    public static string GenerateSubusuarioToken(Guid? userId = null, Guid? condominioId = null)
    {
        return GenerateToken(
            userId ?? Guid.NewGuid(),
            condominioId ?? Guid.NewGuid(),
            "Subusuario");
    }

    private static string Base64UrlEncode(string input)
    {
        var bytes = System.Text.Encoding.UTF8.GetBytes(input);
        return Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
    }
}
