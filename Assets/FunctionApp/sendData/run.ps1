using namespace System.Net

param($Request, $TriggerMetadata)

Write-Output "PowerShell HTTP trigger function processed a request."

# Error handling helper
function Json_Response {
    param (
        [Parameter(Mandatory)]
        $data,
        [Parameter(Mandatory)]
        $statusCode
    )
    Write-Output "Returning response with status code: $statusCode and data: $($data | ConvertTo-Json -Depth 10)"
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = $statusCode
            Body       = $data | ConvertTo-Json -Depth 10
        })
    exit
}

Write-Output "Attempting to acquire Azure Monitor token..."
try {
    $monitorToken = (Get-AzAccessToken -ResourceUrl 'https://monitor.azure.com/').Token
    Write-Output "Acquired Azure Monitor token"
    if (-not $monitorToken) {
        Write-Output "Monitor token is null or empty."
        Json_Response -data @{ error = "Failed to acquire Azure Monitor token." } -statusCode 500
    }
} catch {
    Write-Output "Exception acquiring Azure Monitor token: $($_.Exception.Message)"
    Json_Response -data @{ error = "Exception acquiring Azure Monitor token: $($_.Exception.Message)" } -statusCode 500
}

$dceURI = $env:DCR_URI
$DCR_Table = $env:DCR_TABLE | ConvertFrom-Json
$Table = $env:TABLE_NAME

Write-Output "DCR_URI: $dceURI"
Write-Output "TABLE_NAME: $Table"
Write-Output "DCR_TABLE: $($DCR_Table | ConvertTo-Json -Depth 5)"

$RawHeaders = [collections.hashtable]$Request.Headers
$DecodedHeaders = [PSCustomObject]$RawHeaders
$ClientPublicIP = $($DecodedHeaders.'x-forwarded-for').Split(":")[0]
if (-not([string]::IsNullOrEmpty($ClientPublicIP))) {
    Write-Output "Connecting IP address is $ClientPublicIP"
}
 

# Read the DCR query parameter from the request URI
$DcrQueryParam = $Request.Query.DCR
Write-Output "DCR query parameter from request: $DcrQueryParam"
if ($null -eq $DcrQueryParam -or $DcrQueryParam -eq "") {
    Write-Output "DCR query parameter is missing in the request URI."
    Json_Response -data @{ error = "DCR query parameter is missing in the request URI." } -statusCode 400
}
$DcrImmutableId = $DcrQueryParam

# Validate DCR URI and Table
if ($null -eq $dceURI -or $dceURI -eq "") {
    Write-Output "DCR_URI environment variable is missing."
    Json_Response -data @{ error = "DCR_URI environment variable is missing." } -statusCode 500
}
if ($null -eq $DCR_Table -or $DCR_Table.Count -eq 0) {
    Write-Output "DCR_TABLE environment variable is missing or empty."
    Json_Response -data @{ error = "DCR_TABLE environment variable is missing or empty." } -statusCode 500
}

# Sending the data to Log Analytics via the DCR!
$inputBody = $Request.Body
# Write-Output "Request body: $($inputBody | ConvertTo-Json -Depth 5)"
if ($null -eq $inputBody -or $inputBody -eq "") {
    Write-Output "Request body is empty."
    Json_Response -data @{ error = "Request body is empty." } -statusCode 400
}

#Add connecting IP to each record if available
$inputBody | ForEach-Object {
    if (-not([string]::IsNullOrEmpty($ClientPublicIP))) {
        $_ | Add-Member -MemberType NoteProperty -Name "ConnectingIP" -Value $ClientPublicIP -Force
    }
}

# Determine the table to use for the DCR
$selectedDCR = $DCR_Table | Where-Object { $_.id -eq $DcrImmutableId }
Write-Output "Selected DCR: $($selectedDCR | ConvertTo-Json -Depth 5)"
[string]$dcrTableName = $selectedDCR.table
Write-Output "DCR Table Name: $dcrTableName"
if ($null -eq $selectedDCR -or $selectedDCR -eq "") {
    Write-Output "No matching DCR found for the provided DCR Immutable ID."
    Json_Response -data @{ error = "No matching DCR found for the provided DCR Immutable ID." } -statusCode 400
}

# Prepare payload
try {
    [string]$rawBody = $inputBody | ConvertTo-Json -Depth 10
    Write-Output "Raw body after conversion to JSON: $rawBody"
    if ($rawBody.StartsWith('[')) {
        $jsonPayload = $rawBody
    } else {
        $jsonPayload = @(
            $rawBody
        ) -join ','
        $jsonPayload = "[{0}]" -f $jsonPayload
    }

    Write-Output "Final JSON payload: $jsonPayload"
} catch {
    Write-Output "Failed to convert request body to JSON: $($_.Exception.Message)"
    Json_Response -data @{ error = "Failed to convert request body to JSON: $($_.Exception.Message)" } -statusCode 400
}

$headers = @{
    "Authorization" = "Bearer $monitorToken"
    "Content-Type"  = "application/json"
}
$dcrUri = "$dceURI/dataCollectionRules/$DcrImmutableId/streams/Custom-$($dcrTableName)?api-version=2023-01-01"
Write-Output "POST URI: $dcrUri "

try {
    $uploadResponse = Invoke-WebRequest -Uri $dcrUri -Method "Post" -Body $jsonPayload -Headers $headers -ErrorAction Stop
    Write-Output "Response headers: $($uploadResponse.Headers | ConvertTo-Json -Depth 5)"
    if ($null -eq $uploadResponse) {
        Write-Output "No response from Log Analytics ingestion endpoint."
        Json_Response -data @{ error = "No response from Log Analytics ingestion endpoint." } -statusCode 502
    } elseif ($uploadResponse.StatusCode -notin 200, 201, 202, 204) {
        Write-Output "Error response from Log Analytics ingestion endpoint: $($uploadResponse.StatusCode)"
        Json_Response -data @{ error = "Error response from Log Analytics ingestion endpoint: $($uploadResponse.StatusCode) - $($uploadResponse.Content | ConvertTo-Json -Depth 10)" } -statusCode 502
    } elseif ($uploadResponse.StatusCode -in 200, 201, 202, 204) {
        Write-Output "Data uploaded successfully to Log Analytics."
        $returnMessageContent = @{
            StatusCode   = $uploadResponse.StatusCode
            ResponseBody = if ($uploadResponse.Content) { $uploadResponse.Content | ConvertTo-Json -Depth 10 } else { "No Content" }       
            dcrId        = $DcrImmutableId
        }
        Write-Output "Return message content: $returnMessageContent"
        Json_Response -data $returnMessageContent -statusCode $uploadResponse.StatusCode
    }
} catch {
    Write-Output "Failed to upload data: $($_.Exception.Message)"
    Json_Response -data @{ error = "Failed to upload data: $($_.Exception.Message)" } -statusCode 502
}