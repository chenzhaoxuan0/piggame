param(
    [switch]$Packed,
    [string]$Test = "",
    [switch]$AllTests,
    [switch]$Console
)
$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))

# Ensure builds directory exists for logs
$buildsDir = Join-Path $projectRoot 'builds'
if (-not (Test-Path -LiteralPath $buildsDir)) {
    New-Item -ItemType Directory -Path $buildsDir -Force | Out-Null
}

# Auto-probe Godot engine path
$candidateGui = @(
    (Join-Path $projectRoot '.tools/godot-4.3/Godot_v4.3-stable_win64.exe'),
    'C:\Users\chenziyu\project\piggame\.tools\godot-4.3\Godot_v4.3-stable_win64.exe'
)
$candidateConsole = @(
    (Join-Path $projectRoot '.tools/godot-4.3/Godot_v4.3-stable_win64_console.exe'),
    'C:\Users\chenziyu\project\piggame\.tools\godot-4.3\Godot_v4.3-stable_win64_console.exe'
)

$engineGui = $candidateGui | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
$engineConsole = $candidateConsole | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

if (-not $engineGui -and -not $engineConsole) {
    $cmd = Get-Command godot -ErrorAction SilentlyContinue
    if ($cmd) {
        $engineGui = $cmd.Source
        $engineConsole = $cmd.Source
    }
}

if (-not $engineGui -and -not $engineConsole) {
    throw 'Godot 4.3 executable not found. Please ensure .tools/godot-4.3/ exists or godot is in PATH.'
}

# If running tests
if ($AllTests -or ($Test -ne "")) {
    $engine = if ($engineConsole) { $engineConsole } else { $engineGui }
    $testScripts = @()
    if ($AllTests) {
        $testScripts = @(
            'tests/scene/test_course_components.gd',
            'tests/scene/test_course_01_journey.gd',
            'tests/scene/test_chase_and_qte_journey.gd',
            'tests/scene/test_dodge_and_stamina.gd',
            'tests/scene/test_pokemon_battle.gd',
            'tests/scene/test_ui_improvements.gd',
            'tests/scene/test_farm_grounds.gd',
            'tests/scene/test_chase_polish.gd',
            'tests/scene/test_full_journey.gd'
        )
    } elseif ($Test -eq "journey" -or $Test -eq "full") {
        $testScripts = @('tests/scene/test_full_journey.gd')
    } elseif ($Test -eq "course" -or $Test -eq "courses") {
        $testScripts = @('tests/scene/test_course_components.gd', 'tests/scene/test_course_01_journey.gd')
    } else {
        $target = $Test
        if (-not (Test-Path -LiteralPath (Join-Path $projectRoot $target))) {
            if (Test-Path -LiteralPath (Join-Path $projectRoot "tests/scene/$target.gd")) {
                $target = "tests/scene/$target.gd"
            }
        }
        $testScripts = @($target)
    }

    Write-Host "Running $($testScripts.Count) test suite(s)..." -ForegroundColor Cyan
    $totalFailures = 0
    foreach ($ts in $testScripts) {
        Write-Host "`n>>> Running: $ts" -ForegroundColor Yellow
        $argsList = @('--headless', '--path', $projectRoot, '-s', $ts)
        & $engine $argsList
        if ($LASTEXITCODE -ne 0) {
            $totalFailures++
            Write-Host "FAILED: $ts (exit code $LASTEXITCODE)" -ForegroundColor Red
        } else {
            Write-Host "PASSED: $ts" -ForegroundColor Green
        }
    }
    if ($totalFailures -gt 0) {
        exit 1
    }
    exit 0
}

# Normal Demo Game Launch
$engine = if ($Console -and $engineConsole) { $engineConsole } elseif ($engineGui) { $engineGui } else { $engineConsole }
$arguments = @('--path', $projectRoot, '--log-file', (Join-Path $buildsDir 'play.log'))
if ($Packed) {
    $pack = Join-Path $projectRoot 'builds/windows/PigGoldenFarm.pck'
    if (-not (Test-Path -LiteralPath $pack)) { throw 'Export the Windows Art Demo pack first.' }
    $arguments += @('--main-pack', $pack)
}

Write-Host "Starting Pig Farm Demo..." -ForegroundColor Green
Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Normal
