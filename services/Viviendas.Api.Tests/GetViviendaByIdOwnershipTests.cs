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

public class GetViviendaByIdOwnershipTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public GetViviendaByIdOwnershipTests()
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

    [Fact]
    public async Task GetViviendaById_MismatchCondominio_ReturnsNotFoundNotForbidden()
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

        var response = await client.GetAsync($"/api/viviendas/{viviendaId}");

        // El bug potencial a evitar es que regrese 403. Al tratarse de GET,
        // ocultamos la existencia del registro devolviendo 404 si es de otro condominio.
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetViviendaById_MatchCondominio_ReturnsOkWithData()
    {
        var adminId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);
        var condominioId = Guid.NewGuid();
        var viviendaId = 100;
        var nombreCondominio = "Condominio Las Rosas";

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(adminId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));
        
        mockSupabaseService.Setup(s => s.GetViviendaByIdAsync(viviendaId))
            .ReturnsAsync(new ViviendaDto { 
                Id = viviendaId, 
                CondominioId = condominioId,
                CondominioNombre = nombreCondominio,
                NumeroCasa = "45B"
            });

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/viviendas/{viviendaId}");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadFromJsonAsync<JsonElement>();
        
        Assert.Equal(viviendaId, content.GetProperty("id").GetInt32());
        Assert.Equal(condominioId.ToString(), content.GetProperty("condominioId").GetString());
        Assert.Equal(nombreCondominio, content.GetProperty("condominioNombre").GetString());
        Assert.Equal("45B", content.GetProperty("numeroCasa").GetString());
    }

    [Fact]
    public async Task GetViviendaById_ViviendaNoExiste_ReturnsNotFound()
    {
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

        var response = await client.GetAsync($"/api/viviendas/{viviendaId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task GetViviendaById_UserWithoutCondominioId_ReturnsNotFound()
    {
        var adminId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);
        var viviendaId = 100;

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(adminId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", (Guid?)null));
        
        // No importa si la vivienda existe o no, si el admin no tiene condominio
        // debe regresar 404 (u oculta la informacion)
        mockSupabaseService.Setup(s => s.GetViviendaByIdAsync(viviendaId))
            .ReturnsAsync(new ViviendaDto { Id = viviendaId, CondominioId = Guid.NewGuid() });

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync($"/api/viviendas/{viviendaId}");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
