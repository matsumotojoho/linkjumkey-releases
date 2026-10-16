#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$DemoBaseUrl = 'http://127.0.0.1:8765',
    [string]$DemoToken,
    [string]$DemoTokenFile = (Join-Path $PSScriptRoot 'demo-data/demo-api-token.txt'),
    [string]$ReportDirectory = (Join-Path $PSScriptRoot 'demo-data/reports'),
    [string]$LinkJumkeyBaseUrl,
    [string]$LinkJumkeyToken,
    [string]$Project = 'AI連携検証・架空顧客'
)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'CustomerDemo.psm1') -Force
if (-not $DemoToken) { $DemoToken = [IO.File]::ReadAllText($DemoTokenFile, [Text.Encoding]::UTF8).Trim() }
$script:checks = 0
function Assert-Demo($Condition, [string]$Message) {
    if (-not $Condition) { throw ('FAIL: ' + $Message) }
    $script:checks++
    Write-Output ('PASS: ' + $Message)
}
function Search-Demo([string]$Query) {
    Invoke-DemoCustomerSearch -BaseUrl $DemoBaseUrl -Token $DemoToken -Query $Query
}
foreach ($file in @('CustomerDemo.psm1','Search-Customer.ps1','LinkJumkey-PC-code.ps1','Test-WindowsDemo.ps1')) {
    $bytes = [IO.File]::ReadAllBytes((Join-Path $PSScriptRoot $file))
    Assert-Demo ($bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) ($file + ' is UTF-8 with BOM')
    $tokens = $null; $parseErrors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile((Join-Path $PSScriptRoot $file), [ref]$tokens, [ref]$parseErrors)
    Assert-Demo (@($parseErrors).Count -eq 0) ($file + ' parses on this PowerShell runtime')
}
$result = Search-Demo 'ｻｸﾗ'
Assert-Demo ($result.count -eq 2) 'halfwidth kana matches fullwidth and halfwidth stored kana'
$result = Search-Demo 'ｶﾞﾗｽ'
Assert-Demo ($result.rows[0].CustomerId -eq 'DEMO-008') 'halfwidth voiced kana matches ガラス'
$result = Search-Demo "O'Reilly & Sons"
Assert-Demo ($result.rows[0].CustomerId -eq 'DEMO-003') 'quotes and ampersands are data'
$report = Write-DemoReport -Rows @($result.rows) -Query "O'Reilly & Sons" -Directory $ReportDirectory -ReportBaseUrl $DemoBaseUrl
$csv = @(Import-Csv -LiteralPath $report.CsvPath -Encoding UTF8)
Assert-Demo ($csv[0].CustomerName -eq "架空 O'Reilly & Sons") 'CSV round trip preserves Japanese and quotes'
$bytes = [IO.File]::ReadAllBytes($report.CsvPath)
Assert-Demo ($bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) 'CSV has UTF-8 BOM'
Assert-Demo ((Invoke-WebRequest -UseBasicParsing -Uri $report.ResultUrl -TimeoutSec 5).StatusCode -eq 200) 'generated report URL resolves through the actual adapter'
Assert-Demo ((Search-Demo '%_').count -eq 1) 'SQL wildcard characters remain literal'
Assert-Demo ((Search-Demo "' OR 1=1; DROP TABLE customers; --").count -eq 0) 'SQL injection query returns zero records'
Assert-Demo ((Search-Demo '架空').count -eq 8) 'database remains intact after injection query'
Assert-Demo ((Search-Demo '$(Write-Output hacked); & | < > " ` % ! ^ ( )').count -eq 0) 'shell metacharacters remain data'
Assert-Demo ((Search-Demo "第一行`n第二行").count -eq 1) 'inner newline is preserved as one query'
$result = Search-Demo '=HYPERLINK'
$formulaReport = Write-DemoReport -Rows @($result.rows) -Query '=HYPERLINK' -Directory $ReportDirectory -ReportBaseUrl $DemoBaseUrl
$csv = @(Import-Csv -LiteralPath $formulaReport.CsvPath -Encoding UTF8)
Assert-Demo ($csv[0].CustomerName.StartsWith("'=")) 'spreadsheet formula cell is prefixed with apostrophe'
Assert-Demo ($csv[0].Contact.StartsWith("'+")) 'spreadsheet plus-prefix cell is escaped'
$result = Search-Demo '<script>'
$escapedReport = Write-DemoReport -Rows @($result.rows) -Query '<script>' -Directory $ReportDirectory -ReportBaseUrl $DemoBaseUrl
$html = [IO.File]::ReadAllText($escapedReport.HtmlPath)
Assert-Demo ($html.Contains('&lt;script&gt;') -and -not $html.Contains('<script>')) 'HTML query and customer cells are escaped'
$emptyReport = Write-DemoReport -Rows @() -Query '存在しない架空顧客' -Directory $ReportDirectory -ReportBaseUrl $DemoBaseUrl
Assert-Demo ($emptyReport.Count -eq 0 -and [IO.File]::ReadAllText($emptyReport.CsvPath).Contains('CustomerId')) 'zero-match CSV retains header'
foreach ($invalid in @('', '   ', (('x' * 8193)), ('x' + [char]0 + 'y'))) {
    $rejected = $false
    try { $null = Get-DemoQuery $invalid } catch { $rejected = $true }
    Assert-Demo $rejected 'invalid/empty/over-limit query rejected'
}
$rejected = $false
try { $null = Invoke-DemoCustomerSearch -BaseUrl $DemoBaseUrl -Token 'wrong-demo-token' -Query '架空' } catch { $rejected = $true }
Assert-Demo $rejected 'wrong demo token rejected'
foreach ($invalidBase in @('https://example.com', 'http://127.0.0.1:8765/api', 'http://127.0.0.1:8765/?query=x', 'http://user@127.0.0.1:8765')) {
    $rejected = $false
    try { $null = Assert-LoopbackBaseUrl $invalidBase } catch { $rejected = $true }
    Assert-Demo $rejected 'invalid or external base URL rejected before credentials are sent'
}
if ($LinkJumkeyBaseUrl -or $LinkJumkeyToken) {
    if (-not $LinkJumkeyBaseUrl -or -not $LinkJumkeyToken) { throw 'Both LinkJumkey test parameters are required.' }
    $library = Get-LinkJumkeyDemoProjects -BaseUrl $LinkJumkeyBaseUrl -Token $LinkJumkeyToken
    Assert-Demo ($library.ok -eq $true) 'fixture projects authorized GET succeeds'
    Assert-Demo (@($library.projects | Where-Object { [string]::Equals($_.name, $Project, [StringComparison]::Ordinal) }).Count -eq 1) 'destination is selected from project object.name exactly'
    $registration = Add-LinkJumkeyDemoResult -BaseUrl $LinkJumkeyBaseUrl -Token $LinkJumkeyToken -Project $Project -ResultUrl $report.ResultUrl
    Assert-Demo ($registration.ok -eq $true -and $registration.button.id -and $registration.project.name -ceq $Project) 'fixture quick-add returns saved button and exact project'
    $repeat = Add-LinkJumkeyDemoResult -BaseUrl $LinkJumkeyBaseUrl -Token $LinkJumkeyToken -Project $Project -ResultUrl $report.ResultUrl
    Assert-Demo ($repeat.created -eq $false -and $repeat.replayed -eq $true -and $repeat.button.id -ceq $registration.button.id) 'same report retry reuses the saved button'
    Write-Output ('OBSERVED_BUTTON=' + ($registration.button | ConvertTo-Json -Depth 12 -Compress))
}
Write-Output ('Completed ' + $script:checks + ' assertions on PowerShell ' + $PSVersionTable.PSVersion)
