using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

public class ViviendaItemDto
{
    [JsonPropertyName("id")]
    public int Id { get; set; }
}
