using HavenApi.Shared.Exceptions;

namespace Pagos.Api.Clients;

public class PostgrestException : SupabaseRpcException
{
    public int StatusCode { get; }
    public string MensajeUsuario { get; }
    public string? Details { get; }
    public MotivoConflicto? MotivoConflicto { get; }
    public MotivoConflicto? Motivo => MotivoConflicto;
    public string? ConstraintName { get; }

    public PostgrestException(
        int statusCode, 
        string code, 
        string mensajeUsuario, 
        string? details = null,
        MotivoConflicto? motivoConflicto = null,
        string? constraintName = null)
        : base(code, mensajeUsuario)
    {
        StatusCode = statusCode;
        MensajeUsuario = mensajeUsuario;
        Details = details;
        MotivoConflicto = motivoConflicto;
        ConstraintName = constraintName;
    }
}
