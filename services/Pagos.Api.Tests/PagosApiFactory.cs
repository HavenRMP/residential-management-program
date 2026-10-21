using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Protocols;
using Microsoft.IdentityModel.Protocols.OpenIdConnect;
using Moq;
using Pagos.Api.Clients;

namespace Pagos.Api.Tests;

public class PagosApiFactory : WebApplicationFactory<Program>
{
    public Mock<ISupabaseRestClient> MockSupabaseRestClient { get; } = new();

    public PagosApiFactory()
    {
        Environment.SetEnvironmentVariable("Supabase__Url", "http://localhost:54321");
        Environment.SetEnvironmentVariable("Supabase__AnonKey", "test-anon-key");
        Environment.SetEnvironmentVariable("Supabase__ServiceRoleKey", "test-service-key");
        Environment.SetEnvironmentVariable("NO_GCE_CHECK", "true");
    }

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
            services.PostConfigure<JwtBearerOptions>(
                JwtBearerDefaults.AuthenticationScheme,
                options =>
                {
                    options.Authority = null;
                    options.ConfigurationManager = new StaticConfigurationManager<OpenIdConnectConfiguration>(new OpenIdConnectConfiguration());
                    options.TokenValidationParameters.ValidateIssuer = false;
                    options.TokenValidationParameters.ValidateAudience = false;
                    options.TokenValidationParameters.ValidateLifetime = false;
                    options.TokenValidationParameters.ValidateIssuerSigningKey = false;
                    options.TokenValidationParameters.RequireSignedTokens = false;
                });

            var descriptor = services.SingleOrDefault(d => d.ServiceType == typeof(ISupabaseRestClient));
            if (descriptor != null)
            {
                services.Remove(descriptor);
            }
            services.AddSingleton(MockSupabaseRestClient.Object);
        });
    }
}
