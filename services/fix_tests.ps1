$files = Get-ChildItem -Path "c:\Users\EQUIPO\Haven\residential-management-program\services" -Recurse -Filter "*Tests.cs"

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $modified = $false
    
    # Fix GenerateFakeToken
    if ($content -match 'private string GenerateFakeToken\(Guid userId\)') {
        $replacement = 'private string GenerateFakeToken(Guid userId)
    {
        var header = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes("{\"alg\":\"none\"}")).TrimEnd(''='').Replace(''+'', ''-'').Replace(''/'', ''_'');
        var payload = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes($"{\"sub\":\"{userId}\",\"http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier\":\"{userId}\"}")).TrimEnd(''='').Replace(''+'', ''-'').Replace(''/'', ''_'');
        return $"{header}.{payload}.";
    }'
        $content = $content -replace '(?s)private string GenerateFakeToken\(Guid userId\).*?return handler\.WriteToken\(token\);\s*\}', $replacement
        $modified = $true
    }

    # Fix API Route in AsignarCondominioAdminTests
    if ($file.Name -eq 'AsignarCondominioAdminTests.cs') {
        $content = $content -replace '/api/auth/\{userId\}/condominio', '/api/usuarios/{userId}/condominio'
        $modified = $true
    }

    if ($modified) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Modified $($file.Name)"
    }
}
