using System.Text.Json.Serialization;

namespace Usuarios.Api.DTOs;

public class ViviendaResidentesDto
{
    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("numero_casa")]
    public string NumeroCasa { get; set; } = string.Empty;

    [JsonPropertyName("tipo")]
    public string? Tipo { get; set; }

    [JsonPropertyName("activo")]
    public bool Activo { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTime CreadoEn { get; set; }

    [JsonPropertyName("residentes")]
    public List<UsuarioDto> Residentes { get; set; } = new List<UsuarioDto>();
}
