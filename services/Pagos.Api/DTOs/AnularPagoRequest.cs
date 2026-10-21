using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de solicitud para anular un pago confirmado.
/// </summary>
public class AnularPagoRequest
{
    [Required(ErrorMessage = "El motivo de anulación es obligatorio.")]
    [StringLength(300, MinimumLength = 5, ErrorMessage = "El motivo debe tener entre 5 y 300 caracteres.")]
    [JsonPropertyName("motivo")]
    public string Motivo { get; set; } = string.Empty;
}
