using Xunit;
using Pagos.Api.DTOs;
using Pagos.Api.Enums;
using Pagos.Api.Models;

namespace Pagos.Api.Tests;

public class CargoMapperTests
{
    [Fact]
    public void ToResponse_MapeaTodasLasPropiedadesCorrectamente()
    {
        // Arrange
        var id = Guid.NewGuid();
        var condominioId = Guid.NewGuid();
        var plantillaId = Guid.NewGuid();
        var creadoPor = Guid.NewGuid();
        var canceladoPor = Guid.NewGuid();
        var fechaCreacion = DateTimeOffset.UtcNow;
        var fechaCancelacion = DateTimeOffset.UtcNow;
        var fechaVencimiento = new DateOnly(2026, 11, 15);
        var periodo = new DateOnly(2026, 11, 1);

        var vw = new VwCargo
        {
            Id = id,
            CondominioId = condominioId,
            CondominioNombre = "Residencial Las Palmas",
            ViviendaId = 101,
            NumeroCasa = "Casa 12",
            PlantillaId = plantillaId,
            Periodo = periodo,
            Tipo = TipoCargo.Mantenimiento,
            Concepto = "Cuota ordinaria noviembre 2026",
            Monto = 1500.50m,
            MontoPagadoConfirmado = 500.00m,
            SaldoPendiente = 1000.50m,
            Estado = EstadoCargo.Parcial,
            FechaVencimiento = fechaVencimiento,
            EstaVencido = false,
            ResponsablePago = ResponsablePago.Propietario,
            MotivoCancelacion = "Cancelación de prueba",
            CanceladoPor = canceladoPor,
            CanceladoEn = fechaCancelacion,
            CreadoPor = creadoPor,
            CreadoEn = fechaCreacion
        };

        // Act
        var response = vw.ToResponse();

        // Assert
        Assert.NotNull(response);
        Assert.Equal(id, response.Id);
        Assert.Equal(condominioId, response.CondominioId);
        Assert.Equal(101, response.ViviendaId);
        Assert.Equal("Casa 12", response.NumeroCasa);
        Assert.Equal(plantillaId, response.PlantillaId);
        Assert.Equal("2026-11", response.Periodo);
        Assert.Equal(TipoCargo.Mantenimiento, response.Tipo);
        Assert.Equal("Cuota ordinaria noviembre 2026", response.Concepto);
        Assert.Equal(1500.50m, response.Monto);
        Assert.Equal(500.00m, response.MontoPagadoConfirmado);
        Assert.Equal(1000.50m, response.SaldoPendiente);
        Assert.Equal(EstadoCargo.Parcial, response.Estado);
        Assert.Equal("Parcial", response.EstadoEfectivo);
        Assert.Equal(fechaVencimiento, response.FechaVencimiento);
        Assert.Equal(ResponsablePago.Propietario, response.ResponsablePago);
        Assert.Equal("Cancelación de prueba", response.MotivoCancelacion);
        Assert.Equal(fechaCreacion, response.CreadoEn);
    }

    [Fact]
    public void ToResponse_CuandoEstaVencidoEsVerdadero_EstadoEfectivoEsVencido()
    {
        // Arrange
        var vw = new VwCargo
        {
            Id = Guid.NewGuid(),
            Estado = EstadoCargo.Pendiente,
            EstaVencido = true,
            FechaVencimiento = new DateOnly(2026, 1, 1)
        };

        // Act
        var response = vw.ToResponse();

        // Assert
        Assert.Equal(EstadoCargo.Pendiente, response.Estado);
        Assert.Equal("Vencido", response.EstadoEfectivo);
    }

    [Fact]
    public void ToResponse_CuandoEstaVencidoEsFalso_EstadoEfectivoEsElEstadoPersistido()
    {
        // Arrange
        var vw = new VwCargo
        {
            Id = Guid.NewGuid(),
            Estado = EstadoCargo.Pagado,
            EstaVencido = false
        };

        // Act
        var response = vw.ToResponse();

        // Assert
        Assert.Equal("Pagado", response.EstadoEfectivo);
    }

    [Fact]
    public void ToResponse_CuandoPeriodoEsNulo_PeriodoEnResponseEsNulo()
    {
        // Arrange
        var vw = new VwCargo
        {
            Id = Guid.NewGuid(),
            Periodo = null
        };

        // Act
        var response = vw.ToResponse();

        // Assert
        Assert.Null(response.Periodo);
    }

    [Fact]
    public void ToResponseList_MapeaColeccionCorrectamente()
    {
        // Arrange
        var items = new List<VwCargo>
        {
            new() { Id = Guid.NewGuid(), Concepto = "Cargo 1", EstaVencido = true, Estado = EstadoCargo.Pendiente },
            new() { Id = Guid.NewGuid(), Concepto = "Cargo 2", EstaVencido = false, Estado = EstadoCargo.Pagado }
        };

        // Act
        var responses = items.ToResponseList();

        // Assert
        Assert.Equal(2, responses.Count);
        Assert.Equal("Vencido", responses[0].EstadoEfectivo);
        Assert.Equal("Pagado", responses[1].EstadoEfectivo);
    }
}
