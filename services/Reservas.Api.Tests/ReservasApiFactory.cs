using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Moq;
using Reservas.Api.Services;
using System.Collections.Generic;
using System.Linq;

namespace Reservas.Api.Tests;

public class ReservasApiFactory : WebApplicationFactory<Program>
{
    public Mock<ISupabaseService> MockSupabaseService { get; } = new Mock<ISupabaseService>();

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.ConfigureAppConfiguration((context, configBuilder) =>
        {
            configBuilder.AddInMemoryCollection(new Dictionary<string, string?>
            {
                { "Supabase:Url", "http://localhost:54321" },
                { "Supabase:AnonKey", "test-anon-key" },
                { "Supabase:ServiceRoleKey", "test-service-key" },
                { "DevTools:ApiKey", "test-dev-key" }
            });
        });

        builder.ConfigureServices(services =>
        {
            services.PostConfigure<Microsoft.AspNetCore.Authentication.JwtBearer.JwtBearerOptions>(
                Microsoft.AspNetCore.Authentication.JwtBearer.JwtBearerDefaults.AuthenticationScheme,
                options =>
                {
                    options.Authority = null;
                    options.TokenValidationParameters.ValidateIssuer = false;
                    options.TokenValidationParameters.ValidateAudience = false;
                    options.TokenValidationParameters.ValidateLifetime = false;
                    options.TokenValidationParameters.ValidateIssuerSigningKey = false;
                    options.TokenValidationParameters.RequireSignedTokens = false;
                });

            var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseService));
            if (descriptor != null)
            {
                services.Remove(descriptor);
            }
            services.AddSingleton(MockSupabaseService.Object);
        });
    }
}
