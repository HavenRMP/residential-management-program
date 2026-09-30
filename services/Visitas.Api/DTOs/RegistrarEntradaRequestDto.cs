using System.ComponentModel.DataAnnotations;
using System.Text.Json.Serialization;

namespace Visitas.Api.DTOs;

public class RegistrarEntradaRequestDto
{
    [MaxLength(15, ErrorMessage = "Las placas del vehículo no pueden exceder 15 caracteres.")]
    [JsonPropertyName("vehiculoPlacas")]
    public string? VehiculoPlacas { get; set; }
}
