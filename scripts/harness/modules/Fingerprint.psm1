# Fingerprint.psm1 - Input fingerprint per contract: HEAD + tracked/staged/untracked + config/lock/task.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$script:ExclusionPrefixes = @(
  '.git/','.gitnexus/','.harness/runs/','.harness/tmp/','.harness/locks/','.harness/local/'
)
$script:ExclusionGlobs = @(
  '**/node_modules/**','**/.next/**','**/target/**','**/build/**','**/.dart_tool/**',
  '**/bin/**','**/obj/**','**/dist/**','**/out/**','repomix-output.xml'
)

function Test-Excluded {
  param([string]$RelPath)
  $r = $RelPath -replace '\\','/'
  foreach ($p in $script:ExclusionPrefixes) { if ($r.StartsWith($p,[StringComparison]::OrdinalIgnoreCase)) { return $true } }
  foreach ($g in $script:ExclusionGlobs) {
    if ($r -like $g -or $r -like ($g -replace '^\*\*/','')) { return $true }
  }
  return $false
}

function Get-HeadSha {
  param([string]$RepoRoot)
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $sha = & git -C $RepoRoot rev-parse --verify HEAD 2>$null
    if ($LASTEXITCODE -ne 0 -or -not $sha) { return $null }
    return ($sha | Select-Object -First 1).Trim()
  } finally { $ErrorActionPreference = $prev }
}

function Get-GitStatusEntries {
  param([string]$RepoRoot)
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $raw = & git -C $RepoRoot status --porcelain=v1 -z --untracked-files=all --ignored=no 2>$null
    if ($LASTEXITCODE -ne 0) { throw "git status failed: $raw" }
    if (-not $raw) { return @() }
    $entries = @()
    $parts = ([string]$raw) -split "`0"
    foreach ($p in $parts) {
      if (-not $p) { continue }
      if ($p.Length -lt 4) { continue }
      $xy = $p.Substring(0,2); $path = $p.Substring(3)
      $entries += [pscustomobject]@{ xy=$xy; path=$path }
    }
    return $entries
  } finally { $ErrorActionPreference = $prev }
}

function Get-FileSha256 {
  param([string]$Path)
  $h = [System.Security.Cryptography.SHA256]::Create()
  try {
    $fs = [System.IO.File]::OpenRead($Path)
    $bytes = $h.ComputeHash($fs); $fs.Close()
    return ([BitConverter]::ToString($bytes) -replace '-','').ToLowerInvariant()
  } finally { $h.Dispose() }
}

function Get-StringSha256 {
  param([string]$Text)
  $h = [System.Security.Cryptography.SHA256]::Create()
  try {
    $bytes = $h.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Text))
    return ([BitConverter]::ToString($bytes) -replace '-','').ToLowerInvariant()
  } finally { $h.Dispose() }
}

function Get-IndexBlobState {
  param([string]$RepoRoot)
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $raw = & git -C $RepoRoot ls-files -s 2>$null
    if ($LASTEXITCODE -ne 0) { return @() }
    $out = @()
    foreach ($l in $raw) {
      if (-not $l) { continue }
      if ($l -match '^(\d+) ([0-9a-f]{40}) (\d+)\t(.+)$') {
        $out += [pscustomobject]@{ mode=$Matches[1]; sha=$Matches[2]; stage=$Matches[3]; path=$Matches[4] }
      }
    }
    return $out
  } finally { $ErrorActionPreference = $prev }
}

