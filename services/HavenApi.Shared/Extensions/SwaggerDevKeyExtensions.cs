using Microsoft.Extensions.DependencyInjection;
using Microsoft.OpenApi;
using Swashbuckle.AspNetCore.SwaggerGen;
using System.Collections.Generic;

namespace HavenApi.Shared.Extensions;

public static class SwaggerDevKeyExtensions
{
    public static SwaggerGenOptions AddDevKeySecurityDefinition(this SwaggerGenOptions options)
    {
        options.AddSecurityDefinition("DevKey", new OpenApiSecurityScheme
        {
            Name = "X-Dev-Key",
            Type = SecuritySchemeType.ApiKey,
            In = ParameterLocation.Header,
            Description = "Introduce el ApiKey de desarrollo (DevTools:ApiKey) en el formato: {tu_apikey_aqui}"
        });

        options.AddSecurityRequirement(document => new OpenApiSecurityRequirement
        {
            [new OpenApiSecuritySchemeReference("DevKey", document)] = new List<string>()
        });

        return options;
    }
}
