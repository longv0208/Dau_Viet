#requires -Version 5.1
# Plain pwsh assertion-based tests for harness (Pester 5 fallback per contract).
# Usage: pwsh -File tests/harness/run-tests.ps1
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$modDir = Join-Path $repoRoot 'scripts/harness/modules'
Import-Module (Join-Path $modDir 'State.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $modDir 'Runner.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $modDir 'Fingerprint.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $modDir 'GitNexus.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $modDir 'Progress.psm1') -Force -DisableNameChecking
Import-Module (Join-Path $modDir 'ResumeFinish.psm1') -Force -DisableNameChecking

$script:Pass = 0; $script:Fail = 0; $script:Results = @()
function Assert-True { param([bool]$Cond,[string]$Name)
  if ($Cond) { $script:Pass++; $script:Results += "PASS $Name" } else { $script:Fail++; $script:Results += "FAIL $Name" }
}
function Assert-Equal { param($A,$B,[string]$Name) Assert-True ($A -eq $B) "$Name (expected=$B actual=$A)" }
function Assert-Match { param($Text,[string]$Pattern,[string]$Name) Assert-True ($Text -match $Pattern) "$Name (text=$Text pattern=$Pattern)" }

# ---------- fixture setup ----------
$fixture = Join-Path ([System.IO.Path]::GetTempPath()) ("harness-fixture-" + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $fixture -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $fixture '.harness/locks') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $fixture '.harness/schemas') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $fixture '.harness/runs') -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $fixture 'tasks/TASK-0001') -Force | Out-Null

# Minimal config.
@'
{"schemaVersion":1,"profile":"bootstrap","modules":{"backend":{"path":"dau-viet-backend","status":"uninitialized","manifests":["pom.xml"],"gates":[]}},"gates":[],"policy":{"maxRepairAttempts":3,"requireIndependentReview":true,"requireHandoff":true},"gitnexus":{"enabled":false,"version":null,"fallback":"targeted-search"}}
'@ | Out-File -FilePath (Join-Path $fixture '.harness/config.json') -Encoding utf8

# git init (unborn HEAD)
Push-Location $fixture
& git init -q 2>&1 | Out-Null
& git config user.email 'test@local' ; & git config user.name 'test'
Pop-Location

# Helper: run pwsh harness subcommand in fixture
function Invoke-Harness {
  param([string[]]$SubArgs)
  $h = Join-Path $repoRoot 'scripts/harness/harness.ps1'
  $exe = (Get-Command pwsh -ErrorAction SilentlyContinue)
  if (-not $exe) { $exe = (Get-Command powershell -ErrorAction SilentlyContinue) }
  $prev = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  try {
    $output = & $exe.Source -NoProfile -File $h @SubArgs -RepoRoot $fixture 2>&1 | Out-String
    return @{ out = $output; code = $LASTEXITCODE }
  } finally { $ErrorActionPreference = $prev }
}

# ---------- tests ----------

Write-Host "== fingerprint: unborn HEAD ==" -ForegroundColor Cyan
$fp = Get-InputFingerprint -RepoRoot $fixture
Assert-True ($null -eq $fp.headSha) 'unborn headSha is null'
Assert-True ($fp.digest -match '^[0-9a-f]{64}$') 'digest sha256 format'
Assert-True ($fp.count -gt 0) 'fingerprint counted inputs'

Write-Host "== fingerprint: excluded paths ==" -ForegroundColor Cyan
Assert-True (Test-Excluded '.git/config') 'excludes .git/'
Assert-True (Test-Excluded '.harness/runs/x.log') 'excludes .harness/runs/'
Assert-True (-not (Test-Excluded 'docs/README.md')) 'does not exclude docs'
Assert-True (Test-Excluded 'foo/node_modules/x.js') 'excludes node_modules'

Write-Host "== fingerprint: edit mid-run -> stale ==" -ForegroundColor Cyan
$f1 = Join-Path $fixture 'file1.txt'
'v1' | Out-File -FilePath $f1 -Encoding utf8
$a = Get-InputFingerprint -RepoRoot $fixture
'v2-changed' | Out-File -FilePath $f1 -Encoding utf8
$b = Get-InputFingerprint -RepoRoot $fixture
Assert-True ($a.digest -ne $b.digest) 'content edit changes digest'

Write-Host "== fingerprint: staged state changes digest ==" -ForegroundColor Cyan
Push-Location $fixture
& git add file1.txt 2>&1 | Out-Null
$c = Get-InputFingerprint -RepoRoot $fixture
Assert-True ($b.digest -ne $c.digest) 'staged state changes digest'

