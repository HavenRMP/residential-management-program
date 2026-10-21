using System.Text.Json.Serialization;

namespace Pagos.Api.Models;

/// <summary>
/// Modelo auxiliar para capturar el identificador generado tras la inserción en la tabla 'plantillas_cargo'.
/// </summary>
public class PlantillaInsertResult
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }
}
