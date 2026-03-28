<#
.SYNOPSIS
  Build the SM89 monograph PDF.

.DESCRIPTION
  Generates monograph assets, runs pdflatex twice for cross-references,
  verifies the PDF and checksums, and validates monograph assets.
  The PDF is output to tex/build/sm89_monograph.pdf.

.NOTES
  Equivalent of build_monograph_pdf.sh.
  Requires: python3, pdflatex
#>

$ErrorActionPreference = "Stop"

$Root    = Join-Path $PSScriptRoot ".." | Resolve-Path
$TexDir  = Join-Path $Root "tex"
$OutDir  = Join-Path $TexDir "build"
$LogFile = Join-Path ([System.IO.Path]::GetTempPath()) "sm89_monograph_pdflatex.log"

# Generate monograph assets
& python3 (Join-Path $Root "scripts" "generate_monograph_assets.py")
if ($LASTEXITCODE -ne 0) { throw "generate_monograph_assets.py failed" }

New-Item -ItemType Directory -Path $OutDir -Force | Out-Null

# Run pdflatex twice for cross-references
Push-Location $TexDir
try {
    & pdflatex -interaction=nonstopmode -halt-on-error "-output-directory=$OutDir" sm89_monograph.tex > $LogFile
    if ($LASTEXITCODE -ne 0) { throw "pdflatex first pass failed (see $LogFile)" }

    & pdflatex -interaction=nonstopmode -halt-on-error "-output-directory=$OutDir" sm89_monograph.tex > $LogFile
    if ($LASTEXITCODE -ne 0) { throw "pdflatex second pass failed (see $LogFile)" }
}
finally {
    Pop-Location
}

# Verify PDF, checksums, and assets
& python3 (Join-Path $Root "scripts" "verify_monograph_pdf.py")
if ($LASTEXITCODE -ne 0) { throw "verify_monograph_pdf.py failed" }

& python3 (Join-Path $Root "scripts" "write_monograph_checksums.py")
if ($LASTEXITCODE -ne 0) { throw "write_monograph_checksums.py failed" }

& python3 (Join-Path $Root "scripts" "verify_monograph_assets.py")
if ($LASTEXITCODE -ne 0) { throw "verify_monograph_assets.py failed" }

Write-Host "built_monograph_pdf"
Write-Host (Join-Path $OutDir "sm89_monograph.pdf")
