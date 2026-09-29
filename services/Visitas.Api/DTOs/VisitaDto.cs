using System.Text.Json.Serialization;

namespace Visitas.Api.DTOs;

public class VisitaDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("numero_casa")]
    public string NumeroCasa { get; set; } = string.Empty;

    [JsonPropertyName("condominio_id")]
    public Guid CondominioId { get; set; }

    [JsonPropertyName("nombre_visitante")]
    public string NombreVisitante { get; set; } = string.Empty;

    [JsonPropertyName("apellidos_visitante")]
    public string ApellidosVisitante { get; set; } = string.Empty;

    [JsonPropertyName("telefono_visitante")]
    public string? TelefonoVisitante { get; set; }

    [JsonPropertyName("motivo")]
    public string Motivo { get; set; } = string.Empty;

    [JsonPropertyName("num_acompanantes")]
    public int NumAcompanantes { get; set; }

    [JsonPropertyName("vehiculo_placas")]
    public string? VehiculoPlacas { get; set; }

    [JsonPropertyName("notas")]
    public string? Notas { get; set; }

    [JsonPropertyName("fecha_llegada_esperada")]
    public DateTimeOffset FechaLlegadaEsperada { get; set; }

    [JsonPropertyName("vigencia_hasta")]
    public DateTimeOffset VigenciaHasta { get; set; }

    [JsonPropertyName("estado")]
    public string Estado { get; set; } = string.Empty;

    [JsonPropertyName("hora_entrada")]
    public DateTimeOffset? HoraEntrada { get; set; }

    [JsonPropertyName("hora_salida")]
    public DateTimeOffset? HoraSalida { get; set; }

    [JsonPropertyName("codigo")]
    public string? Codigo { get; set; }

    [JsonPropertyName("creado_por")]
    public Guid? CreadoPor { get; set; }

    [JsonPropertyName("creado_por_nombre")]
    public string? CreadoPorNombre { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTimeOffset CreadoEn { get; set; }
}
