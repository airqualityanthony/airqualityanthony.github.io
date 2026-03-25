param(
	[string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$devLogsPath = Join-Path $ProjectRoot 'dev_logs'
$hubPath = Join-Path $ProjectRoot 'dev_logs.html'
$startMarker = '<!-- DEV_LOG_LIST_START -->'
$endMarker = '<!-- DEV_LOG_LIST_END -->'
$excludedFiles = @('template-dev-log.html')

if (-not (Test-Path $devLogsPath)) {
	throw "Dev logs directory not found: $devLogsPath"
}

if (-not (Test-Path $hubPath)) {
	throw "Hub page not found: $hubPath"
}

function Get-LogDateFromName {
	param([string]$FileName)

	if ($FileName -match '^(?<date>\d{4}-\d{2}-\d{2})') {
		return $matches['date']
	}

	return 'Undated'
}

function Get-LogTitle {
	param([System.IO.FileInfo]$File)

	$content = Get-Content -Path $File.FullName -Raw
	$h1Match = [regex]::Match($content, '<h1[^>]*>\s*(?<title>.*?)\s*</h1>', 'IgnoreCase, Singleline')

	if ($h1Match.Success) {
		$rawTitle = $h1Match.Groups['title'].Value
		$stripped = [regex]::Replace($rawTitle, '<[^>]+>', '')
		$title = $stripped.Trim()
		if ($title.Length -gt 0) {
			return $title
		}
	}

	$baseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
	$baseName = $baseName -replace '^\d{4}-\d{2}-\d{2}[-_\s]*', ''
	$parts = $baseName -split '[-_\s]+' | Where-Object { $_ -ne '' }
	if ($parts.Count -eq 0) {
		return $baseName
	}

	return (($parts | ForEach-Object { $_.Substring(0, 1).ToUpper() + $_.Substring(1) }) -join ' ')
}

function Get-EncodedHrefName {
	param([string]$FileName)

	return [System.Uri]::EscapeDataString($FileName)
}

$files = Get-ChildItem -Path $devLogsPath -File -Filter '*.html' |
	Where-Object { $excludedFiles -notcontains $_.Name } |
	Sort-Object -Property Name -Descending

$lines = foreach ($file in $files) {
	$date = [System.Net.WebUtility]::HtmlEncode((Get-LogDateFromName -FileName $file.Name))
	$title = [System.Net.WebUtility]::HtmlEncode((Get-LogTitle -File $file))
	$href = Get-EncodedHrefName -FileName $file.Name
	@(
		"`t`t`t<li class=`"log-item`">"
		"`t`t`t`t<a class=`"log-link`" href=`"dev_logs/$href`">"
		"`t`t`t`t`t<span class=`"log-title`">$title</span>"
		"`t`t`t`t`t<span class=`"log-date`">$date</span>"
		"`t`t`t`t</a>"
		"`t`t`t</li>"
	)
}

if (-not $lines) {
	$lines = @(
		"`t`t`t<li class=`"log-item`">"
		"`t`t`t`t<a class=`"log-link`" href=`"dev_logs/template-dev-log.html`">"
		"`t`t`t`t`t<span class=`"log-title`">Use this page as a starting point for new posts</span>"
		"`t`t`t`t`t<span class=`"log-date`">Template</span>"
		"`t`t`t`t</a>"
		"`t`t`t</li>"
	)
}

$listBlock = ($lines -join "`r`n")
$html = Get-Content -Path $hubPath -Raw

$pattern = "(?s)($([regex]::Escape($startMarker))).*?($([regex]::Escape($endMarker)))"
$replacement = "$startMarker`r`n$listBlock`r`n`t`t`t$endMarker"

$updatedHtml = [regex]::Replace($html, $pattern, $replacement)

if ($updatedHtml -eq $html) {
	throw 'Could not find list markers in dev_logs.html. Expected DEV_LOG_LIST_START/END markers.'
}

Set-Content -Path $hubPath -Value $updatedHtml -Encoding UTF8
Write-Host "Updated dev log list in: $hubPath"
