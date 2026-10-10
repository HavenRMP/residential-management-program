using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Threading.Tasks;
using Xunit;

namespace Reservas.Api.Tests;

public class HealthControllerTests : IClassFixture<ReservasApiFactory>
{
    private readonly ReservasApiFactory _factory;

    public HealthControllerTests(ReservasApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task GetPublicHealth_ReturnsOk_AndServicioName()
    {
        var client = _factory.CreateClient();

        var response = await client.GetAsync("/api/health/public");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);

        var content = await response.Content.ReadFromJsonAsync<JsonElement>();
        Assert.Equal("ok", content.GetProperty("status").GetString());
        Assert.Equal("Reservas.Api", content.GetProperty("servicio").GetString());
    }
}
