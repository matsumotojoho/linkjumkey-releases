Set-StrictMode -Version 2.0

function Assert-LoopbackBaseUrl {
    param([Parameter(Mandatory=$true)][string]$Value)
    $parsed = $null
    if (-not [Uri]::TryCreate($Value, [UriKind]::Absolute, [ref]$parsed)) { throw 'Base URL must be an absolute URL.' }
    if ($parsed.Scheme -ne 'http' -or $parsed.Host -ne '127.0.0.1' -or $parsed.UserInfo -or $parsed.Query -or $parsed.Fragment -or $parsed.AbsolutePath -ne '/') {
        throw 'This demo accepts only http://127.0.0.1:PORT with no credentials, path, query or fragment.'
    }
    return $Value.TrimEnd('/')
}

function Get-DemoQuery {
    param([AllowEmptyString()][string]$Value)
    $query = $Value.Trim()
    if (-not $query) { throw '検索語を入力してください。空欄では全顧客を出力しません。' }
    if ($query.Length -gt 8192 -or $query.IndexOf([char]0) -ge 0) { throw '検索語は8192文字以内で、NULを含めないでください。' }
    return $query
}

function Invoke-DemoCustomerSearch {
    param([string]$BaseUrl, [string]$Token, [string]$Query)
    $base = Assert-LoopbackBaseUrl $BaseUrl
    if ([string]::IsNullOrWhiteSpace($Token) -or $Token -match '[\r\n]') { throw 'Supply the demo API token.' }
    $queryValue = Get-DemoQuery $Query
    $json = @{ query = $queryValue } | ConvertTo-Json -Compress
    $response = Invoke-RestMethod -Method Post -Uri ($base + '/customers/search') -Headers @{ Authorization = 'Bearer ' + $Token } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($json)) -TimeoutSec 10 -MaximumRedirection 0
    if ($response.ok -ne $true -or $response.syntheticData -ne $true) { throw 'Demo API returned an unexpected result.' }
    return $response
}

function ConvertTo-SafeCsvCell {
    param([AllowEmptyString()][string]$Value)
    # Prefix spreadsheet formula triggers, including those preceded by whitespace/control characters.
    if ($Value -match '^[\s\p{Cc}]*[=+@-]') { return "'" + $Value }
    return $Value
}

function Write-DemoReport {
    param([object[]]$Rows, [string]$Query, [string]$Directory, [string]$ReportBaseUrl)
    $base = Assert-LoopbackBaseUrl $ReportBaseUrl
    $null = [IO.Directory]::CreateDirectory($Directory)
    $directoryPath = [IO.Path]::GetFullPath($Directory)
    $reportId = [Guid]::NewGuid().ToString('N')
    $csvPath = Join-Path $directoryPath ($reportId + '.csv')
    $htmlPath = Join-Path $directoryPath ($reportId + '.html')
    $columns = @('CustomerId', 'CustomerName', 'Kana', 'Prefecture', 'Contact', 'Notes')
    $safeRows = @($Rows | ForEach-Object {
        $row = $_
        $fields = [ordered]@{}
        foreach ($column in $columns) { $fields[$column] = ConvertTo-SafeCsvCell ([string]$row.$column) }
        [pscustomobject]$fields
    })
    if ($safeRows.Count -gt 0) {
        $csvLines = @($safeRows | ConvertTo-Csv -NoTypeInformation)
    } else {
        $csvLines = @(($columns | ForEach-Object { '"' + $_ + '"' }) -join ',')
    }
    $utf8Bom = New-Object Text.UTF8Encoding($true)
    [IO.File]::WriteAllText($csvPath, (($csvLines -join "`r`n") + "`r`n"), $utf8Bom)
    $html = New-Object Text.StringBuilder
    $null = $html.Append('<!doctype html><html lang="ja"><meta charset="utf-8"><title>架空顧客の検索結果</title><style>body{font:16px sans-serif;margin:2rem;color:#182231}table{border-collapse:collapse;width:100%}th,td{padding:.65rem;border:1px solid #bbb;text-align:left;white-space:pre-wrap}th{background:#edf3f7}p{white-space:pre-wrap}</style><h1>架空顧客の検索結果</h1><p>合成データ専用のデモです。</p><p>検索語: ')
    $null = $html.Append([Net.WebUtility]::HtmlEncode($Query))
    $null = $html.Append('</p><p>件数: ' + $Rows.Count + '</p><p><a href="' + $reportId + '.csv">CSVをダウンロード</a>（UTF-8 BOM、数式として解釈される値は先頭にアポストロフィを追加）</p><table><thead><tr>')
    foreach ($column in $columns) { $null = $html.Append('<th>' + [Net.WebUtility]::HtmlEncode($column) + '</th>') }
    $null = $html.Append('</tr></thead><tbody>')
    foreach ($row in $Rows) {
        $null = $html.Append('<tr>')
        foreach ($column in $columns) { $null = $html.Append('<td>' + [Net.WebUtility]::HtmlEncode([string]$row.$column) + '</td>') }
        $null = $html.Append('</tr>')
    }
    $null = $html.Append('</tbody></table></html>')
    [IO.File]::WriteAllText($htmlPath, $html.ToString(), $utf8Bom)
    return [pscustomobject]@{ Count = $Rows.Count; CsvPath = $csvPath; HtmlPath = $htmlPath; ResultUrl = $base + '/reports/' + $reportId + '.html' }
}

