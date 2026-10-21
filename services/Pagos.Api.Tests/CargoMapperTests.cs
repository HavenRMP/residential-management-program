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

    #region Casos 1 al 5 - Mapeo

    [Fact]
    public void Caso1_Mapeo_EstaVencidoVerdaderoConEstadoPendiente_EstadoEfectivoEsVencido()
    {
        // Caso 1: esta_vencido verdadero con estado Pendiente => estado_efectivo Vencido.
        var vw = new VwCargo
        {
            Id = Guid.NewGuid(),
            Estado = EstadoCargo.Pendiente,
            EstaVencido = true,
            FechaVencimiento = new DateOnly(2026, 1, 15)
        };

        var response = vw.ToResponse();

        Assert.Equal(EstadoCargo.Pendiente, response.Estado);
        Assert.Equal("Vencido", response.EstadoEfectivo);
    }

    [Fact]
    public void Caso2_Mapeo_EstaVencidoVerdaderoConEstadoParcial_EstadoEfectivoEsVencido()
    {
        // Caso 2: esta_vencido verdadero con estado Parcial => Vencido.
        var vw = new VwCargo
        {
            Id = Guid.NewGuid(),
            Estado = EstadoCargo.Parcial,
            EstaVencido = true,
            FechaVencimiento = new DateOnly(2026, 2, 20)
        };

        var response = vw.ToResponse();

        Assert.Equal(EstadoCargo.Parcial, response.Estado);
        Assert.Equal("Vencido", response.EstadoEfectivo);
    }

    [Theory]
    [InlineData(EstadoCargo.Pendiente, "Pendiente")]
    [InlineData(EstadoCargo.Parcial, "Parcial")]
    [InlineData(EstadoCargo.Pagado, "Pagado")]
    [InlineData(EstadoCargo.Cancelado, "Cancelado")]
    public void Caso3_Mapeo_EstaVencidoFalso_EstadoEfectivoIgualAlEstadoPersistido(EstadoCargo estado, string esperado)
    {
        // Caso 3: esta_vencido falso => estado_efectivo igual al estado persistido.
        var vw = new VwCargo
        {
            Id = Guid.NewGuid(),
            Estado = estado,
            EstaVencido = false,
            FechaVencimiento = new DateOnly(2026, 12, 31)
        };

        var response = vw.ToResponse();

        Assert.Equal(estado, response.Estado);
        Assert.Equal(esperado, response.EstadoEfectivo);
    }

    [Theory]
    [InlineData(EstadoCargo.Pagado, "Pagado")]
    [InlineData(EstadoCargo.Cancelado, "Cancelado")]
    public void Caso4_Mapeo_PagadoOCancelado_NuncaSalenComoVencido_DocumentaComportamientoVista(EstadoCargo estado, string esperado)
    {
        // Caso 4: Pagado o Cancelado nunca salen como Vencido (la vista en base de datos ya manda esta_vencido falso; el test lo documenta).
        // En la vista PostgreSQL: esta_vencido = (fecha_vencimiento < current_date AND estado NOT IN ('Pagado', 'Cancelado'))
        // Por definición de vista, Pagado y Cancelado siempre tienen EstaVencido = false.
        var vw = new VwCargo
        {
            Id = Guid.NewGuid(),
            Estado = estado,
            EstaVencido = false,
            FechaVencimiento = new DateOnly(2020, 1, 1) // Fecha pasada, pero estado Pagado o Cancelado
        };

        var response = vw.ToResponse();

        Assert.Equal(estado, response.Estado);
        Assert.Equal(esperado, response.EstadoEfectivo);
        Assert.NotEqual("Vencido", response.EstadoEfectivo);
    }

    [Theory]
    [InlineData(2026, 1, "2026-01")]
    [InlineData(2026, 11, "2026-11")]
    [InlineData(2027, 12, "2027-12")]
    public void Caso5_Mapeo_PeriodoPrimerDiaDelMes_SeExponeComoTextoAnioMes(int anio, int mes, string esperado)
    {
        // Caso 5: periodo DateOnly del primer día del mes se expone como texto año-mes.
        var vw = new VwCargo
        {
            Id = Guid.NewGuid(),
            Periodo = new DateOnly(anio, mes, 1),
            Estado = EstadoCargo.Pendiente,
            EstaVencido = false
        };

        var response = vw.ToResponse();

        Assert.Equal(esperado, response.Periodo);
    }

    #endregion
}
