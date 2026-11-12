Param
(
    [string[]] $Packages = @("rspec", "cucumber", "watir", "allure-cucumber", "allure-rspec"),
    [string] $OutputDirectory = "./data",
    [int] $RetentionDays = 45
)

$ErrorActionPreference = "Stop"

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$Timestamp = [DateTimeOffset]::UtcNow.ToString("o")

$PackageRows = @()
$VersionRows = @()

ForEach ($Package in $Packages)
{
    Write-Host "Fetching $Package..."

    $Name = [Uri]::EscapeDataString($Package)

    $Gem = Invoke-RestMethod -Uri "https://rubygems.org/api/v1/gems/$Name.json"

    $PackageRows += [PSCustomObject]@{
        Timestamp = $Timestamp
        Package = $Package
        Downloads = $Gem.downloads
    }

    $Versions = Invoke-RestMethod -Uri "https://rubygems.org/api/v1/versions/$Name.json"

    ForEach ($Version in $Versions)
    {
        $VersionRows += [PSCustomObject]@{
            Timestamp = $Timestamp
            Package = $Package
            Version = $Version.number
            Platform = $Version.platform
            Downloads = $Version.downloads_count
        }
    }
}

Function Append-Csv ($Path, $Rows)
{
    $Cutoff = [DateTimeOffset]::UtcNow.AddDays(-$RetentionDays)

    $Existing = If (Test-Path $Path)
    {
        @(Import-Csv -Path $Path | Where-Object {
            [DateTimeOffset]::Parse($_.Timestamp, [CultureInfo]::InvariantCulture) -ge $Cutoff
        })
    }
    Else
    {
        @()
    }

    $Combined = @($Existing) + @($Rows)

    If ($Combined.Count -gt 0)
    {
        $Combined | Export-Csv -Path $Path -NoTypeInformation
    }
}

Append-Csv (Join-Path $OutputDirectory "packages.csv") $PackageRows
Append-Csv (Join-Path $OutputDirectory "versions.csv") $VersionRows

Write-Host "Saved $($PackageRows.Count) package snapshots."
Write-Host "Saved $($VersionRows.Count) version snapshots."
