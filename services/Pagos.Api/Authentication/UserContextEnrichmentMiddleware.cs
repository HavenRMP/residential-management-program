using System.Security.Claims;
using HavenApi.Shared.Rpc;

namespace Pagos.Api.Authentication;

/// <summary>
/// Middleware que enriquece el ClaimsPrincipal del usuario autenticado consultando
/// la vista 'vw_usuarios' si el token no incluye 'condominio_id' o 'rol' de negocio en sus claims.
/// </summary>
public class UserContextEnrichmentMiddleware
{
    private readonly RequestDelegate _next;
    private readonly ILogger<UserContextEnrichmentMiddleware> _logger;

    public UserContextEnrichmentMiddleware(RequestDelegate next, ILogger<UserContextEnrichmentMiddleware> logger)
    {
        _next = next;
        _logger = logger;
    }

    public async Task InvokeAsync(
        HttpContext context,
        IConfiguration configuration,
        IHttpClientFactory httpClientFactory)
    {
        if (context.User.Identity?.IsAuthenticated == true)
        {
            var tieneCondominio = TokenClaimsExtractor.TryGetCondominioId(context.User, out _);
            var rol = TokenClaimsExtractor.GetRol(context.User);
            var tieneRol = !string.IsNullOrWhiteSpace(rol);

            // Si falta condominio o rol de negocio, consultamos la vista vw_usuarios
            if (!tieneCondominio || !tieneRol)
            {
                if (TokenClaimsExtractor.TryGetUserId(context.User, out var userId))
                {
                    var authHeader = context.Request.Headers.Authorization.ToString();
                    var accessToken = authHeader.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)
                        ? authHeader.Substring(7).Trim()
                        : string.Empty;

                    var baseUrl = configuration["Supabase:Url"];
                    var anonKey = configuration["Supabase:AnonKey"];

                    if (!string.IsNullOrEmpty(baseUrl) && !string.IsNullOrEmpty(anonKey) && !string.IsNullOrEmpty(accessToken))
                    {
                        try
                        {
                            var httpClient = httpClientFactory.CreateClient("UserContextLookup");
                            var (rolNombre, condominioId) = await SupabaseUserContextClient.GetContextoUsuarioAsync(
                                httpClient, baseUrl, anonKey, userId, accessToken);

                            if (string.IsNullOrWhiteSpace(rolNombre) && !condominioId.HasValue)
                            {
                                _logger.LogWarning("Consulta a 'vw_usuarios' no devolvió registro para userId {UserId}", userId);
                            }
                            else
                            {
                                var claims = new List<Claim>();
                                if (!tieneCondominio && condominioId.HasValue)
                                {
                                    claims.Add(new Claim("condominio_id", condominioId.Value.ToString()));
                                }

                                if (!tieneRol && !string.IsNullOrWhiteSpace(rolNombre))
                                {
                                    claims.Add(new Claim("rol", rolNombre));
                                    claims.Add(new Claim("role", rolNombre));
                                    claims.Add(new Claim(ClaimTypes.Role, rolNombre));
                                }

                                if (claims.Count > 0)
                                {
                                    var identity = new ClaimsIdentity(claims);
                                    context.User.AddIdentity(identity);
                                    _logger.LogInformation("Contexto de usuario enriquecido desde 'vw_usuarios' para userId {UserId}: Rol='{Rol}', Condominio='{CondominioId}'",
                                        userId, rolNombre, condominioId);
                                }
                            }
                        }
                        catch (Exception ex)
                        {
                            _logger.LogError(ex, "Error al consultar 'vw_usuarios' para userId {UserId}", userId);
                        }
                    }
                    else
                    {
                        _logger.LogWarning("No se pudo consultar 'vw_usuarios': configuración de Supabase o accessToken ausente.");
                    }
                }
            }
        }

        await _next(context);
    }
}

public static class UserContextEnrichmentMiddlewareExtensions
{
    public static IApplicationBuilder UseUserContextEnrichment(this IApplicationBuilder app)
    {
        return app.UseMiddleware<UserContextEnrichmentMiddleware>();
    }
}
