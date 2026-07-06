#Requires -Version 5.1
param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [string]$DestinationPath = "",

    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$ScriptVersion = '1.3'

function Get-DateFromFolderName {
    param([string]$FolderName)

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
        return Get-Date -Year $year -Month $month -Day $day -Hour $hour -Minute $minute -Second $second
    }
    catch {
        return $null
    }
}

function Get-UniqueFilePath {
    param([string]$Directory, [string]$FileName)

    $base   = [System.IO.Path]::GetFileNameWithoutExtension($FileName)
    $ext    = [System.IO.Path]::GetExtension($FileName)
    $target = Join-Path $Directory $FileName

    if (-not (Test-Path -LiteralPath $target)) { return $target }

    $counter = 1
    do {
        $candidate = Join-Path $Directory ("{0}_{1}{2}" -f $base, $counter, $ext)
        $counter++
    } while (Test-Path -LiteralPath $candidate)

    return $candidate
}

function Write-Log {
    param([string]$Message, [string]$Color = 'White')
    Write-Host ("[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date), $Message) -ForegroundColor $Color
}

$SourcePath = (Resolve-Path -LiteralPath $SourcePath).Path
if ([string]::IsNullOrWhiteSpace($DestinationPath)) {
    $DestinationPath = $SourcePath
}
elseif (-not (Test-Path -LiteralPath $DestinationPath)) {
    if (-not $DryRun) {
        New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
    }
    $DestinationPath = (Resolve-Path -LiteralPath $DestinationPath).Path
}
else {
    $DestinationPath = (Resolve-Path -LiteralPath $DestinationPath).Path
}

$stats = @{ Scanned = 0; Moved = 0; Removed = 0; Skipped = 0; Errors = 0 }

Write-Log "=== Reorganize Video Folders v$ScriptVersion ===" Cyan
Write-Log "Kalla: $SourcePath"
Write-Log "Destination: $DestinationPath"
Write-Log "DryRun: $DryRun"
Write-Log ""

$sourceFolders = @(Get-ChildItem -LiteralPath $SourcePath -Directory | Where-Object {
    $null -ne (Get-DateFromFolderName -FolderName $_.Name)
})

Write-Log "Hittade $($sourceFolders.Count) mappar att bearbeta." Green

foreach ($folder in $sourceFolders) {
    $stats.Scanned++

    $date = Get-DateFromFolderName -FolderName $folder.Name
    $targetFolderName = $date.ToString('yyyy_MM_dd')
    $targetFolderPath = Join-Path $DestinationPath $targetFolderName

    # Flytta alla filer i mappen (inte bara video)
    $files = @(Get-ChildItem -LiteralPath $folder.FullName -File -Force -ErrorAction SilentlyContinue)

    if ($files.Count -eq 0) {
        Write-Log "  HOPPAR OVER (ingen fil): $($folder.Name)" Yellow
        $stats.Skipped++
        continue
    }

    foreach ($file in $files) {
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

            $stats.Moved++
        }
        catch {
            Write-Log "  FEL: $($file.FullName) - $_" Red
            $stats.Errors++
        }
    }

    $remaining = @(Get-ChildItem -LiteralPath $folder.FullName -Force -ErrorAction SilentlyContinue)
    if ($remaining.Count -eq 0) {
        if ($DryRun) {
            Write-Log "  SKULLE TA BORT TOM MAPP: $($folder.Name)" DarkGray
        }
        else {
            Remove-Item -LiteralPath $folder.FullName -Force
        }
        $stats.Removed++
    }
}

Write-Log ""
Write-Log "=== SAMMANFATTNING ===" Cyan
Write-Log "Mappar skannade:    $($stats.Scanned)"
Write-Log "Filer flyttade:     $($stats.Moved)"
Write-Log "Tomma mappar borta: $($stats.Removed)"
Write-Log "Hoppade over:       $($stats.Skipped)"
Write-Log "Fel:                $($stats.Errors)"

if ($DryRun) {
    Write-Log ""
    Write-Log "Torrkorning klar. Kor: sortera_datum_mappar.bat KOR" Yellow
}
