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
using Testcontainers.PostgreSql;
using Visitas.Api.DTOs;
using Visitas.Api.Services;
using Xunit;

namespace Visitas.Api.Tests;

public class CrearVisitaTests
{
    public CrearVisitaTests()
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
    public async Task CrearVisita_ValidRequest_UsesUserIdFromTokenAndReturnsCreated()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        
        var expectedDto = new VisitaDto
        {
            Id = Guid.NewGuid(),
            ViviendaId = 1,
            NombreVisitante = "Juan",
            ApellidosVisitante = "Perez",
            Motivo = "personal",
            Estado = "programada",
            Codigo = "XYZ123",
            FechaLlegadaEsperada = DateTimeOffset.UtcNow.AddDays(1)
        };

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.CreateVisitaAsync(It.IsAny<CreateVisitaRequestDto>(), userId))
            .ReturnsAsync(expectedDto);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new CreateVisitaRequestDto 
        { 
            ViviendaId = 1,
            NombreVisitante = "Juan",
            ApellidosVisitante = "Perez",
            Motivo = "personal",
            FechaLlegadaEsperada = DateTimeOffset.UtcNow.AddDays(1)
        };
        
        var response = await client.PostAsJsonAsync("/api/visitas", requestBody);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        
        mockSupabaseService.Verify(s => s.CreateVisitaAsync(It.IsAny<CreateVisitaRequestDto>(), userId), Times.Once);
        
        // Ensure body property name in output
        var content = await response.Content.ReadAsStringAsync();
        Assert.Contains(expectedDto.Codigo, content);
    }

    [Fact]
    public async Task CrearVisita_NoToken_ReturnsUnauthorizedAndServiceNotCalled()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        
        var requestBody = new CreateVisitaRequestDto 
        { 
            ViviendaId = 1,
            NombreVisitante = "Juan",
            ApellidosVisitante = "Perez",
            Motivo = "personal",
            FechaLlegadaEsperada = DateTimeOffset.UtcNow.AddDays(1)
        };
        
        var response = await client.PostAsJsonAsync("/api/visitas", requestBody);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        
        mockSupabaseService.Verify(s => s.CreateVisitaAsync(It.IsAny<CreateVisitaRequestDto>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task CrearVisita_InvalidBody_ReturnsBadRequestAndServiceNotCalled()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Sin NombreVisitante
        var requestBody = new CreateVisitaRequestDto 
        { 
            ViviendaId = 1,
            ApellidosVisitante = "Perez",
            Motivo = "personal",
            FechaLlegadaEsperada = DateTimeOffset.UtcNow.AddDays(1)
        };
        
        var response = await client.PostAsJsonAsync("/api/visitas", requestBody);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        
        mockSupabaseService.Verify(s => s.CreateVisitaAsync(It.IsAny<CreateVisitaRequestDto>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task CrearVisita_InvalidMotivo_ReturnsBadRequest()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new CreateVisitaRequestDto 
        { 
            ViviendaId = 1,
            NombreVisitante = "Juan",
            ApellidosVisitante = "Perez",
            Motivo = "invalid_motivo",
            FechaLlegadaEsperada = DateTimeOffset.UtcNow.AddDays(1)
        };
        
        var response = await client.PostAsJsonAsync("/api/visitas", requestBody);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        
        mockSupabaseService.Verify(s => s.CreateVisitaAsync(It.IsAny<CreateVisitaRequestDto>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task CrearVisita_RpcExceptionVI002_ReturnsForbidden()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.CreateVisitaAsync(It.IsAny<CreateVisitaRequestDto>(), userId))
            .ThrowsAsync(new SupabaseRpcException("VI002", "Acceso denegado a la vivienda"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new CreateVisitaRequestDto 
        { 
            ViviendaId = 1,
            NombreVisitante = "Juan",
            ApellidosVisitante = "Perez",
            Motivo = "personal",
            FechaLlegadaEsperada = DateTimeOffset.UtcNow.AddDays(1)
        };
        
        var response = await client.PostAsJsonAsync("/api/visitas", requestBody);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
    }

    [Fact]
    public async Task CrearVisita_RpcExceptionVI009_ReturnsNotFound()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.CreateVisitaAsync(It.IsAny<CreateVisitaRequestDto>(), userId))
            .ThrowsAsync(new SupabaseRpcException("VI009", "Vivienda no encontrada"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new CreateVisitaRequestDto 
        { 
            ViviendaId = 1,
            NombreVisitante = "Juan",
            ApellidosVisitante = "Perez",
            Motivo = "personal",
            FechaLlegadaEsperada = DateTimeOffset.UtcNow.AddDays(1)
        };
        
        var response = await client.PostAsJsonAsync("/api/visitas", requestBody);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task CrearVisita_RpcExceptionVI008_ReturnsBadRequest()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.CreateVisitaAsync(It.IsAny<CreateVisitaRequestDto>(), userId))
            .ThrowsAsync(new SupabaseRpcException("VI008", "Estado inválido"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new CreateVisitaRequestDto 
        { 
            ViviendaId = 1,
            NombreVisitante = "Juan",
            ApellidosVisitante = "Perez",
            Motivo = "personal",
            FechaLlegadaEsperada = DateTimeOffset.UtcNow.AddDays(1)
        };
        
        var response = await client.PostAsJsonAsync("/api/visitas", requestBody);

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
    }
}
