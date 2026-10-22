using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO de solicitud para revertir una aplicación previa de saldo a favor a un cargo.
/// </summary>
public class RevertirAplicacionSaldoRequest
{
    [Required(ErrorMessage = "El motivo de la reversa es obligatorio.")]
    [StringLength(300, MinimumLength = 5, ErrorMessage = "El motivo debe tener entre 5 y 300 caracteres.")]
    [JsonPropertyName("motivo")]
    public string Motivo { get; set; } = string.Empty;
}
