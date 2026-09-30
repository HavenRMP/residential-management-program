using System.Net;
using Xunit;
using Microsoft.Extensions.Configuration;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using HavenApi.Shared.Exceptions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.AspNetCore.TestHost;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Visitas.Api.DTOs;
using Visitas.Api.Services;

namespace Visitas.Api.Tests;

public class RegistrarSalidaVisitaTests
{
    public RegistrarSalidaVisitaTests()
    {
        Environment.SetEnvironmentVariable("Supabase__Url", "https://localhost:54321");
    }

    private WebApplicationFactory<Program> BuildApplication(Mock<ISupabaseService> mockSupabaseService)
    {
        return new WebApplicationFactory<Program>().WithWebHostBuilder(builder =>
        {
            builder.ConfigureAppConfiguration((context, configBuilder) =>
            {
                configBuilder.AddInMemoryCollection(new Dictionary<string, string?>
                {
                    { "Supabase:Url", "http://localhost:54321" }
                });
            });
            builder.ConfigureTestServices(services =>
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
                if (descriptor != null)
                {
                    services.Remove(descriptor);
                }
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
    public async Task RegistrarSalida_Vigilancia_ReturnsOkYServicioLlamado()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();
        var visitaId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Vigilancia", condominioId));

        var expectedVisita = new VisitaDto { Id = visitaId, NombreVisitante = "Juan" };
        mockSupabaseService.Setup(s => s.RegistrarSalidaAsync(visitaId, userId))
            .ReturnsAsync(expectedVisita);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsync($"/api/visitas/{visitaId}/salida", null);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        mockSupabaseService.Verify(s => s.RegistrarSalidaAsync(visitaId, userId), Times.Once);
    }

    [Fact]
    public async Task RegistrarSalida_Administrador_ReturnsForbidden()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();
        var visitaId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsync($"/api/visitas/{visitaId}/salida", null);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.RegistrarSalidaAsync(It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task RegistrarSalida_Residente_ReturnsForbidden()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();
        var visitaId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Residente", condominioId));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsync($"/api/visitas/{visitaId}/salida", null);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.RegistrarSalidaAsync(It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task RegistrarSalida_SinToken_ReturnsUnauthorized()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        var visitaId = Guid.NewGuid();

        var response = await client.PostAsync($"/api/visitas/{visitaId}/salida", null);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        mockSupabaseService.Verify(s => s.RegistrarSalidaAsync(It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }

    private async Task TestRpcException(string errorCode, HttpStatusCode expectedStatus)
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var condominioId = Guid.NewGuid();
        var visitaId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoUsuarioAsync(userId, It.IsAny<string>()))
            .ReturnsAsync(("Vigilancia", condominioId));

        mockSupabaseService.Setup(s => s.RegistrarSalidaAsync(visitaId, userId))
            .ThrowsAsync(new SupabaseRpcException(errorCode, "Error de prueba"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.PostAsync($"/api/visitas/{visitaId}/salida", null);

        Assert.Equal(expectedStatus, response.StatusCode);
    }

    [Fact]
    public Task RegistrarSalida_RpcExceptionVI007_ReturnsConflict() => TestRpcException("VI007", HttpStatusCode.Conflict);

    [Fact]
    public Task RegistrarSalida_RpcExceptionVI003_ReturnsConflict() => TestRpcException("VI003", HttpStatusCode.Conflict);

    [Fact]
    public Task RegistrarSalida_RpcExceptionVI002_ReturnsForbidden() => TestRpcException("VI002", HttpStatusCode.Forbidden);

    [Fact]
    public Task RegistrarSalida_RpcExceptionVI001_ReturnsNotFound() => TestRpcException("VI001", HttpStatusCode.NotFound);
}
