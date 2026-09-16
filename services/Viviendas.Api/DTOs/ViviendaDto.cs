using System.Text.Json.Serialization;

namespace Viviendas.Api.DTOs;

public class ViviendaDto
{
    [JsonPropertyName("id")]
    public int Id { get; set; }

    [JsonPropertyName("numero_casa")]
    public string NumeroCasa { get; set; } = string.Empty;

    [JsonPropertyName("tipo")]
    public string? Tipo { get; set; }

    [JsonPropertyName("activo")]
    public bool Activo { get; set; }

    [JsonPropertyName("condominio_id")]
    public Guid CondominioId { get; set; }

    [JsonPropertyName("condominio_nombre")]
    public string CondominioNombre { get; set; } = string.Empty;

    [JsonPropertyName("creado_en")]
    public DateTime CreadoEn { get; set; }

    [JsonPropertyName("total_residentes")]
    public int TotalResidentes { get; set; }

    [JsonPropertyName("esta_ocupada")]
    public bool EstaOcupada { get; set; }
}
