using System;

namespace HavenApi.Shared.Services;

public static class FirebaseTopics
{
    public static string GetUserTopic(Guid userId)
    {
        return $"user{userId:N}";
    }
}
