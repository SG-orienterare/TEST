#Requires -Version 5.1
<#
.SYNOPSIS
    Grupperar videomappar från Duplicate Cleaner Pro 5 efter datum.

.DESCRIPTION
    Duplicate Cleaner skapar en mapp per film med namn som:
      "7_5_2013 9_08_38 AM"
    (månad_dag_år timme_minut_sekund AM/PM)

    Skriptet flyttar alla filer till mappar med formatet:
      "2013-07-05"
    Alla filer från samma dag hamnar i samma mapp.

.PARAMETER SourcePath
    Rotmappen som innehåller alla Duplicate Cleaner-mappar.

.PARAMETER DestinationPath
    Vart de nya datummapparna ska skapas. Standard: samma som SourcePath.

.PARAMETER DryRun
    Visar vad som skulle göras utan att flytta något.

.PARAMETER VideoExtensions
    Filändelser som räknas som video. Standard: vanliga format.

.EXAMPLE
    .\Reorganize-VideoFolders.ps1 -SourcePath "D:\Videos\DuplicateCleaner" -DryRun

.EXAMPLE
    .\Reorganize-VideoFolders.ps1 -SourcePath "D:\Videos\DuplicateCleaner"
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [string]$DestinationPath = "",

    [switch]$DryRun,

    [string[]]$VideoExtensions = @('.mp4', '.mov', '.avi', '.mkv', '.m4v', '.wmv', '.mpg', '.mpeg', '.3gp', '.mts', '.m2ts')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-DateFromFolderName {
    param([string]$FolderName)

    # Format: M_D_YYYY H_M_S AM/PM  (t.ex. "7_5_2013 9_08_38 AM")
    if ($FolderName -notmatch '^(\d+)_(\d+)_(\d+)\s+(\d+)_(\d+)_(\d+)\s+(AM|PM)$') {
        return $null
    }

    $month  = [int]$Matches[1]
    $day    = [int]$Matches[2]
    $year   = [int]$Matches[3]
    $hour   = [int]$Matches[4]
    $minute = [int]$Matches[5]
    $second = [int]$Matches[6]
    $ampm   = $Matches[7]

    if ($ampm -eq 'PM' -and $hour -ne 12) { $hour += 12 }
    if ($ampm -eq 'AM' -and $hour -eq 12) { $hour = 0 }

    try {
        $dt = Get-Date -Year $year -Month $month -Day $day -Hour $hour -Minute $minute -Second $second
        return $dt
    }
    catch {
        return $null
    }
}

function Get-UniqueFilePath {
    param(
        [string]$Directory,
        [string]$FileName
    )

    $base   = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $ext    = [System.IO.Path]::GetExtension($FileName)
    $target = Join-Path $Directory $FileName

    if (-not (Test-Path -LiteralPath $target)) {
        return $target
    }

    $counter = 1
    do {
        $candidate = Join-Path $Directory ("{0}_{1}{2}" -f $base, $counter, $ext)
        $counter++
    } while (Test-Path -LiteralPath $candidate)

    return $candidate
}

# --- Validering ---
$SourcePath = (Resolve-Path -LiteralPath $SourcePath).Path
if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
    $DestinationPath = $SourcePath
}
else {
    if (-not (Test-Path -LiteralPath $DestinationPath)) {
        if ($DryRun) {
            Write-Host "Skapar destinationsmapp: $DestinationPath" -ForegroundColor Yellow
        }
        else {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
        }
    }
    $DestinationPath = (Resolve-Path -LiteralPath $DestinationPath).Path
}

$logPath = Join-Path $DestinationPath ("reorganize-log_{0:yyyyMMdd_HHmmss}.txt" -f (Get-Date))
$stats = @{
    FoldersScanned = 0
    FilesMoved     = 0
    FoldersRemoved = 0
    Skipped        = 0
    Errors         = 0
}

function Write-Log {
    param([string]$Message, [string]$Color = 'White')
    $line = "[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date), $Message
    Write-Host $line -ForegroundColor $Color
    if (-not $DryRun) {
        Add-Content -LiteralPath $logPath -Value $line -Encoding UTF8
    }
}

Write-Log "=== Reorganize Video Folders ===" Cyan
Write-Log "Källa: $SourcePath"
Write-Log "Destination: $DestinationPath"
Write-Log "DryRun: $DryRun"
Write-Log ""

# Hitta alla undermappar som matchar datumformatet
$sourceFolders = Get-ChildItem -LiteralPath $SourcePath -Directory | Where-Object {
    $null -ne (Get-DateFromFolderName -FolderName $_.Name)
}

Write-Log "Hittade $($sourceFolders.Count) mappar att bearbeta." Green

foreach ($folder in $sourceFolders) {
    $stats.FoldersScanned++

    $date = Get-DateFromFolderName -FolderName $folder.Name
    $targetFolderName = $date.ToString('yyyy-MM-dd')
    $targetFolderPath = Join-Path $DestinationPath $targetFolderName

    # Hitta videofiler i mappen (inte i undermappar)
    $videoFiles = Get-ChildItem -LiteralPath $folder.FullName -File | Where-Object {
        $VideoExtensions -contains $_.Extension.ToLower()
    }

    if ($videoFiles.Count -eq 0) {
        Write-Log "  HOPPAR ÖVER (ingen video): $($folder.Name)" Yellow
        $stats.Skipped++
        continue
    }

    foreach ($file in $videoFiles) {
        try {
            if (-not (Test-Path -LiteralPath $targetFolderPath)) {
                if ($DryRun) {
                    Write-Log "  SKULLE SKAPA: $targetFolderName" Yellow
                }
                else {
                    New-Item -ItemType Directory -Path $targetFolderPath -Force | Out-Null
                }
            }

            $destFile = Get-UniqueFilePath -Directory $targetFolderPath -FileName $file.Name

            if ($DryRun) {
                Write-Log "  SKULLE FLYTTA: $($file.Name)  <-  $($folder.Name)  ->  $targetFolderName\" Cyan
            }
            else {
                Move-Item -LiteralPath $file.FullName -Destination $destFile
                Write-Log "  FLYTTAD: $($file.Name)  <-  $($folder.Name)  ->  $targetFolderName\" Green
            }

            $stats.FilesMoved++
        }
        catch {
            Write-Log "  FEL vid flytt av $($file.FullName): $_" Red
            $stats.Errors++
        }
    }

    # Ta bort tom källmapp
    $remaining = Get-ChildItem -LiteralPath $folder.FullName -Force -ErrorAction SilentlyContinue
    if ($remaining.Count -eq 0) {
        if ($DryRun) {
            Write-Log "  SKULLE TA BORT TOM MAPP: $($folder.Name)" DarkGray
        }
        else {
            Remove-Item -LiteralPath $folder.FullName -Force
            Write-Log "  BORTTAGEN TOM MAPP: $($folder.Name)" DarkGray
        }
        $stats.FoldersRemoved++
    }
}

Write-Log ""
Write-Log "=== SAMMANFATTNING ===" Cyan
Write-Log "Mappar skannade:  $($stats.FoldersScanned)"
Write-Log "Filer flyttade:   $($stats.FilesMoved)"
Write-Log "Tomma mappar borta: $($stats.FoldersRemoved)"
Write-Log "Hoppade över:     $($stats.Skipped)"
Write-Log "Fel:              $($stats.Errors)"

if ($DryRun) {
    Write-Log ""
    Write-Log "Detta var en torrkörning. Kör utan -DryRun för att utföra ändringarna." Yellow
}
elseif ($stats.FilesMoved -gt 0) {
    Write-Log "Logg sparad: $logPath" Green
}
