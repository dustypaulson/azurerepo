﻿#Deploy template
New-AzResourceGroupDeployment -TemplateUri $templateuri -ResourceGroupName password_spray_demo -victimPIP $victimPIP -attackPIP $attackPIP -victimNSG $victimNSG -attackNSG $attackNSG -victimNIC $victimNIC -attackNIC $attackNIC -victimVM $victimVM -attackVM $attackVM -adminUsername $adminUsername -sourceAddressPrefix $sourceAddressPrefix -adminPassword $adminPassword -Mode Incremental
