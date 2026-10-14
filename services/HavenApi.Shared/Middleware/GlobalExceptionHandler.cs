using HavenApi.Shared.Exceptions;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace HavenApi.Shared.Middleware;

public class GlobalExceptionHandler : IExceptionHandler
{
    private readonly ILogger<GlobalExceptionHandler> _logger;
    private readonly IHostEnvironment _env;

    public GlobalExceptionHandler(ILogger<GlobalExceptionHandler> logger, IHostEnvironment env)
    {
        _logger = logger;
        _env = env;
    }

    public async ValueTask<bool> TryHandleAsync(HttpContext httpContext, Exception exception, CancellationToken cancellationToken)
    {
        var statusCode = StatusCodes.Status500InternalServerError;
        var title = "An unexpected error occurred.";

        var exponerDetalle = false;

        switch (exception)
        {
            case SupabaseUnauthorizedException:
                statusCode = StatusCodes.Status401Unauthorized;
                title = "Token expirado o inválido.";
                exponerDetalle = true;
                _logger.LogWarning("Supabase rejected the user's access token: {Message}", exception.Message);
                break;
            case SupabaseUnavailableException:
                statusCode = StatusCodes.Status503ServiceUnavailable;
                title = "Service dependency unavailable.";
                _logger.LogError(exception, "Supabase service is unavailable.");
                break;
            case SupabaseResponseException:
                statusCode = StatusCodes.Status502BadGateway;
                title = "Invalid response from upstream service.";
                _logger.LogError(exception, "Invalid response received from Supabase.");
                break;
            default:
                _logger.LogError(exception, "An unhandled exception occurred during the request.");
                break;
        }

        var problemDetails = new ProblemDetails
        {
            Status = statusCode,
            Title = title,
            Detail = _env.IsDevelopment() || exponerDetalle ? exception.Message : "Please contact support if the issue persists.",
            Instance = httpContext.Request.Path
        };

        if (exponerDetalle)
        {
            problemDetails.Extensions["error"] = exception.Message;
        }

        if (_env.IsDevelopment())
        {
            problemDetails.Extensions["traceId"] = httpContext.TraceIdentifier;
            problemDetails.Extensions["stackTrace"] = exception.StackTrace;
        }
        else
        {
            problemDetails.Extensions["traceId"] = httpContext.TraceIdentifier;
        }

        httpContext.Response.StatusCode = statusCode;
        await httpContext.Response.WriteAsJsonAsync(problemDetails, cancellationToken);

        return true;
    }
}
