using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// Respuesta del proceso de generación por lote de cargos desde plantillas.
/// </summary>
public class GenerarCargosLoteResponse
{
    /// <summary>
    /// Cantidad de cargos nuevos generados e insertados en la base de datos.
    /// </summary>
    [JsonPropertyName("creados")]
    public int Creados { get; set; }

    /// <summary>
    /// Cantidad de cargos omitidos debido a que ya existía un cargo generado para dicha plantilla y periodo.
    /// </summary>
    [JsonPropertyName("omitidos_por_ya_existir")]
    public int OmitidosPorYaExistir { get; set; }

    /// <summary>
    /// Cantidad de plantillas omitidas debido a que el periodo no se encuentra cubierto por su vigencia.
    /// </summary>
    [JsonPropertyName("omitidos_por_vigencia")]
    public int OmitidosPorVigencia { get; set; }

    /// <summary>
    /// Lista de cargos nuevos que fueron creados durante este lote.
    /// </summary>
    [JsonPropertyName("cargos")]
    public List<CargoCreadoItemResponse> Cargos { get; set; } = new();
}

/// <summary>
/// Representación resumida de un cargo creado durante la generación por lote.
/// </summary>
public class CargoCreadoItemResponse
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("monto")]
    public decimal Monto { get; set; }

    [JsonPropertyName("fecha_vencimiento")]
    public DateOnly FechaVencimiento { get; set; }
}
