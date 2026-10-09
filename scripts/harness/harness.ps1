# harness.ps1 - thin entrypoint. Subcommands: doctor, start, verify, status, resume, finish, progress, new-handoff.
# Tolerates Windows PowerShell 5.1 for the common path; doctor reports the runtime mismatch.
[CmdletBinding()]
param(
  [Parameter(Position=0,Mandatory=$true)]
  [ValidateSet('doctor','start','verify','status','resume','finish','progress','new-handoff')]
  [string]$Command,
  [Parameter(Position=1)][string]$TaskId,
  [switch]$DryRun,
  [string]$RepoRoot
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$modDir = Join-Path $PSScriptRoot 'modules'
Import-Module (Join-Path $modDir 'State.psm1') -Force
Import-Module (Join-Path $modDir 'Runner.psm1') -Force
Import-Module (Join-Path $modDir 'Fingerprint.psm1') -Force
Import-Module (Join-Path $modDir 'GitNexus.psm1') -Force
Import-Module (Join-Path $modDir 'Progress.psm1') -Force
Import-Module (Join-Path $modDir 'ResumeFinish.psm1') -Force

if (-not $RepoRoot) { $RepoRoot = Get-RepoRoot -StartPath $PSScriptRoot }
$RepoRoot = (Resolve-Path $RepoRoot).Path
$ConfigPath = Join-Path $RepoRoot '.harness/config.json'

function Read-Config {
  if (-not (Test-Path $ConfigPath)) { throw "Missing $ConfigPath" }
  return (Get-Content -Raw -LiteralPath $ConfigPath | ConvertFrom-Json)
}

function Get-RunsDir { param([string]$Task)
  $d = Join-Path $RepoRoot '.harness/runs'
  if ($Task) { $d = Join-Path $d $Task }
  if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
  return $d
}

function Write-Evidence {
  param([object]$Record,[string]$TaskId,[string]$GateId)
  $dir = Get-RunsDir -Task $TaskId
  $runId = $Record.runId
  $p = Join-Path $dir "evidence-$GateId-$runId.json"
  # Atomic write: temp + rename so a crash cannot leave a half-written evidence file.
  $tmp = "$p.tmp.$([guid]::NewGuid().ToString('N'))"
  [System.IO.File]::WriteAllText($tmp, ($Record | ConvertTo-Json -Depth 32), (New-Object System.Text.UTF8Encoding $false))
  if (Test-Path $p) {
    $bak = "$p.bak.$([guid]::NewGuid().ToString('N'))"
    [System.IO.File]::Move($p, $bak)
    try { [System.IO.File]::Move($tmp, $p); Remove-Item -LiteralPath $bak -Force }
    catch { if (Test-Path $bak) { [System.IO.File]::Move($bak, $p) }; throw }
  } else {
    [System.IO.File]::Move($tmp, $p)
  }
  return $p
}

function Get-ConfigHash {
  if (-not (Test-Path $ConfigPath)) { return $null }
  return Get-FileSha256 -Path $ConfigPath
}

function Invoke-Doctor {
  $cfg = Read-Config
  $doc = [ordered]@{
    pwsh = @{ version = $PSVersionTable.PSVersion.ToString(); edition = $PSVersionTable.PSEdition; ok = ($PSVersionTable.PSVersion.Major -ge 7) }
    git = @{}
    repo = @{ root = $RepoRoot; head = (Get-HeadSha -RepoRoot $RepoRoot); unborn = $false }
    config = @{ path = $ConfigPath; valid = $false; hash = (Get-ConfigHash) }
    modules = @{}
    gitnexus = @{}
  }
  try {
    $gv = & git --version 2>&1 | Out-String
    $doc.git = @{ version=$gv.Trim(); ok=($LASTEXITCODE -eq 0) }
  } catch { $doc.git = @{ version=$null; ok=$false; error=$_.Exception.Message } }
  $doc.repo.unborn = ($null -eq $doc.repo.head)
  $doc.config.valid = ($null -ne $cfg -and $cfg.schemaVersion -ge 1)
  foreach ($k in $cfg.modules.PSObject.Properties.Name) {
    $m = $cfg.modules.$k
    $mpath = Join-Path $RepoRoot $m.path
    $manifestsFound = @()
    if (Test-Path $mpath) {
      foreach ($mf in $m.manifests) {
        if (Test-Path (Join-Path $mpath $mf)) { $manifestsFound += $mf }
      }
    }
    $entry = [ordered]@{ status=$m.status; path=$m.path; manifestsFound=$manifestsFound }
    if ($m.status -eq 'uninitialized' -and $manifestsFound.Count -gt 0) {
      $entry.warning = 'manifests present but module uninitialized - bootstrap registration required'
    }
    $doc.modules[$k] = $entry
  }
  $gn = Get-GitNexusStatus -ExpectedVersion $cfg.gitnexus.version
  $doc.gitnexus = @{ available=$gn.available; version=$gn.version; reason=$gn.reason; fallback=$gn.fallback }
  $doc | ConvertTo-Json -Depth 8 | Write-Output
  if (-not $doc.pwsh.ok -or -not $doc.git.ok) { exit 2 }
  exit 0
}

function Resolve-Gates {
  param([object]$Cfg,[object]$Task)
  $gates = @()
  $taskModules = @($Task.modules)
  $docsOnly = ($taskModules.Count -eq 0)
  if ($docsOnly) {
    $gates += [pscustomobject]@{ id='task-schema'; type='internal'; applies=$true }
    $gates += [pscustomobject]@{ id='app-build'; type='module'; applies=$false; reason='docs-only scope: no module targeted' }
  } else {
    foreach ($m in $taskModules) {
      $mcfg = $Cfg.modules.$m
      if (-not $mcfg) { $gates += [pscustomobject]@{ id="module-$m"; applies=$false; status='blocked'; reason="module $m not in registry" }; continue }
      if ($mcfg.status -eq 'uninitialized') {
        $mpath = Join-Path $RepoRoot $mcfg.path
        $hasManifest = $false
        if (Test-Path $mpath) {
          foreach ($mf in $mcfg.manifests) { if (Test-Path (Join-Path $mpath $mf)) { $hasManifest=$true; break } }
        }
        $reason = if ($hasManifest) { "module $m has manifest but status=uninitialized; bootstrap registration required" } else { "module $m uninitialized; bootstrap dependency required" }
        $gates += [pscustomobject]@{ id="module-$m"; applies=$false; status='blocked'; reason=$reason }
      } else {
        foreach ($g in @($mcfg.gates)) { $gates += [pscustomobject]@{ id=$g.id; gate=$g; applies=$true } }
      }
    }
  }
  if ($Task.scope -match '^scripts/harness/' -or $Task.scope -match '^\.harness/') {
    $gates += [pscustomobject]@{ id='harness-self-test'; type='internal'; applies=$true }
  }
  return $gates
}

function Invoke-Start {
  param([string]$TaskId,[object]$Cfg)
  if (-not $TaskId) { throw 'start requires -TaskId' }
  $t = Read-Task -RepoRoot $RepoRoot -TaskId $TaskId
  if ($t.status -notin @('ready','blocked','draft')) { throw "Cannot start task in status=$($t.status)" }
  foreach ($dep in @($t.dependencies)) {
    $d = Read-Task -RepoRoot $RepoRoot -TaskId $dep
    if ($d.status -ne 'done') { throw "Dependency $dep not done (status=$($d.status))" }
  }
  foreach ($m in @($t.modules)) {
    if ($Cfg.modules.$m.status -eq 'uninitialized') { throw "Module $m uninitialized; bootstrap first" }
  }
  $fp = Get-InputFingerprint -RepoRoot $RepoRoot -TaskId $TaskId
  $t = Set-TaskStatus -RepoRoot $RepoRoot -TaskId $TaskId -To 'implementing'
  $t.baseCommit = $fp.headSha; $t.inputFingerprint = $fp.digest
  Write-TaskAtomic -RepoRoot $RepoRoot -Task $t
  Write-Output "task=$TaskId status=implementing fingerprint=$($fp.digest)"
  exit 0
}

function Invoke-Verify {
  param([string]$TaskId,[object]$Cfg,[switch]$DryRun)
  if (-not $TaskId) { throw 'verify requires -TaskId' }
  $t = Read-Task -RepoRoot $RepoRoot -TaskId $TaskId
  $fpBefore = Get-InputFingerprint -RepoRoot $RepoRoot -TaskId $TaskId
  $runId = (Get-Date).ToString('yyyyMMdd-HHmmss')
  $gates = Resolve-Gates -Cfg $Cfg -Task $t
  $results = @()
  foreach ($g in $gates) {
    if ($DryRun) {
      Write-Output "[dry-run] gate $($g.id) applies=$($g.applies) reason=$($g.reason)"
      continue
    }
    if (-not $g.applies) {
      $gst = if ($g.PSObject.Properties.Name -contains 'status' -and $g.status) { $g.status } else { 'not_applicable' }
      $greason = if ($g.PSObject.Properties.Name -contains 'reason') { $g.reason } else { $null }
      $results += [pscustomobject]@{ gateId=$g.id; status=$gst; reason=$greason; exitCode=$null; runId=$runId }
      continue
    }
    if ($g.id -eq 'task-schema') {
      $errs = Test-TaskJsonSchema -Task $t
      $st = if ($errs.Count) { 'failed' } else { 'passed' }
      $ec = if ($errs.Count) { 1 } else { 0 }
      $results += [pscustomobject]@{ gateId=$g.id; status=$st; reason=($errs -join '; '); exitCode=$ec; runId=$runId }
      continue
    }
    if ($g.id -eq 'harness-self-test') {
      $testScript = Join-Path $RepoRoot 'tests/harness/run-tests.ps1'
      if (-not (Test-Path $testScript)) {
        $results += [pscustomobject]@{ gateId=$g.id; status='failed'; reason='missing tests/harness/run-tests.ps1'; exitCode=$null; runId=$runId }
        continue
      }
      $log = Join-Path (Get-RunsDir -Task $TaskId) "harness-self-test-$runId.log"
      $r = Invoke-HarnessGate -GateId $g.id -Executable 'pwsh' -Arguments @('-NoProfile','-File',$testScript) -WorkingDirectory $RepoRoot -RepoRoot $RepoRoot -TimeoutSeconds 300 -LogPath $log
      $results += $r
      continue
    }
    $gg = if ($g.PSObject.Properties.Name -contains 'gate') { $g.gate } else { $null }
    if (-not $gg -or -not ($gg.PSObject.Properties.Name -contains 'executable') -or -not $gg.executable) {
      $results += [pscustomobject]@{ gateId=$g.id; status='failed'; reason='gate missing executable'; exitCode=$null; runId=$runId }
      continue
    }
    $cwd = if ($gg.PSObject.Properties.Name -contains 'cwd' -and $gg.cwd) { Join-Path $RepoRoot $gg.cwd } else { $RepoRoot }
    $log = Join-Path (Get-RunsDir -Task $TaskId) "$($g.id)-$runId.log"
    $to = if ($gg.PSObject.Properties.Name -contains 'timeoutSeconds' -and $gg.timeoutSeconds) { $gg.timeoutSeconds } else { 300 }
    $r = Invoke-HarnessGate -GateId $g.id -Executable $gg.executable -Arguments @($gg.args) -WorkingDirectory $cwd -RepoRoot $RepoRoot -TimeoutSeconds $to -LogPath $log
    $results += $r
  }
  if ($DryRun) { exit 0 }
  $fpAfter = Get-InputFingerprint -RepoRoot $RepoRoot -TaskId $TaskId
  $stale = ($fpBefore.digest -ne $fpAfter.digest -or $fpBefore.headSha -ne $fpAfter.headSha)
  $overall = 'passed'
  foreach ($r in $results) {
    if ($r.status -eq 'failed' -or $r.status -eq 'blocked') { $overall='failed'; break }
  }
  if ($stale) { $overall='stale' }
  $ev = [ordered]@{
    taskId=$TaskId; runId=$runId; scope=$t.scope
    headSha=$fpBefore.headSha; inputFingerprint=$fpBefore.digest
    fingerprintAfter=$fpAfter.digest; stale=$stale
    gateConfigHash=(Get-ConfigHash)
    toolVersions=@{ pwsh=$PSVersionTable.PSVersion.ToString(); git=(git --version 2>&1 | Out-String).Trim() }
    gates=$results; status=$overall; at=(Get-Date).ToString('o')
  }
  $ep = Write-Evidence -Record $ev -TaskId $TaskId -GateId 'verify'
  Write-Output "verify status=$overall stale=$stale evidence=$ep"
  foreach ($r in $results) { Write-Output ("  {0}: {1} {2}" -f $r.gateId,$r.status,$r.reason) }
  if ($stale) { exit 4 }
  if ($overall -eq 'failed') { exit 3 }
  exit 0
}

function Invoke-Status {
  param([string]$TaskId)
  if ($TaskId) {
    $t = Read-Task -RepoRoot $RepoRoot -TaskId $TaskId
    $t | ConvertTo-Json -Depth 8 | Write-Output
  } else {
    $tasksDir = Join-Path $RepoRoot 'tasks'
    Get-ChildItem -Path $tasksDir -Directory | ForEach-Object {
      $tj = Join-Path $_.FullName 'task.json'
      if (Test-Path $tj) {
        $t = Get-Content -Raw -LiteralPath $tj | ConvertFrom-Json
        Write-Output ("{0} {1} risk={2} modules={3}" -f $t.id,$t.status,$t.risk,($t.modules -join ','))
      } else {
        # Documented skip: a directory without task.json is not a task (e.g. scratch dirs).
        Write-Verbose "skipping $($_.Name): no task.json"
      }
    }
  }
  exit 0
}

function Invoke-Resume {
  param([string]$TaskId,[object]$Cfg)
  if (-not $TaskId) { throw 'resume requires -TaskId' }
  $t = Read-Task -RepoRoot $RepoRoot -TaskId $TaskId
  $fpNow = Get-InputFingerprint -RepoRoot $RepoRoot -TaskId $TaskId
  $latest = Get-LatestVerifyEvidence -RepoRoot $RepoRoot -TaskId $TaskId
  $stale = Get-ResumeStaleReasons -Task $t -FpNow $fpNow -LatestEvidence $latest -ConfigHashNow (Get-ConfigHash) -RepoRoot $RepoRoot
  # No prior verify evidence is itself a stale signal for any non-draft task —
  # the report should say "nothing verified yet", not look clean.
  if (-not $latest -and $t.status -in @('implementing','verifying','reviewing','done')) {
    $stale += 'no prior verify evidence found'
  }
  $depErrs = @()
  foreach ($dep in @($t.dependencies)) {
    $dPath = Join-Path $RepoRoot "tasks/$dep/task.json"
    if (-not (Test-Path $dPath)) { $depErrs += "dependency $dep missing"; continue }
    $d = Get-Content -Raw -LiteralPath $dPath | ConvertFrom-Json
    if ($d.status -ne 'done') { $depErrs += "dependency $dep not done (status=$($d.status))" }
  }
  $resumeFrom = if ($t.resumeFrom) { $t.resumeFrom } elseif ($t.status -eq 'blocked') { 'implementing' } else { $t.status }
  $report = [ordered]@{
    taskId=$TaskId; status=$t.status; resumeFrom=$resumeFrom
    headSha=$fpNow.headSha; inputFingerprint=$fpNow.digest
    gateConfigHash=(Get-ConfigHash)
    deps=$depErrs; staleReasons=$stale
    nextAction=$t.nextAction
  }
  $report | ConvertTo-Json -Depth 8 | Write-Output
  # Only transition blocked -> resumeFrom when the resume report is clean: no dep
  # errors AND no stale reasons. A stale evidence trail means "still needs redo",
  # not "ready to pick up where we left off".
  if ($t.status -eq 'blocked' -and -not $depErrs.Count -and -not $stale.Count) {
    $null = Set-TaskStatus -RepoRoot $RepoRoot -TaskId $TaskId -To $resumeFrom
    Write-Output "resumed task=$TaskId status=$resumeFrom"
  }
  if ($depErrs.Count -or $stale.Count) { exit 6 }
  exit 0
}

function Invoke-Progress {
  $out = Write-ProgressDoc -RepoRoot $RepoRoot
  Write-Output "progress wrote $out"
  exit 0
}

function Invoke-NewHandoff {
  param([string]$TaskId)
  if (-not $TaskId) { throw 'new-handoff requires -TaskId' }
  $null = Read-Task -RepoRoot $RepoRoot -TaskId $TaskId
  $tmpl = Join-Path $RepoRoot '.harness/templates/handoff.md'
  if (-not (Test-Path $tmpl)) { throw "Missing template $tmpl" }
  $body = Get-Content -Raw -LiteralPath $tmpl
  $body = $body -replace '\{TASK-ID\}', $TaskId
  $outDir = Join-Path $RepoRoot "tasks/$TaskId"
  if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }
  $outPath = Join-Path $outDir 'handoff.md'
  if (Test-Path $outPath) { Write-Output "handoff exists: $outPath"; exit 0 }
  # UTF-8 with BOM so powershell.exe 5.1 Get-Content round-trips non-ASCII.
  # Atomic write via temp + rename.
  $tmp = "$outPath.tmp.$([guid]::NewGuid().ToString('N'))"
  [System.IO.File]::WriteAllText($tmp, $body, (New-Object System.Text.UTF8Encoding $true))
  [System.IO.File]::Move($tmp, $outPath)
  Write-Output "wrote $outPath"
  exit 0
}

