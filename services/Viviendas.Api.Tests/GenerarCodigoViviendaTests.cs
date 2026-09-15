using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using HavenApi.Shared.Exceptions;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Viviendas.Api.DTOs;
using Viviendas.Api.Services;
using Xunit;

namespace Viviendas.Api.Tests;

public class GenerarCodigoViviendaTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public GenerarCodigoViviendaTests()
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
    public async Task GenerarCodigo_MismatchCondominio_ReturnsForbidden()
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

        var requestBody = new GenerarCodigoRequestDto { MinutosVigencia = 60 };
        var response = await client.PostAsJsonAsync($"/api/viviendas/{viviendaId}/codigo", requestBody);

        Assert.Equal(HttpStatusCode.Forbidden, response.StatusCode);
        mockSupabaseService.Verify(s => s.GenerarCodigoViviendaAsync(It.IsAny<int>(), It.IsAny<int?>(), It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task GenerarCodigo_MatchCondominio_ReturnsOkWithCodigo()
    {
        var adminId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);
        var condominioId = Guid.NewGuid();
        var viviendaId = 100;

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(adminId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));
        
        mockSupabaseService.Setup(s => s.GetViviendaByIdAsync(viviendaId))
            .ReturnsAsync(new ViviendaDto { Id = viviendaId, CondominioId = condominioId });

        var expectedResult = new CodigoViviendaDto
        {
            Codigo = "ABCDEF",
            ExpiraEn = DateTime.UtcNow.AddMinutes(60)
        };

        mockSupabaseService.Setup(s => s.GenerarCodigoViviendaAsync(viviendaId, 60, adminId))
            .ReturnsAsync(expectedResult);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new GenerarCodigoRequestDto { MinutosVigencia = 60 };
        var response = await client.PostAsJsonAsync($"/api/viviendas/{viviendaId}/codigo", requestBody);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        var content = await response.Content.ReadFromJsonAsync<CodigoViviendaDto>();
        Assert.NotNull(content);
        Assert.Equal("ABCDEF", content.Codigo);
    }

    [Fact]
    public async Task GenerarCodigo_RpcExceptionThrown_MapsToCorrectStatusCode()
    {
        var adminId = Guid.NewGuid();
        var token = GenerateFakeToken(adminId);
        var condominioId = Guid.NewGuid();
        var viviendaId = 100;

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetContextoAdminAsync(adminId, It.IsAny<string>()))
            .ReturnsAsync(("Administrador", condominioId));
        
        mockSupabaseService.Setup(s => s.GetViviendaByIdAsync(viviendaId))
            .ReturnsAsync(new ViviendaDto { Id = viviendaId, CondominioId = condominioId });

        // Simulamos un error de RPC (Ej. CD002 -> 409 Conflict)
        mockSupabaseService.Setup(s => s.GenerarCodigoViviendaAsync(viviendaId, 60, adminId))
            .ThrowsAsync(new SupabaseRpcException("CD002", "Ya existe un código activo"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var requestBody = new GenerarCodigoRequestDto { MinutosVigencia = 60 };
        var response = await client.PostAsJsonAsync($"/api/viviendas/{viviendaId}/codigo", requestBody);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }
}
