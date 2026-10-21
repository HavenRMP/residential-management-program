using System.Text.Json.Serialization;

namespace Pagos.Api.Enums;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum EstadoCargo
{
    Pendiente,
    Parcial,
    Pagado,
    Cancelado
}
