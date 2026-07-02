$ErrorActionPreference = 'Continue'
$repoDir = 'C:\Users\pc\Desktop\yardim-takip'
$maxIter = 36
$iter = 0
$deployTriggered = $false
$deployedSha = $null
Set-Location $repoDir

function Log($msg) {
  Write-Host ("[" + (Get-Date -Format 'HH:mm:ss') + "] " + $msg)
}

function Get-PagesStatus {
  try {
    $r = Invoke-WebRequest -Uri 'https://www.githubstatus.com/api/v2/components.json' -UseBasicParsing -TimeoutSec 15
    $d = $r.Content | ConvertFrom-Json
    $p = $d.components | Where-Object { $_.name -eq 'Pages' }
    return $p.status
  } catch { return 'unknown' }
}

function Get-LatestRun {
  try {
    $r = Invoke-WebRequest -Uri 'https://api.github.com/repos/salimoglu/yardim-takip/actions/runs?per_page=1' -UseBasicParsing -TimeoutSec 15
    $d = $r.Content | ConvertFrom-Json
    return $d.workflow_runs[0]
  } catch { return $null }
}

function Get-LiveVersion {
  try {
    $r = Invoke-WebRequest -Uri ("https://salimoglu.github.io/yardim-takip/?nc=" + [guid]::NewGuid().ToString()) -UseBasicParsing -TimeoutSec 15 -Headers @{'Cache-Control'='no-cache'}
    $m = [regex]::Match($r.Content, '<meta name="version" content="([^"]+)"')
    if ($m.Success) { return $m.Groups[1].Value } else { return 'none' }
  } catch { return 'error' }
}

Log "=== DEPLOY WATCHER BASLADI ==="
Log ("Repo: " + $repoDir)
Log ("Onceki version canliya: " + (Get-LiveVersion))

while ($iter -lt $maxIter) {
  $iter++
  $status = Get-PagesStatus
  $run    = Get-LatestRun
  if ($run) {
    $runInfo = $run.head_sha.Substring(0,7) + " " + $run.status + "/" + $run.conclusion
  } else {
    $runInfo = "n/a"
  }
  Log ("Iter " + $iter + "/" + $maxIter + " Pages: " + $status + " | son run: " + $runInfo)

  if ($deployTriggered) {
    if ($run -and $run.head_sha -eq $deployedSha -and $run.status -eq 'completed') {
      if ($run.conclusion -eq 'success') {
        $ver = Get-LiveVersion
        Log ("DEPLOY_SUCCESS canli version: " + $ver)
        Log "MONITOR_DONE_OK"
        break
      } else {
        Log ("Bizim tetikledigimiz deploy fail oldu, tekrar deneyecegim.")
        $deployTriggered = $false
        $deployedSha = $null
      }
    }
  }

  if (-not $deployTriggered -and $status -eq 'operational') {
    Log "PAGES_OPERATIONAL deploy tetikleniyor"
    try {
      git commit --allow-empty -m "Auto-redeploy: Pages recovered" 2>&1 | Out-Host
      $push = git push 2>&1
      $push | Out-Host
      $sha = (git rev-parse HEAD).Trim()
      $deployedSha = $sha
      $deployTriggered = $true
      Log ("DEPLOY_PUSHED sha: " + $sha.Substring(0,7))
    } catch {
      Log ("Push_hatasi: " + $_.Exception.Message)
    }
  }

  Start-Sleep -Seconds 300
}

if ($iter -ge $maxIter) { Log "MONITOR_TIMEOUT" }
Log "=== BITTI ==="
