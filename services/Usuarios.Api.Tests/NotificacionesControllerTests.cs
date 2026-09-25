using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Usuarios.Api.DTOs;
using Usuarios.Api.Services;
using Xunit;

namespace Usuarios.Api.Tests;

public class NotificacionesControllerTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;

    public NotificacionesControllerTests()
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
    public async Task GetNotificaciones_ValidToken_ReturnsOk()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var mockSupabaseService = new Mock<ISupabaseService>();
        
        var expectedList = new List<NotificacionDto>
        {
            new NotificacionDto { Id = Guid.NewGuid(), UsuarioId = userId, Titulo = "Test 1" },
            new NotificacionDto { Id = Guid.NewGuid(), UsuarioId = userId, Titulo = "Test 2" }
        };

        mockSupabaseService.Setup(s => s.GetNotificacionesAsync(userId, It.IsAny<string>()))
            .ReturnsAsync((expectedList, null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Act
        var response = await client.GetAsync("/api/notificaciones");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        Assert.Contains("Test 1", content);
        Assert.Contains("Test 2", content);
    }

    [Fact]
    public async Task GetContadorNoLeidas_ValidToken_ReturnsOkWithCount()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.GetContadorNoLeidasAsync(userId, It.IsAny<string>()))
            .ReturnsAsync((5, null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Act
        var response = await client.GetAsync("/api/notificaciones/contador-no-leidas");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        using var jsonDoc = JsonDocument.Parse(content);
        var root = jsonDoc.RootElement;
        Assert.Equal(5, root.GetProperty("count").GetInt32());
    }

    [Fact]
    public async Task MarcarComoLeida_Success_ReturnsNoContent()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var notificacionId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.MarcarNotificacionComoLeidaAsync(notificacionId, userId, It.IsAny<string>()))
            .ReturnsAsync((true, null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Act
        var request = new HttpRequestMessage(HttpMethod.Patch, $"/api/notificaciones/{notificacionId}/leer");
        var response = await client.SendAsync(request);

        // Assert
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task MarcarTodasComoLeidas_Success_ReturnsNoContent()
    {
        // Arrange
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.MarcarTodasComoLeidasAsync(userId, It.IsAny<string>()))
            .ReturnsAsync((true, null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        // Act
        var request = new HttpRequestMessage(HttpMethod.Post, "/api/notificaciones/marcar-todas");
        var response = await client.SendAsync(request);

        // Assert
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }
}
