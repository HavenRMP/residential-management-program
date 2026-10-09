using System;

namespace HavenApi.Shared.Roles;

public static class RolExtensions
{
    public static bool EsAdministrador(this string? rol)
    {
        return string.Equals(rol, RolesHaven.AdministradorNombre, StringComparison.OrdinalIgnoreCase);
    }

    public static bool EsVigilancia(this string? rol)
    {
        return string.Equals(rol, RolesHaven.VigilanciaNombre, StringComparison.OrdinalIgnoreCase);
    }

    public static bool PuedeConsultarDatosResidenciales(this string? rol)
    {
        return rol.EsAdministrador() || rol.EsVigilancia();
    }

    public static bool EsResidente(this string? rol)
    {
        return string.Equals(rol, RolesHaven.ResidenteNombre, StringComparison.OrdinalIgnoreCase);
    }

    public static bool EsMantenimiento(this string? rol)
    {
        return string.Equals(rol, RolesHaven.MantenimientoNombre, StringComparison.OrdinalIgnoreCase);
    }

    public static bool EsRolDeSoloLectura(this string? rol)
    {
        return rol.EsVigilancia() || rol.EsMantenimiento();
    }
}
