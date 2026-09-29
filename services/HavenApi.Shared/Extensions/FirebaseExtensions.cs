using System;
using FirebaseAdmin;
using Google.Apis.Auth.OAuth2;
using HavenApi.Shared.Services;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;

namespace HavenApi.Shared.Extensions;

public static class FirebaseExtensions
{
    public static IServiceCollection AddHavenFirebase(this IServiceCollection services, IConfiguration configuration)
    {
        var loggerFactory = LoggerFactory.Create(builder => builder.AddConsole());
        var logger = loggerFactory.CreateLogger("FirebaseExtensions");

        if (FirebaseApp.DefaultInstance == null)
        {
            try
            {
                var credentialPath = configuration["Firebase:CredentialPath"];
                if (!string.IsNullOrEmpty(credentialPath) && System.IO.File.Exists(credentialPath))
                {
                    FirebaseApp.Create(new AppOptions()
                    {
                        Credential = GoogleCredential.FromFile(credentialPath)
                    });
                    logger.LogInformation("FirebaseApp initialized from {CredentialPath}", credentialPath);
                }
                else
                {
                    // Attempt to use Application Default Credentials (e.g. from GOOGLE_APPLICATION_CREDENTIALS environment variable)
                    FirebaseApp.Create(new AppOptions()
                    {
                        Credential = GoogleCredential.GetApplicationDefault()
                    });
                    logger.LogInformation("FirebaseApp initialized using Application Default Credentials.");
                }
            }
            catch (Exception ex)
            {
                logger.LogWarning(ex, "Failed to initialize FirebaseApp. Push notifications might not work. Please check your credentials configuration.");
            }
        }

        services.AddSingleton<IFirebaseNotificationService, FirebaseNotificationService>();
        return services;
    }
}
