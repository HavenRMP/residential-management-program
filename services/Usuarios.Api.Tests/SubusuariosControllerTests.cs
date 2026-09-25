using System.Net;
using System.Net.Http.Json;
using Microsoft.Extensions.Configuration;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Usuarios.Api.DTOs;
using Usuarios.Api.Services;
using Xunit;

namespace Usuarios.Api.Tests;

public class SubusuariosControllerTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;
    private readonly Guid _userId = Guid.NewGuid();
    private readonly int _viviendaId = 100;

    public SubusuariosControllerTests()
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
                        { "Supabase:Url", "http://localhost:54321" },
                        { "Supabase:AnonKey", "fake-anon-key" },
                        { "Supabase:ServiceRoleKey", "fake-service-key" }
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

    // Helper fake token since ValidateIssuerSigningKey = false and RequireSignedTokens = false
    private string GenerateFakeToken()
    {
        // A minimal fake JWT format: header.payload.signature
        // Payload has sub = _userId
        var header = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes("{\"alg\":\"none\"}")).TrimEnd('=');
        var payload = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes($"{{\"sub\":\"{_userId}\"}}")).TrimEnd('=');
        return $"{header}.{payload}.";
    }

    [Fact]
    public async Task GetMisSubusuarios_ReturnsList_WhenValid()
    {
        // Arrange
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.GetSubusuariosActivosAsync(_viviendaId, It.IsAny<string>()))
            .ReturnsAsync(new List<VwViviendaSubusuarioDto>
            {
                new VwViviendaSubusuarioDto { UsuarioId = Guid.NewGuid(), UsuarioNombre = "Juan", Parentesco = "Hijo", Activo = true }
            });
        
        mockSupabaseService.Setup(s => s.GetInvitacionesSubusuarioAsync(_viviendaId, It.IsAny<string>()))
            .ReturnsAsync(new List<VwCodigoSubusuarioDto>
            {
                new VwCodigoSubusuarioDto { Id = Guid.NewGuid(), Codigo = "XYZ123", Parentesco = "Esposa", EsVigente = true }
            });

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", GenerateFakeToken());

        // Act
        var response = await client.GetAsync($"/api/Subusuarios/mis-subusuarios?viviendaId={_viviendaId}");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var result = await response.Content.ReadFromJsonAsync<List<SubusuarioItemDto>>();
        Assert.NotNull(result);
        Assert.Equal(2, result.Count);
        Assert.Contains(result, r => r.Nombre == "Juan");
        Assert.Contains(result, r => r.Codigo == "XYZ123");
    }

    [Fact]
    public async Task InvitarSubusuario_ReturnsCreated_WhenValid()
    {
        // Arrange
        var requestDto = new InvitarSubusuarioRequestDto
        {
            ViviendaId = _viviendaId,
            Nombre = "Maria",
            Apellidos = "Lopez",
            Email = "maria@example.com",
            Telefono = "5551234",
            Parentesco = "Hermana"
        };

        var newCode = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.InvitarSubusuarioAsync(_viviendaId, "Hermana", _userId, It.IsAny<string>()))
            .ReturnsAsync((new VwCodigoSubusuarioDto { Id = newCode, Codigo = "ABC999", Parentesco = "Hermana" }, null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", GenerateFakeToken());

        // Act
        var response = await client.PostAsJsonAsync("/api/Subusuarios/invitar", requestDto);

        // Assert
        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var result = await response.Content.ReadFromJsonAsync<SubusuarioItemDto>();
        Assert.NotNull(result);
        Assert.Equal(newCode, result.Id);
        Assert.Equal("ABC999", result.Codigo);
        Assert.Equal("Maria", result.Nombre);
    }
    
    [Fact]
    public async Task InvitarSubusuario_ReturnsConflict_WhenLimitReached()
    {
        // Arrange
        var requestDto = new InvitarSubusuarioRequestDto
        {
            ViviendaId = _viviendaId,
            Nombre = "Maria",
            Apellidos = "Lopez",
            Email = "maria@example.com",
            Telefono = "5551234",
            Parentesco = "Hermana"
        };

        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.InvitarSubusuarioAsync(_viviendaId, "Hermana", _userId, It.IsAny<string>()))
            .ReturnsAsync((null, "Límite máximo de 2 sub-usuarios alcanzado en la vivienda."));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", GenerateFakeToken());

        // Act
        var response = await client.PostAsJsonAsync("/api/Subusuarios/invitar", requestDto);

        // Assert
        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    [Fact]
    public async Task RevocarSubusuario_ReturnsNoContent_WhenValidActiveUser()
    {
        // Arrange
        var subusuarioId = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        mockSupabaseService.Setup(s => s.RevocarSubusuarioAsync(_viviendaId, subusuarioId, It.IsAny<string>()))
            .ReturnsAsync(true);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", GenerateFakeToken());

        // Act
        var response = await client.DeleteAsync($"/api/Subusuarios/{subusuarioId}?viviendaId={_viviendaId}");

        // Assert
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }
}
