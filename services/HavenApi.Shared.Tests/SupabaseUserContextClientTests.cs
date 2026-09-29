using System;
using System.Net;
using System.Net.Http;
using System.Threading;
using System.Threading.Tasks;
using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Rpc;
using Xunit;

namespace HavenApi.Shared.Tests;

public class SupabaseUserContextClientTests
{
    private class FakeHttpMessageHandler : HttpMessageHandler
    {
        private readonly HttpStatusCode _statusCode;
        private readonly string _responseBody;
        private readonly Exception? _exceptionToThrow;
        public HttpRequestMessage? LastRequest { get; private set; }

        public FakeHttpMessageHandler(HttpStatusCode statusCode, string responseBody)
        {
            _statusCode = statusCode;
            _responseBody = responseBody;
        }

        public FakeHttpMessageHandler(Exception exceptionToThrow)
        {
            _exceptionToThrow = exceptionToThrow;
            _responseBody = "";
        }

        protected override Task<HttpResponseMessage> SendAsync(
            HttpRequestMessage request, CancellationToken cancellationToken)
        {
            LastRequest = request;

            if (_exceptionToThrow != null)
            {
                throw _exceptionToThrow;
            }

            var response = new HttpResponseMessage(_statusCode)
            {
                Content = new StringContent(_responseBody, System.Text.Encoding.UTF8, "application/json")
            };
            return Task.FromResult(response);
        }
    }

    private readonly string _baseUrl = "https://fake.supabase.co";
    private readonly string _anonKey = "fake-anon-key";
    private readonly string _accessToken = "fake-access-token";
    private readonly Guid _userId = Guid.NewGuid();

    [Fact]
    public async Task GetContextoUsuarioAsync_UsuarioConRolYCondominio_RetornaAmbos()
    {
        var condominioId = Guid.NewGuid();
        var json = $"[{{\"rol_nombre\":\"Administrador\",\"condominio_id\":\"{condominioId}\"}}]";
        var handler = new FakeHttpMessageHandler(HttpStatusCode.OK, json);
        var httpClient = new HttpClient(handler);

        var (rol, cond) = await SupabaseUserContextClient.GetContextoUsuarioAsync(
            httpClient, _baseUrl, _anonKey, _userId, _accessToken);

        Assert.Equal("Administrador", rol);
        Assert.Equal(condominioId, cond);

        Assert.NotNull(handler.LastRequest);
        Assert.Equal($"{_baseUrl}/rest/v1/vw_usuarios?id=eq.{_userId}&select=rol_nombre,condominio_id", handler.LastRequest.RequestUri?.ToString());
        Assert.True(handler.LastRequest.Headers.TryGetValues("apikey", out var apikeyValues));
        Assert.Contains(_anonKey, apikeyValues);
        Assert.Equal("Bearer", handler.LastRequest.Headers.Authorization?.Scheme);
        Assert.Equal(_accessToken, handler.LastRequest.Headers.Authorization?.Parameter);
    }

    [Fact]
    public async Task GetContextoUsuarioAsync_UsuarioSinCondominio_RetornaRolYNull()
    {
        var json = "[{\"rol_nombre\":\"Vigilancia\",\"condominio_id\":null}]";
        var handler = new FakeHttpMessageHandler(HttpStatusCode.OK, json);
        var httpClient = new HttpClient(handler);

        var (rol, cond) = await SupabaseUserContextClient.GetContextoUsuarioAsync(
            httpClient, _baseUrl, _anonKey, _userId, _accessToken);

        Assert.Equal("Vigilancia", rol);
        Assert.Null(cond);
    }

    [Fact]
    public async Task GetContextoUsuarioAsync_ArregloVacio_RetornaNulls()
    {
        var json = "[]";
        var handler = new FakeHttpMessageHandler(HttpStatusCode.OK, json);
        var httpClient = new HttpClient(handler);

        var (rol, cond) = await SupabaseUserContextClient.GetContextoUsuarioAsync(
            httpClient, _baseUrl, _anonKey, _userId, _accessToken);

        Assert.Null(rol);
        Assert.Null(cond);
    }

    [Fact]
    public async Task GetContextoUsuarioAsync_Respuesta401_RetornaNulls()
    {
        var handler = new FakeHttpMessageHandler(HttpStatusCode.Unauthorized, "");
        var httpClient = new HttpClient(handler);

        var (rol, cond) = await SupabaseUserContextClient.GetContextoUsuarioAsync(
            httpClient, _baseUrl, _anonKey, _userId, _accessToken);

        Assert.Null(rol);
        Assert.Null(cond);
    }

    [Fact]
    public async Task GetContextoUsuarioAsync_JsonInvalido_LanzaSupabaseResponseException()
    {
        var handler = new FakeHttpMessageHandler(HttpStatusCode.OK, "no-es-json");
        var httpClient = new HttpClient(handler);

        await Assert.ThrowsAsync<SupabaseResponseException>(() =>
            SupabaseUserContextClient.GetContextoUsuarioAsync(httpClient, _baseUrl, _anonKey, _userId, _accessToken));
    }

    [Fact]
    public async Task GetContextoUsuarioAsync_ErrorDeRed_LanzaSupabaseUnavailableException()
    {
        var handler = new FakeHttpMessageHandler(new HttpRequestException("network error"));
        var httpClient = new HttpClient(handler);

        await Assert.ThrowsAsync<SupabaseUnavailableException>(() =>
            SupabaseUserContextClient.GetContextoUsuarioAsync(httpClient, _baseUrl, _anonKey, _userId, _accessToken));
    }
}
