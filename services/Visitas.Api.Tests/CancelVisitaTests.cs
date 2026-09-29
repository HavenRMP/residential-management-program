using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Security.Claims;
using HavenApi.Shared.Exceptions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Visitas.Api.Services;
using Xunit;

namespace Visitas.Api.Tests;

public class CancelVisitaTests
{
    public CancelVisitaTests()
    {
        Environment.SetEnvironmentVariable("Supabase__Url", "https://localhost:54321");
    }

    private WebApplicationFactory<Program> BuildApplication(Mock<ISupabaseService> mockSupabaseService)
    {
        return new WebApplicationFactory<Program>()
            .WithWebHostBuilder(builder =>
            {
                builder.ConfigureAppConfiguration((context, configBuilder) =>
                {
                    configBuilder.AddInMemoryCollection(new Dictionary<string, string?>
                    {
                        { "Supabase:Url", "http://localhost:54321" }
                    });
                });
                builder.ConfigureServices(services =>
                {
                    services.PostConfigure<Microsoft.AspNetCore.Authentication.JwtBearer.JwtBearerOptions>(
                        Microsoft.AspNetCore.Authentication.JwtBearer.JwtBearerDefaults.AuthenticationScheme,
                        options =>
                        {
                            options.Authority = null;
                            options.TokenValidationParameters.ValidateIssuer = false;
                            options.TokenValidationParameters.ValidateAudience = false;
                            options.TokenValidationParameters.ValidateLifetime = false;
                            options.TokenValidationParameters.ValidateIssuerSigningKey = false;
                            options.TokenValidationParameters.RequireSignedTokens = false;
                        });

                    var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseService));
                    if (descriptor != null) services.Remove(descriptor);
                    services.AddSingleton(mockSupabaseService.Object);
                });
            });
    }

    private string GenerateFakeToken(Guid userId)
    {
        var header = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes("{\"alg\":\"none\"}")).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        var payload = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes($"{{\"sub\":\"" + userId + "\",\"http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier\":\"" + userId + "\"}}")).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        return $"{header}.{payload}.";
    }

    [Fact]
    public async Task CancelVisita_SinToken_ReturnsUnauthorized()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();

        var visitaId = Guid.NewGuid();
        var response = await client.PostAsync($"/api/visitas/{visitaId}/cancelar", null);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        mockSupabaseService.Verify(s => s.CancelVisitaAsync(It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task CancelVisita_Exitosa_ReturnsNoContent()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var visitaId = Guid.NewGuid();
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.CancelVisitaAsync(visitaId, userId))
            .ReturnsAsync(true);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsync($"/api/visitas/{visitaId}/cancelar", null);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        mockSupabaseService.Verify(s => s.CancelVisitaAsync(visitaId, userId), Times.Once);
    }

    [Fact]
    public async Task CancelVisita_ServicioDevuelveFalse_ReturnsNotFound()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var visitaId = Guid.NewGuid();
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.CancelVisitaAsync(visitaId, userId))
            .ReturnsAsync(false);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsync($"/api/visitas/{visitaId}/cancelar", null);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        mockSupabaseService.Verify(s => s.CancelVisitaAsync(visitaId, userId), Times.Once);
    }

    [Fact]
    public async Task CancelVisita_RpcExceptionVI002_ReturnsForbidden()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var visitaId = Guid.NewGuid();
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.CancelVisitaAsync(visitaId, userId))
            .ThrowsAsync(new SupabaseRpcException("VI002", "No tienes permisos"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsync($"/api/visitas/{visitaId}/cancelar", null);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CancelVisita_RpcExceptionVI003_ReturnsConflict()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var visitaId = Guid.NewGuid();
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.CancelVisitaAsync(visitaId, userId))
            .ThrowsAsync(new SupabaseRpcException("VI003", "Estado no permite modificación"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsync($"/api/visitas/{visitaId}/cancelar", null);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }
}
