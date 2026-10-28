Param(
    [string] $appFilePath,
    [ValidateSet('app', 'testApp', 'bcptApp')]
    [string] $appType,
    [ref] $parameters
)

if ($appType -eq 'app') {
    Write-Host "PostCompileApp :"
    Write-Host "  appProjectFolder    : " $parameters.Value["appProjectFolder"]

    # Read Smartcat project name safely from AL-Go settings JSON (injected as $env:Settings)
    $smartcatProjectName = $null
    if ($env:Settings) {
        $settingsObject = $env:Settings | ConvertFrom-Json
        if ($settingsObject.PSObject.Properties.Name -contains 'smartcatProjectName') {
            $smartcatProjectName = $settingsObject.smartcatProjectName
        }
    }
    if (-not $smartcatProjectName) {
        Write-Host "Warning: smartcatProjectName not set in settings.json."
        return
    }

    # Upload SmartCat
    Write-Host "Smartcat project name: $smartcatProjectName"
    $smartcatScriptPath = Join-Path -Path $PSScriptRoot -ChildPath ".\KollabSmartcatUpload.ps1"
    if (Test-Path $smartcatScriptPath) {
        . $smartcatScriptPath -projectName $smartcatProjectName -appProjectFolder $parameters.Value["appProjectFolder"]
    }
    else {
        throw "Error: KollabSmartcatUpload.ps1 not found at $smartcatScriptPath."
    }
}
