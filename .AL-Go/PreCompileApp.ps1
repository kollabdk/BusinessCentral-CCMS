Param(
    [string] $appType,
    [ref] $compilationParams
)

if ($appType -eq 'app') {
    Write-Host "PreCompileApp"
    Write-Host "compilationParams: "
    $compilationParams | Format-Table -AutoSize

    # Download SmartCat
    $smartcatProjectName = $null
    if ($env:Settings) {
        $settingsObject = $env:Settings | ConvertFrom-Json
        if ($settingsObject.PSObject.Properties.Name -contains 'smartcatProjectName') {
            $smartcatProjectName = $settingsObject.smartcatProjectName
        }
    }
    if (-not $smartcatProjectName) {
        Write-Host "smartcatProjectName not set in settings."
        return
    }

    # Download SmartCat"
    Write-Host "Smartcat project name: $smartcatProjectName"
    $smartcatScriptPath = Join-Path -Path $PSScriptRoot -ChildPath ".\KollabSmartcatDownload.ps1"
    if (Test-Path $smartcatScriptPath) {
        . $smartcatScriptPath -projectName $smartcatProjectName -appProjectFolder $compilationParams.Value["appProjectFolder"]
    }
    else {
        Write-Host "Error: KollabSmartcatDownload.ps1 not found at $smartcatScriptPath."
    }
}
