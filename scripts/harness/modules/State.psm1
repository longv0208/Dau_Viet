# State.psm1 - Task state, schema check, atomic writes, lock with stale recovery.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:StatusOrder = @('draft','ready','implementing','verifying','reviewing','done')
$script:ValidStatus = $script:StatusOrder + @('blocked')

function Get-RepoRoot {
  param([string]$StartPath = (Get-Location).Path)
  $p = (Resolve-Path $StartPath).Path
  while ($true) {
    if (Test-Path (Join-Path $p '.git')) { return $p }
    $parent = Split-Path -Parent $p
    if ($null -eq $parent -or $parent -eq $p) { throw "Not inside a git repo: $StartPath" }
    $p = $parent
  }
}

function Get-TaskDir { param([string]$RepoRoot, [string]$TaskId)
  Join-Path $RepoRoot (Join-Path 'tasks' $TaskId)
}
function Get-TaskJsonPath { param([string]$RepoRoot, [string]$TaskId)
  Join-Path (Get-TaskDir -RepoRoot $RepoRoot -TaskId $TaskId) 'task.json'
}
function Get-LockDir { param([string]$RepoRoot) Join-Path $RepoRoot '.harness/locks' }

function Test-TaskJsonSchema {
  param([object]$Task)
  $errs = @()
  $props = $Task.PSObject.Properties
  $required = 'schemaVersion','id','type','risk','status','goal','owner','modules','scope','acceptanceCriteria','dependencies','planPath','evidenceRefs','reviewRefs','nextAction'
  foreach ($r in $required) { if (-not ($props.Name -contains $r)) { $errs += "missing:$r" } }
  $id = if ($props.Name -contains 'id') { $Task.id } else { $null }
  if ($id -and ($id -notmatch '^TASK-[0-9]{4,}$')) { $errs += 'id:pattern' }
  $status = if ($props.Name -contains 'status') { $Task.status } else { $null }
  if ($status -and ($script:ValidStatus -notcontains $status)) { $errs += "status:$status" }
  if ($status -eq 'blocked') {
    $br = if ($props.Name -contains 'blockedReason') { $Task.blockedReason } else { $null }
    $rf = if ($props.Name -contains 'resumeFrom') { $Task.resumeFrom } else { $null }
    if (-not $br) { $errs += 'blockedReason-required' }
    if ($null -eq $rf) { $errs += 'resumeFrom-required' }
  }
  $risk = if ($props.Name -contains 'risk') { $Task.risk } else { $null }
  $pp = if ($props.Name -contains 'planPath') { $Task.planPath } else { $null }
  if ($risk -in @('normal','high-risk') -and -not $pp) { $errs += 'planPath-required' }
  # Optional acEvidence: { "AC-1": ["path/one","path/two"], ... }. Keys must match AC ids.
  if ($props.Name -contains 'acEvidence' -and $Task.acEvidence) {
    $acIds = @()
    if ($props.Name -contains 'acceptanceCriteria' -and $Task.acceptanceCriteria) {
      $acIds = @($Task.acceptanceCriteria | ForEach-Object { $_.id })
    }
    # acEvidence may arrive as hashtable (test fixtures) or PSCustomObject (JSON).
    $acEvKeys = @()
    if ($Task.acEvidence -is [System.Collections.IDictionary]) {
      $acEvKeys = @($Task.acEvidence.Keys)
      $getV = { param($k) $Task.acEvidence[$k] }
    } else {
      $acEvKeys = @($Task.acEvidence.PSObject.Properties.Name)
      $getV = { param($k) $Task.acEvidence.$k }
    }
    foreach ($k in $acEvKeys) {
      if ($acIds.Count -and ($acIds -notcontains $k)) { $errs += "acEvidence key not an AC id: $k" }
      $vArr = @(& $getV $k)
      if ($vArr.Count -eq 0) { $errs += "acEvidence[$k] must be non-empty array" }
    }
  }
  return ,$errs
}

function Read-Task {
  param([string]$RepoRoot, [string]$TaskId)
  $p = Get-TaskJsonPath -RepoRoot $RepoRoot -TaskId $TaskId
  if (-not (Test-Path $p)) { throw "Task not found: $TaskId ($p)" }
  $raw = Get-Content -Raw -LiteralPath $p
  $t = $raw | ConvertFrom-Json
  $errs = Test-TaskJsonSchema -Task $t
  if ($errs.Count) { throw "task.json schema violations for $TaskId`: $($errs -join '; ')" }
  return $t
}

