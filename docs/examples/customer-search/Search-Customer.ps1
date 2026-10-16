#requires -Version 5.1
[CmdletBinding()]
param(
    [AllowEmptyString()][string]$Query = $env:LINKJUMKEY_INPUT,
    [string]$DemoBaseUrl = 'http://127.0.0.1:8765',
    [string]$DemoToken,
    [string]$DemoTokenFile = (Join-Path $PSScriptRoot 'demo-data/demo-api-token.txt'),
    [string]$ReportDirectory = (Join-Path $PSScriptRoot 'demo-data/reports'),
    [switch]$OpenReport,
    [switch]$RegisterResult,
    [string]$LinkJumkeyBaseUrl,
    [string]$LinkJumkeyToken,
    [string]$Project
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'CustomerDemo.psm1') -Force
try {
    $queryValue = Get-DemoQuery $Query
    if (-not $DemoToken) { $DemoToken = [IO.File]::ReadAllText($DemoTokenFile, [Text.Encoding]::UTF8).Trim() }
    if ($RegisterResult) {
        if (-not $LinkJumkeyBaseUrl -or -not $LinkJumkeyToken -or -not $Project) { throw 'Registration requires explicit LinkJumkeyBaseUrl, LinkJumkeyToken and Project.' }
        $null = Assert-LoopbackBaseUrl $LinkJumkeyBaseUrl
    }
    $response = Invoke-DemoCustomerSearch -BaseUrl $DemoBaseUrl -Token $DemoToken -Query $queryValue
    $report = Write-DemoReport -Rows @($response.rows) -Query $queryValue -Directory $ReportDirectory -ReportBaseUrl $DemoBaseUrl
    Write-Output ('検索件数: ' + $report.Count)
    Write-Output ('CSV: ' + $report.CsvPath)
    Write-Output ('レポート: ' + $report.ResultUrl)
    if ($RegisterResult) {
        # Ensure the configured local report directory is actually served before creating a button.
        $served = Invoke-WebRequest -UseBasicParsing -Method Get -Uri $report.ResultUrl -TimeoutSec 5 -MaximumRedirection 0
        if ($served.StatusCode -ne 200) { throw 'Report URL is not reachable. Registration was not attempted.' }
        $registration = Add-LinkJumkeyDemoResult -BaseUrl $LinkJumkeyBaseUrl -Token $LinkJumkeyToken -Project $Project -ResultUrl $report.ResultUrl
        Write-Output ('LinkJumkey保存先: ' + $registration.project.name)
        Write-Output ('ボタンID: ' + $registration.button.id + ' / 再送: ' + $registration.replayed)
    }
    if ($OpenReport) { Start-Process -FilePath $report.ResultUrl }
} catch {
    # The LinkJumkey PC-code wrapper must use exit on failure, because stdin statements can otherwise continue.
    Write-Error $_ -ErrorAction Continue
    exit 1
}
