using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Viviendas.Api.DTOs;
using Viviendas.Api.Services;
using Xunit;

namespace Viviendas.Api.Tests;

public class ResidentesOwnershipTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public ResidentesOwnershipTests()
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
        var handler = new JwtSecurityTokenHandler();
        var token = new JwtSecurityToken(claims: new[]
        {
            new Claim(ClaimTypes.NameIdentifier, userId.ToString()),
            new Claim("sub", userId.ToString())
        });
        return handler.WriteToken(token);
    }

    // ---------------------------------------------------------
    // AssignResidente: POST /api/viviendas/{id}/residentes
    // ---------------------------------------------------------

    [Fact]
    public async Task AssignResidente_Mismatch_ReturnsForbidden()
    {
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

        var requestBody = new AsignarResidenteRequestDto { UsuarioId = Guid.NewGuid() };
        var response = await client.PostAsJsonAsync($"/api/viviendas/{viviendaId}/residentes", requestBody);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.AssignResidenteAsync(It.IsAny<int>(), It.IsAny<AsignarResidenteRequestDto>()), Times.Never);
    }

    [Fact]
    public async Task AssignResidente_Match_ReturnsCreated()
    {
        var adminId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);
        var condominioAId = Guid.NewGuid();
        var viviendaId = 100;

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(adminId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioAId));
        mockSupabaseService.Setup(s => s.GetViviendaByIdAsync(viviendaId))
            .ReturnsAsync(new ViviendaDto { Id = viviendaId, CondominioId = condominioAId });
        
        var dummyData = JsonDocument.Parse("{\"success\":true}").RootElement;
        mockSupabaseService.Setup(s => s.AssignResidenteAsync(viviendaId, It.IsAny<AsignarResidenteRequestDto>()))
            .ReturnsAsync((dummyData, null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new AsignarResidenteRequestDto { UsuarioId = Guid.NewGuid() };
        var response = await client.PostAsJsonAsync($"/api/viviendas/{viviendaId}/residentes", requestBody);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        mockSupabaseService.Verify(s => s.AssignResidenteAsync(viviendaId, It.IsAny<AsignarResidenteRequestDto>()), Times.Once);
    }

    // ---------------------------------------------------------
    // RemoveResidente: DELETE /api/viviendas/{id}/residentes/{usuarioId}
    // ---------------------------------------------------------

    [Fact]
    public async Task RemoveResidente_Mismatch_ReturnsForbidden()
    {
        var adminId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);
        var condominioAId = Guid.NewGuid();
        var condominioBId = Guid.NewGuid();
        var viviendaId = 100;
        var usuarioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(adminId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioAId));
        mockSupabaseService.Setup(s => s.GetViviendaByIdAsync(viviendaId))
            .ReturnsAsync(new ViviendaDto { Id = viviendaId, CondominioId = condominioBId });

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.DeleteAsync($"/api/viviendas/{viviendaId}/residentes/{usuarioId}");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.RemoveResidenteAsync(It.IsAny<int>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task RemoveResidente_Match_ReturnsNoContent()
    {
        var adminId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);
        var condominioAId = Guid.NewGuid();
        var viviendaId = 100;
        var usuarioId = Guid.NewGuid();

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(adminId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioAId));
        mockSupabaseService.Setup(s => s.GetViviendaByIdAsync(viviendaId))
            .ReturnsAsync(new ViviendaDto { Id = viviendaId, CondominioId = condominioAId });
        
        mockSupabaseService.Setup(s => s.RemoveResidenteAsync(viviendaId, usuarioId))
            .ReturnsAsync(true);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.DeleteAsync($"/api/viviendas/{viviendaId}/residentes/{usuarioId}");

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
        mockSupabaseService.Verify(s => s.RemoveResidenteAsync(viviendaId, usuarioId), Times.Once);
    }

    // ---------------------------------------------------------
    // GetResidentes: GET /api/viviendas/{id}/residentes
    // ---------------------------------------------------------

    [Fact]
    public async Task GetResidentes_Mismatch_ReturnsForbidden()
    {
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

        var response = await client.GetAsync($"/api/viviendas/{viviendaId}/residentes");

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetResidentesByViviendaIdAsync(It.IsAny<int>()), Times.Never);
    }

    [Fact]
    public async Task GetResidentes_Match_ReturnsOk()
    {
        var adminId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);
        var condominioAId = Guid.NewGuid();
        var viviendaId = 100;

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(adminId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioAId));
        mockSupabaseService.Setup(s => s.GetViviendaByIdAsync(viviendaId))
            .ReturnsAsync(new ViviendaDto { Id = viviendaId, CondominioId = condominioAId });
        
        var dummyData = JsonDocument.Parse("[]").RootElement;
        mockSupabaseService.Setup(s => s.GetResidentesByViviendaIdAsync(viviendaId))
            .ReturnsAsync(dummyData);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/viviendas/{viviendaId}/residentes");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetResidentesByViviendaIdAsync(viviendaId), Times.Once);
    }
}
