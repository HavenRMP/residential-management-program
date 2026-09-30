using HavenApi.Shared.Exceptions;

namespace HavenApi.Shared.Rpc;

public static class RpcErrorMapper
{
    public static (int StatusCode, string MensajeUsuario) Map(SupabaseRpcException ex)
    {
        return ex.Code switch
        {
            "CD001" => (404, "El código ingresado no existe."),
            "CD002" => (409, "Este código ya fue utilizado."),
            "CD003" => (410, "Este código ha expirado o fue invalidado."),
            "CD004" => (409, "El usuario ya pertenece a un condominio diferente."),
            "23505" => (409, "El usuario ya está vinculado a esa vivienda."),
            "VI001" => (404, "La visita no existe."),
            "VI002" => (403, "No tienes permiso para realizar esta operación sobre la visita."),
            "VI003" => (409, "La visita no permite esta operación en su estado actual."),
            "VI004" => (404, "El código de visita no existe."),
            "VI005" => (410, "La visita o su código ha expirado."),
            "VI006" => (409, "La entrada de esta visita ya fue registrada."),
            "VI007" => (409, "No se puede registrar la salida: la visita no ha ingresado."),
            "VI008" => (400, "Los datos de la visita no son válidos."),
            "VI009" => (404, "La vivienda no existe o está inactiva."),
            _ => (500, $"Ocurrió un error inesperado al procesar el código. (Código: {ex.Code})")
        };
    }
}
