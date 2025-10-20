function Invoke-GraphRestRequest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$urlRelLink,
        [Parameter(Mandatory = $true)]
        [object]$authHeaders,
        [Parameter(Mandatory = $false)]
        [ValidateSet('v1.0', 'beta')]
        [string]$apiVersion = 'beta'
    )

    #Construct the URL for the REST API call
    $definedURL = "https://graph.microsoft.com/$apiVersion/$urlRelLink"
    # Add the content type to the headers
    $authHeaders["Content-Type"] = "application/json"

    try {
        $results = @()
        #Invoke the initial Rest API call
        Write-Verbose "Invoking REST API call to: $definedURL"         
        $response = Invoke-RestMethod -Uri $definedURL -Headers $authHeaders
        $results += $response.value    
        #If the response has nextLink, we need to handle pagination
        while (($response."@odata.nextLink") -and ($response."@odata.nextLink" -ne $null)) {
            #Invoke the next link
            Write-Verbose "Fetching next page of results from: $($response."@odata.nextLink")"
            $nextLink = $response."@odata.nextLink"
            $response = Invoke-RestMethod -Uri $nextLink -Headers $authHeaders
            #Append the results to the existing results
            $results += $response.value
        }
    } catch {
        Write-Error "An error occurred while invoking the REST API: $_"
        return $null
    }
    #Invoke the initial Rest API call

    return $results
}
Export-ModuleMember -Function *

function Json_Response {
    param (
        [Parameter(Mandatory = $true)]
        $data,
        [Parameter(Mandatory = $false)]
        [int]$statusCode = 200
    )

    if ($null -ne $data) {
        #If the data is an object, convert it to JSON
        if ($data -is [string]) {
            $responseBody = $data
        } else {
            $responseBody = $data | ConvertTo-Json -Depth 10
        }
    } else {
        $responseBody.Body = ''
    }

    Push-OutputBinding -Name Response -Value $responseBody -statusCode $statusCode
    break
}