using System;

namespace Reservas.Api.Tests;

public static class TestTokenGenerator
{
    public static string GenerateFakeToken(Guid userId)
    {
        var header = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes("{\"alg\":\"none\"}")).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        var payload = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes($"{{\"sub\":\"" + userId + "\",\"http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier\":\"" + userId + "\"}}")).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        return $"{header}.{payload}.";
    }
}
