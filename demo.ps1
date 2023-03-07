#Reference: https://techcommunity.microsoft.com/t5/microsoft-365/get-site-permissions-with-pnp-powershell/m-p/140002

$spoUrl = 'https://ORG.sharepoint.com/sites/SITE'
$spoConnection = Connect-PnPOnline -Url $spoUrl -Interactive -ReturnConnection

$spoPermissions = .\Get-SpoSitePermissions.ps1 -spoUrl $spoUrl -spoConnection $spoConnection