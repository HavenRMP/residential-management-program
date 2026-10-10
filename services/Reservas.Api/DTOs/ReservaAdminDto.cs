using System.Text.Json.Serialization;

namespace Reservas.Api.DTOs;

public class ReservaAdminDto : ReservaUsuarioDto
{
    [JsonPropertyName("no_shows_titular")]
    public int NoShowsTitular { get; set; }

    [JsonPropertyName("no_shows_solicitante")]
    public int NoShowsSolicitante { get; set; }
}
