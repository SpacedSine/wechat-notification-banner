# 批量导出：给每个种子出一张透明底 PNG（Windows / PowerShell）
#
# 用法：
#   .\batch-export.ps1                                     # 默认 6 张，种子 1..6
#   .\batch-export.ps1 -Seed 1013,7,42 -Scale 3
#   .\batch-export.ps1 -Name 导演 -Msg "第三幕重来" -Time 昨天 -Fit width
#
# 原理：用无头 Chrome 打开 index.html?mode=raw&emit=1，把画布导出的
#      base64 PNG 从 DOM 里取出来写成文件，所以拿到的和你点「下载」完全一致。

param(
  [string]$Seed = '1,2,3,4,5,6',
  [string]$Name = '老师',
  [string]$Msg = '什么时候交作业?',
  [string]$Time = '现在',
  [int]$Scale = 3,
  [ValidateSet('fit','width','fixed')][string]$Fit = 'width',
  [int]$Amount = 100,
  [ValidateSet('none','color')][string]$Bg = 'none',
  [string]$Color = '#3f3e52',
  [string]$OutDir = (Join-Path $PSScriptRoot '..\out'),
  [string]$Page = (Join-Path $PSScriptRoot '..\index.html')
)

$ErrorActionPreference = 'Stop'

$chrome = @(
  "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
  "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe",
  "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
  "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
  "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

if (-not $chrome) { throw '找不到 Chrome 或 Edge，请先安装其中之一' }
if (-not (Test-Path $Page)) { throw "找不到 $Page（先在仓库根目录运行构建，或直接使用仓库里的 index.html）" }

New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$pageUrl = 'file:///' + ((Resolve-Path $Page).Path -replace '\\','/')
$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ('wxbatch_' + [guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Force -Path $tmp | Out-Null

function Enc([string]$s){ [uri]::EscapeDataString($s) }

# 种子列表：以逗号/分号/空格分隔，自行切分（避免 PowerShell 把 "1013,7" 当成数字 10137）
$seedList = @($Seed -split '[,;\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ })
if ($seedList.Count -eq 0) { throw "种子参数无效：$Seed（示例：-Seed 1013,7,42）" }

$i = 0
foreach ($s in $seedList) {
  $i++
  $q = '?mode=raw&emit=1&deform=1' +
       '&u=' + (Enc $Name) + '&m=' + (Enc $Msg) + '&t=' + (Enc $Time) +
       "&s=$Scale&fit=$Fit&amount=$Amount&bg=$Bg&c=" + (Enc $Color) + "&seed=$s"
  $dump = Join-Path $tmp ("d$i.html")
  $ud   = Join-Path $tmp ("cr$i")
  $chromeArgs = @('--headless=new','--disable-gpu','--disable-breakpad','--no-first-run',
                  '--force-device-scale-factor=1','--hide-scrollbars',"--user-data-dir=$ud",
                  '--virtual-time-budget=9000','--dump-dom',($pageUrl + $q))

  $p = Start-Process -FilePath $chrome -ArgumentList $chromeArgs -RedirectStandardOutput $dump -NoNewWindow -PassThru
  $p.WaitForExit(60000) | Out-Null

  $html = ''
  for ($k = 0; $k -lt 12; $k++) {
    try { $html = [System.IO.File]::ReadAllText($dump, [System.Text.Encoding]::UTF8); break }
    catch { Start-Sleep -Milliseconds 400 }
  }
  $m = [regex]::Match($html, '(?s)<div id="raw-meta"[^>]*>(.*?)</div>')
  if (-not $m.Success) { Write-Warning "种子 $s 失败，跳过"; continue }

  # 只保留弹窗本身（透明底），不带背景色
  $b64 = $m.Groups[1].Value.Trim() -replace '^data:image/png;base64,',''
  $out = Join-Path $OutDir ("wx-banner_seed$s`_$($Scale)x.png")
  [System.IO.File]::WriteAllBytes($out, [Convert]::FromBase64String($b64))
  Write-Host ("[{0}/{1}] seed {2} -> {3}" -f $i, $seedList.Count, $s, (Split-Path $out -Leaf))
}

Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "完成，输出目录：$OutDir"
