using System.Text.Json.Serialization;

namespace Pagos.Api.Enums;

[JsonConverter(typeof(JsonStringEnumConverter))]
public enum TipoCargo
{
    Renta,
    Mantenimiento,
    Servicio,
    Multa,
    Otro
}
