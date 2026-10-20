using Microsoft.AspNetCore.Mvc;
using HavenApi.Shared.Filters;

namespace Pagos.Api.Controllers;

[ApiController]
public class HealthController : ControllerBase
{
    [HttpGet("api/health/public")]
    public IActionResult GetPublicHealth()
    {
        return Ok(new { status = "ok", servicio = "Pagos.Api" });
    }

    [HttpGet("api/health/dev-only")]
    [RequireDevKey]
    public IActionResult GetDevOnlyHealth()
    {
        return Ok(new { status = "ok, autenticado como dev" });
    }
}
