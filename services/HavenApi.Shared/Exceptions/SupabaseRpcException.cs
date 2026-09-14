namespace HavenApi.Shared.Exceptions;

public class SupabaseRpcException : SupabaseDomainException
{
    public string Code { get; }

    public SupabaseRpcException(string code, string message) : base(message)
    {
        Code = code;
    }
}
