using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using HavenApi.Shared.Exceptions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Visitas.Api.DTOs;
using Visitas.Api.Services;
using Xunit;

namespace Visitas.Api.Tests;

public class UpdateVisitaTests
{
    public UpdateVisitaTests()
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
    public async Task UpdateVisita_SinToken_ReturnsUnauthorized()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();

        var requestBody = new UpdateVisitaRequestDto { Motivo = "personal" };
        var visitaId = Guid.NewGuid();

        var response = await client.PutAsJsonAsync($"/api/visitas/{visitaId}", requestBody);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        mockSupabaseService.Verify(s => s.UpdateVisitaAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<UpdateVisitaRequestDto>()), Times.Never);
    }

    [Fact]
    public async Task UpdateVisita_BodyVacio_ReturnsBadRequestYNuncaLlamaAlServicio()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new UpdateVisitaRequestDto(); // Empty body
        var visitaId = Guid.NewGuid();

        var response = await client.PutAsJsonAsync($"/api/visitas/{visitaId}", requestBody);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        mockSupabaseService.Verify(s => s.UpdateVisitaAsync(It.IsAny<Guid>(), It.IsAny<Guid>(), It.IsAny<UpdateVisitaRequestDto>()), Times.Never);
    }

    [Fact]
    public async Task UpdateVisita_Valida_ReturnsOkYServicioRecibeUserIdDelToken()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var visitaId = Guid.NewGuid();
        
        var expectedDto = new VisitaDto
        {
            Id = visitaId,
            ViviendaId = 1,
            NombreVisitante = "Juan",
            ApellidosVisitante = "Perez",
            Motivo = "familiar",
            Estado = "programada",
            Codigo = "ABCDEF"
        };

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.UpdateVisitaAsync(visitaId, userId, It.IsAny<UpdateVisitaRequestDto>()))
            .ReturnsAsync(expectedDto);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new UpdateVisitaRequestDto { Motivo = "familiar" };

        var response = await client.PutAsJsonAsync($"/api/visitas/{visitaId}", requestBody);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        mockSupabaseService.Verify(s => s.UpdateVisitaAsync(visitaId, userId, It.IsAny<UpdateVisitaRequestDto>()), Times.Once);
        
        var content = await response.Content.ReadAsStringAsync();
        Assert.Contains("ABCDEF", content);
    }

    [Fact]
    public async Task UpdateVisita_RpcExceptionVI001_ReturnsNotFound()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var visitaId = Guid.NewGuid();
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.UpdateVisitaAsync(visitaId, userId, It.IsAny<UpdateVisitaRequestDto>()))
            .ThrowsAsync(new SupabaseRpcException("VI001", "Visita no encontrada"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new UpdateVisitaRequestDto { Motivo = "familiar" };

        var response = await client.PutAsJsonAsync($"/api/visitas/{visitaId}", requestBody);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task UpdateVisita_RpcExceptionVI002_ReturnsForbidden()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var visitaId = Guid.NewGuid();
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.UpdateVisitaAsync(visitaId, userId, It.IsAny<UpdateVisitaRequestDto>()))
            .ThrowsAsync(new SupabaseRpcException("VI002", "No tienes permisos"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new UpdateVisitaRequestDto { Motivo = "familiar" };

        var response = await client.PutAsJsonAsync($"/api/visitas/{visitaId}", requestBody);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task UpdateVisita_RpcExceptionVI003_ReturnsConflict()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var visitaId = Guid.NewGuid();
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.UpdateVisitaAsync(visitaId, userId, It.IsAny<UpdateVisitaRequestDto>()))
            .ThrowsAsync(new SupabaseRpcException("VI003", "Estado no permite modificación"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new UpdateVisitaRequestDto { Motivo = "familiar" };

        var response = await client.PutAsJsonAsync($"/api/visitas/{visitaId}", requestBody);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task UpdateVisita_RpcExceptionVI008_ReturnsBadRequest()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var visitaId = Guid.NewGuid();
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.UpdateVisitaAsync(visitaId, userId, It.IsAny<UpdateVisitaRequestDto>()))
            .ThrowsAsync(new SupabaseRpcException("VI008", "Error de validación"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new UpdateVisitaRequestDto { Motivo = "familiar" };

        var response = await client.PutAsJsonAsync($"/api/visitas/{visitaId}", requestBody);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
