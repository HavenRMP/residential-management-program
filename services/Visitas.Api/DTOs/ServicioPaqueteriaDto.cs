using System.Text.Json.Serialization;

namespace Visitas.Api.DTOs;

public class ServicioPaqueteriaDto
{
    [JsonPropertyName("id")]
    public int Id { get; set; }

    [JsonPropertyName("condominio_id")]
    public Guid? CondominioId { get; set; }

    [JsonPropertyName("nombre")]
    public string Nombre { get; set; } = string.Empty;

    [JsonPropertyName("icono_url")]
    public string? IconoUrl { get; set; }

    [JsonPropertyName("activo")]
    public bool Activo { get; set; }

    [JsonPropertyName("es_sistema")]
    public bool EsSistema { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTimeOffset CreadoEn { get; set; }
}
