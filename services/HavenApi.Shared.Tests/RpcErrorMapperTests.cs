using HavenApi.Shared.Exceptions;
using HavenApi.Shared.Rpc;
using Xunit;

namespace HavenApi.Shared.Tests;

public class RpcErrorMapperTests
{
    [Theory]
    [InlineData("CD001", 404)]
    [InlineData("CD002", 409)]
    [InlineData("CD003", 410)]
    [InlineData("CD004", 409)]
    [InlineData("23505", 409)]
    [InlineData("ALGO_DESCONOCIDO", 500)]
    [InlineData("", 500)]
    public void Map_ShouldReturnExpectedStatusCode(string code, int expectedStatusCode)
    {
        // Arrange
        var ex = new SupabaseRpcException(code, "mensaje de prueba");

        // Act
        var result = RpcErrorMapper.Map(ex);

        // Assert
        Assert.Equal(expectedStatusCode, result.StatusCode);
        Assert.False(string.IsNullOrWhiteSpace(result.MensajeUsuario), "El mensaje de usuario no debería estar vacío");
    }
}
