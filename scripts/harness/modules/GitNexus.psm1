# GitNexus.psm1 - detect binary, --version, --help; if absent return available=$false + fallback note.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-GitNexusStatus {
  param(
    [string]$ExpectedVersion,
    [int]$ProbeTimeoutSeconds = 15
  )
  $out = [ordered]@{
    available = $false
    version = $null
    path = $null
    fallback = 'targeted-search'
    reason = $null
    versionMatches = $null
    helpSurface = $null
  }
  $cmd = Get-Command gitnexus -ErrorAction SilentlyContinue
  if (-not $cmd) {
    $out.reason = 'gitnexus binary not on PATH'
    return [pscustomobject]$out
  }
  $out.path = $cmd.Source
  # Probe --version
  try {
    $vraw = & $cmd.Source --version 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
      $out.reason = "gitnexus --version exited $LASTEXITCODE"
      return [pscustomobject]$out
    }
    $out.version = ($vraw -split "`n" | Select-Object -First 1).Trim()
  } catch {
    $out.reason = "gitnexus --version failed: $($_.Exception.Message)"
    return [pscustomobject]$out
  }
  # Probe --help
  try {
    $hraw = & $cmd.Source --help 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
      $out.reason = "gitnexus --help exited $LASTEXITCODE"
      return [pscustomobject]$out
    }
    $out.helpSurface = ($hraw -split "`n" | Select-Object -First 40) -join "`n"
  } catch {
    $out.reason = "gitnexus --help failed: $($_.Exception.Message)"
    return [pscustomobject]$out
  }
  if ($ExpectedVersion) {
    $out.versionMatches = ($out.version -like "*$ExpectedVersion*")
    if (-not $out.versionMatches) {
      $out.reason = "version mismatch: expected $ExpectedVersion, found $($out.version); refusing to claim available"
      return [pscustomobject]$out
    }
  }
  $out.available = $true
  $out.reason = 'probed ok'
  return [pscustomobject]$out
}

Export-ModuleMember -Function Get-GitNexusStatus
