using System.Text.Json.Serialization;

namespace Pagos.Api.Enums;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum TipoMovimientoSaldo
{
    Abono,
    Aplicacion,
    ReversoAbono,
    ReversoAplicacion
}
