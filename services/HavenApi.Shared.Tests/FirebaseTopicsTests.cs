using System;
using HavenApi.Shared.Services;
using Xunit;

namespace HavenApi.Shared.Tests;

public class FirebaseTopicsTests
{
    [Fact]
    public void GetUserTopic_ShouldReturnExpectedFormat()
    {
        // Arrange
        var userId = new Guid("11111111-2222-3333-4444-555555555555");
        var expectedTopic = "user11111111222233334444555555555555";

        // Act
        var topic = FirebaseTopics.GetUserTopic(userId);

        // Assert
        Assert.Equal(expectedTopic, topic);
    }
}
