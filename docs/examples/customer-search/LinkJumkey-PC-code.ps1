# Paste this fixed wrapper into LinkJumkey's Windows PowerShell PC-code action.
# Enable the UI option that passes the search input to code.
# Replace only this trusted, fixed installation path. Never interpolate the query into code.
$ErrorActionPreference = 'Stop'
try {
    & 'C:\LinkJumkeyCustomerDemo\Search-Customer.ps1' -Query $env:LINKJUMKEY_INPUT -OpenReport
    if (-not $?) { exit 1 }
} catch {
    Write-Error $_ -ErrorAction Continue
    exit 1
}
