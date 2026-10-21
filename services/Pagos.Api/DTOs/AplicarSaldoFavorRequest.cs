using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Pagos.Api.DTOs;

/// <summary>
/// DTO con el monto de saldo a favor a aplicar manualmente a un cargo.
/// </summary>
public class AplicarSaldoFavorRequest
{
    /// <summary>
    /// Monto a aplicar de saldo a favor (mayor a cero, máximo 2 decimales).
    /// </summary>
    [Required]
    [JsonPropertyName("monto")]
    public decimal Monto { get; set; }
}
