<#
.SYNOPSIS
    Resolves and downloads the upstream umu-launcher zipapp.
.DESCRIPTION
    Contract:
      -CheckOnly            write the upstream version to stdout and exit.
      -OutputPath <dir>     download and extract the payload there, then emit a
                            JSON object with Version and optionally Changelog.

    Upstream publishes a .deb and an .rpm per supported distribution plus exactly
    one portable artefact: umu-launcher-<version>-zipapp.tar, holding umu/umu-run.
    That file is a Python zip application with a '#!/usr/bin/env python3' shebang.
    It bundles umu and its Python dependencies but NOT an interpreter -- the -p
    flag to 'python3 -m zipapp' sets the shebang, it does not embed anything -- so
    the client needs a system Python 3.10 or newer.

    Only the named member is extracted. The tar also carries umu/umu_run.py as a
    symlink to umu-run, which Windows cannot create and which a ZIP would store as
    a second full copy of the zipapp.

    Upstream tags without a leading 'v' ('1.4.4'). Resolve-UpstreamVersion only
    strips one when it is there, so the version passes through untouched.
#>
[CmdletBinding(DefaultParameterSetName = 'Download')]
param(
    [Parameter(ParameterSetName = 'Check')][switch] $CheckOnly,
    [Parameter(ParameterSetName = 'Download', Mandatory)][string] $OutputPath
)

$ErrorActionPreference = 'Stop'

$definition = Get-RedistributableDefinition -Path $PSScriptRoot
$source = $definition['Source']

$upstream = Resolve-UpstreamVersion -Resolver ([string] $source['Resolver']) `
    -Url ([string] $source['Url']) `
    -AssetPattern ([string] $source['AssetPattern'])

if ($CheckOnly) {
    Write-Output $upstream.Version
    return
}

if (-not $upstream.DownloadUrl) {
    throw "No asset matched '$($source['AssetPattern'])' on the latest release"
}

$temp = Join-Path ([System.IO.Path]::GetTempPath()) "umu-launcher-$([guid]::NewGuid())"
$archive = Join-Path $temp 'zipapp.tar'
$extracted = Join-Path $temp 'extracted'

$null = New-Item -ItemType Directory -Path $extracted -Force

try {
    Write-Verbose "Downloading $($upstream.DownloadUrl)"
    Invoke-WebRequest -Uri $upstream.DownloadUrl -OutFile $archive -MaximumRetryCount 3 -RetryIntervalSec 5

    # Expand-Archive only understands ZIP, and shelling out to tar is not portable:
    # GNU tar reads a Windows path as a remote host spec and fails on 'C:'. Reading
    # the archive directly is both cross-platform and how the symlink is avoided --
    # only the one regular file we want is ever written out.
    $members = [System.Collections.Generic.List[string]]::new()
    $umuRun = Join-Path $extracted 'umu-run'

    $stream = [System.IO.File]::OpenRead($archive)

    try {
        $reader = [System.Formats.Tar.TarReader]::new($stream)
        $regular = @([System.Formats.Tar.TarEntryType]::RegularFile, [System.Formats.Tar.TarEntryType]::V7RegularFile)

        while ($null -ne ($entry = $reader.GetNextEntry())) {
            $members.Add("$($entry.Name) [$($entry.EntryType)]")

            if ($regular -contains $entry.EntryType -and $entry.Name -match '(^|/)umu-run$') {
                $entry.ExtractToFile($umuRun, $true)
                break
            }
        }
    }
    finally {
        $stream.Dispose()
    }

    if (-not (Test-Path -LiteralPath $umuRun)) {
        throw "The zipapp archive has no umu-run entry; upstream may have changed its layout. Contents: $($members -join ', ')"
    }

    # The zipapp is the whole payload, flattened out of its umu/ directory. Its
    # executable bit does not survive the ZIP the payload ships in; the Install
    # script restores it on the client.
    Copy-Item -LiteralPath $umuRun -Destination (Join-Path $OutputPath 'umu-run') -Force

    # GPLv3: the licence has to travel with the binary, not only with the source.
    $license = Join-Path $PSScriptRoot 'LICENSES/UPSTREAM-LICENSE.txt'

    if (Test-Path -LiteralPath $license) {
        Copy-Item -LiteralPath $license -Destination (Join-Path $OutputPath 'COPYING.txt') -Force
    }

    @{
        Version   = $upstream.Version
        Changelog = $upstream.Changelog
    } | ConvertTo-Json -Compress | Write-Output
}
finally {
    Remove-Item -LiteralPath $temp -Recurse -Force -ErrorAction SilentlyContinue
}
