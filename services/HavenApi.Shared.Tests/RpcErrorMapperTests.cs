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
    [InlineData("PQ001", 404)]
    [InlineData("PQ002", 403)]
    [InlineData("PQ003", 400)]
    [InlineData("PQ004", 409)]
    [InlineData("PQ005", 400)]
    [InlineData("PQ006", 400)]
    [InlineData("PQ007", 403)]
    [InlineData("PQ008", 400)]
    [InlineData("PQ009", 400)]
    [InlineData("PQ010", 403)]
    [InlineData("PQ011", 403)]
    [InlineData("RE001", 404)]
    [InlineData("RE002", 404)]
    [InlineData("RE003", 403)]
    [InlineData("RE004", 409)]
    [InlineData("RE005", 400)]
    [InlineData("RE006", 400)]
    [InlineData("RE007", 400)]
    [InlineData("RE008", 409)]
    [InlineData("RE009", 409)]
    [InlineData("RE010", 400)]
    [InlineData("RE011", 409)]
    [InlineData("RE012", 409)]
    [InlineData("RE013", 409)]
    [InlineData("RE014", 403)]
    [InlineData("RE015", 404)]
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
