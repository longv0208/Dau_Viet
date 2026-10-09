# ResumeFinish.psm1 - resume checks and finish gating logic.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-LatestVerifyEvidence {
  param([string]$RepoRoot,[string]$TaskId)
  $runsDir = Join-Path $RepoRoot ".harness/runs/$TaskId"
  if (-not (Test-Path $runsDir)) { return $null }
  $latest = Get-ChildItem -Path $runsDir -Filter 'evidence-verify-*.json' -ErrorAction SilentlyContinue |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if (-not $latest) { return $null }
  try { return (Get-Content -Raw -LiteralPath $latest.FullName | ConvertFrom-Json) }
  catch { return $null }
}

function Get-ResumeStaleReasons {
  param(
    [object]$Task,
    [object]$FpNow,
    [object]$LatestEvidence,
    [string]$ConfigHashNow,
    [string]$RepoRoot
  )
  $stale = @()
  if ($Task.inputFingerprint -and $Task.inputFingerprint -ne $FpNow.digest) {
    $stale += 'inputFingerprint drift since task start'
  }
  if ($Task.baseCommit -and $FpNow.headSha -and $Task.baseCommit -ne $FpNow.headSha) {
    $stale += "HEAD moved from $($Task.baseCommit.Substring(0,[Math]::Min(8,$Task.baseCommit.Length))) to $($FpNow.headSha.Substring(0,8))"
  }
  if ($LatestEvidence) {
    if ($LatestEvidence.PSObject.Properties.Name -contains 'gateConfigHash' -and $LatestEvidence.gateConfigHash -and $ConfigHashNow -ne $LatestEvidence.gateConfigHash) {
      $stale += 'gate config hash changed since last verify'
    }
    if ($LatestEvidence.inputFingerprint -and $LatestEvidence.inputFingerprint -ne $FpNow.digest) {
      $stale += "evidence fingerprint stale (runId=$($LatestEvidence.runId))"
    }
    if ($LatestEvidence.headSha -and $FpNow.headSha -and $LatestEvidence.headSha -ne $FpNow.headSha) {
      $stale += "evidence headSha stale (runId=$($LatestEvidence.runId))"
    }
  }
  foreach ($r in @($Task.evidenceRefs)) {
    $p = Join-Path $RepoRoot $r
    if (-not (Test-Path $p)) { $stale += "evidenceRef missing on disk: $r" }
  }
  foreach ($r in @($Task.reviewRefs)) {
    $p = Join-Path $RepoRoot $r
    if (-not (Test-Path $p)) { $stale += "reviewRef missing on disk: $r" }
  }
  if ($Task.handoffRef) {
    $p = Join-Path $RepoRoot $Task.handoffRef
    if (-not (Test-Path $p)) { $stale += "handoffRef missing on disk: $($Task.handoffRef)" }
  }
  return ,$stale
}

function Test-AcCoverage {
  <#
    Every AC must have at least one artifact path that proves it.
    Sources checked in order:
      1. task.acEvidence["<AC-id>"] -> [artifact paths] (explicit map, checked for existence)
      2. Fallback: scan task.evidenceRefs/reviewRefs/roleReports/handoffRef files on disk;
         an artifact "covers" an AC if its file content mentions the AC id literal (e.g. "AC-3").
    Returns array of uncovered AC ids (empty = all covered).
  #>
  param(
    [object]$Task,
    [string]$RepoRoot
  )
  $uncovered = @()
  $acs = @()
  if ($Task.PSObject.Properties.Name -contains 'acceptanceCriteria' -and $Task.acceptanceCriteria) {
    $acs = @($Task.acceptanceCriteria)
  }
  if (-not $acs.Count) { return ,@('__no-acs__') }

  $acMap = @{}
  if ($Task.PSObject.Properties.Name -contains 'acEvidence' -and $Task.acEvidence) {
    if ($Task.acEvidence -is [System.Collections.IDictionary]) {
      foreach ($k in $Task.acEvidence.Keys) { $acMap[$k] = @($Task.acEvidence[$k]) }
    } else {
      foreach ($k in $Task.acEvidence.PSObject.Properties.Name) { $acMap[$k] = @($Task.acEvidence.$k) }
    }
  }

  # Build candidate artifact pool: all refs + handoff. Defensive: task fixtures in
  # tests and legacy tasks may not carry every field.
  $pool = New-Object System.Collections.Generic.List[string]
  foreach ($prop in 'evidenceRefs','reviewRefs','roleReports') {
    if ($Task.PSObject.Properties.Name -contains $prop -and $Task.$prop) {
      foreach ($r in @($Task.$prop)) { if ($r) { $pool.Add($r) } }
    }
  }
  if ($Task.PSObject.Properties.Name -contains 'handoffRef' -and $Task.handoffRef) {
    $pool.Add($Task.handoffRef)
  }

  # Lazy cache: path -> raw text content (or $null if missing).
  $contentCache = @{}
  $getContent = {
    param([string]$rel)
    if ($contentCache.ContainsKey($rel)) { return $contentCache[$rel] }
    $p = Join-Path $RepoRoot $rel
    if (-not (Test-Path $p)) { $contentCache[$rel] = $null; return $null }
    try {
      $c = Get-Content -Raw -LiteralPath $p -ErrorAction Stop
      $contentCache[$rel] = $c
      return $c
    } catch { $contentCache[$rel] = $null; return $null }
  }

  foreach ($ac in $acs) {
    $aid = $ac.id
    if (-not $aid) { $uncovered += '(unnamed-AC)'; continue }
    $covered = $false

    # 1. Explicit map: every listed path must exist on disk.
    if ($acMap.ContainsKey($aid) -and $acMap[$aid].Count -gt 0) {
      $allExist = $true
      foreach ($rel in $acMap[$aid]) {
        $p = Join-Path $RepoRoot $rel
        if (-not (Test-Path $p)) { $allExist = $false; break }
      }
      if ($allExist) { $covered = $true }
    }

    # 2. Fallback: any artifact in pool whose content mentions the AC id.
    if (-not $covered) {
      foreach ($rel in $pool) {
        $body = & $getContent $rel
        if ($body -and $body -match [regex]::Escape($aid)) { $covered = $true; break }
      }
    }

    if (-not $covered) { $uncovered += $aid }
  }
  return ,$uncovered
}