Write-Host "== fingerprint: rename detection ==" -ForegroundColor Cyan
& git mv file1.txt file1-renamed.txt 2>&1 | Out-Null
$d = Get-InputFingerprint -RepoRoot $fixture
Assert-True ($c.digest -ne $d.digest) 'rename changes digest'
Pop-Location

Write-Host "== fingerprint: deleted tracked ==" -ForegroundColor Cyan
Push-Location $fixture
'newfile' | Out-File -FilePath (Join-Path $fixture 'to-delete.txt') -Encoding utf8
& git add to-delete.txt ; & git commit -q -m 'x' 2>&1 | Out-Null
$preDel = Get-InputFingerprint -RepoRoot $fixture
Remove-Item (Join-Path $fixture 'to-delete.txt') -Force
$postDel = Get-InputFingerprint -RepoRoot $fixture
Pop-Location
Assert-True ($preDel.digest -ne $postDel.digest) 'delete changes digest'

Write-Host "== state: schema validation ==" -ForegroundColor Cyan
$badTask = [pscustomobject]@{ id='TASK-9999'; status='bogus' }
$errs = Test-TaskJsonSchema -Task $badTask
Assert-True ($errs.Count -gt 0) 'invalid task triggers schema errors'

$goodTask = [pscustomobject]@{
  schemaVersion=1; id='TASK-0001'; type='docs'; risk='tiny'; status='ready'
  goal='t'; owner='t'; modules=@(); scope=@('x')
  acceptanceCriteria=@(@{id='AC-1';text='t'}); dependencies=@()
  planPath='p.md'; evidenceRefs=@(); reviewRefs=@(); nextAction='x'
}
$errs2 = Test-TaskJsonSchema -Task $goodTask
Assert-Equal $errs2.Count 0 'valid task passes schema'

Write-Host "== state: transitions ==" -ForegroundColor Cyan
Assert-True (Test-StatusTransition -From 'ready' -To 'implementing') 'ready->implementing ok'
Assert-True (-not (Test-StatusTransition -From 'ready' -To 'done')) 'ready->done rejected'
Assert-True (-not (Test-StatusTransition -From 'blocked' -To 'done')) 'blocked->done rejected'
Assert-True (Test-StatusTransition -From 'blocked' -To 'implementing') 'blocked->implementing ok'
Assert-True (Test-StatusTransition -From 'verifying' -To 'blocked') 'verifying->blocked ok'

Write-Host "== state: atomic write + lock ==" -ForegroundColor Cyan
$taskPath = Join-Path $fixture 'tasks/TASK-0001/task.json'
@'
{"schemaVersion":1,"id":"TASK-0001","type":"docs","risk":"tiny","status":"ready","goal":"t","owner":"t","modules":[],"scope":["x"],"acceptanceCriteria":[{"id":"AC-1","text":"t"}],"dependencies":[],"planPath":"p.md","evidenceRefs":[],"reviewRefs":[],"nextAction":"x","createdAt":"2026-10-09T00:00:00+07:00","updatedAt":"2026-10-09T00:00:00+07:00","blockedReason":null,"resumeFrom":null,"handoffRef":null,"baseCommit":null,"inputFingerprint":null}
'@ | Out-File -FilePath $taskPath -Encoding utf8
$lock = Enter-TaskLock -RepoRoot $fixture -TaskId 'TASK-0001'
Assert-True (Test-Path $lock) 'lock file created'
# second acquire should fail (live pid)
$secondFailed = $false
try { Enter-TaskLock -RepoRoot $fixture -TaskId 'TASK-0001' | Out-Null } catch { $secondFailed = $true }
Assert-True $secondFailed 'second lock acquire refused for live pid'
Exit-TaskLock -LockPath $lock
Assert-True (-not (Test-Path $lock)) 'lock released'

Write-Host "== runner: success exit code ==" -ForegroundColor Cyan
$pwshExe = (Get-Command pwsh -ErrorAction SilentlyContinue); if (-not $pwshExe) { $pwshExe = (Get-Command powershell) }
$r = Invoke-HarnessGate -GateId 'ok' -Executable $pwshExe.Source -Arguments @('-NoProfile','-Command','exit 0') -WorkingDirectory $fixture -RepoRoot $fixture -TimeoutSeconds 30
Assert-Equal $r.status 'passed' 'runner passed on exit 0'
Assert-Equal $r.exitCode 0 'runner propagates exit 0'

