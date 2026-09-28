using HavenApi.Shared.Roles;
using Usuarios.Api.DTOs;
using Xunit;

namespace Usuarios.Api.Tests;

public class UsuarioDtoEffectiveRolTests
{
    [Fact]
    public void EffectiveRol_WithRol_ReturnsRol()
    {
        // Arrange
        var dto = new UsuarioDto { Rol = RolesHaven.AdministradorNombre, Role = "Algo", RoleId = 2 };

        // Act
        var result = dto.EffectiveRol;

        // Assert
        Assert.Equal(RolesHaven.AdministradorNombre, result);
    }

    [Fact]
    public void EffectiveRol_WithRole_ReturnsRole_WhenRolIsEmpty()
    {
        // Arrange
        var dto = new UsuarioDto { Rol = "", Role = RolesHaven.ResidenteNombre, RoleId = 1 };

        // Act
        var result = dto.EffectiveRol;

        // Assert
        Assert.Equal(RolesHaven.ResidenteNombre, result);
    }

    [Theory]
    [InlineData(1, RolesHaven.AdministradorNombre)]
    [InlineData(2, RolesHaven.ResidenteNombre)]
    [InlineData(3, RolesHaven.VigilanciaNombre)]
    [InlineData(4, RolesHaven.MantenimientoNombre)]
    public void EffectiveRol_WithRoleIdAsInt_ReturnsExpectedNombre(int roleId, string expectedNombre)
    {
        // Arrange
        var dto = new UsuarioDto { RoleId = roleId };

        // Act
        var result = dto.EffectiveRol;

        // Assert
        Assert.Equal(expectedNombre, result);
    }

    [Theory]
    [InlineData("1", RolesHaven.AdministradorNombre)]
    [InlineData("2", RolesHaven.ResidenteNombre)]
    [InlineData("3", RolesHaven.VigilanciaNombre)]
    [InlineData("4", RolesHaven.MantenimientoNombre)]
    public void EffectiveRol_WithRolIdAsString_ReturnsExpectedNombre(string rolId, string expectedNombre)
    {
        // Arrange
        var dto = new UsuarioDto { RolId = rolId };

        // Act
        var result = dto.EffectiveRol;

        // Assert
        Assert.Equal(expectedNombre, result);
    }

    [Fact]
    public void EffectiveRol_WithoutAnyData_ReturnsResidente()
    {
        // Arrange
        var dto = new UsuarioDto();

        // Act
        var result = dto.EffectiveRol;

        // Assert
        Assert.Equal(RolesHaven.ResidenteNombre, result);
    }
}