function Invoke-Finish {
  param([string]$TaskId,[object]$Cfg)
  if (-not $TaskId) { throw 'finish requires -TaskId' }
  $t = Read-Task -RepoRoot $RepoRoot -TaskId $TaskId
  $fpNow = Get-InputFingerprint -RepoRoot $RepoRoot -TaskId $TaskId
  $latest = Get-LatestVerifyEvidence -RepoRoot $RepoRoot -TaskId $TaskId
  $errs = Get-FinishBlockers -Task $t -LatestEvidence $latest -FpNow $fpNow -RepoRoot $RepoRoot -Cfg $Cfg
  if ($errs.Count) {
    foreach ($e in $errs) { Write-Output "finish-blocked: $e" }
    exit 5
  }
  # Walk the state machine forward to 'done': implementing -> verifying -> reviewing -> done.
  # Each step is a legal transition; Set-TaskStatus enforces the machine.
  $cur = $t.status
  while ($cur -ne 'done') {
    $next = switch ($cur) {
      'draft'        { 'ready' }
      'ready'        { 'implementing' }
      'implementing' { 'verifying' }
      'verifying'    { 'reviewing' }
      'reviewing'    { 'done' }
      'blocked'      { throw "Cannot finish a blocked task; resolve $($t.blockedReason) first" }
      default        { throw "Cannot finish from status=$cur" }
    }
    $t = Set-TaskStatus -RepoRoot $RepoRoot -TaskId $TaskId -To $next
    $cur = $t.status
  }
  Write-Output "task=$TaskId done"
  exit 0
}

try {
  $cfg = Read-Config
  switch ($Command) {
    'doctor'       { Invoke-Doctor }
    'start'        { Invoke-Start -TaskId $TaskId -Cfg $cfg }
    'verify'       { Invoke-Verify -TaskId $TaskId -Cfg $cfg -DryRun:$DryRun }
    'status'       { Invoke-Status -TaskId $TaskId }
    'resume'       { Invoke-Resume -TaskId $TaskId -Cfg $cfg }
    'finish'       { Invoke-Finish -TaskId $TaskId -Cfg $cfg }
    'progress'     { Invoke-Progress }
    'new-handoff'  { Invoke-NewHandoff -TaskId $TaskId }
  }
} catch {
  Write-Error "harness: $($_.Exception.Message)"
  exit 1
}
