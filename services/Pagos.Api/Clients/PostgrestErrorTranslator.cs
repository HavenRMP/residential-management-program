using System.Text.Json;
using System.Text.Json.Serialization;

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

public static class PostgrestErrorTranslator
{
    public static (int StatusCode, string MensajeUsuario) Traducir(string? code, string? message = null, string? details = null)
    {
        var cleanCode = code?.Trim();

        return cleanCode switch
        {
            "23505" => (409, "Conflicto: ya existe un registro con información duplicada."),
            "23503" or "23514" or "23502" => (400, !string.IsNullOrWhiteSpace(message) ? message : "Error de validación en los datos enviados."),
            "PG000" => (404, "El recurso solicitado no fue encontrado."),
            "PG001" => (409, "El cargo está cancelado o el estado no permite la operación"),
            "PG002" or "PG003" => (409, "El pago no está pendiente de confirmación"),
            "PG004" => (409, "Solo se pueden anular pagos confirmados"),
            "PG005" => (409, "El cargo ya está cancelado"),
            "PG006" => (409, "No se puede cancelar: el cargo tiene pagos o aplicaciones de saldo vigentes"),
            "PG007" => (409, "Saldo a favor insuficiente"),
            "PG008" => (409, "El monto es inválido o mayor al saldo pendiente del cargo"),
            "PG009" => (409, "El movimiento no se puede revertir"),
            "PG010" => (409, "El cargo ya está pagado"),
            _ => (500, "Ocurrió un error interno en el servidor.")
        };
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

        var (statusCode, mensajeUsuario) = Traducir(code, message, details);
        return new PostgrestException(statusCode, code ?? "UNKNOWN", mensajeUsuario, details);
    }
}
