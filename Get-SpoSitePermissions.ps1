
<#PSScriptInfo

.VERSION 0.1

.GUID 27961db8-6abf-4f0c-b059-aed312f34efc

.AUTHOR June Castillote

.COMPANYNAME

.COPYRIGHT june.castillote@gmail.com

.TAGS

.LICENSEURI https://github.com/junecastillote/Get-SpoSitePermissions/blob/main/LICENSE

.PROJECTURI https://github.com/junecastillote/Get-SpoSitePermissions

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

#Requires -Version 7.2
#Requires -Module @{ModuleName="Pnp.PowerShell";ModuleVersion="2.2.0"}

<#

.DESCRIPTION
 PowerShell script to export SharePoint Online site permissions with Pnp.

#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string[]]
    $SiteURL,

    [Parameter(Mandatory)]
    [pscredential]
    $Credential,

    [Parameter(Mandatory)]
    [String]
    $OutCsvFile,

    [Parameter()]
    [bool]
    $DisplayResults = $true
)

$PSStyle.Progress.View = 'Classic'

if ($OutCsvFile) {
    # if (!(Test-Path $OutCsvFile)) {
    try {
        $null = New-Item -Path $OutCsvFile -ItemType File -Force -ErrorAction Stop
    }
    catch {
        "    -> [ERROR] : [$($_.Exception.Message)]" | Out-Default
        return $null
    }
    # }
}

$urlPatternToExclude = ".*-my\.sharepoint\.com/$|.*\.sharepoint\.com/$|.*\.sharepoint\.com/search$|.*\.sharepoint\.com/portals/hub$|.*\.sharepoint\.com/sites/appcatalog$"
$SiteURL = $SiteURL | Where-Object { $_ -notmatch $urlPatternToExclude } | Sort-Object

# $result = [System.Collections.ArrayList]@()
for ($i = 0; $i -lt $SiteURL.Count; $i++) {
    "[$($i+1) of $($SiteURL.Count)] : $($SiteURL[$i])" | Out-Default
    # $percentComplete = (($i + 1) / ($SiteURL.Count)) * 100
    # Write-Progress -PercentComplete $percentComplete -CurrentOperation "Processing site $($i+1) of $($SiteURL.Count) ($percentComplete%)" -Activity "Get SharePoint Site Permission" -Status $($SiteURL[$i])

    try {
        Connect-PnPOnline -Url $SiteURL[$i] -Credentials $Credential -ErrorAction Stop
        $site = Get-PnPTenantSite -Identity $SiteURL[$i] -ErrorAction Stop
    }
    catch {
        "    -> [ERROR] : [$($_.Exception.Message)]" | Out-Default
        Continue # Skip to next item
    }

    if ($site.Template -eq 'RedirectSite#0') {
        "    -> [INFO] : [$($site.Url)] is a Redirect Site and will be skipped." | Out-Default
        Continue # Skip to next item
    }

    $members = [System.Collections.ArrayList]@()

    try {
        $web = Get-PnPWeb -Includes RoleAssignments -ErrorAction Stop
    }
    catch {
        "    -> [ERROR] : [$($_.Exception.Message)]" | Out-Default
        Continue

    }
    $context = Get-PnPContext
    foreach ($ra in $web.RoleAssignments) {
        try {
            $context.Load($ra.RoleDefinitionBindings)
            $context.Load($ra.Member)
            $context.ExecuteQuery()

            $null = $members.Add(
                $(
                    [PSCustomObject]$(
                        [ordered]@{
                            Name          = $ra.Member.Title
                            LoginName     = $(
                                if ($ra.Member.LoginName -like "*guest#*") {
                                    ($ra.Member.LoginName).Split('#')[-1]
                                }
                                else {
                                    ($ra.Member.LoginName).Split('|')[-1]
                                }
                            )
                            Permission    = $($ra.RoleDefinitionBindings[0].Name.ToString())
                            PrincipalType = $ra.Member.TypedObject.ToString().Split('.')[-1]
                        }
                    )
                )
            )
        }
        catch {
            "    -> [ERROR] : [$($_.Exception.Message)]" | Out-Default
            Continue
        }
    }

    foreach ($item in $members) {
        if ($item.PrincipalType -eq 'User') {
            $tempResult = $(
                [PSCustomObject]$(
                    [ordered]@{
                        SiteName        = $web.Title
                        SiteURL         = $web.Url
                        SharePointGroup = $null
                        Name            = $item.Name
                        PrincipalId     = $item.LoginName
                        PrincipalType   = $item.PrincipalType
                        Permission      = $item.Permission
                        External        = $(
                            if ($_.LoginName -like "*guest#*") {
                                'Yes'
                            }
                            else {
                                'No'
                            }
                        )

                    }
                )
            )
            # $null = $result.Add($tempResult)
            if ($OutCsvFile) {
                $tempResult | Export-Csv -Path $OutCsvFile -NoTypeInformation -Append -Force -Encoding unicode -Delimiter "`t"
            }
            if ($DisplayResults) { $tempResult }
        }

        if ($item.PrincipalType -eq 'Group') {
            $spoGroupMember = Get-PnPGroupMember -Group $item.LoginName | Where-Object { $_.LoginName -ne 'SHAREPOINT\system' }
            $spoGroupMember | ForEach-Object {
                $tempResult = $(
                    [PSCustomObject]$(
                        [ordered]@{
                            SiteName        = $web.Title
                            SiteURL         = $web.Url
                            SharePointGroup = $item.LoginName
                            Name            = $_.Title
                            PrincipalId     = $(
                                if ($_.LoginName -like "*guest#*") {
                                    ($_.LoginName).Split('#')[-1]
                                }
                                else {
                                    ($_.LoginName).Split('|')[-1]
                                }
                            )
                            PrincipalType   = $_.PrincipalType
                            Permission      = $item.Permission
                            External        = $(
                                if ($_.LoginName -like "*guest#*") {
                                    'Yes'
                                }
                                else {
                                    'No'
                                }
                            )
                        }
                    )
                )
                # $null = $result.Add($tempResult)
                if ($OutCsvFile) {
                    $tempResult | Export-Csv -Path $OutCsvFile -NoTypeInformation -Append -Force -Encoding unicode -Delimiter "`t"
                }
                if ($DisplayResults) { $tempResult }
            }
        }
    }
}

# Write-Progress -PercentComplete 100 -Completed -Activity "Get SharePoint Site Permission"

if ($OutCsvFile) {
    "Results are exported to $(Resolve-Path $OutCsvFile)." | Out-Default
}