function Write-TaskAtomic {
  param([string]$RepoRoot, [object]$Task)
  $p = Get-TaskJsonPath -RepoRoot $RepoRoot -TaskId $Task.id
  $errs = Test-TaskJsonSchema -Task $Task
  if ($errs.Count) { throw "Refusing to write invalid task.json for $($Task.id): $($errs -join '; ')" }
  $dir = Split-Path -Parent $p
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
  $tmp = "$p.tmp.$([guid]::NewGuid().ToString('N'))"
  $json = $Task | ConvertTo-Json -Depth 32
  [System.IO.File]::WriteAllText($tmp, $json, (New-Object System.Text.UTF8Encoding $false))
  # Atomic rename on Windows requires removing existing target first.
  if (Test-Path $p) {
    $bak = "$p.bak.$([guid]::NewGuid().ToString('N'))"
    [System.IO.File]::Move($p, $bak)
    try { [System.IO.File]::Move($tmp, $p); Remove-Item -LiteralPath $bak -Force }
    catch { if (Test-Path $bak) { [System.IO.File]::Move($bak, $p) }; throw }
  } else {
    [System.IO.File]::Move($tmp, $p)
  }
}

function Enter-TaskLock {
  param([string]$RepoRoot, [string]$TaskId, [int]$StaleMinutes = 30)
  $ld = Get-LockDir -RepoRoot $RepoRoot
  if (-not (Test-Path $ld)) { New-Item -ItemType Directory -Path $ld -Force | Out-Null }
  $lock = Join-Path $ld "$TaskId.lock"
  if (Test-Path $lock) {
    $info = Get-Item -LiteralPath $lock
    $ageMin = ((Get-Date) - $info.LastWriteTime).TotalMinutes
    $owner = (Get-Content -Raw -LiteralPath $lock -ErrorAction SilentlyContinue)
    $ownerPid = ($owner | ConvertFrom-Json -ErrorAction SilentlyContinue).pid
    $alive = $false
    if ($ownerPid) {
      try { $null = Get-Process -Id $ownerPid -ErrorAction Stop; $alive = $true } catch { $alive = $false }
    }
    if ($alive -and $ageMin -lt $StaleMinutes) {
      throw "Task $TaskId locked by live pid=$ownerPid (age=${([int]$ageMin)}m). Refusing to delete."
    }
    # Stale or dead owner: safe to recover.
    Remove-Item -LiteralPath $lock -Force
  }
  $body = @{ taskId=$TaskId; pid=$PID; host=$env:COMPUTERNAME; at=(Get-Date).ToString('o') } | ConvertTo-Json -Compress
  try {
    $fs = [System.IO.File]::Open($lock,'CreateNew','Write','None')
    $b = [System.Text.Encoding]::UTF8.GetBytes($body)
    $fs.Write($b,0,$b.Length); $fs.Close()
  } catch [System.IO.IOException] {
    throw "Task $TaskId lock acquired concurrently. Retry later."
  }
  return $lock
}

function Exit-TaskLock { param([string]$LockPath)
  if ($LockPath -and (Test-Path $LockPath)) {
    $owner = (Get-Content -Raw -LiteralPath $LockPath -ErrorAction SilentlyContinue) | ConvertFrom-Json -ErrorAction SilentlyContinue
    if ($owner -and $owner.pid -eq $PID) { Remove-Item -LiteralPath $LockPath -Force }
  }
}

function Test-StatusTransition {
  param([string]$From, [string]$To)
  # Terminal: 'done' cannot transition anywhere, including done->done (refinish blocked).
  if ($From -eq 'done') { return $false }
  if ($From -eq $To) { return $true }
  if ($From -eq 'blocked') {
    # resumeFrom governs; allow return to any non-done state.
    return $To -ne 'done'
  }
  $fi = $script:StatusOrder.IndexOf($From); $ti = $script:StatusOrder.IndexOf($To)
  if ($fi -lt 0) { return $false }
  if ($To -eq 'blocked') { return $true }
  # Allow forward-only or same; backward moves only via blocked or explicit stale reset.
  return ($ti -eq ($fi + 1)) -or ($ti -eq $fi)
}

function Set-TaskStatus {
  param([string]$RepoRoot,[string]$TaskId,[string]$To,[string]$Reason,[string]$ResumeFrom)
  $lock = Enter-TaskLock -RepoRoot $RepoRoot -TaskId $TaskId
  try {
    $t = Read-Task -RepoRoot $RepoRoot -TaskId $TaskId
    if (-not (Test-StatusTransition -From $t.status -To $To)) {
      throw "Invalid transition $($t.status) -> $To for $TaskId"
    }
    $t.status = $To
    if ($To -eq 'blocked') {
      $t.blockedReason = $Reason
      if ($ResumeFrom) { $t.resumeFrom = $ResumeFrom } elseif (-not $t.resumeFrom) { $t.resumeFrom = 'implementing' }
    } else {
      $t.blockedReason = $null
    }
    $t.updatedAt = (Get-Date).ToString('o')
    Write-TaskAtomic -RepoRoot $RepoRoot -Task $t
    return $t
  } finally { Exit-TaskLock -LockPath $lock }
}

Export-ModuleMember -Function Get-RepoRoot,Get-TaskDir,Get-TaskJsonPath,Read-Task,Write-TaskAtomic,Enter-TaskLock,Exit-TaskLock,Test-StatusTransition,Set-TaskStatus,Test-TaskJsonSchema
