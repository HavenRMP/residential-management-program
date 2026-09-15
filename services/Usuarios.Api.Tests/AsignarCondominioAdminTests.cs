using System.Net;
using System.Net.Http.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Usuarios.Api.DTOs;
using Usuarios.Api.Services;
using Xunit;

namespace Usuarios.Api.Tests;

public class AsignarCondominioAdminTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;
    private const string ApiKey = "fake-dev-key";

    public AsignarCondominioAdminTests()
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
                        { "DevTools:ApiKey", ApiKey }
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

    // 1. Sin header X-Dev-Key -> 401
    [Fact]
    public async Task AsignarCondominioAdmin_WithoutDevKey_ReturnsUnauthorized()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();

        var userId = Guid.NewGuid();
        var request = new { CondominioId = Guid.NewGuid() };

        var response = await client.PostAsJsonAsync($"/api/usuarios/{userId}/condominio", request);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        mockSupabaseService.Verify(s => s.AsignarCondominioAdminAsync(It.IsAny<Guid>(), It.IsAny<Guid>()), Times.Never);
    }

    // 2. Con header X-Dev-Key correcto, mock de AsignarCondominioAdminAsync retornando (null, "Usuario no encontrado") -> 404
    [Fact]
    public async Task AsignarCondominioAdmin_UserNotFound_ReturnsNotFound()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();

        mockSupabaseService.Setup(s => s.AsignarCondominioAdminAsync(userId, condominioId))
            .ReturnsAsync((null, "Usuario no encontrado"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("X-Dev-Key", ApiKey);

        var request = new { CondominioId = condominioId };

        var response = await client.PostAsJsonAsync($"/api/usuarios/{userId}/condominio", request);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    // 3. Con header X-Dev-Key correcto, mock retornando (null, "Ya existe un administrador asignado a este condominio") -> 409
    [Fact]
    public async Task AsignarCondominioAdmin_AdminExists_ReturnsConflict()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();

        mockSupabaseService.Setup(s => s.AsignarCondominioAdminAsync(userId, condominioId))
            .ReturnsAsync((null, "Ya existe un administrador asignado a este condominio"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("X-Dev-Key", ApiKey);

        var request = new { CondominioId = condominioId };

        var response = await client.PostAsJsonAsync($"/api/usuarios/{userId}/condominio", request);

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
    }

    // 4. Con header X-Dev-Key correcto, mock retornando (un UsuarioDto válido, null) -> 200 con el usuario en el body
    [Fact]
    public async Task AsignarCondominioAdmin_Success_ReturnsOk()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        var userId = Guid.NewGuid();
        var condominioId = Guid.NewGuid();

        var expectedUser = new UsuarioDto { Id = userId, CondominioId = condominioId };

        mockSupabaseService.Setup(s => s.AsignarCondominioAdminAsync(userId, condominioId))
            .ReturnsAsync((expectedUser, null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("X-Dev-Key", ApiKey);

        var request = new { CondominioId = condominioId };

        var response = await client.PostAsJsonAsync($"/api/usuarios/{userId}/condominio", request);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        var content = await response.Content.ReadFromJsonAsync<UsuarioDto>();
        Assert.NotNull(content);
        Assert.Equal(userId, content.Id);
        Assert.Equal(condominioId, content.CondominioId);
    }
}
