using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using Condominios.Api.DTOs;
using Condominios.Api.Services;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Testcontainers.PostgreSql;
using Xunit;

namespace Condominios.Api.Tests;

public class CondominiosCrudDevOnlyTests : IAsyncLifetime
{
    private readonly PostgreSqlContainer _dbContainer;
    private const string DevKey = "test-dev-key-123";

    public CondominiosCrudDevOnlyTests()
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
                        { "DevTools:ApiKey", DevKey }
                    });
                });
                builder.ConfigureServices(services =>
                {
                    var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseService));
                    if (descriptor != null) services.Remove(descriptor);
                    services.AddSingleton(mockSupabaseService.Object);
                });
            });
    }

    // ---------------------------------------------------------
    // POST /api/condominios (Create)
    // ---------------------------------------------------------

    [Fact]
    public async Task CreateCondominio_NoDevKey_ReturnsUnauthorized()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();

        var requestBody = new CreateCondominioRequestDto { Nombre = "Nuevo Condominio" };
        var response = await client.PostAsJsonAsync("/api/condominios", requestBody);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        mockSupabaseService.Verify(s => s.CrearCondominioAsync(It.IsAny<CreateCondominioRequestDto>()), Times.Never);
    }

    [Fact]
    public async Task CreateCondominio_WithDevKey_ReturnsCreated()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        var expectedCondominioId = Guid.NewGuid();
        
        mockSupabaseService.Setup(s => s.CrearCondominioAsync(It.IsAny<CreateCondominioRequestDto>()))
            .ReturnsAsync((new CondominioDto { Id = expectedCondominioId, Nombre = "Nuevo Condominio" }, null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("X-Dev-Key", DevKey);

        var requestBody = new CreateCondominioRequestDto { Nombre = "Nuevo Condominio" };
        var response = await client.PostAsJsonAsync("/api/condominios", requestBody);

        Assert.Equal(HttpStatusCode.Created, response.StatusCode);
        var content = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal(expectedCondominioId.ToString(), content.GetProperty("id").GetString());
    }

    // ---------------------------------------------------------
    // POST /api/condominios/{id}/baja (Desactivar)
    // ---------------------------------------------------------

    [Fact]
    public async Task BajaCondominio_NoDevKey_ReturnsUnauthorized()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        var id = Guid.NewGuid();

        var response = await client.PostAsync($"/api/condominios/{id}/baja", null);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        mockSupabaseService.Verify(s => s.DesactivarCondominioAsync(It.IsAny<Guid>()), Times.Never);
    }

    [Fact]
    public async Task BajaCondominio_WithDevKey_ReturnsNoContent()
    {
        var id = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.DesactivarCondominioAsync(id))
            .ReturnsAsync(true);

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("X-Dev-Key", DevKey);

        var response = await client.PostAsync($"/api/condominios/{id}/baja", null);

        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    // ---------------------------------------------------------
    // PATCH /api/condominios/{id} (Update)
    // ---------------------------------------------------------

    [Fact]
    public async Task UpdateCondominio_NoDevKey_ReturnsUnauthorized()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        var id = Guid.NewGuid();

        var requestBody = new UpdateCondominioRequestDto { Nombre = "Actualizado" };
        var response = await client.PatchAsJsonAsync($"/api/condominios/{id}", requestBody);

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        mockSupabaseService.Verify(s => s.ActualizarCondominioAsync(It.IsAny<Guid>(), It.IsAny<UpdateCondominioRequestDto>()), Times.Never);
    }

    [Fact]
    public async Task UpdateCondominio_WithDevKey_ReturnsOk()
    {
        var id = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.ActualizarCondominioAsync(id, It.IsAny<UpdateCondominioRequestDto>()))
            .ReturnsAsync((new CondominioDto { Id = id, Nombre = "Actualizado" }, null));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("X-Dev-Key", DevKey);

        var requestBody = new UpdateCondominioRequestDto { Nombre = "Actualizado" };
        var response = await client.PatchAsJsonAsync($"/api/condominios/{id}", requestBody);

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task UpdateCondominio_WithDevKey_NotFound_ReturnsNotFound()
    {
        var id = Guid.NewGuid();
        var mockSupabaseService = new Mock<ISupabaseService>();
        
        mockSupabaseService.Setup(s => s.ActualizarCondominioAsync(id, It.IsAny<UpdateCondominioRequestDto>()))
            .ReturnsAsync((null, "Condominio no encontrado"));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Add("X-Dev-Key", DevKey);

        var requestBody = new UpdateCondominioRequestDto { Nombre = "Actualizado" };
        var response = await client.PatchAsJsonAsync($"/api/condominios/{id}", requestBody);

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }
}
