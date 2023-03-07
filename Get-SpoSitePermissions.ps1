[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $spoUrl,

    [Parameter()]
    $spoConnection
)

$web = Get-PnPWeb -Includes RoleAssignments -Connection $spoConnection
$members = [System.Collections.ArrayList]@()
foreach ($ra in $web.RoleAssignments) {
    $null = $members.Add(
        $(
            [PSCustomObject]$([ordered]@{
                    Name         = $ra.Member.Title
                    LoginName    = $(
                        if ($ra.Member.LoginName -like "*guest#*") {
                                ($ra.Member.LoginName).Split('#')[-1]
                        }
                        else {
                                ($ra.Member.LoginName).Split('|')[-1]
                        }
                    )
                    RoleTypeKind = $($ra.RoleDefinitionBindings[0].RoleTypeKind.ToString())
                    ObjectType   = $ra.Member.TypedObject.ToString().Split('.')[-1]
                })
        )
    )
}

# $members
$result = [System.Collections.ArrayList]@()
foreach ($item in $members) {
    if ($item.ObjectType -eq 'User') {
        $null = $result.Add(
            [PSCustomObject]$([ordered]@{
                    SharePointGroup = $null
                    Name            = $item.Name
                    LoginName       = $item.LoginName
                    Permission      = $item.RoleTypeKind
                    External        = $(
                        if ($_.LoginName -like "*guest#*") {
                            'Yes'
                        }
                        else {
                            'No'
                        }
                    )
                    ObjectType      = $item.ObjectType
                })
        )
    }

    if ($item.ObjectType -eq 'Group') {
        $spoGroupMember = Get-PnPGroupMember -Group $item.LoginName -Connection $spoConnection
        $spoGroupMember | ForEach-Object {
            if ($_.LoginName -ne 'SHAREPOINT\system') {
                $null = $result.Add(
                    [PSCustomObject]$([ordered]@{
                            SharePointGroup = $item.LoginName
                            Name            = $_.Title
                            LoginName       = $(
                                if ($_.LoginName -like "*guest#*") {
                                ($_.LoginName).Split('#')[-1]
                                }
                                else {
                                ($_.LoginName).Split('|')[-1]
                                }
                            )
                            Permission      = $item.RoleTypeKind
                            External        = $(
                                if ($_.LoginName -like "*guest#*") {
                                    'Yes'
                                }
                                else {
                                    'No'
                                }
                            )
                            ObjectType      = $_.PrincipalType
                        })
                )
            }
        }
    }
}
$result