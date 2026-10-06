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
    [InlineData("VI001", 404)]
    [InlineData("VI002", 403)]
    [InlineData("VI003", 409)]
    [InlineData("VI004", 404)]
    [InlineData("VI005", 410)]
    [InlineData("VI006", 409)]
    [InlineData("VI007", 409)]
    [InlineData("VI008", 400)]
    [InlineData("VI009", 404)]
    [InlineData("P0002", 404)]
    [InlineData("SU004", 400)]
    [InlineData("42501", 403)]
    [InlineData("22023", 400)]
    [InlineData("RC001", 404)]
    [InlineData("RC002", 400)]
    [InlineData("RC003", 404)]
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
