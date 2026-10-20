using HavenApi.Shared.Exceptions;

namespace Pagos.Api.Clients;

public class PostgrestException : SupabaseRpcException
{
    public int StatusCode { get; }
    public string MensajeUsuario { get; }
    public string? Details { get; }

    public PostgrestException(int statusCode, string code, string mensajeUsuario, string? details = null)
        : base(code, mensajeUsuario)
    {
        StatusCode = statusCode;
        MensajeUsuario = mensajeUsuario;
        Details = details;
    }
}
