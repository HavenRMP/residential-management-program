using Microsoft.AspNetCore.Authorization;

namespace Pagos.Api.Authentication;

public class RolCondominioHandler : AuthorizationHandler<RolCondominioRequirement>
{
    private readonly ILogger<RolCondominioHandler> _logger;

    public RolCondominioHandler(ILogger<RolCondominioHandler>? logger = null)
    {
        _logger = logger ?? Microsoft.Extensions.Logging.Abstractions.NullLogger<RolCondominioHandler>.Instance;
    }

    protected override Task HandleRequirementAsync(AuthorizationHandlerContext context, RolCondominioRequirement requirement)
    {
        if (context.User.Identity?.IsAuthenticated != true)
        {
            return Task.CompletedTask;
        }

        // 1. Validar que el token traiga un condominio_id válido
        if (!TokenClaimsExtractor.TryGetCondominioId(context.User, out var condominioId))
        {
            var msg = "El usuario autenticado no tiene un 'condominio_id' asignado ni en claims ni en vw_usuarios.";
            _logger.LogWarning("Autorización rechazada: {Reason}", msg);
            context.Fail(new AuthorizationFailureReason(this, msg));
            return Task.CompletedTask;
        }

        // 2. Validar que el rol esté dentro de los roles permitidos por la política
        var rol = TokenClaimsExtractor.GetRol(context.User);
        if (string.IsNullOrWhiteSpace(rol) || !requirement.RolesPermitidos.Contains(rol))
        {
            var msg = $"El rol '{rol}' no tiene autorización. Roles permitidos: [{string.Join(", ", requirement.RolesPermitidos)}]";
            _logger.LogWarning("Autorización rechazada: {Reason}", msg);
            context.Fail(new AuthorizationFailureReason(this, msg));
            return Task.CompletedTask;
        }

        _logger.LogInformation("Autorización exitosa. Rol: '{Rol}', Condominio: '{CondominioId}'",
            rol, condominioId);

        context.Succeed(requirement);
        return Task.CompletedTask;
    }
}
