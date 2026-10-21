using Microsoft.Extensions.Logging;
using Moq;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Enums;
using Pagos.Api.Models;
using Pagos.Api.Services;
using Xunit;

namespace Pagos.Api.Tests;

public class CargosServiceTests
{
    private readonly Mock<ISupabaseRestClient> _mockClient;
    private readonly Mock<IUserContextService> _mockUserContext;
    private readonly Mock<IViviendasLookupService> _mockViviendasLookup;
    private readonly Mock<ILogger<CargosService>> _mockLogger;
    private readonly CargosService _service;

    private readonly Guid _condominioId = Guid.NewGuid();
    private readonly Guid _userId = Guid.NewGuid();

    public CargosServiceTests()
    {
        _mockClient = new Mock<ISupabaseRestClient>();
        _mockUserContext = new Mock<IUserContextService>();
        _mockViviendasLookup = new Mock<IViviendasLookupService>();
        _mockLogger = new Mock<ILogger<CargosService>>();

        _mockUserContext.Setup(u => u.CondominioId).Returns(_condominioId);
        _mockUserContext.Setup(u => u.UserId).Returns(_userId);
        _mockUserContext.Setup(u => u.EsAdmin).Returns(true);

        _service = new CargosService(
            _mockClient.Object,
            _mockUserContext.Object,
            _mockViviendasLookup.Object,
            _mockLogger.Object);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-1)]
    public async Task CrearCargo_ViviendaIdInvalida_LanzaArgumentException(int viviendaId)
    {
        var req = new CrearCargoRequest
        {
            ViviendaId = viviendaId,
            Monto = 100m,
            Concepto = "Cuota",
            Tipo = TipoCargo.Otro,
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };

        var ex = await Assert.ThrowsAsync<ArgumentException>(() => _service.CrearCargoAsync(req));
        Assert.Contains("vivienda", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData(0)]
    [InlineData(-50)]
    public async Task CrearCargo_MontoMenorOIgualAZero_LanzaArgumentException(decimal monto)
    {
        var req = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = monto,
            Concepto = "Cuota",
            Tipo = TipoCargo.Otro,
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };

        var ex = await Assert.ThrowsAsync<ArgumentException>(() => _service.CrearCargoAsync(req));
        Assert.Contains("monto", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task CrearCargo_MontoConMasDeDosDecimales_LanzaArgumentException()
    {
        var req = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = 125.456m,
            Concepto = "Cuota",
            Tipo = TipoCargo.Otro,
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };

        var ex = await Assert.ThrowsAsync<ArgumentException>(() => _service.CrearCargoAsync(req));
        Assert.Contains("decimales", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData(null)]
    [InlineData("")]
    [InlineData("   ")]
    public async Task CrearCargo_ConceptoVacio_LanzaArgumentException(string? concepto)
    {
        var req = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = 100m,
            Concepto = concepto!,
            Tipo = TipoCargo.Otro,
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };

        var ex = await Assert.ThrowsAsync<ArgumentException>(() => _service.CrearCargoAsync(req));
        Assert.Contains("concepto", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task CrearCargo_ConceptoExcede200Caracteres_LanzaArgumentException()
    {
        var req = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = 100m,
            Concepto = new string('x', 201),
            Tipo = TipoCargo.Otro,
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };

        var ex = await Assert.ThrowsAsync<ArgumentException>(() => _service.CrearCargoAsync(req));
        Assert.Contains("200", ex.Message);
    }

    [Fact]
    public async Task CrearCargo_TipoInvalido_LanzaArgumentException()
    {
        var req = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = 100m,
            Concepto = "Cuota",
            Tipo = (TipoCargo)999,
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };

        var ex = await Assert.ThrowsAsync<ArgumentException>(() => _service.CrearCargoAsync(req));
        Assert.Contains("tipo", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task CrearCargo_FechaVencimientoDefault_LanzaArgumentException()
    {
        var req = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = 100m,
            Concepto = "Cuota",
            Tipo = TipoCargo.Otro,
            FechaVencimiento = default
        };

        var ex = await Assert.ThrowsAsync<ArgumentException>(() => _service.CrearCargoAsync(req));
        Assert.Contains("vencimiento", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Theory]
    [InlineData(TipoCargo.Renta)]
    [InlineData(TipoCargo.Mantenimiento)]
    public async Task CrearCargo_RentaOMantenimientoSinPeriodo_LanzaArgumentException(TipoCargo tipo)
    {
        var req = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = 100m,
            Concepto = "Cuota",
            Tipo = tipo,
            Periodo = null,
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };

        var ex = await Assert.ThrowsAsync<ArgumentException>(() => _service.CrearCargoAsync(req));
        Assert.Contains("periodo", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task CrearCargo_PeriodoInvalido_LanzaArgumentException()
    {
        var req = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = 100m,
            Concepto = "Cuota",
            Tipo = TipoCargo.Mantenimiento,
            Periodo = "2026-13",
            FechaVencimiento = new DateOnly(2026, 12, 1)
        };

        var ex = await Assert.ThrowsAsync<ArgumentException>(() => _service.CrearCargoAsync(req));
        Assert.Contains("periodo", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task CrearCargo_ResponsablePagoInvalido_LanzaArgumentException()
    {
        var req = new CrearCargoRequest
        {
            ViviendaId = 1,
            Monto = 100m,
            Concepto = "Cuota",
            Tipo = TipoCargo.Servicio,
            Periodo = null,
            FechaVencimiento = new DateOnly(2026, 12, 1),
            ResponsablePago = (ResponsablePago)999
        };

        var ex = await Assert.ThrowsAsync<ArgumentException>(() => _service.CrearCargoAsync(req));
        Assert.Contains("responsable", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task CrearCargo_ViviendaNoPerteneceACondominio_LanzaKeyNotFoundException()
    {
        var req = new CrearCargoRequest
        {
            ViviendaId = 42,
            Monto = 1000m,
            Concepto = "Mantenimiento",
            Tipo = TipoCargo.Mantenimiento,
            Periodo = "2026-10",
            FechaVencimiento = new DateOnly(2026, 10, 15)
        };

        _mockViviendasLookup
            .Setup(v => v.ExisteViviendaEnCondominioAsync(42, _condominioId))
            .ReturnsAsync(false);

        var ex = await Assert.ThrowsAsync<KeyNotFoundException>(() => _service.CrearCargoAsync(req));
        Assert.Equal("Vivienda no encontrada.", ex.Message);

        _mockClient.Verify(c => c.InsertSingleAsync<It.IsAnyType>(It.IsAny<string>(), It.IsAny<object>(), It.IsAny<Guid?>()), Times.Never);
    }

    [Fact]
    public async Task CrearCargo_Exito_InsertaYReleeDeVistaCorrectamente()
    {
        // Arrange
        var req = new CrearCargoRequest
        {
            ViviendaId = 10,
            Monto = 2500.50m,
            Concepto = "  Cuota de Mantenimiento Octubre  ",
            Tipo = TipoCargo.Mantenimiento,
            Periodo = "2026-10",
            FechaVencimiento = new DateOnly(2026, 10, 20),
            ResponsablePago = ResponsablePago.Propietario
        };

        _mockViviendasLookup
            .Setup(v => v.ExisteViviendaEnCondominioAsync(10, _condominioId))
            .ReturnsAsync(true);

        var cargoId = Guid.NewGuid();

        _mockClient
            .Setup(c => c.InsertSingleAsync<CargoIdResult>("cargos", It.IsAny<CargoInsert>(), _userId))
            .Callback<string, object, Guid?>((_, data, _) =>
            {
                var insert = (CargoInsert)data;
                Assert.Equal(_condominioId, insert.CondominioId);
                Assert.Equal(10, insert.ViviendaId);
                Assert.Null(insert.PlantillaId);
                Assert.Equal(TipoCargo.Mantenimiento, insert.Tipo);
                Assert.Equal("Cuota de Mantenimiento Octubre", insert.Concepto);
                Assert.Equal(2500.50m, insert.Monto);
                Assert.Equal(new DateOnly(2026, 10, 1), insert.Periodo);
                Assert.Equal(new DateOnly(2026, 10, 20), insert.FechaVencimiento);
                Assert.Equal(ResponsablePago.Propietario, insert.ResponsablePago);
                Assert.Equal(_userId, insert.CreadoPor);
            })
            .ReturnsAsync(new CargoIdResult { Id = cargoId });

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = _condominioId,
            CondominioNombre = "Residencial Haven",
            ViviendaId = 10,
            NumeroCasa = "Casa 10-A",
            PlantillaId = null,
            Periodo = new DateOnly(2026, 10, 1),
            Tipo = TipoCargo.Mantenimiento,
            Concepto = "Cuota de Mantenimiento Octubre",
            Monto = 2500.50m,
            MontoPagadoConfirmado = 0m,
            SaldoPendiente = 2500.50m,
            Estado = EstadoCargo.Pendiente,
            FechaVencimiento = new DateOnly(2026, 10, 20),
            EstaVencido = false,
            ResponsablePago = ResponsablePago.Propietario,
            CreadoPor = _userId,
            CreadoEn = DateTimeOffset.UtcNow
        };

        _mockClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        // Act
        var result = await _service.CrearCargoAsync(req);

        // Assert
        Assert.NotNull(result);
        Assert.Equal(cargoId, result.Id);
        Assert.Equal(_condominioId, result.CondominioId);
        Assert.Equal(10, result.ViviendaId);
        Assert.Equal("Casa 10-A", result.NumeroCasa);
        Assert.Equal("2026-10", result.Periodo);
        Assert.Equal(TipoCargo.Mantenimiento, result.Tipo);
        Assert.Equal("Cuota de Mantenimiento Octubre", result.Concepto);
        Assert.Equal(2500.50m, result.Monto);
        Assert.Equal(0m, result.MontoPagadoConfirmado);
        Assert.Equal(2500.50m, result.SaldoPendiente);
        Assert.Equal(EstadoCargo.Pendiente, result.Estado);
        Assert.Equal("Pendiente", result.EstadoEfectivo);
        Assert.Equal(ResponsablePago.Propietario, result.ResponsablePago);
    }
}