function Get-LinkJumkeyDemoProjects {
    param([string]$BaseUrl, [string]$Token)
    $base = Assert-LoopbackBaseUrl $BaseUrl
    if ([string]::IsNullOrWhiteSpace($Token) -or $Token -match '[\r\n]') { throw 'Supply the LinkJumkey API token explicitly.' }
    $response = Invoke-RestMethod -Method Get -Uri ($base + '/api/projects') -Headers @{ Authorization = 'Bearer ' + $Token } -TimeoutSec 10 -MaximumRedirection 0
    if ($response.ok -ne $true -or -not $response.PSObject.Properties['projects']) { throw 'LinkJumkey project read failed. Desktop 1.8.24 or later is required.' }
    foreach ($item in @($response.projects)) {
        if (-not ($item.name -is [string]) -or -not ($item.id -is [string]) -or -not ($item.rootId -is [string])) { throw 'Unexpected project response.' }
    }
    return $response
}

function Add-LinkJumkeyDemoResult {
    param([string]$BaseUrl, [string]$Token, [string]$Project, [string]$ResultUrl)
    $base = Assert-LoopbackBaseUrl $BaseUrl
    if ([string]::IsNullOrWhiteSpace($Token) -or $Token -match '[\r\n]') { throw 'Supply the LinkJumkey API token explicitly.' }
    if ([string]::IsNullOrWhiteSpace($Project)) { throw 'Supply an explicit destination project.' }
    $resultUri = [Uri]$ResultUrl
    if (-not $resultUri.IsAbsoluteUri -or $resultUri.Scheme -ne 'http' -or $resultUri.Host -ne '127.0.0.1' -or $resultUri.UserInfo) { throw 'Only this demo report server can be registered.' }
    $projects = Get-LinkJumkeyDemoProjects -BaseUrl $base -Token $Token
    # project is a string name, not an entire project object. Keep kana, case and spaces exact.
    $matches = @($projects.projects | Where-Object { [string]::Equals($_.name, $Project, [StringComparison]::Ordinal) })
    if ($matches.Count -ne 1) { throw 'Choose one existing project name from projects[].name. This demo never creates a project implicitly.' }
    $destination = $matches[0]
    # The same report URL produces the same key, so a retry cannot create a second button.
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try { $reportHash = [BitConverter]::ToString($sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($ResultUrl))).Replace('-', '').ToLowerInvariant() }
    finally { $sha256.Dispose() }
    $request = @{ title = '架空顧客の検索結果'; url = $ResultUrl; projectId = $destination.id; requestId = 'customer-report-' + $reportHash }
    $json = $request | ConvertTo-Json -Depth 8 -Compress
    $response = Invoke-RestMethod -Method Post -Uri ($base + '/api/quick-add') -Headers @{ Authorization = 'Bearer ' + $Token } -ContentType 'application/json; charset=utf-8' -Body ([Text.Encoding]::UTF8.GetBytes($json)) -TimeoutSec 10 -MaximumRedirection 0
    if ($response.ok -ne $true) { throw 'LinkJumkey did not report ok:true.' }
    if (-not $response.button.id -or $response.button.url -cne $ResultUrl -or $response.project.id -cne $destination.id -or $response.project.name -cne $Project) { throw 'Saved button or destination does not match the request. Inspect the project before retrying.' }
    return $response
}

Export-ModuleMember -Function Assert-LoopbackBaseUrl, Get-DemoQuery, Invoke-DemoCustomerSearch, ConvertTo-SafeCsvCell, Write-DemoReport, Get-LinkJumkeyDemoProjects, Add-LinkJumkeyDemoResult
