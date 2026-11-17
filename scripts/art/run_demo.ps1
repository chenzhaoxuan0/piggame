param(
    [switch]$Packed,
    [string]$Test = "",
    [switch]$AllTests,
    [switch]$PackCheck,
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
        # Enumerate every test under tests/ (skip capture_* / *_demo helpers by name filter).
        $testsRoot = Join-Path $projectRoot 'tests'
        $testScripts = @(Get-ChildItem -LiteralPath $testsRoot -Recurse -Filter 'test_*.gd' |
            Sort-Object FullName |
            ForEach-Object { 'tests/' + $_.FullName.Substring($testsRoot.Length + 1).Replace('\', '/') })
        Write-Host "Discovered $($testScripts.Count) test suites." -ForegroundColor Cyan
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
        # 0xC0000005 (-1073741819) is an engine-level access violation that
        # haunts the dummy renderer under load (big scenes + skeletal clips);
        # it never reproduces on a standalone rerun. One retry before calling
        # it a failure keeps the suite's signal honest.
        $crash_retries = 0
        while ($LASTEXITCODE -eq -1073741819 -and $crash_retries -lt 2) {
            $crash_retries++
            Write-Host "CRASHED (engine access violation) - retry $crash_retries/2: $ts" -ForegroundColor DarkYellow
            & $engine $argsList
        }
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

# Pack verification: export the .pck, byte-scan it, and boot it standalone.
# GDScript preload dependencies are NOT auto-collected by the "resources" export
# filter, so anything missing from export_files only shows up here.
if ($PackCheck) {
    $engine = if ($engineConsole) { $engineConsole } else { $engineGui }
    $pack = Join-Path $projectRoot 'builds/windows/PigGoldenFarm.pck'
    New-Item -ItemType Directory -Path (Split-Path $pack -Parent) -Force | Out-Null

    # Native stderr must not trip $ErrorActionPreference='Stop' (the headless dummy
    # renderer prints harmless ERROR lines), so capture both streams as plain text.
    function Invoke-EngineLogged([string[]]$EngineArgs, [string]$LogPath, [string]$WorkDir = '') {
        $previous = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        try {
            if ($WorkDir -ne '') { Push-Location $WorkDir }
            & $engine @EngineArgs 2>&1 | ForEach-Object { "$_" } | Out-File -FilePath $LogPath -Encoding utf8
            return $LASTEXITCODE
        } finally {
            if ($WorkDir -ne '') { Pop-Location }
            $ErrorActionPreference = $previous
        }
    }

    Write-Host "Exporting pack..." -ForegroundColor Cyan
    $exportLog = Join-Path $buildsDir 'export_pack.log'
    $exportExit = Invoke-EngineLogged @('--headless', '--path', $projectRoot, '--export-pack', 'Windows Art Demo', $pack) $exportLog
    if ($exportExit -ne 0 -or -not (Test-Path -LiteralPath $pack)) {
        Get-Content $exportLog -Tail 30
        throw "Export failed (exit $exportExit). See $exportLog"
    }
    if (Select-String -Path $exportLog -Pattern 'SCRIPT ERROR' -Quiet) {
        Select-String -Path $exportLog -Pattern 'SCRIPT ERROR' | Select-Object -First 10
        throw "Export log contains script errors. See $exportLog"
    }
    Write-Host ("Exported {0:N1} MB" -f ((Get-Item -LiteralPath $pack).Length / 1MB)) -ForegroundColor Green

    Write-Host "Scanning pack contents..." -ForegroundColor Cyan
    $bytes = [System.IO.File]::ReadAllBytes($pack)
    $text = [System.Text.Encoding]::GetEncoding(28591).GetString($bytes)
    $mustContain = @(
        'res://scripts/battle/pokemon_showdown.gd.remap',
        'res://scripts/courses/course_02_creek.gd.remap',
        'res://scripts/courses/course_03_woodland.gd.remap',
        'res://scripts/courses/course_04_courtyard.gd.remap',
        'res://scenes/courses/course_02_creek.tscn.remap',
        'res://scenes/courses/course_03_woodland.tscn.remap',
        'res://scenes/courses/course_04_courtyard.tscn.remap',
        'voxel_push_block.gd.remap', 'voxel_slime_block.gd.remap', 'voxel_water_stream.gd.remap',
        'voxel_pressure_plate.gd.remap', 'voxel_obsidian_wall.gd.remap',
        'cardboard_box_prop.gd.remap', 'pinecone_prop.gd.remap', 'patrol_vision_cone.gd.remap',
        'illusory_wall.gd.remap', 'mimic_chest.gd.remap', 'bouncy_mushroom.gd.remap',
        'boost_pad.gd.remap', 'watermelon_peel.gd.remap', 'racing_finish_gate.gd.remap',
        'mystery_item_box.gd.remap', 'stunt_jump_ramp.gd.remap', 'neon_bumper.gd.remap',
        'zone_environment.gd.remap', 'race_timer.gd.remap', 'mud_patch.gd.remap', 'patrol_guard_dog.gd.remap', 'sweet_potato_pickup.gd.remap', 'conveyor_belt.gd.remap', 'drowsy_fog.gd.remap',
        'res://scripts/courses/course_00_nightmare.gd.remap', 'res://scenes/courses/course_00_nightmare.tscn.remap',
        'pastoral_farm.scn', 'runtime_catalog.json', 'res://scripts/ui/game_hud.gd.remap', 'res://scripts/ui/menus.gd.remap',
        'res://scenes/ui/opening_scene.tscn.remap', 'res://scripts/ui/opening_scene.gd.remap',
        'res://scripts/ui/ui_kit.gd.remap', 'res://scripts/core/achievement_manager.gd.remap'
    )
    # Absent checks target real pack entries (.remap/.gdc/.import), because plain path
    # strings also appear inside the packed .godot/uid_cache.bin for every project resource.
    $mustAbsent = @(
        'res://.env', '_lux3d.zip', 'res://tests/', 'res://scenes/tests/',
        'farm_greybox.tscn.remap', 'farm_greybox.gd.remap', 'test_greybox.gd.remap',
        'character_selection.tscn.remap', 'character_selection.gd.remap', 'character_selection.gdc',
        'produce_assets.py', 'production.json'
    )
    $mustAbsentRegex = @(
        'res://assets/art_references/[\w\-./]{1,150}\.import'
    )
    $bad = $false
    foreach ($needle in $mustContain) {
        if (-not $text.Contains($needle)) { Write-Host "PACK MISSING: $needle" -ForegroundColor Red; $bad = $true }
    }
    foreach ($needle in $mustAbsent) {
        if ($text.Contains($needle)) { Write-Host "PACK LEAKED: $needle" -ForegroundColor Red; $bad = $true }
    }
    foreach ($re in $mustAbsentRegex) {
        if ([regex]::IsMatch($text, $re)) { Write-Host "PACK LEAKED (regex): $re" -ForegroundColor Red; $bad = $true }
    }
    if ($bad) { throw 'Pack content check failed.' }
    Write-Host "Pack contents OK." -ForegroundColor Green

    Write-Host "Booting pack standalone from an empty folder..." -ForegroundColor Cyan
    $probeDir = New-Item -ItemType Directory -Path (Join-Path $env:TEMP ("packprobe_" + [guid]::NewGuid().ToString('N'))) -Force
    $probeLog = Join-Path $probeDir 'probe.log'
    [void](Invoke-EngineLogged @('--headless', '--main-pack', $pack, '--quit-after', '300') $probeLog $probeDir.FullName)
    $errors = Select-String -Path $probeLog -Pattern 'SCRIPT ERROR', 'Failed to load script', 'Parse Error'
    if ($errors) {
        $errors | Select-Object -First 10 | ForEach-Object { Write-Host $_.Line -ForegroundColor Red }
        throw "Exported pack fails to boot. See $probeLog"
    }
    Remove-Item -Recurse -Force $probeDir.FullName -ErrorAction SilentlyContinue
    Write-Host "PACK CHECK PASSED" -ForegroundColor Green
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
