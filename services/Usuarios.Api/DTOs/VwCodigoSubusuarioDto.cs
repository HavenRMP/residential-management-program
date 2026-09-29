using System.Text.Json.Serialization;

namespace Usuarios.Api.DTOs;

public class VwCodigoSubusuarioDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("codigo")]
    public string Codigo { get; set; } = string.Empty;

    [JsonPropertyName("parentesco")]
    public string Parentesco { get; set; } = string.Empty;

    [JsonPropertyName("expira_en")]
    public DateTime ExpiraEn { get; set; }

    [JsonPropertyName("es_vigente")]
    public bool EsVigente { get; set; }
}