Write-Host "== runner: nonzero propagates ==" -ForegroundColor Cyan
$r2 = Invoke-HarnessGate -GateId 'fail' -Executable $pwshExe.Source -Arguments @('-NoProfile','-Command','exit 7') -WorkingDirectory $fixture -RepoRoot $fixture -TimeoutSeconds 30
Assert-Equal $r2.status 'failed' 'runner failed on exit 7'
Assert-Equal $r2.exitCode 7 'runner propagates exit 7'
Assert-Match $r2.reason 'nonzero' 'runner reason mentions nonzero'

Write-Host "== runner: timeout ==" -ForegroundColor Cyan
$r3 = Invoke-HarnessGate -GateId 'slow' -Executable $pwshExe.Source -Arguments @('-NoProfile','-Command','Start-Sleep -Seconds 30') -WorkingDirectory $fixture -RepoRoot $fixture -TimeoutSeconds 2
Assert-Equal $r3.status 'failed' 'runner fails on timeout'
Assert-True $r3.timedOut 'timeout flag set'

Write-Host "== runner: missing executable ==" -ForegroundColor Cyan
$r4 = Invoke-HarnessGate -GateId 'missing' -Executable 'definitely-not-real-exe-xyz' -Arguments @() -WorkingDirectory $fixture -RepoRoot $fixture -TimeoutSeconds 5
Assert-Equal $r4.status 'failed' 'runner fails missing executable'
Assert-Match $r4.reason 'executable not found' 'runner reports missing executable'

Write-Host "== runner: cwd outside repo blocked ==" -ForegroundColor Cyan
$r5 = Invoke-HarnessGate -GateId 'evil' -Executable $pwshExe.Source -Arguments @('-NoProfile','-Command','exit 0') -WorkingDirectory 'C:\Windows' -RepoRoot $fixture -TimeoutSeconds 5
Assert-Equal $r5.status 'blocked' 'cwd outside repo blocked'

Write-Host "== runner: secret redaction ==" -ForegroundColor Cyan
$redact = Protect-Secrets 'token=abc1234567890xyz password=hunter2'
Assert-Match $redact 'REDACTED' 'secrets redacted'
Assert-True ($redact -notmatch 'hunter2') 'plaintext secret removed'

Write-Host "== gitnexus: absence -> fallback ==" -ForegroundColor Cyan
$gn = Get-GitNexusStatus -ExpectedVersion $null
if (-not $gn.available) {
  Assert-Equal $gn.fallback 'targeted-search' 'gitnexus absent -> targeted-search fallback'
  Assert-True ($gn.reason -ne $null -and $gn.reason.Length -gt 0) 'gitnexus absent -> reason provided'
} else {
  Assert-True $gn.available 'gitnexus available'
  Assert-True ($null -ne $gn.version) 'gitnexus version reported'
}

Write-Host "== harness.ps1: missing task ==" -ForegroundColor Cyan
$res = Invoke-Harness @('status','TASK-9999')
Assert-True ($res.code -ne 0) 'status on missing task returns nonzero'

Write-Host "== harness.ps1: verify on fixture ==" -ForegroundColor Cyan
# docs-only fixture task should run task-schema gate only; uninitialized module not engaged.
$res2 = Invoke-Harness @('verify','-TaskId','TASK-0001')
$verifyOut = $res2.out
Assert-True ($res2.code -in @(0,3,4)) "verify exit code 0/3/4 (got $($res2.code))"
Assert-Match $verifyOut 'verify status=' 'verify emits status line'

Write-Host "== resume: missing task fails ==" -ForegroundColor Cyan
$resRm = Invoke-Harness @('resume','-TaskId','TASK-9999')
Assert-True ($resRm.code -ne 0) 'resume on missing task returns nonzero'
Assert-Match $resRm.out 'not found|Task not found' 'resume missing task reports error'

Write-Host "== resume: on ready task reports deps and stale ==" -ForegroundColor Cyan
$resRr = Invoke-Harness @('resume','-TaskId','TASK-0001')
Assert-True ($resRr.code -in @(0,6)) "resume exit code 0 or 6 (got $($resRr.code))"
Assert-Match $resRr.out 'resumeFrom' 'resume emits resumeFrom in JSON'
Assert-Match $resRr.out 'inputFingerprint' 'resume emits fingerprint'

