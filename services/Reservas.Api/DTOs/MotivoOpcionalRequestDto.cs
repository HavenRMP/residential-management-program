using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Reservas.Api.DTOs;

public class MotivoOpcionalRequestDto
{
    [MaxLength(500, ErrorMessage = "El motivo no puede exceder 500 caracteres")]
    [JsonPropertyName("motivo")]
    public string? Motivo { get; set; }
}
