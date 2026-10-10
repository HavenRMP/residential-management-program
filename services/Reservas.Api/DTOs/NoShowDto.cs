using System;
using System.Text.Json.Serialization;

namespace Reservas.Api.DTOs;

public class NoShowDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("area_id")]
    public Guid AreaId { get; set; }

    [JsonPropertyName("area_nombre")]
    public string AreaNombre { get; set; } = string.Empty;

    [JsonPropertyName("condominio_id")]
    public Guid CondominioId { get; set; }

    [JsonPropertyName("inicio")]
    public DateTimeOffset Inicio { get; set; }

    [JsonPropertyName("fin")]
    public DateTimeOffset Fin { get; set; }

    [JsonPropertyName("titular_id")]
    public Guid TitularId { get; set; }

    [JsonPropertyName("titular_nombre")]
    public string TitularNombre { get; set; } = string.Empty;

    [JsonPropertyName("titular_apellidos")]
    public string TitularApellidos { get; set; } = string.Empty;

    [JsonPropertyName("vivienda_id")]
    public int ViviendaId { get; set; }

    [JsonPropertyName("numero_casa")]
    public string NumeroCasa { get; set; } = string.Empty;

    [JsonPropertyName("solicitante_id")]
    public Guid SolicitanteId { get; set; }

    [JsonPropertyName("solicitante_nombre")]
    public string SolicitanteNombre { get; set; } = string.Empty;

    [JsonPropertyName("solicitante_apellidos")]
    public string SolicitanteApellidos { get; set; } = string.Empty;

    [JsonPropertyName("creado_en")]
    public DateTimeOffset CreadoEn { get; set; }
}
