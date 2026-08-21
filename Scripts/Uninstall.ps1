# Removes the Wine prefix this shim created.
#
# Everything else lives inside {InstallDir}/.lancommander/{RedistributableId}/,
# which the launcher deletes on its own. The prefix does not: umu creates it at
# launch, nothing tracks it, and it is never empty, so the launcher's own cleanup
# will not reach it. Left alone it orphans hundreds of megabytes per game.
#
# Working directory: {InstallDir}/.lancommander/{RedistributableId}/Files/
# Runs before the launcher deletes the tracked files and the metadata directory.

$Return = 0

$options = Get-RedistributableOptions -Path $InstallDirectory -Id $GameManifest.Id -Name 'umu-launcher'
$prefix = if ($options -and $options.Game) { [string] $options.Game.WINEPREFIX } else { '' }

if ([string]::IsNullOrWhiteSpace($prefix)) { return }

# Get-RedistributableOptions returns the stored value verbatim. Only the launcher
# expands {InstallDir}, and only when it sets the environment variable.
$prefix = $prefix.Replace('{InstallDir}', $InstallDirectory)

$resolvedPrefix = [System.IO.Path]::GetFullPath($prefix)
$resolvedInstall = [System.IO.Path]::GetFullPath($InstallDirectory)

# Only ever delete a prefix inside this game's own directory. An administrator who
# pointed WINEPREFIX at a shared prefix has other games depending on it, and
# uninstalling one of them must not take the rest with it.
if (-not $resolvedPrefix.StartsWith($resolvedInstall + [System.IO.Path]::DirectorySeparatorChar)) {
    Write-Host "Leaving the Wine prefix at $resolvedPrefix alone; it is outside $resolvedInstall and may be shared with other games"
    return
}

if (Test-Path -LiteralPath $resolvedPrefix) {
    Write-Host "Removing the Wine prefix at $resolvedPrefix"
    Remove-Item -LiteralPath $resolvedPrefix -Recurse -Force -ErrorAction SilentlyContinue
}
