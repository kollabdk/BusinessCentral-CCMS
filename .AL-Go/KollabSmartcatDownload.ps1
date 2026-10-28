Param(
    [string] $projectName,
    [string] $appProjectFolder = '.'
)

# Read Smartcat project name safely from AL-Go settings JSON (injected as $env:Settings)
if (-not $projectName) {
    $settingsPath = Join-Path -Path $appProjectFolder -ChildPath ".AL-Go\settings.json"
    if (Test-Path $settingsPath) {
        $settingsObject = Get-Content -Path $settingsPath -Raw | ConvertFrom-Json
        if ($settingsObject.PSObject.Properties.Name -contains 'smartcatProjectName') {
            $projectName = $settingsObject.smartcatProjectName
        }
    }
}
if (-not $projectName) {
    Write-Host "smartcatProjectName not set in projectName parameter or .AL-Go\settings.json."
    return
}

###
### https://smartcat.com/api/methods/#/
###
$username = '32187351-2b4f-4894-91fe-c163d5f64424'
$password = '1_KVX7E0Gwxt5PhT60PQ51zeOue'

# Get Project
$bytes = [System.Text.Encoding]::ASCII.GetBytes("${username}:${password}")
$base64 = [System.Convert]::ToBase64String($bytes)
$basicAuth = "Basic $base64"
$headers = @{ Authorization = $basicAuth }
$json = (Invoke-WebRequest -Method Get -Uri "https://smartcat.ai/api/integration/v1/project/list?projectName=${projectName}" -Headers $headers -UseBasicParsing).Content | ConvertFrom-Json
for ($i = 0; $i -lt $json.length; $i++) {
    if ($json[$i].name -eq $projectName) {
        $projectId = $json[$i].id
    }
}
Write-Host "Project Id $projectId" -ForegroundColor White

# Download translation for files
foreach ($filename in (Get-ChildItem -Path . -Include *.g.xlf -Recurse)) {
    $documentId = $null
    $documentName = ''
    Write-Host $filename.Name
    Write-Host "Get Document Id"

    $json = (Invoke-WebRequest -Method Get -Uri "https://smartcat.ai/api/integration/v1/project/${projectId}" -Headers $headers -UseBasicParsing).Content | ConvertFrom-Json
    for ($i = 0; $i -lt $json.documents.Length; $i++) {
        if (("$($json.documents[$i].name).xlf" -eq $filename.Name) -and ($json.documents[$i].targetLanguage -eq 'da')) {
            $documentId = $json.documents[$i].id
            $documentName = $json.documents[$i].name
        }
    }
    if ($null -eq $documentId) {
        Write-Host "Document not found. Add to project" -ForegroundColor Red
    }
    else {
        Write-Host "Document ID : $DocumentId"
    
        # Start task and wait for complete
        $json = (Invoke-WebRequest -Method Post -Uri "https://smartcat.ai/api/integration/v1/document/export?documentIds=$($documentId)&type=target" -Headers $headers -UseBasicParsing) | ConvertFrom-Json 
        $taskId = $json.id
        Write-Host "Export Task ID $taskId" -ForegroundColor White
        $retrySchedule = (@(1) * 10) + (@(3) * 10) + (@(6) * 10)
        $data = $null
        foreach ($delay in $retrySchedule) {
            $data = (Invoke-WebRequest -Method Get -Uri "https://smartcat.ai/api/integration/v1/document/export/$taskId" -Headers $headers -UseBasicParsing -ContentType "application/octet-stream" )
            Write-Host "Task $($data.StatusDescription)"  -ForegroundColor White
            if ($data.StatusCode -ne '204') { break }
            Start-Sleep -Seconds $delay
        }

        # Modify Target language
        if ($data.Content[0] -eq 239) {
            Write-Host "Removing BOM"
            $lastByte = $data.Content.Length
            [xml]$xml = [System.Text.Encoding]::UTF8.GetString($data.Content[3 .. $lastByte])
        }
        else {
            [xml]$xml = [System.Text.Encoding]::UTF8.GetString($data.Content)
        }
        $xml.xliff.file.'target-language' = 'da-DK'
        $xml.xliff.file.datatype = 'xml'

        # Save document
        $targetFilename = "$documentName(da).xlf"
        $targetPath = (Join-Path -Path $filename.DirectoryName -ChildPath $targetFilename)
        Write-Host "Saving document to $targetPath"
        $xml.Save($targetPath)
    }
}
