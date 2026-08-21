# Prepares the umu-launcher zipapp that was just extracted into this directory.
#
# Nothing is copied into the game directory. The launcher runs the zipapp where it
# sits, through the CommandTemplate in the option schema, which points here.
#
# Working directory: {InstallDir}/.lancommander/{RedistributableId}/Files/
# No elevation: everything happens inside the game's own metadata directory.

$metadata = Join-Path $InstallDirectory (Join-Path '.lancommander' $RedistributableManifest.Id)
$umuRun = Join-Path (Join-Path $metadata 'Files') 'umu-run'

if (-not (Test-Path -LiteralPath $umuRun)) {
    Write-Error "umu-run is missing from $umuRun; the payload did not extract as expected"
    $Return = 1
    return
}

# The executable bit does not survive the ZIP the payload ships in -- ZipArchive
# records no Unix mode, so the file arrives 0644. The CommandTemplate invokes it
# through python3 and so does not strictly need it, but anyone running it by hand
# does, and umu re-executes itself in places.
try {
    [System.IO.File]::SetUnixFileMode($umuRun,
        [System.IO.UnixFileMode] 'UserRead, UserWrite, UserExecute, GroupRead, GroupExecute, OtherRead, OtherExecute')
}
catch {
    & chmod 755 $umuRun
}

# umu-run is a Python zip application: it bundles umu and its dependencies but not
# an interpreter. Without python3 the game fails at launch with nothing more useful
# than "No such file or directory", so say so here, where somebody will read it.
$python = Get-Command python3 -ErrorAction SilentlyContinue

if (-not $python) {
    Write-Error "python3 was not found on PATH. umu-launcher needs Python 3.10 or newer -- install your distribution's python3 package, then reinstall this game's redistributables."
    $Return = 1
    return
}

$reported = & python3 -c 'import sys; print("{}.{}".format(sys.version_info[0], sys.version_info[1]))'

if ([version] $reported -lt [version] '3.10') {
    Write-Warning "python3 on PATH reports $reported; umu-launcher requires 3.10 or newer and will fail at launch."
}

Write-Host "umu-launcher $($RedistributableManifest.Version) is ready at $umuRun (python $reported)"

# Written last, and only once everything above has succeeded: DetectInstall
# compares against this, so it must not exist unless the deployment is usable.
Set-Content -LiteralPath (Join-Path $metadata 'InstalledVersion.txt') `
    -Value ([string] $RedistributableManifest.Version) -Encoding utf8 -NoNewline

$Return = 0
