using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Mvc.Abstractions;
using Microsoft.AspNetCore.Mvc.Filters;
using Microsoft.AspNetCore.Routing;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using HavenApi.Shared.Filters;
using Xunit;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace HavenApi.Shared.Tests;

public class RequireDevKeyAttributeTests
{
    private ActionExecutingContext CreateContext(string? configuredKey, string? headerValue)
    {
        var httpContext = new DefaultHttpContext();

        var builder = new ConfigurationBuilder();
        if (configuredKey != null)
        {
            builder.AddInMemoryCollection(new Dictionary<string, string?> { ["DevTools:ApiKey"] = configuredKey });
        }
        var configuration = builder.Build();

        var services = new ServiceCollection();
        services.AddSingleton<IConfiguration>(configuration);
        httpContext.RequestServices = services.BuildServiceProvider();

        if (headerValue != null)
        {
            httpContext.Request.Headers["X-Dev-Key"] = headerValue;
        }

        var actionContext = new ActionContext(httpContext, new RouteData(), new ActionDescriptor());
        var context = new ActionExecutingContext(
            actionContext,
            new List<IFilterMetadata>(),
            new Dictionary<string, object?>(),
            null!
        );

        // We capture this variable using an array or a class level field if needed, but since it's an out parameter it's a bit tricky for the lambda.
        // Instead of out parameter in next(), we will just return a state object or we can use a wrapper.
        return context;
    }

    [Fact]
    public async Task OnActionExecutionAsync_KeyNotConfigured_ValidHeader_Rejects()
    {
        var context = CreateContext(null, "some-key");
        
        bool nextCalled = false;
        ActionExecutionDelegate next = () =>
        {
            nextCalled = true;
            return Task.FromResult<ActionExecutedContext>(new ActionExecutedContext(context, new List<IFilterMetadata>(), null!));
        };

        var attribute = new RequireDevKeyAttribute();
        await attribute.OnActionExecutionAsync(context, next);

        Assert.False(nextCalled);
        var objectResult = Assert.IsType<ObjectResult>(context.Result);
        Assert.Equal(401, objectResult.StatusCode);
    }

    [Fact]
    public async Task OnActionExecutionAsync_KeyConfigured_NoHeader_Rejects()
    {
        var context = CreateContext("secret-key", null);
        
        bool nextCalled = false;
        ActionExecutionDelegate next = () =>
        {
            nextCalled = true;
            return Task.FromResult<ActionExecutedContext>(new ActionExecutedContext(context, new List<IFilterMetadata>(), null!));
        };

        var attribute = new RequireDevKeyAttribute();
        await attribute.OnActionExecutionAsync(context, next);

        Assert.False(nextCalled);
        var objectResult = Assert.IsType<ObjectResult>(context.Result);
        Assert.Equal(401, objectResult.StatusCode);
    }

    [Fact]
    public async Task OnActionExecutionAsync_KeyConfigured_IncorrectHeader_Rejects()
    {
        var context = CreateContext("secret-key", "wrong-key");
        
        bool nextCalled = false;
        ActionExecutionDelegate next = () =>
        {
            nextCalled = true;
            return Task.FromResult<ActionExecutedContext>(new ActionExecutedContext(context, new List<IFilterMetadata>(), null!));
        };

        var attribute = new RequireDevKeyAttribute();
        await attribute.OnActionExecutionAsync(context, next);

        Assert.False(nextCalled);
        var objectResult = Assert.IsType<ObjectResult>(context.Result);
        Assert.Equal(401, objectResult.StatusCode);
    }

    [Fact]
    public async Task OnActionExecutionAsync_KeyConfigured_CorrectHeader_LetsPass()
    {
        var context = CreateContext("secret-key", "secret-key");
        
        bool nextCalled = false;
        ActionExecutionDelegate next = () =>
        {
            nextCalled = true;
            return Task.FromResult<ActionExecutedContext>(new ActionExecutedContext(context, new List<IFilterMetadata>(), null!));
        };

        var attribute = new RequireDevKeyAttribute();
        await attribute.OnActionExecutionAsync(context, next);

        Assert.True(nextCalled);
        Assert.Null(context.Result);
    }
}
