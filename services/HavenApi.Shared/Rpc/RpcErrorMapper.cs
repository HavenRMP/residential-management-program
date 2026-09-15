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
            _ => (500, $"Ocurrió un error inesperado al procesar el código. Detalles: {ex.Message}")
        };
    }
}
