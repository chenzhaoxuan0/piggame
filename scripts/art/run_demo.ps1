param([switch]$Packed)
$ErrorActionPreference = 'Stop'
$projectRoot = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$engine = Join-Path $projectRoot '.tools/godot-4.3/Godot_v4.3-stable_win64.exe'
if (-not (Test-Path -LiteralPath $engine)) {
    throw 'Godot 4.3 is required. Open project.godot with Godot or restore the project-local engine.'
}
$arguments = @('--path', ('"' + $projectRoot + '"'), '--log-file', 'builds/play.log')
if ($Packed) {
    $pack = Join-Path $projectRoot 'builds/windows/PigGoldenFarm.pck'
    if (-not (Test-Path -LiteralPath $pack)) { throw 'Export the Windows Art Demo pack first.' }
    $arguments += @('--main-pack', ('"' + $pack + '"'))
}
Start-Process -FilePath $engine -ArgumentList $arguments -WorkingDirectory $projectRoot -WindowStyle Normal
