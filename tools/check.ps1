# check.ps1 — 知识库只读体检脚本（死链 / BOM / 编码 / 命名 / 头部行统计）
# 用法: pwsh tools/check.ps1 [-Root <知识库目录>]
# 退出码: 0 = 全部通过; 1 = 存在死链/BOM/非法编码（CI 会红）
param(
    [string]$Root = (Join-Path $PSScriptRoot "..\嵌入式工程师知识库")
)
try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch {}

$Root = [System.IO.Path]::GetFullPath($Root)
if (-not (Test-Path -LiteralPath $Root)) { Write-Output "ROOT NOT FOUND: $Root"; exit 1 }

$files = Get-ChildItem -LiteralPath $Root -Recurse -Filter *.md | Sort-Object FullName
$utf8  = New-Object System.Text.UTF8Encoding($false, $true)   # strict: throw on invalid bytes

$deadLinks = New-Object System.Collections.Generic.List[string]
$bomFiles  = New-Object System.Collections.Generic.List[string]
$badUtf8   = New-Object System.Collections.Generic.List[string]
$numbered = 0; $readmes = 0; $headerOk = 0; $totalLinks = 0

foreach ($f in $files) {
    $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
        $bomFiles.Add($f.FullName.Substring($Root.Length + 1))
    }
    try { $text = $utf8.GetString($bytes) } catch {
        $badUtf8.Add($f.FullName.Substring($Root.Length + 1)); continue
    }
    if ($f.Name -eq "README.md") { $readmes++ }
    elseif ($f.Name -match '^\d{2}-') {
        $numbered++
        if ($text -match '(?m)^>.*(等级|一句话)') { $headerOk++ }
    }

    # 死链扫描：跳过代码围栏内的行
    $inCode = $false
    $lines = $text -split "`r?`n"
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^\s*`{3,}') { $inCode = -not $inCode; continue }
        if ($inCode) { continue }
        foreach ($m in [regex]::Matches($line, '\]\(([^)]+)\)')) {
            $link = $m.Groups[1].Value.Trim()
            if ($link.Length -eq 0) { continue }
            if ($link -match '^(https?:|mailto:|ftp:|file:)' -or $link.StartsWith('#')) { continue }
            $path = ($link -replace '#.*$', '').Trim()
            if ($path.Length -eq 0) { continue }
            $path = ($path -replace '\s+"[^"]*"\s*$', '').Trim()
            if ($path.StartsWith('<') -and $path.EndsWith('>')) { $path = $path.Substring(1, $path.Length - 2) }
            $path = [uri]::UnescapeDataString($path)
            $totalLinks++
            $abs = [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($f.DirectoryName, $path))
            if (-not (Test-Path -LiteralPath $abs)) {
                $deadLinks.Add("$($f.FullName.Substring($Root.Length + 1)) :: line $($i + 1) :: $link")
            }
        }
    }
}

Write-Output "===== 知识库体检 ($Root) ====="
Write-Output ("md 文件总数      : " + $files.Count)
Write-Output ("域笔记(序号开头) : " + $numbered + "  其中含头部等级行: " + $headerOk)
Write-Output ("README 数        : " + $readmes)
Write-Output ("互链总数         : " + $totalLinks + "  死链: " + $deadLinks.Count)
Write-Output ("UTF-8 BOM        : " + $bomFiles.Count)
Write-Output ("非法 UTF-8 字节  : " + $badUtf8.Count)
if ($deadLinks.Count) { Write-Output "--- 死链明细 ---"; $deadLinks | ForEach-Object { Write-Output $_ } }
if ($bomFiles.Count)  { Write-Output "--- BOM 明细 ---";  $bomFiles  | ForEach-Object { Write-Output $_ } }
if ($badUtf8.Count)   { Write-Output "--- 非法编码明细 ---"; $badUtf8 | ForEach-Object { Write-Output $_ } }

if ($deadLinks.Count -or $bomFiles.Count -or $badUtf8.Count) {
    Write-Output "RESULT: FAIL"; exit 1
}
Write-Output "RESULT: PASS"; exit 0
