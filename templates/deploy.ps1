az deployment group create `
  --name AIS-Darius-v1 `
  --resource-group Darius-AIS `
  --template-file main.bicep `
  --parameters '@main.parameters-dev.json'

# $profile = az webapp deployment list-publishing-profiles --name plan-eis-dev-auea --resource-group Darius-AIS -o tsv

Install-Module -Name Az.Websites   


Connect-AzAccount
$con = Get-AzSubscription -SubscriptionId e96ed8d4-2224-445d-a27b-d1523a78bfe6
Select-AzSubscription -SubscriptionObject $con

$profile = Get-AzWebAppPublishingProfile `
  -ResourceGroupName "Darius-AIS" `
  -Name "logic-eis-dev-auea" 


Write-Output  $profile > publishprofile

[xml]$xml = Get-Content "./publishprofile"
$deploySetting = $xml.SelectNodes("/publishData/publishProfile[@publishMethod='MSDeploy']") | Select-Object
$workdingDir = Get-Location

& 'C:\Program Files\IIS\Microsoft Web Deploy V3\msdeploy.exe' `
     "-verb:sync" `
     "-source:contentPath='$workdingDir\logicAppWorkflow'" `
     "-enableRule:offline" `
     "-dest:contentPath=wwwroot,ComputerName='https://$($deploySetting.publishUrl)/msdeploy.axd?site=$($deploySetting.msdeploySite)',UserName=$($deploySetting.userName),Password='$($deploySetting.userPWD)',AuthType='Basic'" `
     "-usechecksum" `
     "-verbose"


     ### todo: below after lunch
$azureRestApiBasePath = "https://management.azure.com/subscriptions/${{ secrets.AZURE_SUBSCRIPTION_ID_DEV }}/resourceGroups/${{ secrets.AZURE_RESOURCE_GROUP_DEV }}/providers"
$worklowCallback = $(az rest --method post --uri "$azureRestApiBasePath/Microsoft.Web/sites/${{ env.LA_NAME }}/hostruntime/runtime/webhooks/workflow/api/management/workflows/${{ env.WORKFLOW_NAME }}/triggers/manual/listCallbackUrl?api-version=2018-11-01")
$workflowResponse = $worklowCallback | ConvertFrom-Json
$workflowBasePath= $workflowResponse.basePath

$apimRestApiBasePath = "$azureRestApiBasePath/Microsoft.ApiManagement/service/${{ env.APIM_NAME }}"
#update APIM backend runtime url for logic app
$backendPath = $workflowBasePath.Substring(0,$workflowBasePath.IndexOf("/manual/"))
$backendBody = '{\"properties\":{\"url\":\"' + $backendPath + '\"}}'
az rest --method patch --uri "$apimRestApiBasePath/backends/${{ env.LA_NAME }}-backend?api-version=2020-06-01-preview" --body $backendBody

#Update APIM name value for logic app rewrite url signature
$nameValueBody = '{\"properties\":{\"value\":\"' + $workflowResponse.queries.sig + '\"}}'
az rest --method patch --uri "$apimRestApiBasePath/namedValues/${{ env.LA_NAME }}-name-value?api-version=2020-06-01-preview" --body $nameValueBody