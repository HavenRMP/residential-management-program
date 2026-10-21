using HavenApi.Shared.Extensions;
using HavenApi.Shared.Roles;
using Microsoft.AspNetCore.Authorization;
using Pagos.Api.Authentication;
using Pagos.Api.Clients;
using Pagos.Api.DTOs;
using Pagos.Api.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddHavenJwtAuth(builder.Configuration);

builder.Services.AddHavenExceptionHandler();

builder.Services.AddHttpContextAccessor();
builder.Services.AddSingleton(TimeProvider.System);
builder.Services.AddScoped<IUserContextService, UserContextService>();
builder.Services.AddScoped<IViviendasLookupService, ViviendasLookupService>();
builder.Services.AddScoped<ICargosService, CargosService>();
builder.Services.AddScoped<IPagosService, PagosService>();

builder.Services.Configure<ComprobanteOptions>(builder.Configuration.GetSection(ComprobanteOptions.SectionName));
builder.Services.AddSingleton<IComprobanteProcessor, ComprobanteProcessor>();

builder.Services.Configure<StorageOptions>(builder.Configuration.GetSection(StorageOptions.SectionName));
builder.Services.AddHttpClient<IComprobanteStorageService, ComprobanteStorageService>();

builder.Services.AddSingleton<IAuthorizationHandler, RolCondominioHandler>();

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy("Admin", policy =>
        policy.Requirements.Add(new RolCondominioRequirement(RolesHaven.AdministradorNombre, "Admin")));

    options.AddPolicy("Inquilino", policy =>
        policy.Requirements.Add(new RolCondominioRequirement(RolesHaven.ResidenteNombre, "Inquilino")));

    options.AddPolicy("AdminOInquilino", policy =>
        policy.Requirements.Add(new RolCondominioRequirement(
            RolesHaven.AdministradorNombre, "Admin", RolesHaven.ResidenteNombre, "Inquilino")));
});

builder.Services.AddHttpClient<ISupabaseRestClient, SupabaseRestClient>();

builder.Services.AddControllers()
    .AddJsonOptions(options =>
    {
        options.JsonSerializerOptions.Converters.Add(new System.Text.Json.Serialization.JsonStringEnumConverter());
    });

builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new Microsoft.OpenApi.OpenApiInfo
    {
        Title = "Pagos API",
        Version = "v1",
        Description = "Microservicio de Pagos para el sistema de gestión residencial Haven."
    });

    options.AddSecurityDefinition("Bearer", new Microsoft.OpenApi.OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = Microsoft.OpenApi.SecuritySchemeType.ApiKey,
        Scheme = "Bearer",
        BearerFormat = "JWT",
        In = Microsoft.OpenApi.ParameterLocation.Header,
        Description = "Introduce el token JWT (access_token de la sesión de Supabase) en el formato: Bearer {tu_token_aqui}"
    });

    options.AddSecurityRequirement(document => new Microsoft.OpenApi.OpenApiSecurityRequirement { [new Microsoft.OpenApi.OpenApiSecuritySchemeReference("Bearer", document)] = new System.Collections.Generic.List<string>() });
});

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowClients", policy =>
    {
        policy.AllowAnyOrigin()
              .AllowAnyHeader()
              .AllowAnyMethod();
    });
});

var app = builder.Build();

app.UseHavenExceptionHandler();

app.UseSwagger();
app.UseSwaggerUI(options =>
{
    options.SwaggerEndpoint("/swagger/v1/swagger.json", "Pagos API v1");
});

app.UseCors("AllowClients");

app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();

public partial class Program { }
