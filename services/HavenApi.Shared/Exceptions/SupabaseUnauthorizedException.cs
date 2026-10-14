namespace HavenApi.Shared.Exceptions;

/// <summary>
/// Supabase rechazó el token del usuario (por ejemplo, porque ya expiró).
/// Se traduce a 401 para que el cliente refresque su sesión y reintente.
/// </summary>
public class SupabaseUnauthorizedException : SupabaseDomainException
{
    public SupabaseUnauthorizedException(string message) : base(message)
    {
    }

    public SupabaseUnauthorizedException(string message, Exception innerException) : base(message, innerException)
    {
    }
}
