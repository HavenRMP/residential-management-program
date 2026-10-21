using System.Security.Claims;
using HavenApi.Shared.Roles;
using Microsoft.AspNetCore.Http;
using Pagos.Api.Authentication;

namespace Pagos.Api.Services;

public class UserContextService : IUserContextService
{
    private readonly IHttpContextAccessor _httpContextAccessor;

    public UserContextService(IHttpContextAccessor httpContextAccessor)
    {
        _httpContextAccessor = httpContextAccessor;
    }

    private ClaimsPrincipal? User => _httpContextAccessor.HttpContext?.User;

    public bool IsAuthenticated => User?.Identity?.IsAuthenticated ?? false;

    public Guid UserId
    {
        get
        {
            if (User != null && TokenClaimsExtractor.TryGetUserId(User, out var userId))
            {
                return userId;
            }
            throw new InvalidOperationException("No se encontró un ID de usuario válido en el token (claim 'sub').");
        }
    }

    public string? Rol => User != null ? TokenClaimsExtractor.GetRol(User) : null;

    public Guid CondominioId
    {
        get
        {
            if (User != null && TokenClaimsExtractor.TryGetCondominioId(User, out var condominioId))
            {
                return condominioId;
            }
            throw new InvalidOperationException("El token no contiene un 'app_metadata.condominio_id' válido.");
        }
    }

    public bool EsAdmin => string.Equals(Rol, RolesHaven.AdministradorNombre, StringComparison.OrdinalIgnoreCase)
                        || string.Equals(Rol, "Admin", StringComparison.OrdinalIgnoreCase);

    public bool EsInquilino => string.Equals(Rol, RolesHaven.ResidenteNombre, StringComparison.OrdinalIgnoreCase)
                            || string.Equals(Rol, "Inquilino", StringComparison.OrdinalIgnoreCase);
}
