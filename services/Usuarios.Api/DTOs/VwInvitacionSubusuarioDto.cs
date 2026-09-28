using System.Text.Json.Serialization;

namespace Usuarios.Api.DTOs;

public class VwInvitacionSubusuarioDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("numero_casa")]
    public string? NumeroCasa { get; set; }

    [JsonPropertyName("condominio_nombre")]
    public string? CondominioNombre { get; set; }

    [JsonPropertyName("titular_id")]
    public Guid TitularId { get; set; }

    [JsonPropertyName("titular_nombre")]
    public string? TitularNombre { get; set; }

    [JsonPropertyName("invitado_id")]
    public Guid InvitadoId { get; set; }

    [JsonPropertyName("invitado_email")]
    public string? InvitadoEmail { get; set; }

    [JsonPropertyName("parentesco")]
    public string Parentesco { get; set; } = string.Empty;

    [JsonPropertyName("estado")]
    public string Estado { get; set; } = string.Empty;

    [JsonPropertyName("creado_en")]
    public DateTime CreadoEn { get; set; }
}
