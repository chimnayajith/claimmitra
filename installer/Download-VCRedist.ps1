$ErrorActionPreference = 'Stop'

$url = 'https://aka.ms/vc14/vc_redist.x64.exe'
$output = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..\dist')) 'vc_redist.x64.exe'

if (Test-Path $output) {
    Remove-Item $output -Force
}

& curl.exe --fail --location --silent --show-error $url --output $output
if ($LASTEXITCODE -ne 0) {
    throw "Microsoft Visual C++ Redistributable download failed with curl exit code $LASTEXITCODE."
}
if (!(Test-Path $output -PathType Leaf)) {
    throw 'Microsoft Visual C++ Redistributable download did not create the expected file.'
}
if ((Get-Item $output).Length -lt 1MB) {
    throw 'Downloaded Microsoft Visual C++ Redistributable is unexpectedly small.'
}

$signature = Get-AuthenticodeSignature $output
if ($signature.Status -ne 'Valid' -or
    $signature.SignerCertificate.Subject -notmatch 'CN=Microsoft Corporation') {
    throw "Downloaded redistributable does not have a valid Microsoft signature (status: $($signature.Status))."
}

$stream = [System.IO.File]::OpenRead($output)
try {
    $reader = [System.IO.BinaryReader]::new($stream)
    if ($reader.ReadUInt16() -ne 0x5A4D) {
        throw 'Downloaded redistributable is not a valid Windows executable (missing MZ header).'
    }
    $stream.Position = 0x3C
    $peOffset = $reader.ReadInt32()
    if ($peOffset -lt 0 -or $peOffset -gt ($stream.Length - 6)) {
        throw 'Downloaded redistributable has an invalid PE header offset.'
    }
    $stream.Position = $peOffset
    if ($reader.ReadUInt32() -ne 0x00004550) {
        throw 'Downloaded redistributable is not a valid PE executable.'
    }
    $machine = $reader.ReadUInt16()
    if ($machine -ne 0x8664) {
        throw ('Expected an x64 redistributable (PE machine 0x8664), got 0x{0:X4}.' -f $machine)
    }
}
finally {
    $stream.Dispose()
}

Write-Host "Validated signed Microsoft x64 Visual C++ Redistributable: $output"
