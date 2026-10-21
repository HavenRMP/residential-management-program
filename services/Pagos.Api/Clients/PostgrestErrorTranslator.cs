using System.Text.Json;
using System.Text.Json.Serialization;
using System.Text.RegularExpressions;

namespace Pagos.Api.Clients;

public class PostgrestErrorResponse
{
    [JsonPropertyName("code")]
    public string? Code { get; set; }

    [JsonPropertyName("message")]
    public string? Message { get; set; }

    [JsonPropertyName("details")]
    public string? Details { get; set; }

    [JsonPropertyName("hint")]
    public string? Hint { get; set; }
}

public readonly record struct ErrorTraduccion(
    int StatusCode, 
    string MensajeUsuario, 
    MotivoConflicto? MotivoConflicto = null, 
    string? ConstraintName = null)
{
    public MotivoConflicto? Motivo => MotivoConflicto;

    public void Deconstruct(out int statusCode, out string mensajeUsuario)
    {
        statusCode = StatusCode;
        mensajeUsuario = MensajeUsuario;
    }

    public void Deconstruct(out int statusCode, out string mensajeUsuario, out MotivoConflicto? motivoConflicto)
    {
        statusCode = StatusCode;
        mensajeUsuario = MensajeUsuario;
        motivoConflicto = MotivoConflicto;
    }

    public void Deconstruct(out int statusCode, out string mensajeUsuario, out MotivoConflicto? motivoConflicto, out string? constraintName)
    {
        statusCode = StatusCode;
        mensajeUsuario = MensajeUsuario;
        motivoConflicto = MotivoConflicto;
        constraintName = ConstraintName;
    }

    public static implicit operator (int StatusCode, string MensajeUsuario)(ErrorTraduccion t) => 
        (t.StatusCode, t.MensajeUsuario);

    public static implicit operator (int StatusCode, string MensajeUsuario, MotivoConflicto? MotivoConflicto)(ErrorTraduccion t) => 
        (t.StatusCode, t.MensajeUsuario, t.MotivoConflicto);
}

public static class PostgrestErrorTranslator
{
    public static string? ExtraerNombreConstraint(string? message)
    {
        if (string.IsNullOrWhiteSpace(message))
        {
            return null;
        }

        // En un error 23505, el campo message del JSON de error de PostgREST incluye
        // el nombre del constraint entre comillas (después de "violates unique constraint").
        var match = Regex.Match(message, @"violates unique constraint\s+[""'](?<name>[^""']+)[""']", RegexOptions.IgnoreCase);
        if (match.Success)
        {
            var name = match.Groups["name"].Value.Trim();
            if (name.Contains('.'))
            {
                name = name.Substring(name.LastIndexOf('.') + 1);
            }
            return name;
        }

        var matchAlt = Regex.Match(message, @"violates unique constraint\s+(?<name>[^\s;]+)", RegexOptions.IgnoreCase);
        if (matchAlt.Success)
        {
            var name = matchAlt.Groups["name"].Value.Trim().Trim('"', '\'');
            if (name.Contains('.'))
            {
                name = name.Substring(name.LastIndexOf('.') + 1);
            }
            return name;
        }

        if (message.Contains("idx_pagos_anti_duplicado_ref", StringComparison.OrdinalIgnoreCase))
            return "idx_pagos_anti_duplicado_ref";
        if (message.Contains("idx_pagos_anti_duplicado_hash", StringComparison.OrdinalIgnoreCase))
            return "idx_pagos_anti_duplicado_hash";
        if (message.Contains("uq_cargos_plantilla_periodo", StringComparison.OrdinalIgnoreCase))
            return "uq_cargos_plantilla_periodo";
        if (message.Contains("idx_plantillas_vivienda_tipo_concepto_activa", StringComparison.OrdinalIgnoreCase))
            return "idx_plantillas_vivienda_tipo_concepto_activa";

        return null;
    }

    public static (string MensajeUsuario, MotivoConflicto Motivo) MapearConflicto(string? constraintName)
    {
        return constraintName switch
        {
            "idx_pagos_anti_duplicado_ref" => (
                "Ya existe un pago registrado con la misma referencia, monto y fecha.",
                MotivoConflicto.PagoDuplicadoReferencia
            ),
            "idx_pagos_anti_duplicado_hash" => (
                "Este comprobante ya fue registrado anteriormente.",
                MotivoConflicto.ComprobanteDuplicado
            ),
            "uq_cargos_plantilla_periodo" => (
                "Ya existe un cargo generado para esta plantilla en dicho periodo.",
                MotivoConflicto.CargoPlantillaPeriodoDuplicado
            ),
            "idx_plantillas_vivienda_tipo_concepto_activa" => (
                "Ya existe una plantilla activa del mismo tipo y concepto para esta vivienda.",
                MotivoConflicto.PlantillaActivaDuplicada
            ),
            _ => (
                "El registro ya existe.",
                MotivoConflicto.Generico
            )
        };
    }

    public static ErrorTraduccion Traducir(string? code, string? message = null, string? details = null)
    {
        var cleanCode = code?.Trim();

        if (cleanCode == "23505")
        {
            var constraint = ExtraerNombreConstraint(message);
            var (mensajeConflicto, motivo) = MapearConflicto(constraint);
            return new ErrorTraduccion(409, mensajeConflicto, motivo, constraint);
        }

        var (statusCode, mensaje) = cleanCode switch
        {
            "23503" or "23514" or "23502" => (400, !string.IsNullOrWhiteSpace(message) ? message : "Error de validación en los datos enviados."),
            "PG000" => (404, "El recurso solicitado no fue encontrado."),
            "PG001" => (409, "El cargo está cancelado o el estado no permite la operación"),
            "PG002" => (409, "El pago no está pendiente de confirmación"),
            "PG003" => (409, "El pago no se encuentra en estado PendienteConfirmacion para ser rechazado"),
            "PG004" => (409, "Solo se pueden anular pagos confirmados"),
            "PG005" => (409, "El cargo ya está cancelado"),
            "PG006" => (409, "No se puede cancelar: el cargo tiene pagos o aplicaciones de saldo vigentes"),
            "PG007" => (409, "Saldo a favor insuficiente"),
            "PG008" => (409, "El monto es inválido o mayor al saldo pendiente del cargo"),
            "PG009" => (409, "El movimiento no se puede revertir"),
            "PG010" => (409, "El cargo ya está pagado"),
            _ => (500, "Ocurrió un error interno en el servidor.")
        };

        return new ErrorTraduccion(statusCode, mensaje, null, null);
    }

    public static PostgrestException ParseAndTranslate(string errorBody)
    {
        string? code = null;
        string? message = null;
        string? details = null;

        if (!string.IsNullOrWhiteSpace(errorBody))
        {
            try
            {
                var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
                var errorData = JsonSerializer.Deserialize<PostgrestErrorResponse>(errorBody, options);
                if (errorData != null)
                {
                    code = errorData.Code;
                    message = errorData.Message;
                    details = errorData.Details;
                }
            }
            catch (JsonException)
            {
                message = errorBody;
            }
        }

        var traduccion = Traducir(code, message, details);
        return new PostgrestException(
            traduccion.StatusCode, 
            code ?? "UNKNOWN", 
            traduccion.MensajeUsuario, 
            details,
            traduccion.MotivoConflicto,
            traduccion.ConstraintName);
    }
}
