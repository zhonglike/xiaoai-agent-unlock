# 通用绕过：读取本机真实机型，写入官方安装包的机型白名单后运行安装
# 适用任意品牌机型（不写死型号）
# 用法: powershell -ExecutionPolicy Bypass -File patch_installer.ps1 -Installer "路径\安装包.exe"
param(
    [Parameter(Mandatory = $true)][string]$Installer
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Installer)) { throw "找不到安装包: $Installer" }

# ---------- 1. 读取本机所有可能的机型标识 ----------
$models = New-Object System.Collections.Generic.List[string]
try { $models.Add((Get-CimInstance Win32_BaseBoard).Product) } catch {}
try { $models.Add((Get-CimInstance Win32_ComputerSystem).Model) } catch {}
try { $models.Add((Get-CimInstance Win32_ComputerSystemProduct).Name) } catch {}
try { $models.Add((Get-CimInstance Win32_BIOS).SMBIOSBIOSVersion) } catch {}

$models = $models | Where-Object { $_ -and $_.Trim() -ne '' } | ForEach-Object { $_.Trim() } | Select-Object -Unique
Write-Host "本机机型标识:" -ForegroundColor Cyan
$models | ForEach-Object { Write-Host "  - $_" }
if ($models.Count -eq 0) { throw '无法读取本机机型信息' }

# ---------- 2. 定位安装包里的 support_tm_list ----------
$bytes = [System.IO.File]::ReadAllBytes($Installer)
$key = [System.Text.Encoding]::ASCII.GetBytes('"support_tm_list"')
$pattern = [System.Text.Encoding]::ASCII.GetBytes('"support_tm_list": [')

$start = -1
for ($i = 0; $i -le $bytes.Length - $pattern.Length; $i++) {
    $ok = $true
    for ($j = 0; $j -lt $pattern.Length; $j++) {
        if ($bytes[$i + $j] -ne $pattern[$j]) { $ok = $false; break }
    }
    if ($ok) { $start = $i + $pattern.Length - 1; break }   # 指向 '['
}
if ($start -lt 0) { throw '未在安装包中找到 support_tm_list 数组（可能不是该安装包）' }

$end = -1
for ($i = $start; $i -lt $bytes.Length; $i++) {
    if ($bytes[$i] -eq 0x5D) { $end = $i; break }           # ']'
}
if ($end -lt 0) { throw '数组未闭合' }
$len = $end - $start + 1
Write-Host "找到机型白名单，占 $len 字节" -ForegroundColor Cyan

# ---------- 3. 组等长替换内容（JSON 合法，空格填充） ----------
$body = "[`n    "
$first = $true
foreach ($m in $models) {
    $piece = if ($first) { '"' + $m + '"' } else { ",`n    " + '"' + $m + '"' }
    if (($body + $piece + "`n  ]").Length -gt $len) { continue }
    $body += $piece
    $first = $false
}
$tail = "`n  "
$pad = $len - $body.Length - $tail.Length - 1
if ($pad -lt 0) { throw '机型名过长，无法写入' }
$new = $body + $tail + (' ' * $pad) + ']'
if ($new.Length -ne $len) { throw "长度不匹配 $($new.Length) != $len" }

$newBytes = [System.Text.Encoding]::UTF8.GetBytes($new)
for ($i = 0; $i -lt $len; $i++) { $bytes[$start + $i] = $newBytes[$i] }

# ---------- 4. 写出并运行 ----------
$out = [System.IO.Path]::Combine(
    [System.IO.Path]::GetDirectoryName($Installer),
    [System.IO.Path]::GetFileNameWithoutExtension($Installer) + '_绕过版.exe')

[System.IO.File]::WriteAllBytes($out, $bytes)
Write-Host "已生成: $out" -ForegroundColor Green

if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host '正在请求管理员权限...' -ForegroundColor Yellow
    Start-Process -FilePath 'powershell' -Verb RunAs -ArgumentList @(
        '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath, '-Installer', $out)
    exit 0
}

Write-Host '开始安装（请按安装向导操作）...' -ForegroundColor Cyan
$p = Start-Process -FilePath $out -PassThru
$p.WaitForExit()
Write-Host "安装程序退出码: $($p.ExitCode)"
if ($p.ExitCode -eq -3) {
    Write-Host '提示: -3 通常是解压失败，请检查 C 盘剩余空间是否充足。' -ForegroundColor Yellow
}
