using Microsoft.AspNetCore.Authorization;

namespace Pagos.Api.Authentication;

public class RolCondominioHandler : AuthorizationHandler<RolCondominioRequirement>
{
    protected override Task HandleRequirementAsync(AuthorizationHandlerContext context, RolCondominioRequirement requirement)
    {
        if (context.User.Identity?.IsAuthenticated != true)
        {
            return Task.CompletedTask;
        }

        // 1. Validar que el token traiga un app_metadata.condominio_id válido
        if (!TokenClaimsExtractor.TryGetCondominioId(context.User, out _))
        {
            context.Fail(new AuthorizationFailureReason(this, "El token no contiene un condominio_id válido en app_metadata."));
            return Task.CompletedTask;
        }

        // 2. Validar que el rol esté dentro de los roles permitidos por la política
        var rol = TokenClaimsExtractor.GetRol(context.User);
        if (string.IsNullOrWhiteSpace(rol) || !requirement.RolesPermitidos.Contains(rol))
        {
            context.Fail(new AuthorizationFailureReason(this, $"El rol '{rol}' no tiene autorización para esta política."));
            return Task.CompletedTask;
        }

        context.Succeed(requirement);
        return Task.CompletedTask;
    }
}