Write-Host "== finish: blocked without reviewRefs on non-tiny ==" -ForegroundColor Cyan
# TASK-0001 in fixture is tiny so reviewRefs not required by gate; test the blocker function directly.
$taskNormal = [pscustomobject]@{
  id='TASK-X'; risk='normal'; status='verifying'
  evidenceRefs=@(); reviewRefs=@(); handoffRef=$null
  inputFingerprint=$null; baseCommit=$null
}
$blockers = Get-FinishBlockers -Task $taskNormal -LatestEvidence $null -FpNow ([pscustomobject]@{digest='x';headSha=$null}) -RepoRoot $fixture
Assert-True ($blockers.Count -ge 2) 'finish blockers emitted for missing review+evidence+handoff'
Assert-True (($blockers -join ';') -match 'reviewRefs') 'blocker mentions reviewRefs'
Assert-True (($blockers -join ';') -match 'handoffRef') 'blocker mentions handoffRef'

Write-Host "== finish: stale fingerprint blocks ==" -ForegroundColor Cyan
$evStale = [pscustomobject]@{
  runId='r1'; inputFingerprint='aaa'; headSha='bbb'
  gates=@([pscustomobject]@{gateId='g1';status='passed'})
  stale=$false
}
$blockers2 = Get-FinishBlockers -Task $taskNormal -LatestEvidence $evStale -FpNow ([pscustomobject]@{digest='zzz';headSha='yyy'}) -RepoRoot $fixture
Assert-True (($blockers2 -join ';') -match 'stale') 'stale fingerprint reported as blocker'

Write-Host "== progress: regenerates docs/PROGRESS.md ==" -ForegroundColor Cyan
$progPath = Join-Path $fixture 'docs/PROGRESS.md'
New-Item -ItemType Directory -Path (Split-Path -Parent $progPath) -Force | Out-Null
$resProg = Invoke-Harness @('progress')
Assert-Equal $resProg.code 0 'progress subcommand exits 0'
Assert-True (Test-Path $progPath) 'PROGRESS.md generated'
$progBody = Get-Content -Raw -LiteralPath $progPath
Assert-Match $progBody 'generated:' 'PROGRESS.md carries generated marker'
Assert-Match $progBody 'TASK-0001' 'PROGRESS.md lists task'

Write-Host "== progress: cycle detected as error ==" -ForegroundColor Cyan
$taskA = [pscustomobject]@{ id='TASK-1001'; dependencies=@('TASK-1002') }
$taskB = [pscustomobject]@{ id='TASK-1002'; dependencies=@('TASK-1001') }
$cycleErrs = Test-TaskDependencyGraph -Tasks @($taskA,$taskB)
Assert-True ($cycleErrs.Count -gt 0) 'dependency cycle detected'
$missingErrs = Test-TaskDependencyGraph -Tasks @([pscustomobject]@{ id='TASK-1001'; dependencies=@('TASK-9999') })
Assert-True ($missingErrs.Count -gt 0) 'missing dependency detected'

Write-Host "== new-handoff: scaffolds from template ==" -ForegroundColor Cyan
New-Item -ItemType Directory -Path (Join-Path $fixture '.harness/templates') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $repoRoot '.harness/templates/handoff.md') -Destination (Join-Path $fixture '.harness/templates/handoff.md') -Force
$resNh = Invoke-Harness @('new-handoff','-TaskId','TASK-0001')
Assert-Equal $resNh.code 0 'new-handoff exit 0'
$hoPath = Join-Path $fixture 'tasks/TASK-0001/handoff.md'
Assert-True (Test-Path $hoPath) 'handoff.md scaffolded'
$hoBody = Get-Content -Raw -LiteralPath $hoPath
Assert-Match $hoBody 'TASK-0001 handoff' 'handoff renders TASK-ID placeholder'

Write-Host "== finish: tiny risk still requires review (P1-1) ==" -ForegroundColor Cyan
$taskTiny = [pscustomobject]@{
  id='TASK-T'; risk='tiny'; status='verifying'
  evidenceRefs=@(); reviewRefs=@(); handoffRef='x.md'
  acceptanceCriteria=@(@{id='AC-1';text='t'})
  inputFingerprint=$null; baseCommit=$null
}
$evOk = [pscustomobject]@{
  runId='r1'; inputFingerprint='aaa'; headSha='bbb'
  gates=@([pscustomobject]@{gateId='g1';status='passed'})
  stale=$false
}
$fpMatch = [pscustomobject]@{digest='aaa';headSha='bbb'}
$cfgWithPolicy = [pscustomobject]@{ policy=[pscustomobject]@{ requireIndependentReview=$true } }
$blkTiny = Get-FinishBlockers -Task $taskTiny -LatestEvidence $evOk -FpNow $fpMatch -RepoRoot $fixture -Cfg $cfgWithPolicy
Assert-True (($blkTiny -join ';') -match 'reviewRefs') 'tiny lane still requires reviewRefs'

