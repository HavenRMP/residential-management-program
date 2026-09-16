# ─────────────────────────────────────────────────────────────
# Stage 1: Build
# ─────────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copiar proyectos y restaurar (Asumiendo contexto de build en la raíz del monorepo)
COPY ["services/Avisos.Api/Avisos.Api.csproj", "services/Avisos.Api/"]
COPY ["services/HavenApi.Shared/HavenApi.Shared.csproj", "services/HavenApi.Shared/"]
RUN dotnet restore "services/Avisos.Api/Avisos.Api.csproj"

# Copiar el resto del código y publicar en modo Release
COPY . .
WORKDIR "/src/services/Avisos.Api"
RUN dotnet publish -c Release -o /app/publish --no-restore

# ─────────────────────────────────────────────────────────────
# Stage 2: Runtime (imagen más ligera, sin SDK)
# ─────────────────────────────────────────────────────────────
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app

# Copiar el artefacto publicado del stage anterior
COPY --from=build /app/publish ./

# Render inyecta la variable PORT dinámicamente
# ASP.NET Core la lee con ASPNETCORE_URLS
ENV ASPNETCORE_URLS=http://+:${PORT:-8080}
ENV DOTNET_HOSTBUILDER__RELOADCONFIGONCHANGE=false

EXPOSE 8080

ENTRYPOINT ["dotnet", "Avisos.Api.dll"]
