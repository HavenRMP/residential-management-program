using System.Text.Json.Serialization;

namespace Condominios.Api.DTOs;

public class CodigoCondominioDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("condominio_id")]
    public Guid CondominioId { get; set; }

    [JsonPropertyName("codigo")]
    public string Codigo { get; set; } = string.Empty;

    [JsonPropertyName("expira_en")]
    public DateTime ExpiraEn { get; set; }

    [JsonPropertyName("usado_por")]
    public Guid? UsadoPor { get; set; }

    [JsonPropertyName("usado_en")]
    public DateTime? UsadoEn { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTime CreadoEn { get; set; }
}
