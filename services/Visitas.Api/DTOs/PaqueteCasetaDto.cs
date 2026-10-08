using System.Text.Json.Serialization;

namespace Visitas.Api.DTOs;

public class PaqueteCasetaDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("condominio_id")]
    public Guid CondominioId { get; set; }

    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("numero_casa")]
    public string NumeroCasa { get; set; } = null!;

    [JsonPropertyName("servicio_id")]
    public int? ServicioId { get; set; }

    [JsonPropertyName("servicio_nombre")]
    public string? ServicioNombre { get; set; }

    [JsonPropertyName("destinatario_nombre")]
    public string DestinatarioNombre { get; set; } = null!;

    [JsonPropertyName("numero_guia")]
    public string? NumeroGuia { get; set; }

    [JsonPropertyName("descripcion")]
    public string? Descripcion { get; set; }

    [JsonPropertyName("notas")]
    public string? Notas { get; set; }

    [JsonPropertyName("fecha_esperada_desde")]
    public DateTimeOffset? FechaEsperadaDesde { get; set; }

    [JsonPropertyName("fecha_esperada_hasta")]
    public DateTimeOffset? FechaEsperadaHasta { get; set; }

    [JsonPropertyName("estado")]
    public string Estado { get; set; } = null!;

    [JsonPropertyName("es_inesperado")]
    public bool EsInesperado { get; set; }

    [JsonPropertyName("ubicacion_almacen")]
    public string? UbicacionAlmacen { get; set; }

    [JsonPropertyName("recibido_en")]
    public DateTimeOffset? RecibidoEn { get; set; }

    [JsonPropertyName("recibido_por_nombre")]
    public string? RecibidoPorNombre { get; set; }

    [JsonPropertyName("entregado_en")]
    public DateTimeOffset? EntregadoEn { get; set; }

    [JsonPropertyName("entregado_a_nombre")]
    public string? EntregadoANombre { get; set; }

    [JsonPropertyName("creado_por")]
    public Guid? CreadoPor { get; set; }

    [JsonPropertyName("creado_por_nombre")]
    public string CreadoPorNombre { get; set; } = null!;

    [JsonPropertyName("creado_en")]
    public DateTimeOffset CreadoEn { get; set; }
}
