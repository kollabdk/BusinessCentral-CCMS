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
if ($null -eq $projectId) {
    Write-Host "Project not found. Aborting!" -ForegroundColor Red
    return
}

# Update files
foreach ($filename in (Get-ChildItem -Path $appProjectFolder -Include *.g.xlf -Recurse)) {
    $documentId = $null
    Write-Host $filename.Name
    Write-Host "Get Document Id"
    $json = (Invoke-WebRequest -Method Get -Uri "https://smartcat.ai/api/integration/v1/project/${projectId}" -Headers $headers -UseBasicParsing).Content | ConvertFrom-Json
    for ($i = 0; $i -lt $json.documents.Length; $i++) {
        if (("$($json.documents[$i].name).xlf" -eq $filename.Name) -and ($json.documents[$i].targetLanguage -eq 'da')) {
            $documentId = $json.documents[$i].id
        }
    }
    if ($null -eq $documentId) {
        Write-Host "Document not found. Add to project" -ForegroundColor Red
    }
    else {
        Write-Host "Document ID : $DocumentId"
    
        # Remove UTF-8 BOM
        $XliffRaw = Get-Content -Raw $filename.FullName
        $UTF8NoBomEncoding = New-Object System.Text.UTF8Encoding $false
        [System.IO.File]::WriteAllLines($filename.FullName, $XliffRaw, $UTF8NoBomEncoding)

        $URL = "https://smartcat.ai/api/integration/v1/document/update?documentId=$documentId"
        $fileContent = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($filename.FullName))
        if ($fileContent.Length -lt 100) {
            throw "File $($filename.FullName) read as $($fileContent.Length) bytes. Aborting!"
        }
        $boundary = [System.Guid]::NewGuid().ToString()
        $LF = "`r`n"
        $bodyLines = ( 
            "--$boundary",
            "Content-Disposition: form-data; name=`"file`"; filename=`"$($filename.Name)`"",
            "Content-Type: application/octet-stream",
            "",
            $fileContent,	
            "--$boundary--$LF" 
        ) -join $LF

        Write-Host "Uploading file $($filename.FullName)"
        $Result = Invoke-RestMethod -Uri $URL -Method Put -ContentType "multipart/form-data; boundary=`"$boundary`"" -Headers $headers -Body $bodyLines
        Write-Host "Document contains $($Result.wordsCount) words"
    }
}

Write-Host "Smartcat upload completed." -ForegroundColor Green
Write-Host ""
