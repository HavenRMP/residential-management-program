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

    [Theory]
    [InlineData("Residente", true)]
    [InlineData("residente", true)]
    [InlineData("Administrador", false)]
    [InlineData("Vigilancia", false)]
    [InlineData("Mantenimiento", false)]
    [InlineData("", false)]
    [InlineData(null, false)]
    public void EsResidente_DeberiaRetornarValorEsperado(string? rol, bool esperado)
    {
        var resultado = rol.EsResidente();
        Assert.Equal(esperado, resultado);
    }

    [Theory]
    [InlineData("Mantenimiento", true)]
    [InlineData("MANTENIMIENTO", true)]
    [InlineData("Administrador", false)]
    [InlineData("Vigilancia", false)]
    [InlineData("Residente", false)]
    [InlineData("", false)]
    [InlineData(null, false)]
    public void EsMantenimiento_DeberiaRetornarValorEsperado(string? rol, bool esperado)
    {
        var resultado = rol.EsMantenimiento();
        Assert.Equal(esperado, resultado);
    }

    [Theory]
    [InlineData("Vigilancia", true)]
    [InlineData("vigilancia", true)]
    [InlineData("Mantenimiento", true)]
    [InlineData("mantenimiento", true)]
    [InlineData("Administrador", false)]
    [InlineData("Residente", false)]
    [InlineData("", false)]
    [InlineData(null, false)]
    public void EsRolDeSoloLectura_DeberiaRetornarValorEsperado(string? rol, bool esperado)
    {
        var resultado = rol.EsRolDeSoloLectura();
        Assert.Equal(esperado, resultado);
    }
}
