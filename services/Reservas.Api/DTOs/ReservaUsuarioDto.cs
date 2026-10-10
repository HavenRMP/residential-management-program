using System;
using System.Text.Json.Serialization;

namespace Reservas.Api.DTOs;

public class ReservaUsuarioDto
{
    [JsonPropertyName("id")]
    public Guid Id { get; set; }

    [JsonPropertyName("area_id")]
    public Guid AreaId { get; set; }

    [JsonPropertyName("area_nombre")]
    public string AreaNombre { get; set; } = string.Empty;

    [JsonPropertyName("condominio_id")]
    public Guid CondominioId { get; set; }

    [JsonPropertyName("tipo")]
    public string Tipo { get; set; } = string.Empty;

    [JsonPropertyName("estado")]
    public string Estado { get; set; } = string.Empty;

    [JsonPropertyName("inicio")]
    public DateTimeOffset Inicio { get; set; }

    [JsonPropertyName("fin")]
    public DateTimeOffset Fin { get; set; }

    [JsonPropertyName("titular_id")]
    public Guid? TitularId { get; set; }

    [JsonPropertyName("titular_nombre")]
    public string? TitularNombre { get; set; }

    [JsonPropertyName("titular_apellidos")]
    public string? TitularApellidos { get; set; }

    [JsonPropertyName("vivienda_id")]
    public int? ViviendaId { get; set; }

    [JsonPropertyName("numero_casa")]
    public string? NumeroCasa { get; set; }

    [JsonPropertyName("solicitante_id")]
    public Guid SolicitanteId { get; set; }

    [JsonPropertyName("solicitante_nombre")]
    public string SolicitanteNombre { get; set; } = string.Empty;

    [JsonPropertyName("solicitante_apellidos")]
    public string SolicitanteApellidos { get; set; } = string.Empty;

    [JsonPropertyName("aprobador_id")]
    public Guid? AprobadorId { get; set; }

    [JsonPropertyName("aprobador_nombre")]
    public string? AprobadorNombre { get; set; }

    [JsonPropertyName("aprobador_apellidos")]
    public string? AprobadorApellidos { get; set; }

    [JsonPropertyName("motivo")]
    public string? Motivo { get; set; }

    [JsonPropertyName("confirmada_en")]
    public DateTimeOffset? ConfirmadaEn { get; set; }

    [JsonPropertyName("creado_en")]
    public DateTimeOffset CreadoEn { get; set; }

    [JsonPropertyName("actualizado_en")]
    public DateTimeOffset ActualizadoEn { get; set; }
}
