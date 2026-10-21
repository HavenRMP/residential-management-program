using Pagos.Api.DTOs;
using Pagos.Api.Enums;
using Pagos.Api.Models;
using Xunit;

namespace Pagos.Api.Tests;

public class PagoMapperTests
{
    [Fact]
    public void ToResumenResponse_MapeaPropiedadesCorrectamente_Y_NoExponeRutaNiHash()
    {
        // Arrange
        var pagoId = Guid.NewGuid();
        var originalId = Guid.NewGuid();
        var vw = new VwPago
        {
            Id = pagoId,
            CargoId = Guid.NewGuid(),
            CondominioId = Guid.NewGuid(),
            ViviendaId = 1,
            NumeroCasa = "101",
            Monto = 1500m,
            MontoCubierto = 1500m,
            MontoExcedente = 0m,
            FechaPago = new DateOnly(2026, 10, 15),
            Metodo = MetodoPago.Transferencia,
            Referencia = "SPEI-998877",
            BancoOrigen = "BBVA",
            Estado = EstadoPago.PendienteConfirmacion,
            Origen = OrigenPago.Inquilino,
            TieneComprobante = true,
            ComprobanteRuta = "condominios/1/pagos/secreto.pdf",
            ComprobanteHash = "sha256-secreto-hash",
            EsReversa = false,
            PagoOriginalId = originalId
        };

        // Act
        var resumen = vw.ToResumenResponse();

        // Assert
        Assert.NotNull(resumen);
        Assert.Equal(pagoId, resumen.Id);
        Assert.Equal(1500m, resumen.Monto);
        Assert.Equal(1500m, resumen.MontoCubierto);
        Assert.Equal(0m, resumen.MontoExcedente);
        Assert.Equal(new DateOnly(2026, 10, 15), resumen.FechaPago);
        Assert.Equal(MetodoPago.Transferencia, resumen.Metodo);
        Assert.Equal("SPEI-998877", resumen.Referencia);
        Assert.Equal(EstadoPago.PendienteConfirmacion, resumen.Estado);
        Assert.Equal(OrigenPago.Inquilino, resumen.Origen);
        Assert.True(resumen.TieneComprobante);
        Assert.False(resumen.EsReversa);
        Assert.Equal(originalId, resumen.PagoOriginalId);

        // Verificación de que el tipo PagoResumenResponse no expone comprobante_ruta ni comprobante_hash
        var propRuta = typeof(PagoResumenResponse).GetProperty("ComprobanteRuta");
        var propHash = typeof(PagoResumenResponse).GetProperty("ComprobanteHash");
        Assert.Null(propRuta);
        Assert.Null(propHash);
    }
}
