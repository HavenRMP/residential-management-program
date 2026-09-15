using System;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Rpc;
using Xunit;

namespace HavenApi.Shared.Tests;

public class FakeHttpMessageHandler : HttpMessageHandler
{
    private readonly HttpStatusCode _statusCode;
    private readonly string _responseBody;
    public HttpRequestMessage? LastRequest { get; private set; }

    public FakeHttpMessageHandler(HttpStatusCode statusCode, string responseBody)
    {
        _statusCode = statusCode;
        _responseBody = responseBody;
    }

    protected override Task<HttpResponseMessage> SendAsync(
        HttpRequestMessage request, CancellationToken cancellationToken)
    {
        LastRequest = request;
        var response = new HttpResponseMessage(_statusCode)
        {
            Content = new StringContent(_responseBody, System.Text.Encoding.UTF8, "application/json")
        };
        return Task.FromResult(response);
    }
}

public record TestResultDto(string Nombre);

public class SupabaseRpcClientTests
{
    private readonly string _supabaseUrl = "https://fake.supabase.co";
    private readonly string _serviceRoleKey = "fake-service-role-key";
    private readonly Guid _actorId = Guid.NewGuid();
    private readonly object _payload = new { };

    [Fact]
    public async Task PostRpcAsync_SuccessResponse_ReturnsParsedObjectAndChecksHeaders()
    {
        // Arrange
        var rpcName = "nombre_de_prueba";
        var body = "{\"Nombre\":\"Prueba\"}";
        var handler = new FakeHttpMessageHandler(HttpStatusCode.OK, body);
        var httpClient = new HttpClient(handler);

        // Act
        var result = await SupabaseRpcClient.PostRpcAsync<TestResultDto>(
            httpClient, _supabaseUrl, _serviceRoleKey, rpcName, _payload, _actorId);

        // Assert
        Assert.NotNull(result);
        Assert.Equal("Prueba", result.Nombre);

        Assert.NotNull(handler.LastRequest);
        Assert.EndsWith($"/rest/v1/rpc/{rpcName}", handler.LastRequest.RequestUri?.ToString());
        
        Assert.True(handler.LastRequest.Headers.TryGetValues("x-actor-id", out var actorIdValues));
        Assert.Contains(_actorId.ToString(), actorIdValues);

        Assert.True(handler.LastRequest.Headers.TryGetValues("apikey", out var apikeyValues));
        Assert.Contains(_serviceRoleKey, apikeyValues);
    }

    [Fact]
    public async Task PostRpcAsync_StructuredErrorResponse_ThrowsSupabaseRpcExceptionWithCode()
    {
        // Arrange
        var rpcName = "nombre_de_prueba";
        var body = "{\"code\":\"CD001\",\"message\":\"no existe\"}";
        var handler = new FakeHttpMessageHandler(HttpStatusCode.BadRequest, body);
        var httpClient = new HttpClient(handler);

        // Act & Assert
        var ex = await Assert.ThrowsAsync<SupabaseRpcException>(() =>
            SupabaseRpcClient.PostRpcAsync<TestResultDto>(
                httpClient, _supabaseUrl, _serviceRoleKey, rpcName, _payload, _actorId));

        Assert.Equal("CD001", ex.Code);
    }

    [Fact]
    public async Task PostRpcAsync_MalformedErrorResponse_ThrowsSupabaseRpcExceptionWithUnknownCode()
    {
        // Arrange
        var rpcName = "nombre_de_prueba";
        var body = "Internal Server Error"; // Not JSON
        var handler = new FakeHttpMessageHandler(HttpStatusCode.InternalServerError, body);
        var httpClient = new HttpClient(handler);

        // Act & Assert
        var ex = await Assert.ThrowsAsync<SupabaseRpcException>(() =>
            SupabaseRpcClient.PostRpcAsync<TestResultDto>(
                httpClient, _supabaseUrl, _serviceRoleKey, rpcName, _payload, _actorId));

        Assert.Equal("UNKNOWN", ex.Code);
    }
}
