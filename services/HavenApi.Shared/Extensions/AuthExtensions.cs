using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;

namespace HavenApi.Shared.Extensions;

public static class AuthExtensions
{
    public static IServiceCollection AddHavenJwtAuth(this IServiceCollection services, IConfiguration configuration)
    {
        var supabaseUrl = configuration["Supabase:Url"];
        if (string.IsNullOrEmpty(supabaseUrl))
        {
            throw new ArgumentNullException("Supabase:Url", "Supabase URL no está configurada.");
        }

        var supabaseIssuer = $"{supabaseUrl}/auth/v1";

        services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
            .AddJwtBearer(options =>
            {
                options.Authority = supabaseIssuer;
                options.RequireHttpsMetadata = false;

                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidIssuer = supabaseIssuer,
                    ValidateAudience = true,
                    ValidAudience = "authenticated",
                    ValidateLifetime = false,
                    ValidateIssuerSigningKey = true
                };
            });

        return services;
    }
}
