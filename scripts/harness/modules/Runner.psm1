# Runner.psm1 - Deterministic executable+args runner with cwd allowlist, timeout, redact.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# cwd allowlist: path must be inside repo root and not in forbidden dirs.
function Test-CwdAllowed {
  param([string]$RepoRoot,[string]$Cwd)
  $r = (Resolve-Path $RepoRoot).Path.TrimEnd('\','/')
  if (-not (Test-Path $Cwd)) { return $false }
  $c = (Resolve-Path $Cwd).Path.TrimEnd('\','/')
  # Reject siblings like C:\repo-evil: candidate must equal root or start with root + separator.
  $eq = [string]::Equals($c,$r,[System.StringComparison]::OrdinalIgnoreCase)
  $prefix = $c.StartsWith($r + [IO.Path]::DirectorySeparatorChar,[System.StringComparison]::OrdinalIgnoreCase)
  if (-not ($eq -or $prefix)) { return $false }
  $rel = $c.Substring($r.Length).TrimStart('\','/')
  $forbidden = @('.git','.gitnexus','.harness\locks','.harness\tmp')
  foreach ($f in $forbidden) { if ($rel -like "$f*") { return $false } }
  return $true
}

function Protect-Secrets {
  param([string]$Text)
  if (-not $Text) { return $Text }
  $patterns = @(
    '(?i)(password|passwd|secret|token|api[_-]?key|access[_-]?key|private[_-]?key|client[_-]?secret|authorization|bearer)\s*[:=]\s*[^\s''";]+',
    '(?i)(-----BEGIN [A-Z ]+PRIVATE KEY-----)[\s\S]+?(-----END [A-Z ]+PRIVATE KEY-----)',
    'ghp_[A-Za-z0-9]{20,}',
    'sk-[A-Za-z0-9]{20,}',
    'AKIA[0-9A-Z]{16}'
  )
  $out = $Text
  foreach ($p in $patterns) { $out = [regex]::Replace($out,$p,'[REDACTED]') }
  return $out
}

function Invoke-HarnessGate {
  param(
    [Parameter(Mandatory)] [string]$GateId,
    [Parameter(Mandatory)] [string]$Executable,
    [string[]]$Arguments = @(),
    [Parameter(Mandatory)] [string]$WorkingDirectory,
    [Parameter(Mandatory)] [string]$RepoRoot,
    [int]$TimeoutSeconds = 300,
    [string]$LogPath
  )
  $result = [ordered]@{
    gateId=$GateId; command=$Executable; args=$Arguments; cwd=$WorkingDirectory
    startedAt=(Get-Date).ToString('o'); finishedAt=$null; durationMs=$null
    exitCode=$null; status='failed'; reason=$null; logPath=$null; timedOut=$false
  }
  if (-not (Test-CwdAllowed -RepoRoot $RepoRoot -Cwd $WorkingDirectory)) {
    $result.status='blocked'; $result.reason="cwd not allowed: $WorkingDirectory"
    $result.finishedAt=(Get-Date).ToString('o'); return [pscustomobject]$result
  }
  $exe = Get-Command $Executable -ErrorAction SilentlyContinue
  if (-not $exe) {
    $result.status='failed'; $result.reason="executable not found: $Executable"
    $result.finishedAt=(Get-Date).ToString('o'); return [pscustomobject]$result
  }
  $sw = [System.Diagnostics.Stopwatch]::StartNew()
  $tmpOut = [System.IO.Path]::GetTempFileName()
  $tmpErr = [System.IO.Path]::GetTempFileName()
  try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe.Source
    $psi.WorkingDirectory = (Resolve-Path $WorkingDirectory).Path
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    # ProcessStartInfo.ArgumentList exists only on .NET Core (pwsh 7+).
    # Fall back to Arguments string with simple quoting for Windows PowerShell 5.1.
    if ($psi.PSObject.Properties.Name -contains 'ArgumentList') {
      foreach ($a in $Arguments) { [void]$psi.ArgumentList.Add([string]$a) }
    } else {
      $quoted = foreach ($a in $Arguments) {
        $s = [string]$a
        if ($s -match '[\s"'']') {
          '"' + ($s -replace '"','\"') + '"'
        } else { $s }
      }
      $psi.Arguments = ($quoted -join ' ')
    }
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()
    # Async read to avoid deadlocks.
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    $finished = $proc.WaitForExit($TimeoutSeconds * 1000)
    if (-not $finished) {
      try { $proc.Kill($true) } catch { try { $proc.Kill() } catch {} }
      $result.timedOut = $true; $result.status='failed'; $result.reason="timeout after ${TimeoutSeconds}s"
      $result.exitCode = -1
    } else {
      $proc.WaitForExit() # flush async readers
      $result.exitCode = $proc.ExitCode
      $result.status = if ($proc.ExitCode -eq 0) { 'passed' } else { 'failed' }
      if ($proc.ExitCode -ne 0) { $result.reason = "nonzero exit: $($proc.ExitCode)" }
    }
    $stdout = $outTask.Result; $stderr = $errTask.Result
    if ($LogPath) {
      $ld = Split-Path -Parent $LogPath
      if (-not (Test-Path $ld)) { New-Item -ItemType Directory -Path $ld -Force | Out-Null }
      $body = @"
=== gate $GateId ===
cmd: $Executable $($Arguments -join ' ')
cwd: $WorkingDirectory
started: $($result.startedAt)  finished: $(Get-Date -Format o)
exit: $($result.exitCode)  timedOut: $($result.timedOut)
--- stdout ---
$(Protect-Secrets $stdout)
--- stderr ---
$(Protect-Secrets $stderr)
"@
      [System.IO.File]::WriteAllText($LogPath, $body, (New-Object System.Text.UTF8Encoding $false))
      $result.logPath = $LogPath
    }
  } finally {
    $sw.Stop(); $result.durationMs = $sw.ElapsedMilliseconds
    $result.finishedAt = (Get-Date).ToString('o')
    Remove-Item -LiteralPath $tmpOut,$tmpErr -Force -ErrorAction SilentlyContinue
  }
  return [pscustomobject]$result
}

Export-ModuleMember -Function Invoke-HarnessGate,Protect-Secrets,Test-CwdAllowed
