using System;
using System.Collections.Generic;
using System.Threading.Tasks;
using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Microsoft.Extensions.Logging;

namespace HavenApi.Shared.Services;

public class FirebaseNotificationService : IFirebaseNotificationService
{
    private readonly ILogger<FirebaseNotificationService> _logger;

    public FirebaseNotificationService(ILogger<FirebaseNotificationService> logger)
    {
        _logger = logger;
    }

    public async Task<bool> SendToTopicAsync(string topic, string title, string body, Dictionary<string, string> data)
    {
        try
        {
            if (FirebaseApp.DefaultInstance == null)
            {
                _logger.LogWarning("FirebaseApp is not initialized. Cannot send push notification to {Topic}", topic);
                return false;
            }

            var message = new Message()
            {
                Notification = new Notification
                {
                    Title = title,
                    Body = body,
                },
                Data = data,
                Topic = topic,
                Android = new AndroidConfig
                {
                    Priority = Priority.High,
                    Notification = new AndroidNotification
                    {
                        ChannelId = "haven_high_importancechannel"
                    }
                }
            };

            string response = await FirebaseMessaging.DefaultInstance.SendAsync(message);
            _logger.LogInformation("Successfully sent message to topic {Topic}: {Response}", topic, response);
            return true;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error sending push notification to topic {Topic}", topic);
            return false;
        }
    }
}