function Get-InputFingerprint {
  param(
    [Parameter(Mandatory)] [string]$RepoRoot,
    [string]$TaskId,
    [string]$ConfigPath = (Join-Path $RepoRoot '.harness/config.json'),
    [string]$SchemaPath = (Join-Path $RepoRoot '.harness/schemas/task.schema.json')
  )
  $head = Get-HeadSha -RepoRoot $RepoRoot
  $items = New-Object System.Collections.Generic.List[string]

  # Per-task fingerprintExcludes: optional prefixes declared in task.json that
  # should NOT contribute to this task's fingerprint (e.g. 'design/' owned by a
  # different agent). We load them up-front so all sections honour them.
  $taskExcludes = @()
  if ($TaskId) {
    $tjPath = Join-Path $RepoRoot "tasks/$TaskId/task.json"
    if (Test-Path $tjPath) {
      try {
        $tjObj0 = Get-Content -Raw -LiteralPath $tjPath | ConvertFrom-Json
        if ($tjObj0.PSObject.Properties.Name -contains 'fingerprintExcludes' -and $tjObj0.fingerprintExcludes) {
          $taskExcludes = @($tjObj0.fingerprintExcludes | ForEach-Object { ([string]$_) -replace '\\','/' })
        }
      } catch { $taskExcludes = @() }
    }
  }
  $isExcluded = {
    param([string]$rel)
    if (Test-Excluded $rel) { return $true }
    foreach ($x in $taskExcludes) {
      $xn = $x.TrimEnd('/')
      if ($rel -eq $xn -or $rel.StartsWith("$xn/")) { return $true }
    }
    return $false
  }
  # For the CURRENT task's own task.json, exclude it from the generic tracked/
  # staged/untracked listing — it is hashed separately below with spec-only
  # semantics so that workflow-state edits (evidenceRefs, reviewRefs, status)
  # do not create a self-stale cycle.
  $ownTaskJson = if ($TaskId) { "tasks/$TaskId/task.json" } else { $null }

  # 1) tracked + staged + untracked via ls-files (covers unborn HEAD).
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $tracked = & git -C $RepoRoot ls-files -z 2>$null
    $trackedList = @()
    if ($tracked) { $trackedList = ([string]$tracked) -split "`0" | Where-Object { $_ } }
    foreach ($p in $trackedList) {
      if (& $isExcluded $p) { continue }
      if ($ownTaskJson -and $p -eq $ownTaskJson) { continue }
      $full = Join-Path $RepoRoot ($p -replace '/','\')
      if (Test-Path $full) {
        $items.Add("tracked:$p=$(Get-FileSha256 -Path $full)")
      } else {
        $items.Add("deleted:$p")
      }
    }

  # 2) staged blob state (catches staged-but-not-yet-committed and renames).
  $staged = Get-IndexBlobState -RepoRoot $RepoRoot
  foreach ($s in $staged) {
    if (& $isExcluded $s.path) { continue }
    if ($ownTaskJson -and $s.path -eq $ownTaskJson) { continue }
    $items.Add("staged:$($s.path)=$($s.sha)@$($s.stage)")
  }

    # 3) untracked nonignored.
    $untracked = & git -C $RepoRoot ls-files -o --exclude-standard -z 2>$null
    $untrackedList = @()
    if ($untracked) { $untrackedList = ([string]$untracked) -split "`0" | Where-Object { $_ } }
    foreach ($p in $untrackedList) {
      if (& $isExcluded $p) { continue }
      if ($ownTaskJson -and $p -eq $ownTaskJson) { continue }
      $full = Join-Path $RepoRoot ($p -replace '/','\')
      if (Test-Path $full) {
        $items.Add("untracked:$p=$(Get-FileSha256 -Path $full)")
      }
    }
  } finally { $ErrorActionPreference = $prev }

  # 4) renamed detection via status (R/C) — capture old+new pair.
  $statuses = Get-GitStatusEntries -RepoRoot $RepoRoot
  foreach ($s in $statuses) {
    if ($s.xy -match '^[RC]') { $items.Add("renamed:$($s.xy):$($s.path)") }
  }

  # 5) config/schema/task inputs (in scope regardless of git tracking).
  foreach ($extra in @($ConfigPath,$SchemaPath)) {
    if ($extra -and (Test-Path $extra)) {
      $rel = (Resolve-Path $extra).Path.Substring((Resolve-Path $RepoRoot).Path.Length).TrimStart('\','/') -replace '\\','/'
      $items.Add("input:$rel=$(Get-FileSha256 -Path $extra)")
    }
  }
  if ($TaskId) {
    $tj = Join-Path $RepoRoot "tasks/$TaskId/task.json"
    if (Test-Path $tj) {
      # Hash only the spec-immutable fields. Fields that must legitimately change
      # between verify and finish (evidenceRefs/reviewRefs/roleReports/handoffRef/
      # nextAction/status/updatedAt/resumeFrom/blockedReason/acEvidence) are
      # workflow state, not input drift — hashing them makes evidence-staleness
      # unfixable because every post-verify task update marks itself stale.
      try {
        $tjObj = Get-Content -Raw -LiteralPath $tj | ConvertFrom-Json
        # Immutable-after-start spec fields. Excluded (workflow state, mutable):
        # status, evidenceRefs, reviewRefs, roleReports, handoffRef, nextAction,
        # acEvidence, snapshot, blockedReason, resumeFrom, updatedAt, createdAt.
        $specFields = 'schemaVersion','id','type','risk','goal','owner','modules','scope','acceptanceCriteria','dependencies','planPath','baseCommit','inputFingerprint'
        $spec = [ordered]@{}
        foreach ($f in $specFields) {
          if ($tjObj.PSObject.Properties.Name -contains $f) { $spec[$f] = $tjObj.$f }
        }
        $specJson = ($spec | ConvertTo-Json -Depth 16 -Compress)
        $items.Add("task:$TaskId=$(Get-StringSha256 -Text $specJson)")
      } catch {
        # Fallback to whole-file hash on parse failure — stricter, not laxer.
        $items.Add("task:$TaskId=$(Get-FileSha256 -Path $tj)")
      }
    }
  }

  $sorted = $items | Sort-Object
  $digest = Get-StringSha256 -Text ($sorted -join "`n")
  return [pscustomobject]@{
    headSha = $head
    digest = $digest
    count = $sorted.Count
    computedAt = (Get-Date).ToString('o')
  }
}

Export-ModuleMember -Function Get-InputFingerprint,Get-HeadSha,Get-FileSha256,Get-StringSha256,Test-Excluded
