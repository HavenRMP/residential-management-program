using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

public class ViviendaResidenteItemDto
{
    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }
}
