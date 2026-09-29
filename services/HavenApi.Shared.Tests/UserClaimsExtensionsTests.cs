using System;
using System.Security.Claims;
using HavenApi.Shared.Extensions;
using Microsoft.AspNetCore.Http;
using Xunit;

namespace HavenApi.Shared.Tests;

public class UserClaimsExtensionsTests
{
    [Fact]
    public void TryGetUserId_ConClaimNameIdentifierValido_DeberiaRetornarTrue()
    {
        var expectedId = Guid.NewGuid();
        var claims = new[] { new Claim(ClaimTypes.NameIdentifier, expectedId.ToString()) };
        var user = new ClaimsPrincipal(new ClaimsIdentity(claims));

        var result = user.TryGetUserId(out var userId);

        Assert.True(result);
        Assert.Equal(expectedId, userId);
    }

    [Fact]
    public void TryGetUserId_ConSoloSubValido_DeberiaRetornarTrue()
    {
        var expectedId = Guid.NewGuid();
        var claims = new[] { new Claim("sub", expectedId.ToString()) };
        var user = new ClaimsPrincipal(new ClaimsIdentity(claims));

        var result = user.TryGetUserId(out var userId);

        Assert.True(result);
        Assert.Equal(expectedId, userId);
    }

    [Fact]
    public void TryGetUserId_ConAmbosPresentes_GanaNameIdentifier()
    {
        var expectedId = Guid.NewGuid();
        var subId = Guid.NewGuid();
        var claims = new[] 
        { 
            new Claim("sub", subId.ToString()),
            new Claim(ClaimTypes.NameIdentifier, expectedId.ToString())
        };
        var user = new ClaimsPrincipal(new ClaimsIdentity(claims));

        var result = user.TryGetUserId(out var userId);

        Assert.True(result);
        Assert.Equal(expectedId, userId);
    }

    [Fact]
    public void TryGetUserId_SinClaims_DeberiaRetornarFalse()
    {
        var user = new ClaimsPrincipal(new ClaimsIdentity());

        var result = user.TryGetUserId(out var userId);

        Assert.False(result);
        Assert.Equal(Guid.Empty, userId);
    }

    [Fact]
    public void TryGetUserId_ConValorQueNoEsGuid_DeberiaRetornarFalse()
    {
        var claims = new[] { new Claim(ClaimTypes.NameIdentifier, "no-es-guid") };
        var user = new ClaimsPrincipal(new ClaimsIdentity(claims));

        var result = user.TryGetUserId(out var userId);

        Assert.False(result);
        Assert.Equal(Guid.Empty, userId);
    }

    [Fact]
    public void GetBearerToken_ConHeaderBearerPresente_DeberiaRetornarToken()
    {
        var context = new DefaultHttpContext();
        context.Request.Headers["Authorization"] = "Bearer mi-token-secreto";

        var result = context.Request.GetBearerToken();

        Assert.Equal("mi-token-secreto", result);
    }

    [Fact]
    public void GetBearerToken_ConHeaderAusente_DeberiaRetornarCadenaVacia()
    {
        var context = new DefaultHttpContext();

        var result = context.Request.GetBearerToken();

        Assert.Equal(string.Empty, result);
    }

    [Fact]
    public void GetBearerToken_ConHeaderSinPrefijoBearer_DeberiaRetornarValor()
    {
        var context = new DefaultHttpContext();
        context.Request.Headers["Authorization"] = "mi-token-sin-prefijo";

        var result = context.Request.GetBearerToken();

        Assert.Equal("mi-token-sin-prefijo", result);
    }
}
