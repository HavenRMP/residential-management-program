using System.Text.Json.Serialization;

namespace Pagos.Api.Models;

/// <summary>
/// Modelo auxiliar para deserializar el ID generado tras una inserción en Supabase/PostgREST.
/// </summary>
public class CargoIdResult
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }
}
