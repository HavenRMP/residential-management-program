using System.IdentityModel.Tokens.Jwt;
using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Security.Claims;
using System.Text.Json;
using HavenApi.Shared.Pagination;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Visitas.Api.DTOs;
using Visitas.Api.Services;
using Xunit;

namespace Visitas.Api.Tests;

public class GetMisVisitasTests
{
    public GetMisVisitasTests()
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
    public async Task GetMisVisitas_SinToken_ReturnsUnauthorized()
    {
        var mockSupabaseService = new Mock<ISupabaseService>();
        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();

        var response = await client.GetAsync("/api/visitas/mis-visitas");

        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetMisVisitasAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<PaginationParams>()), Times.Never);
    }

    [Fact]
    public async Task GetMisVisitas_SinQueryParams_UsaPageUnoYPageSizeVeinte()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        var expectedVisitas = new List<VisitaDto>();
        PaginationParams capturedParams = null!;

        mockSupabaseService.Setup(s => s.GetMisVisitasAsync(token, null, It.IsAny<PaginationParams>()))
            .Callback<string, string?, PaginationParams>((t, e, p) => capturedParams = p)
            .ReturnsAsync((expectedVisitas, 0));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/visitas/mis-visitas");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        Assert.NotNull(capturedParams);
        Assert.Equal(1, capturedParams.Page);
        Assert.Equal(20, capturedParams.PageSize);
        
        var content = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.True(content.TryGetProperty("page", out var pageElement));
        Assert.Equal(1, pageElement.GetInt32());
        Assert.True(content.TryGetProperty("pageSize", out var pageSizeElement));
        Assert.Equal(20, pageSizeElement.GetInt32());
    }

    [Fact]
    public async Task GetMisVisitas_ConParamsPaginacion_LleganAlServicio()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        var expectedVisitas = new List<VisitaDto>();
        PaginationParams capturedParams = null!;

        mockSupabaseService.Setup(s => s.GetMisVisitasAsync(token, null, It.IsAny<PaginationParams>()))
            .Callback<string, string?, PaginationParams>((t, e, p) => capturedParams = p)
            .ReturnsAsync((expectedVisitas, 0));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/visitas/mis-visitas?page=3&pageSize=15");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        
        Assert.NotNull(capturedParams);
        Assert.Equal(3, capturedParams.Page);
        Assert.Equal(15, capturedParams.PageSize);
    }

    [Fact]
    public async Task GetMisVisitas_EstadoInvalido_ReturnsBadRequestSinLlamarAlServicio()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        
        var mockSupabaseService = new Mock<ISupabaseService>();

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/visitas/mis-visitas?estado=invalido");

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        mockSupabaseService.Verify(s => s.GetMisVisitasAsync(It.IsAny<string>(), It.IsAny<string>(), It.IsAny<PaginationParams>()), Times.Never);
    }

    [Fact]
    public async Task GetMisVisitas_EstadoValido_LlegaAlServicioYEstructuraCorrectaConCodigo()
    {
        var userId = Guid.NewGuid();
        var token = GenerateFakeToken(userId);
        
        var mockSupabaseService = new Mock<ISupabaseService>();
        var expectedVisitas = new List<VisitaDto>
        {
            new VisitaDto 
            { 
                Id = Guid.NewGuid(), 
                Codigo = "CODE123",
                Estado = "programada",
                ViviendaId = 1,
                NombreVisitante = "Juan",
                ApellidosVisitante = "Perez",
                Motivo = "personal"
            }
        };

        string capturedEstado = null!;

        mockSupabaseService.Setup(s => s.GetMisVisitasAsync(token, "programada", It.IsAny<PaginationParams>()))
            .Callback<string, string?, PaginationParams>((t, e, p) => capturedEstado = e)
            .ReturnsAsync((expectedVisitas, 1));

        await using var application = BuildApplication(mockSupabaseService);
        var client = application.CreateClient();
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);

        var response = await client.GetAsync("/api/visitas/mis-visitas?estado=programada");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        Assert.Equal("programada", capturedEstado);

        var content = await response.Content.ReadFromJsonAsync<JsonElement>();
        
        Assert.True(content.TryGetProperty("items", out var itemsElement));
        Assert.Equal(JsonValueKind.Array, itemsElement.ValueKind);
        Assert.Equal(1, itemsElement.GetArrayLength());
        
        var firstItem = itemsElement[0];
        Assert.True(firstItem.TryGetProperty("codigo", out var codigoElement));
        Assert.Equal("CODE123", codigoElement.GetString());
        
        Assert.True(content.TryGetProperty("page", out var pageElement));
        Assert.True(content.TryGetProperty("pageSize", out var pageSizeElement));
        Assert.True(content.TryGetProperty("totalCount", out var totalCountElement));
        
        Assert.Equal(1, totalCountElement.GetInt32());
    }
}
