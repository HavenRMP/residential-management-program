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

    [Fact]
    public async Task ListarCargos_FechasVencimientoInvalidas_LanzaArgumentException()
    {
        var filtros = new ConsultaCargosFiltrosDto
        {
            VencimientoDesde = new DateOnly(2026, 12, 1),
            VencimientoHasta = new DateOnly(2026, 11, 1)
        };

        var ex = await Assert.ThrowsAsync<ArgumentException>(() => _service.ListarCargosAsync(filtros));
        Assert.Contains("vencimiento", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ListarCargos_PeriodoInvalido_LanzaArgumentException()
    {
        var filtros = new ConsultaCargosFiltrosDto
        {
            Periodo = "año-invalido"
        };

        var ex = await Assert.ThrowsAsync<ArgumentException>(() => _service.ListarCargosAsync(filtros));
        Assert.Contains("periodo", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ListarCargos_Admin_ConUsuarioSinViviendas_RetornaPaginaVaciaSinConsultarPostgrest()
    {
        var usuarioFiltro = Guid.NewGuid();
        var filtros = new ConsultaCargosFiltrosDto
        {
            UsuarioId = usuarioFiltro
        };

        _mockViviendasLookup
            .Setup(v => v.GetViviendaIdsPorUsuarioTitularAsync(usuarioFiltro))
            .ReturnsAsync(new List<int>());

        var resultado = await _service.ListarCargosAsync(filtros);

        Assert.NotNull(resultado);
        Assert.Empty(resultado.Items);
        Assert.Equal(0, resultado.Total);
        _mockClient.Verify(c => c.GetPagedAsync<VwCargo>(It.IsAny<string>(), It.IsAny<HavenApi.Shared.Pagination.PaginationParams>(), It.IsAny<string?>()), Times.Never);
    }

    [Fact]
    public async Task ListarCargos_Admin_ConFiltrosCompletos_ConstruyeQueryCorrecta()
    {
        var usuarioFiltro = Guid.NewGuid();
        var filtros = new ConsultaCargosFiltrosDto
        {
            UsuarioId = usuarioFiltro,
            Tipo = TipoCargo.Mantenimiento,
            Estado = EstadoCargo.Pendiente,
            Vencido = true,
            Periodo = "2026-10",
            VencimientoDesde = new DateOnly(2026, 10, 1),
            VencimientoHasta = new DateOnly(2026, 10, 31)
        };

        _mockViviendasLookup
            .Setup(v => v.GetViviendaIdsPorUsuarioTitularAsync(usuarioFiltro))
            .ReturnsAsync(new List<int> { 101, 102 });

        string? capturedQuery = null;
        _mockClient
            .Setup(c => c.GetPagedAsync<VwCargo>("vw_cargos", It.IsAny<HavenApi.Shared.Pagination.PaginationParams>(), It.IsAny<string?>()))
            .Callback<string, HavenApi.Shared.Pagination.PaginationParams, string?>((_, _, q) => capturedQuery = q)
            .ReturnsAsync((new List<VwCargo>(), 0));

        var resultado = await _service.ListarCargosAsync(filtros);

        Assert.NotNull(capturedQuery);
        Assert.Contains($"condominio_id=eq.{_condominioId}", capturedQuery);
        Assert.Contains("vivienda_id=in.(101,102)", capturedQuery);
        Assert.Contains("tipo=eq.Mantenimiento", capturedQuery);
        Assert.Contains("estado=eq.Pendiente", capturedQuery);
        Assert.Contains("esta_vencido=eq.true", capturedQuery);
        Assert.Contains("periodo=eq.2026-10-01", capturedQuery);
        Assert.Contains("fecha_vencimiento=gte.2026-10-01", capturedQuery);
        Assert.Contains("fecha_vencimiento=lte.2026-10-31", capturedQuery);
        Assert.Contains("order=fecha_vencimiento.desc,id.desc", capturedQuery);
    }

    [Fact]
    public async Task ListarCargos_Inquilino_ConUsuarioIdAjeno_LanzaUnauthorizedAccessException()
    {
        _mockUserContext.Setup(u => u.EsAdmin).Returns(false);
        var ajenoId = Guid.NewGuid();

        var filtros = new ConsultaCargosFiltrosDto
        {
            UsuarioId = ajenoId
        };

        var ex = await Assert.ThrowsAsync<UnauthorizedAccessException>(() => _service.ListarCargosAsync(filtros));
        Assert.Contains("inquilinos", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ListarCargos_Inquilino_ConViviendaAjena_LanzaUnauthorizedAccessException()
    {
        _mockUserContext.Setup(u => u.EsAdmin).Returns(false);

        _mockViviendasLookup
            .Setup(v => v.GetViviendaIdsPorUsuarioTitularAsync(_userId))
            .ReturnsAsync(new List<int> { 50, 51 });

        var filtros = new ConsultaCargosFiltrosDto
        {
            ViviendaId = 99 // No le pertenece
        };

        var ex = await Assert.ThrowsAsync<UnauthorizedAccessException>(() => _service.ListarCargosAsync(filtros));
        Assert.Contains("no te pertenece", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ListarCargos_Inquilino_SinViviendas_RetornaPaginaVaciaSinConsultarPostgrest()
    {
        _mockUserContext.Setup(u => u.EsAdmin).Returns(false);

        _mockViviendasLookup
            .Setup(v => v.GetViviendaIdsPorUsuarioTitularAsync(_userId))
            .ReturnsAsync(new List<int>());

        var filtros = new ConsultaCargosFiltrosDto();

        var resultado = await _service.ListarCargosAsync(filtros);

        Assert.NotNull(resultado);
        Assert.Empty(resultado.Items);
        Assert.Equal(0, resultado.Total);
        _mockClient.Verify(c => c.GetPagedAsync<VwCargo>(It.IsAny<string>(), It.IsAny<HavenApi.Shared.Pagination.PaginationParams>(), It.IsAny<string?>()), Times.Never);
    }

    [Fact]
    public async Task ListarCargos_Inquilino_ConViviendaPropia_FiltraPorEsaVivienda()
    {
        _mockUserContext.Setup(u => u.EsAdmin).Returns(false);

        _mockViviendasLookup
            .Setup(v => v.GetViviendaIdsPorUsuarioTitularAsync(_userId))
            .ReturnsAsync(new List<int> { 7, 8 });

        var filtros = new ConsultaCargosFiltrosDto
        {
            ViviendaId = 7
        };

        string? capturedQuery = null;
        _mockClient
            .Setup(c => c.GetPagedAsync<VwCargo>("vw_cargos", It.IsAny<HavenApi.Shared.Pagination.PaginationParams>(), It.IsAny<string?>()))
            .Callback<string, HavenApi.Shared.Pagination.PaginationParams, string?>((_, _, q) => capturedQuery = q)
            .ReturnsAsync((new List<VwCargo>
            {
                new()
                {
                    Id = Guid.NewGuid(),
                    CondominioId = _condominioId,
                    ViviendaId = 7,
                    EstaVencido = true,
                    Estado = EstadoCargo.Pendiente
                }
            }, 1));

        var resultado = await _service.ListarCargosAsync(filtros);

        Assert.NotNull(capturedQuery);
        Assert.Contains("vivienda_id=eq.7", capturedQuery);
        Assert.Single(resultado.Items);
        Assert.Equal("Vencido", resultado.Items[0].EstadoEfectivo);
    }

    [Fact]
    public async Task ObtenerDetalleCargo_IdVacio_LanzaArgumentException()
    {
        var ex = await Assert.ThrowsAsync<ArgumentException>(() => _service.ObtenerDetalleCargoAsync(Guid.Empty));
        Assert.Contains("id", ex.Message, StringComparison.OrdinalIgnoreCase);
    }

    [Fact]
    public async Task ObtenerDetalleCargo_NoExiste_LanzaKeyNotFoundException()
    {
        var cargoId = Guid.NewGuid();
        _mockClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync((VwCargo?)null);

        var ex = await Assert.ThrowsAsync<KeyNotFoundException>(() => _service.ObtenerDetalleCargoAsync(cargoId));
        Assert.Equal("Cargo no encontrado.", ex.Message);
    }

    [Fact]
    public async Task ObtenerDetalleCargo_Admin_CondominioDiferente_LanzaKeyNotFoundException()
    {
        var cargoId = Guid.NewGuid();
        var otroCondominioId = Guid.NewGuid();

        _mockClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(new VwCargo
            {
                Id = cargoId,
                CondominioId = otroCondominioId
            });

        var ex = await Assert.ThrowsAsync<KeyNotFoundException>(() => _service.ObtenerDetalleCargoAsync(cargoId));
        Assert.Equal("Cargo no encontrado.", ex.Message);
    }

    [Fact]
    public async Task ObtenerDetalleCargo_Admin_Exito_ConsultaCargosYPagos()
    {
        var cargoId = Guid.NewGuid();

        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = _condominioId,
            ViviendaId = 15,
            NumeroCasa = "15-B",
            Concepto = "Cuota Octubre",
            Monto = 2000m,
            MontoPagadoConfirmado = 1000m,
            SaldoPendiente = 1000m,
            Estado = EstadoCargo.Parcial,
            EstaVencido = false
        };

        var vwPagos = new List<VwPago>
        {
            new()
            {
                Id = Guid.NewGuid(),
                CargoId = cargoId,
                Monto = 1000m,
                MontoCubierto = 1000m,
                Estado = EstadoPago.Confirmado,
                FechaPago = new DateOnly(2026, 10, 5)
            }
        };

        _mockClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        _mockClient
            .Setup(c => c.GetAsync<VwPago>("vw_pagos", $"cargo_id=eq.{cargoId}&order=fecha_pago.desc,creado_en.desc"))
            .ReturnsAsync(vwPagos);

        var detalle = await _service.ObtenerDetalleCargoAsync(cargoId);

        Assert.NotNull(detalle);
        Assert.Equal(cargoId, detalle.Id);
        Assert.Equal("15-B", detalle.NumeroCasa);
        Assert.Equal("Parcial", detalle.EstadoEfectivo);
        Assert.Single(detalle.Pagos);
        Assert.Equal(1000m, detalle.Pagos[0].Monto);
    }

    [Fact]
    public async Task ObtenerDetalleCargo_Inquilino_NoEsTitular_LanzaKeyNotFoundException()
    {
        _mockUserContext.Setup(u => u.EsAdmin).Returns(false);

        var cargoId = Guid.NewGuid();
        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = _condominioId,
            ViviendaId = 88
        };

        _mockClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        _mockViviendasLookup
            .Setup(v => v.EsResidenteTitularAsync(88, _userId))
            .ReturnsAsync(false);

        var ex = await Assert.ThrowsAsync<KeyNotFoundException>(() => _service.ObtenerDetalleCargoAsync(cargoId));
        Assert.Equal("Cargo no encontrado.", ex.Message);
    }

    [Fact]
    public async Task ObtenerDetalleCargo_Inquilino_EsTitular_Exito_IncluyePagosEnCualquierEstado()
    {
        _mockUserContext.Setup(u => u.EsAdmin).Returns(false);

        var cargoId = Guid.NewGuid();
        var vwCargo = new VwCargo
        {
            Id = cargoId,
            CondominioId = _condominioId,
            ViviendaId = 12,
            NumeroCasa = "12",
            Estado = EstadoCargo.Pendiente,
            EstaVencido = true
        };

        var vwPagos = new List<VwPago>
        {
            new()
            {
                Id = Guid.NewGuid(),
                CargoId = cargoId,
                Monto = 500m,
                Estado = EstadoPago.PendienteConfirmacion,
                FechaPago = new DateOnly(2026, 10, 1)
            },
            new()
            {
                Id = Guid.NewGuid(),
                CargoId = cargoId,
                Monto = 300m,
                Estado = EstadoPago.Rechazado,
                FechaPago = new DateOnly(2026, 9, 28)
            }
        };

        _mockClient
            .Setup(c => c.GetSingleOrDefaultAsync<VwCargo>("vw_cargos", $"id=eq.{cargoId}"))
            .ReturnsAsync(vwCargo);

        _mockViviendasLookup
            .Setup(v => v.EsResidenteTitularAsync(12, _userId))
            .ReturnsAsync(true);

        _mockClient
            .Setup(c => c.GetAsync<VwPago>("vw_pagos", $"cargo_id=eq.{cargoId}&order=fecha_pago.desc,creado_en.desc"))
            .ReturnsAsync(vwPagos);

        var detalle = await _service.ObtenerDetalleCargoAsync(cargoId);

        Assert.NotNull(detalle);
        Assert.Equal(cargoId, detalle.Id);
        Assert.Equal("Vencido", detalle.EstadoEfectivo);
        Assert.Equal(2, detalle.Pagos.Count);
        Assert.Contains(detalle.Pagos, p => p.Estado == EstadoPago.PendienteConfirmacion);
        Assert.Contains(detalle.Pagos, p => p.Estado == EstadoPago.Rechazado);
    }
}
