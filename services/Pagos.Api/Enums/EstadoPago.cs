using System.Text.Json.Serialization;

namespace Pagos.Api.Enums;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum EstadoPago
{
    PendienteConfirmacion,
    Confirmado,
    Rechazado,
    Anulado
}