function Get-FinishBlockers {
  param(
    [object]$Task,
    [object]$LatestEvidence,
    [object]$FpNow,
    [string]$RepoRoot,
    [object]$Cfg
  )
  $errs = @()
  if (-not $LatestEvidence) {
    $errs += 'no verify evidence'
  } else {
    if ($LatestEvidence.inputFingerprint -ne $FpNow.digest -or $LatestEvidence.headSha -ne $FpNow.headSha) {
      $errs += "stale evidence: fingerprint drift since runId=$($LatestEvidence.runId)"
    }
    $bad = @($LatestEvidence.gates | Where-Object { $_.status -in @('failed','blocked') })
    if ($bad.Count) { $errs += "gates not passed: $(($bad | ForEach-Object { $_.gateId }) -join ',')" }
    if ($LatestEvidence.stale -eq $true) { $errs += "evidence itself marked stale (runId=$($LatestEvidence.runId))" }
  }

  # Independent review is required for every risk lane when the policy demands it.
  # The 'tiny' lane does not bypass review (contract lane table + AGENT_WORKFLOW.md).
  $requireReview = $true
  if ($Cfg -and $Cfg.PSObject.Properties.Name -contains 'policy' -and $Cfg.policy -and
      ($Cfg.policy.PSObject.Properties.Name -contains 'requireIndependentReview')) {
    $requireReview = [bool]$Cfg.policy.requireIndependentReview
  }
  if ($requireReview -and (-not $Task.reviewRefs -or $Task.reviewRefs.Count -eq 0)) {
    $errs += "no independent reviewRefs (risk=$($Task.risk); policy.requireIndependentReview=$requireReview)"
  }

  if (-not $Task.handoffRef) { $errs += 'missing handoffRef' }

  foreach ($r in @($Task.evidenceRefs)) {
    $p = Join-Path $RepoRoot $r
    if (-not (Test-Path $p)) { $errs += "evidenceRef missing on disk: $r" }
  }
  foreach ($r in @($Task.reviewRefs)) {
    $p = Join-Path $RepoRoot $r
    if (-not (Test-Path $p)) { $errs += "reviewRef missing on disk: $r" }
  }
  if ($Task.handoffRef) {
    $p = Join-Path $RepoRoot $Task.handoffRef
    if (-not (Test-Path $p)) { $errs += "handoffRef missing on disk: $($Task.handoffRef)" }
  }

  # AC coverage: every acceptance criterion must map to at least one concrete artifact.
  $uncovered = Test-AcCoverage -Task $Task -RepoRoot $RepoRoot
  if ($uncovered.Count -gt 0) {
    $errs += "acceptance criteria uncovered: $(($uncovered) -join ',')"
  }

  return ,$errs
}

Export-ModuleMember -Function Get-LatestVerifyEvidence,Get-ResumeStaleReasons,Get-FinishBlockers,Test-AcCoverage
