using Microsoft.AspNetCore.Authorization;

namespace Pagos.Api.Authentication;

public class RolCondominioRequirement : IAuthorizationRequirement
{
    public HashSet<string> RolesPermitidos { get; }

    public RolCondominioRequirement(params string[] rolesPermitidos)
    {
        RolesPermitidos = new HashSet<string>(rolesPermitidos, StringComparer.OrdinalIgnoreCase);
    }
}
