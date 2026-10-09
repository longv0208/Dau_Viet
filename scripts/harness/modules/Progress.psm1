# Progress.psm1 - regenerate docs/PROGRESS.md as a view over tasks/*/task.json.
# Pure view: marker `generated:` declares it non-authoritative. Never read PROGRESS as state.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-AllTasks {
  <#
    Returns every task directory under tasks/ that contains a valid task.json.
    Directories without task.json are skipped silently — by design they are
    scratch/notes folders, not tasks. Documented in HARNESS_RUNBOOK.md.
  #>
  param([string]$RepoRoot)
  $tasksDir = Join-Path $RepoRoot 'tasks'
  $out = @()
  if (-not (Test-Path $tasksDir)) { return ,$out }
  Get-ChildItem -Path $tasksDir -Directory | Sort-Object Name | ForEach-Object {
    $tj = Join-Path $_.FullName 'task.json'
    if (-not (Test-Path $tj)) { return }
    try { $t = Get-Content -Raw -LiteralPath $tj | ConvertFrom-Json }
    catch { throw "Invalid JSON in $tj`: $($_.Exception.Message)" }
    $out += $t
  }
  return ,$out
}

function Test-TaskDependencyGraph {
  param([object[]]$Tasks)
  $errs = @()
  $byId = @{}
  foreach ($t in $Tasks) {
    if ($byId.ContainsKey($t.id)) { $errs += "duplicate task id: $($t.id)"; continue }
    $byId[$t.id] = $t
  }
  foreach ($t in $Tasks) {
    foreach ($d in @($t.dependencies)) {
      if (-not $byId.ContainsKey($d)) { $errs += "$($t.id) depends on missing $d" }
    }
  }
  # Detect cycles via DFS
  $state = @{} # 0=unvisited 1=visiting 2=done
  foreach ($t in $Tasks) { $state[$t.id] = 0 }
  function Visit([string]$id) {
    if ($state[$id] -eq 1) { return $true }  # cycle
    if ($state[$id] -eq 2) { return $false }
    $state[$id] = 1
    if ($byId.ContainsKey($id)) {
      foreach ($d in @($byId[$id].dependencies)) {
        if ($byId.ContainsKey($d) -and (Visit $d)) { return $true }
      }
    }
    $state[$id] = 2
    return $false
  }
  foreach ($t in $Tasks) {
    if ($state[$t.id] -eq 0) {
      if (Visit $t.id) { $errs += "dependency cycle involving $($t.id)" }
    }
  }
  return ,$errs
}

function Write-ProgressDoc {
  param([string]$RepoRoot, [string]$OutPath = (Join-Path $RepoRoot 'docs/PROGRESS.md'))
  $tasks = Get-AllTasks -RepoRoot $RepoRoot
  $errs = Test-TaskDependencyGraph -Tasks $tasks
  if ($errs.Count) {
    throw "PROGRESS build failed: $($errs -join '; ')"
  }
  $sb = New-Object System.Text.StringBuilder
  [void]$sb.AppendLine('# Progress')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine("generated: $((Get-Date).ToString('o')) by scripts/harness/harness.ps1 progress")
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('View-only - derived from `tasks/*/task.json`. Do not edit task status here.')
  [void]$sb.AppendLine('')
  [void]$sb.AppendLine('| Task | Type | Risk | Status | Next action |')
  [void]$sb.AppendLine('|---|---|---|---|---|')
  foreach ($t in $tasks) {
    $na = ($t.nextAction -replace '\|','\|') -replace "`r?`n",' '
    [void]$sb.AppendLine("| $($t.id) | $($t.type) | $($t.risk) | $($t.status) | $na |")
  }
  [void]$sb.AppendLine('')
  $dir = Split-Path -Parent $OutPath
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  # Atomic write: temp + rename so a crash cannot leave a half-written PROGRESS.
  # UTF-8 with BOM so Windows PowerShell 5.1 Get-Content reads non-ASCII correctly.
  $tmp = "$OutPath.tmp.$([guid]::NewGuid().ToString('N'))"
  [System.IO.File]::WriteAllText($tmp, $sb.ToString(), (New-Object System.Text.UTF8Encoding $true))
  if (Test-Path $OutPath) {
    $bak = "$OutPath.bak.$([guid]::NewGuid().ToString('N'))"
    [System.IO.File]::Move($OutPath, $bak)
    try { [System.IO.File]::Move($tmp, $OutPath); Remove-Item -LiteralPath $bak -Force }
    catch { if (Test-Path $bak) { [System.IO.File]::Move($bak, $OutPath) }; throw }
  } else {
    [System.IO.File]::Move($tmp, $OutPath)
  }
  return $OutPath
}

Export-ModuleMember -Function Get-AllTasks,Test-TaskDependencyGraph,Write-ProgressDoc
