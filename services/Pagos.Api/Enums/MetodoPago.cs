using System.Text.Json.Serialization;

namespace Pagos.Api.Enums;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum MetodoPago
{
    Efectivo,
    Transferencia,
    Deposito,
    Otro
}
