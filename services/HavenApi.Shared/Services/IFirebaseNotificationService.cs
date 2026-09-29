using System.Collections.Generic;
using System.Threading.Tasks;

namespace HavenApi.Shared.Services;

public interface IFirebaseNotificationService
{
    Task<bool> SendToTopicAsync(string topic, string title, string body, Dictionary<string, string> data);
}