Write-Host "== finish: AC coverage enforced (P1-2) ==" -ForegroundColor Cyan
# No acEvidence, no artifact mentions AC-1 -> blocked.
$blkAc = Get-FinishBlockers -Task $taskTiny -LatestEvidence $evOk -FpNow $fpMatch -RepoRoot $fixture -Cfg $cfgWithPolicy
Assert-True (($blkAc -join ';') -match 'AC-1') 'uncovered AC-1 is a blocker'

# acEvidence map with existing path covers the AC.
$acFile = Join-Path $fixture 'docs/ac1-proof.md'
New-Item -ItemType Directory -Path (Split-Path -Parent $acFile) -Force | Out-Null
'proof for AC-1' | Out-File -FilePath $acFile -Encoding utf8
$taskTiny2 = [pscustomobject]@{
  id='TASK-T2'; risk='tiny'; status='verifying'
  evidenceRefs=@(); reviewRefs=@('plans/reports/r.md'); handoffRef='tasks/T/handoff.md'
  acceptanceCriteria=@(@{id='AC-1';text='t'})
  acEvidence=@{ 'AC-1'=@('docs/ac1-proof.md') }
  inputFingerprint=$null; baseCommit=$null
}
# Create the referenced files so the existence check passes.
New-Item -ItemType Directory -Path (Join-Path $fixture 'plans/reports') -Force | Out-Null
'review' | Out-File -FilePath (Join-Path $fixture 'plans/reports/r.md') -Encoding utf8
New-Item -ItemType Directory -Path (Join-Path $fixture 'tasks/T') -Force | Out-Null
'handoff' | Out-File -FilePath (Join-Path $fixture 'tasks/T/handoff.md') -Encoding utf8
$blkAc2 = Get-FinishBlockers -Task $taskTiny2 -LatestEvidence $evOk -FpNow $fpMatch -RepoRoot $fixture -Cfg $cfgWithPolicy
Assert-True (-not (($blkAc2 -join ';') -match 'AC-1')) 'acEvidence covering AC-1 satisfies coverage'

# acEvidence pointing at missing file does NOT cover.
$taskTiny3 = [pscustomobject]@{
  id='TASK-T3'; risk='tiny'; status='verifying'
  evidenceRefs=@(); reviewRefs=@('plans/reports/r.md'); handoffRef='tasks/T/handoff.md'
  acceptanceCriteria=@(@{id='AC-1';text='t'})
  acEvidence=@{ 'AC-1'=@('docs/missing-proof.md') }
  inputFingerprint=$null; baseCommit=$null
}
$blkAc3 = Get-FinishBlockers -Task $taskTiny3 -LatestEvidence $evOk -FpNow $fpMatch -RepoRoot $fixture -Cfg $cfgWithPolicy
Assert-True (($blkAc3 -join ';') -match 'AC-1') 'acEvidence with missing path does not cover'

# Fallback: artifact whose content mentions the AC id covers it.
$fbFile = Join-Path $fixture 'docs/fallback.md'
'this artifact proves AC-1 works' | Out-File -FilePath $fbFile -Encoding utf8
$taskTiny4 = [pscustomobject]@{
  id='TASK-T4'; risk='tiny'; status='verifying'
  evidenceRefs=@('docs/fallback.md'); reviewRefs=@('plans/reports/r.md'); handoffRef='tasks/T/handoff.md'
  acceptanceCriteria=@(@{id='AC-1';text='t'})
  inputFingerprint=$null; baseCommit=$null
}
$blkAc4 = Get-FinishBlockers -Task $taskTiny4 -LatestEvidence $evOk -FpNow $fpMatch -RepoRoot $fixture -Cfg $cfgWithPolicy
Assert-True (-not (($blkAc4 -join ';') -match 'AC-1')) 'artifact mentioning AC-1 covers it via fallback'

Write-Host "== transitions: done is terminal ==" -ForegroundColor Cyan
Assert-True (-not (Test-StatusTransition -From 'done' -To 'done')) 'done->done rejected (no refinish)'
Assert-True (-not (Test-StatusTransition -From 'done' -To 'implementing')) 'done->implementing rejected'

