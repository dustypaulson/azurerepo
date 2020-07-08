#From top to line 23 is a single run time ie logic app or similar. There will be 4 of these, one for each spoke
#Login to Spoke 1 Tenant
Connect-AzureAD -AzureEnvironmentName AzureCloud -TenantId "72f988bf-86f1-41af-91ab-2d7cd011db47"

#Get filtered users based on UserState = PendingAcceptance
#$test = Get-AzureADUser with no filter to prove we are filtering out based on guests/pendingacceptace userState
$spoke1 = Get-AzureADUser -Filter "UserState eq 'PendingAcceptance'" #| Format-List -Property DisplayName,UserPrincipalName,UserState,UserStateChangedOn

#Login to Hub Tenant
Connect-AzureAD -AzureEnvironmentName AzureCloud -TenantId "a42a6a34-f15c-445c-82ef-5975c532f170"

#Get filtered users based on UserState = PendingAcceptance
$parentTenant1 = Get-AzureADUser #| Format-List -Property DisplayName,UserPrincipalName,UserState,UserStateChangedOn #-Filter "UserState eq 'PendingAcceptance'" 

#Compare items in both tenants
$compare = Compare-Object -ReferenceObject $parentTenant1 -DifferenceObject $spoke1 -IncludeEqual -Property UserPrincipalName

#Filter by users that need to be added to Hub tenant
$usersToPushToParent = $compare | where {$_.SideIndicator -eq "=>"}

#Push to hub tenant from spoke 1 - can we make this a job?
foreach($u in $usersToPushToParent){
New-AzureADMSInvitation -InvitedUserEmailAddress $u.UserPrincipalName -InvitedUserDisplayName $u.DisplayName -InvitedUserType "Guest" -SendInvitationMessage $True -InviteRedirectUrl "http://myapps.onmicrosoft.com"
}

#Once the hub logic app has received a 200 status code then run the below for each spoke

#Get filtered users based on UserState = PendingAcceptance
$parentTenant1 = Get-AzureADUser -Filter "UserState eq 'PendingAcceptance'" #| Format-List -Property DisplayName,UserPrincipalName,UserState,UserStateChangedOn

#Connect to spoke 1 Tenant
Connect-AzureAD -AzureEnvironmentName AzureCloud -TenantId "72f988bf-86f1-41af-91ab-2d7cd011db47"

#Get filtered users based on UserState = PendingAcceptance
$spoke1 = Get-AzureADUser #| Format-List -Property DisplayName,UserPrincipalName,UserState,UserStateChangedOn #-Filter "UserState eq 'PendingAcceptance'" 

#Compare users in both tenants
$compare = Compare-Object -ReferenceObject $spoke1 -DifferenceObject $parentTenant1 -IncludeEqual -Property UserPrincipalName

#Filter users to push to Spoke 1
$usersToPushToSpokeA = $compare | where {$_.SideIndicator -eq "=>"}

#Push to Spoke 1 tenant from Hub while using a job if possible to parrellize this
foreach($a in $usersToPushToSpokeA){
New-AzureADMSInvitation -InvitedUserEmailAddress $a.UserPrincipalName -InvitedUserDisplayName $a.DisplayName -InvitedUserType "Guest" -SendInvitationMessage $True -InviteRedirectUrl "http://myapps.onmicrosoft.com"
}
