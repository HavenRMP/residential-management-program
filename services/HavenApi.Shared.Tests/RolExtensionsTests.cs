using HavenApi.Shared.Roles;
using Xunit;

namespace HavenApi.Shared.Tests;

public class RolExtensionsTests
{
    [Theory]
    [InlineData("Administrador", true)]
    [InlineData("administrador", true)]
    [InlineData("Vigilancia", false)]
    [InlineData("VIGILANCIA", false)]
    [InlineData("Residente", false)]
    [InlineData("Mantenimiento", false)]
    [InlineData("", false)]
    [InlineData(null, false)]
    public void EsAdministrador_DeberiaRetornarValorEsperado(string? rol, bool esperado)
    {
        var resultado = rol.EsAdministrador();
        Assert.Equal(esperado, resultado);
    }

    [Theory]
    [InlineData("Administrador", false)]
    [InlineData("administrador", false)]
    [InlineData("Vigilancia", true)]
    [InlineData("VIGILANCIA", true)]
    [InlineData("Residente", false)]
    [InlineData("Mantenimiento", false)]
    [InlineData("", false)]
    [InlineData(null, false)]
    public void EsVigilancia_DeberiaRetornarValorEsperado(string? rol, bool esperado)
    {
        var resultado = rol.EsVigilancia();
        Assert.Equal(esperado, resultado);
    }

    [Theory]
    [InlineData("Administrador", true)]
    [InlineData("administrador", true)]
    [InlineData("Vigilancia", true)]
    [InlineData("VIGILANCIA", true)]
    [InlineData("Residente", false)]
    [InlineData("Mantenimiento", false)]
    [InlineData("", false)]
    [InlineData(null, false)]
    public void PuedeConsultarDatosResidenciales_DeberiaRetornarValorEsperado(string? rol, bool esperado)
    {
        var resultado = rol.PuedeConsultarDatosResidenciales();
        Assert.Equal(esperado, resultado);
    }
}
