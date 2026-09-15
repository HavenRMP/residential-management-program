using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Viviendas.Api.DTOs;
using Viviendas.Api.Services;
using Xunit;

namespace Viviendas.Api.Tests;

public class UpdateViviendaOwnershipTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public UpdateViviendaOwnershipTests()
    {
        Environment.SetEnvironmentVariable("Supabase__Url", "https://localhost:54321");

        _dbContainer = new PostgreSqlBuilder()
            .WithImage("postgres:15-alpine")
            .WithDatabase("haven_db")
            .WithUsername("postgres")
            .WithPassword("postgres")
            .Build();
    }

    public async Task InitializeAsync()
    {
        await _dbContainer.StartAsync();
    }

    public async Task DisposeAsync()
    {
        await _dbContainer.DisposeAsync();
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
    public async Task UpdateVivienda_AdminCondominioA_ViviendaCondominioB_ReturnsForbidden()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);
        var condominioAId = Guid.NewGuid();
        var condominioBId = Guid.NewGuid();
        var viviendaId = 100;

        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(adminId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioAId));

        mockSupabaseService.Setup(s => s.GetViviendaByIdAsync(viviendaId))
            .ReturnsAsync(new ViviendaDto { Id = viviendaId, CondominioId = condominioBId });

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new UpdateViviendaRequestDto { NumeroCasa = "123", Tipo = "Casa" };

        // Act
        var response = await client.PutAsJsonAsync($"/api/viviendas/{viviendaId}", requestBody);

        // Assert
        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.UpdateViviendaAsync(It.IsAny<int>(), It.IsAny<UpdateViviendaRequestDto>()), Times.Never);
    }

    [Fact]
    public async Task UpdateVivienda_AdminCondominioA_ViviendaCondominioA_ReturnsOk()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);
        var condominioAId = Guid.NewGuid();
        var viviendaId = 100;

        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(adminId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioAId));

        mockSupabaseService.Setup(s => s.GetViviendaByIdAsync(viviendaId))
            .ReturnsAsync(new ViviendaDto { Id = viviendaId, CondominioId = condominioAId });

        mockSupabaseService.Setup(s => s.UpdateViviendaAsync(viviendaId, It.IsAny<UpdateViviendaRequestDto>()))
            .ReturnsAsync((new ViviendaDto { Id = viviendaId, CondominioId = condominioAId }, null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new UpdateViviendaRequestDto { NumeroCasa = "123", Tipo = "Casa" };

        // Act
        var response = await client.PutAsJsonAsync($"/api/viviendas/{viviendaId}", requestBody);

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        mockSupabaseService.Verify(s => s.UpdateViviendaAsync(viviendaId, It.IsAny<UpdateViviendaRequestDto>()), Times.Once);
    }

    [Fact]
    public async Task UpdateVivienda_ViviendaNotFound_ReturnsNotFound()
    {
        // Arrange
        var adminId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);
        var condominioId = Guid.NewGuid();
        var viviendaId = 100;

        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(adminId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));

        mockSupabaseService.Setup(s => s.GetViviendaByIdAsync(viviendaId))
            .ReturnsAsync((ViviendaDto?)null);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new UpdateViviendaRequestDto { NumeroCasa = "123", Tipo = "Casa" };

        // Act
        var response = await client.PutAsJsonAsync($"/api/viviendas/{viviendaId}", requestBody);

        // Assert
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
        mockSupabaseService.Verify(s => s.UpdateViviendaAsync(It.IsAny<int>(), It.IsAny<UpdateViviendaRequestDto>()), Times.Never);
    }
}
