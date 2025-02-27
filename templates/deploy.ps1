$AZURE_SUBSCRIPTION_ID_DEV = "e96ed8d4-2224-445d-a27b-d1523a78bfe6"
$AZURE_RESOURCE_GROUP_DEV = "Darius-AIS"
$LA_NAME = "logic-eis-dev-auea" 
$APIM_NAME = "apim-eis-dev-auea"
$WORKFLOW_NAME = "eisHttpRequest"

az deployment group create `
  --name AIS-Darius-v1 `
  --resource-group Darius-AIS `
  --template-file main.bicep `
  --parameters '@main.parameters-dev.json'

# $profile = az webapp deployment get-publishing-profiles --name $LA_NAME --resource-group $AZURE_RESOURCE_GROUP_DEV -o tsv
# 

## full command if azure module, az cli or ... exist.
# Install-Module -Name Az.Websites -Scope CurrentUser -Repository PSGallery -Force -AllowClobber

Connect-AzAccount
$con = Get-AzSubscription -SubscriptionId $AZURE_SUBSCRIPTION_ID_DEV
Select-AzSubscription -SubscriptionObject $con

$profile = Get-AzWebAppPublishingProfile `
  -ResourceGroupName  $AZURE_RESOURCE_GROUP_DEV `
  -Name $LA_NAME 


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


$azureRestApiBasePath = "https://management.azure.com/subscriptions/$AZURE_SUBSCRIPTION_ID_DEV/resourceGroups/$AZURE_RESOURCE_GROUP_DEV/providers"
$worklowCallback = $(az rest --method post --uri "$azureRestApiBasePath/Microsoft.Web/sites/$LA_NAME/hostruntime/runtime/webhooks/workflow/api/management/workflows/$WORKFLOW_NAME/triggers/manual/listCallbackUrl?api-version=2018-11-01")
$workflowResponse = $worklowCallback | ConvertFrom-Json
$workflowBasePath= $workflowResponse.basePath

$apimRestApiBasePath = "$azureRestApiBasePath/Microsoft.ApiManagement/service/$APIM_NAME"
#update APIM backend runtime url for logic app
$backendPath = $workflowBasePath.Substring(0,$workflowBasePath.IndexOf("/manual/"))
$backendBody = '{\"properties\":{\"url\":\"' + $backendPath + '\"}}'
az rest --method patch --uri "$apimRestApiBasePath/backends/$LA_NAME-backend?api-version=2020-06-01-preview" --body $backendBody

#Update APIM name value for logic app rewrite url signature
$nameValueBody = '{\"properties\":{\"value\":\"' + $workflowResponse.queries.sig + '\"}}'
az rest --method patch --uri "$apimRestApiBasePath/namedValues/$LA_NAME-name-value?api-version=2020-06-01-preview" --body $nameValueBody