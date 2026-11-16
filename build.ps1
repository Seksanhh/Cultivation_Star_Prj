# Assemble les scripts de src/ en un fichier de place Roblox (.rbxlx) ouvrable dans Studio.
# Usage : pwsh ./build.ps1
# Même arborescence que default.project.json, pour que Rojo et ce script donnent le même résultat.

$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$output = Join-Path $root 'RobloxVR-Melee.rbxlx'
$script:nextRef = 0

function New-Ref {
    $script:nextRef++
    "RBX$($script:nextRef)"
}

function Get-ScriptItem([System.IO.FileInfo]$file) {
    $class = 'ModuleScript'
    $name = $file.BaseName
    if ($file.Name -match '^(.*)\.server\.luau$') { $class = 'Script'; $name = $Matches[1] }
    elseif ($file.Name -match '^(.*)\.client\.luau$') { $class = 'LocalScript'; $name = $Matches[1] }

    $source = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
    # "]]>" fermerait la section CDATA : on la coupe en deux.
    $source = $source.Replace(']]>', ']]]]><![CDATA[>')
    $safeName = [System.Security.SecurityElement]::Escape($name)

    @"
<Item class="$class" referent="$(New-Ref)">
<Properties>
<string name="Name">$safeName</string>
<ProtectedString name="Source"><![CDATA[$source]]></ProtectedString>
</Properties>
</Item>
"@
}

function Get-Container([string]$class, [string]$name, [string[]]$children) {
    @"
<Item class="$class" referent="$(New-Ref)">
<Properties>
<string name="Name">$name</string>
</Properties>
$($children -join "`n")
</Item>
"@
}

function Get-ScriptFolder([string]$name, [string]$relativeDir) {
    $dir = Join-Path $root $relativeDir
    $items = Get-ChildItem -LiteralPath $dir -File -Filter '*.luau' | Sort-Object Name | ForEach-Object { Get-ScriptItem $_ }
    Get-Container 'Folder' $name @($items)
}

$services = @(
    (Get-Container 'Workspace' 'Workspace' @()),
    (Get-Container 'ReplicatedStorage' 'ReplicatedStorage' @(Get-ScriptFolder 'Shared' 'src/shared')),
    (Get-Container 'ServerScriptService' 'ServerScriptService' @(Get-ScriptFolder 'Server' 'src/server')),
    (Get-Container 'StarterPlayer' 'StarterPlayer' @(
        Get-Container 'StarterPlayerScripts' 'StarterPlayerScripts' @(Get-ScriptFolder 'Client' 'src/client')
    ))
)

$xml = @"
<roblox xmlns:xmime="http://www.w3.org/2005/05/xmlmime" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="http://www.roblox.com/roblox.xsd" version="4">
$($services -join "`n")
</roblox>
"@

[System.IO.File]::WriteAllText($output, $xml, [System.Text.UTF8Encoding]::new($false))

# Vérifie que le fichier produit est du XML valide.
$null = [xml](Get-Content -LiteralPath $output -Raw -Encoding utf8)
Write-Host "Fichier généré : $output"
