using Moq;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Services;
using Xunit;

namespace Pagos.Api.Tests;

public class ViviendasLookupServiceTests
{
    private readonly Mock<ISupabaseRestClient> _mockRestClient;
    private readonly ViviendasLookupService _service;

    public ViviendasLookupServiceTests()
    {
        _mockRestClient = new Mock<ISupabaseRestClient>();
        _service = new ViviendasLookupService(_mockRestClient.Object);
    }

    [Fact]
    public async Task GetViviendaIdsPorUsuarioTitularAsync_CuandoTieneViviendas_RetornaListaDeIds()
    {
        // Arrange
        var usuarioId = Guid.NewGuid();
        var queryEsperada = $"usuario_id=eq.{usuarioId}&select=vivienda_id";

        var listaSimulada = new List<ViviendaResidenteItemDto>
        {
            new() { ViviendaId = 10 },
            new() { ViviendaId = 20 }
        };

        _mockRestClient
            .Setup(c => c.GetAsync<ViviendaResidenteItemDto>("vw_vivienda_usuarios", queryEsperada))
            .ReturnsAsync(listaSimulada);

        // Act
        var result = await _service.GetViviendaIdsPorUsuarioTitularAsync(usuarioId);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(2, result.Count);
        Assert.Contains(10, result);
        Assert.Contains(20, result);
    }

    [Fact]
    public async Task GetViviendaIdsPorUsuarioTitularAsync_CuandoNoTieneViviendas_RetornaListaVacia()
    {
        // Arrange
        var usuarioId = Guid.NewGuid();
        var queryEsperada = $"usuario_id=eq.{usuarioId}&select=vivienda_id";

        _mockRestClient
            .Setup(c => c.GetAsync<ViviendaResidenteItemDto>("vw_vivienda_usuarios", queryEsperada))
            .ReturnsAsync(new List<ViviendaResidenteItemDto>());

        // Act
        var result = await _service.GetViviendaIdsPorUsuarioTitularAsync(usuarioId);

        // Assert
        Assert.NotNull(result);
        Assert.Empty(result);
    }

    [Fact]
    public async Task ExisteViviendaEnCondominioAsync_CuandoExiste_RetornaTrue()
    {
        // Arrange
        var viviendaId = 15;
        var condominioId = Guid.NewGuid();
        var queryEsperada = $"id=eq.{viviendaId}&condominio_id=eq.{condominioId}&select=id";

        _mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>("vw_viviendas", queryEsperada))
            .ReturnsAsync(new ViviendaItemDto { Id = viviendaId });

        // Act
        var existe = await _service.ExisteViviendaEnCondominioAsync(viviendaId, condominioId);

        // Assert
        Assert.True(existe);
    }

    [Fact]
    public async Task ExisteViviendaEnCondominioAsync_CuandoNoExiste_RetornaFalse()
    {
        // Arrange
        var viviendaId = 99;
        var condominioId = Guid.NewGuid();
        var queryEsperada = $"id=eq.{viviendaId}&condominio_id=eq.{condominioId}&select=id";

        _mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaItemDto>("vw_viviendas", queryEsperada))
            .ReturnsAsync((ViviendaItemDto?)null);

        // Act
        var existe = await _service.ExisteViviendaEnCondominioAsync(viviendaId, condominioId);

        // Assert
        Assert.False(existe);
    }

    [Fact]
    public async Task EsResidenteTitularAsync_CuandoEsTitular_RetornaTrue()
    {
        // Arrange
        var viviendaId = 10;
        var usuarioId = Guid.NewGuid();
        var queryEsperada = $"vivienda_id=eq.{viviendaId}&usuario_id=eq.{usuarioId}&select=vivienda_id";

        _mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaResidenteItemDto>("vw_vivienda_usuarios", queryEsperada))
            .ReturnsAsync(new ViviendaResidenteItemDto { ViviendaId = viviendaId });

        // Act
        var esTitular = await _service.EsResidenteTitularAsync(viviendaId, usuarioId);

        // Assert
        Assert.True(esTitular);
    }

    [Fact]
    public async Task EsResidenteTitularAsync_CuandoNoEsTitular_RetornaFalse()
    {
        // Arrange
        var viviendaId = 10;
        var usuarioId = Guid.NewGuid();
        var queryEsperada = $"vivienda_id=eq.{viviendaId}&usuario_id=eq.{usuarioId}&select=vivienda_id";

        _mockRestClient
            .Setup(c => c.GetSingleOrDefaultAsync<ViviendaResidenteItemDto>("vw_vivienda_usuarios", queryEsperada))
            .ReturnsAsync((ViviendaResidenteItemDto?)null);

        // Act
        var esTitular = await _service.EsResidenteTitularAsync(viviendaId, usuarioId);

        // Assert
        Assert.False(esTitular);
    }
}
