az deployment group create `
  --name AIS-Darius-v1 `
  --resource-group Darius-AIS `
  --template-file main.bicep `
  --parameters '@main.parameters-dev.json'