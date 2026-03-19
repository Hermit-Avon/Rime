param(
  [switch]$Check
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Format Rime YAML files in current directory (non-recursive).
# - trim trailing whitespace
# - in dictionary body (after `...`), normalize first separator:
#   "text code" / "text  code" -> "text<TAB>code"

$changed = $false
$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

$files = Get-ChildItem -LiteralPath . -File -Filter *.yaml | Sort-Object Name

foreach ($file in $files) {
  $lines = [System.IO.File]::ReadAllLines($file.FullName, $utf8NoBom)
  $out = New-Object System.Collections.Generic.List[string]
  $inDict = $false
  $fileChanged = $false

  foreach ($line in $lines) {
    $newLine = $line -replace '[ \t]+$', ''

    if ($newLine -eq '...') {
      $inDict = $true
      $out.Add($newLine)
      continue
    }

    if ($inDict) {
      if ($newLine -match '^\s*$' -or $newLine -match '^\s*#') {
        $out.Add($newLine)
        continue
      }
      if ($newLine.Contains("`t")) {
        # Normalize "text    <TAB>code" -> "text<TAB>code"
        $tabIndex = $newLine.IndexOf("`t")
        if ($tabIndex -gt 0) {
          $left = $newLine.Substring(0, $tabIndex) -replace '\s+$', ''
          $right = $newLine.Substring($tabIndex + 1)
          $newLine = "$left`t$right"
        }
      } elseif ($newLine -match '^\S+\s+\S') {
        # Normalize "text  code" -> "text<TAB>code"
        $newLine = $newLine -replace '^(\S+)\s+', "`$1`t"
      }
    }

    $out.Add($newLine)
  }

  if ($lines.Count -ne $out.Count) {
    $fileChanged = $true
  } else {
    for ($i = 0; $i -lt $lines.Count; $i++) {
      if ($lines[$i] -ne $out[$i]) {
        $fileChanged = $true
        break
      }
    }
  }

  if ($fileChanged) {
    if ($Check) {
      Write-Output "needs format: ./$($file.Name)"
      $changed = $true
    } else {
      [System.IO.File]::WriteAllLines($file.FullName, $out, $utf8NoBom)
      Write-Output "formatted: ./$($file.Name)"
      $changed = $true
    }
  }
}

if ($Check -and $changed) {
  exit 1
}