Write-Host "== schema: acEvidence shape validated ==" -ForegroundColor Cyan
$badAc = [pscustomobject]@{
  schemaVersion=1; id='TASK-0001'; type='docs'; risk='tiny'; status='ready'
  goal='t'; owner='t'; modules=@(); scope=@('x')
  acceptanceCriteria=@(@{id='AC-1';text='t'}); dependencies=@()
  planPath='p.md'; evidenceRefs=@(); reviewRefs=@(); nextAction='x'
  acEvidence=@{ 'AC-99'=@('x.md') }
}
$acErrs = Test-TaskJsonSchema -Task $badAc
Assert-True (($acErrs -join ';') -match 'AC-99') 'acEvidence rejects non-AC keys'

$emptyAc = [pscustomobject]@{
  schemaVersion=1; id='TASK-0001'; type='docs'; risk='tiny'; status='ready'
  goal='t'; owner='t'; modules=@(); scope=@('x')
  acceptanceCriteria=@(@{id='AC-1';text='t'}); dependencies=@()
  planPath='p.md'; evidenceRefs=@(); reviewRefs=@(); nextAction='x'
  acEvidence=@{ 'AC-1'=@() }
}
$acErrs2 = Test-TaskJsonSchema -Task $emptyAc
Assert-True (($acErrs2 -join ';') -match 'AC-1') 'acEvidence rejects empty array'

$goodAc = [pscustomobject]@{
  schemaVersion=1; id='TASK-0001'; type='docs'; risk='tiny'; status='ready'
  goal='t'; owner='t'; modules=@(); scope=@('x')
  acceptanceCriteria=@(@{id='AC-1';text='t'}); dependencies=@()
  planPath='p.md'; evidenceRefs=@(); reviewRefs=@(); nextAction='x'
  acEvidence=@{ 'AC-1'=@('docs/ac1-proof.md') }
}
$acErrs3 = Test-TaskJsonSchema -Task $goodAc
Assert-Equal $acErrs3.Count 0 'valid acEvidence passes schema'

Write-Host "== fingerprint: task.json spec-only hashing ==" -ForegroundColor Cyan
# Updating workflow-state fields (evidenceRefs, reviewRefs, nextAction, updatedAt) must NOT drift fingerprint.
# Updating spec fields (acceptanceCriteria, scope, goal) MUST drift fingerprint.
Push-Location $fixture
$taskJsonPath = Join-Path $fixture 'tasks/TASK-0001/task.json'
$fpPre = Get-InputFingerprint -RepoRoot $fixture -TaskId 'TASK-0001'
# Mutate workflow state.
$tjObj = Get-Content -Raw -LiteralPath $taskJsonPath | ConvertFrom-Json
$tjObj.evidenceRefs = @('new/evidence.md')
$tjObj.reviewRefs = @('new/review.md')
$tjObj.nextAction = 'changed'
$tjObj.updatedAt = (Get-Date).ToString('o')
$json = $tjObj | ConvertTo-Json -Depth 16
[System.IO.File]::WriteAllText($taskJsonPath, $json, (New-Object System.Text.UTF8Encoding $false))
$fpPost = Get-InputFingerprint -RepoRoot $fixture -TaskId 'TASK-0001'
Assert-Equal $fpPost.digest $fpPre.digest 'workflow-state task.json edits do NOT drift fingerprint'
# Mutate spec field.
$tjObj2 = Get-Content -Raw -LiteralPath $taskJsonPath | ConvertFrom-Json
$tjObj2.acceptanceCriteria = @(@{id='AC-9'; text='changed'})
[System.IO.File]::WriteAllText($taskJsonPath, ($tjObj2 | ConvertTo-Json -Depth 16), (New-Object System.Text.UTF8Encoding $false))
$fpPost2 = Get-InputFingerprint -RepoRoot $fixture -TaskId 'TASK-0001'
Assert-True ($fpPost2.digest -ne $fpPre.digest) 'spec-field edit (acceptanceCriteria) DOES drift fingerprint'
Pop-Location

Write-Host "== Summary ==" -ForegroundColor Cyan
foreach ($l in $script:Results) { Write-Host $l }
Write-Host ""
Write-Host ("Total: $($script:Pass + $script:Fail)  Pass: $($script:Pass)  Fail: $($script:Fail)")

# cleanup
Pop-Location -ErrorAction SilentlyContinue
Remove-Item -LiteralPath $fixture -Recurse -Force -ErrorAction SilentlyContinue

if ($script:Fail -gt 0) { exit 1 } else { exit 0 }
