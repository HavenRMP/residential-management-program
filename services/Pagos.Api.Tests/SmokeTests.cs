using System.Net;
using System.Text.Json;
using Xunit;

namespace Pagos.Api.Tests;

public class SmokeTests : IClassFixture<PagosApiFactory>
{
    private readonly PagosApiFactory _factory;

    public SmokeTests(PagosApiFactory factory)
    {
        _factory = factory;
    }

    [Fact]
    public async Task GetPublicHealth_RetornaOkConServicioPagosApi()
    {
        // Arrange
        var client = _factory.CreateClient();

        // Act
        var response = await client.GetAsync("/api/health/public");

        // Assert
        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
        var content = await response.Content.ReadAsStringAsync();
        using var doc = JsonDocument.Parse(content);
        Assert.Equal("ok", doc.RootElement.GetProperty("status").GetString());
        Assert.Equal("Pagos.Api", doc.RootElement.GetProperty("servicio").GetString());
    }
}
