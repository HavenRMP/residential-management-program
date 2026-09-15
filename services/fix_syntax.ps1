$files = Get-ChildItem -Path "c:\Users\EQUIPO\Haven\residential-management-program\services" -Recurse -Filter "*Tests.cs"

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw
    $modified = $false
    
    if ($content -match 'var payload = Convert\.ToBase64String\(System\.Text\.Encoding\.UTF8\.GetBytes\(\$"\{\\"sub\\":\\"{userId}\\".*?"\}\"\)\)\.TrimEnd') {
        $replacement = 'private string GenerateFakeToken(Guid userId)
    {
        var header = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes("{\"alg\":\"none\"}")).TrimEnd(''='').Replace(''+'', ''-'').Replace(''/'', ''_'');
        var payload = Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes($"{{\"sub\":\"" + userId + "\",\"http://schemas.xmlsoap.org/ws/2005/05/identity/claims/nameidentifier\":\"" + userId + "\"}}")).TrimEnd(''='').Replace(''+'', ''-'').Replace(''/'', ''_'');
        return $"{header}.{payload}.";
    }'
        $content = $content -replace '(?s)private string GenerateFakeToken\(Guid userId\).*?return \$\"\{header\}\.\{payload\}\.\";\s*\}', $replacement
        $modified = $true
    }

    if ($modified) {
        Set-Content -Path $file.FullName -Value $content -NoNewline
        Write-Host "Fixed $($file.Name)"
    }
}
