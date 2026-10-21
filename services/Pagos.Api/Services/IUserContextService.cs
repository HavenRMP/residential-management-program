namespace Pagos.Api.Services;

public interface IUserContextService
{
    Guid UserId { get; }
    string? Rol { get; }
    Guid CondominioId { get; }
    bool IsAuthenticated { get; }
    bool EsAdmin { get; }
    bool EsInquilino { get; }
}
