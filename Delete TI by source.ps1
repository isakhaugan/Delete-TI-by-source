# This script deletes all threat indicators by a specific source.
# To run this script, you must have the Az PowerShell module installed. For more information, see https://docs.microsoft.com/powershell/azure/install-az-ps

# Define necessary variables, such as SubscriptionId, LogAnalyticsResourceGroup, LogAnalyticsWorkspaceName, and LaAPIHeaders
$SubscriptionId = ""
$LogAnalyticsResourceGroup = ""
$LogAnalyticsWorkspaceName = ""

# Check if the variables are populated
if ([string]::IsNullOrEmpty($SubscriptionId) -or [string]::IsNullOrEmpty($LogAnalyticsResourceGroup) -or [string]::IsNullOrEmpty($LogAnalyticsWorkspaceName)) {
    Write-Host "Please fill in the SubscriptionId, LogAnalyticsResourceGroup, and LogAnalyticsWorkspaceName variables before running."
    exit 1
}

# This function gets all threat indicators from the Log Analytics workspace and deletes them.
function Get-AllThreatIndicators {
    $ThreatIndicatorsApi = "https://management.azure.com/subscriptions/$SubscriptionId/resourcegroups/$LogAnalyticsResourceGroup/providers/Microsoft.OperationalInsights/workspaces/$LogAnalyticsWorkspaceName/providers/Microsoft.SecurityInsights/threatIntelligence/"
    $SECURITY_INSIGHTS_API_VERSION = "api-version=2022-07-01-preview"
    # Change the PAGE_SIZE to the number of indicators you want to delete per page. When running three script with different sort orders, I found that 200 was the optimal number.
    $PAGE_SIZE = "200"
    $getAllIndicatorsUri = $ThreatIndicatorsApi + "query?$SECURITY_INSIGHTS_API_VERSION"
    # Change the source to whichever source you want to delete indicators from. 
    $getAllIndicatorsPostParameters = @{ "sortBy" = $sort; "pageSize" = $PAGE_SIZE;  "sources" = ,"SecurityGraph" } | ConvertTo-Json
    $indicatorsFetched = 0
    # Sort by name in ascending order. Change to "unsorted" or "descending" to sort by unsorted or descending order, respectively.
    $sort = '[
    {
      "itemKey": "name",
      "sortOrder": "ascending"
    }
  ]'

    do {
        try {
            $LaAPIHeaders = Get-LaAPIHeaders
            $response = Invoke-WebRequest -Uri "$getAllIndicatorsUri" -Method POST -Body $getAllIndicatorsPostParameters -Headers $LaAPIHeaders  -UseBasicParsing
            if ($null -eq $response -or $response.StatusCode -ne 200) {
                Write-Host "Failed to fetch indicators. Status Code = $($response.StatusCode)"
                exit 1
            }
            $responseBody = $response.Content | ConvertFrom-Json
            $indicatorList = $responseBody.value
        }
        catch {
            if ($response.error.code -eq "ExpiredAuthenticationToken") {
            $LaAPIHeaders = Get-LaAPIHeaders
            # Retry to fetch indicators
            Write-Host "Retrying to fetch indicators."
            Get-AllThreatIndicators
            } else {
                Write-Host "Failed to get all indicators. $($_.Exception)"
                exit 1
            }

        }
        # If there are no indicators, exit the loop
        if ($null -eq $indicatorList -or $indicatorList.Count -eq 0) {
            Write-Host "Finished querying workspace = $WorkspaceName for indicators."
            Write-Host "Fetched $indicatorsFetched indicators"
            break
        }
        # If there are indicators, delete them
        $startTime = Get-Date
        Write-Host "Successfully fetched $($indicatorList.Count) indicators."
        $indicatorsFetched += $indicatorList.Count
        Write-Host "A total of $indicatorsFetched indicators have been fetched so far."

        $results = $indicatorList | ForEach-Object {
            Start-ThreadJob {
                $indicator = $using:_
                $indicatorName = $($indicator).name
                $deleteIndicatorUri = $using:ThreatIndicatorsApi + $indicator.name + "?$using:SECURITY_INSIGHTS_API_VERSION"
                $response = Invoke-WebRequest -Uri $deleteIndicatorUri -Method DELETE -Headers $using:LaAPIHeaders -UseBasicParsing
                # If the response is null or the status code is not 200, return a PSCustomObject with Success = false and the status code
                if ($null -eq $response -or $response.StatusCode -ne 200) {
                    # Uncomment the line below to see which indicators failed to delete
                    # Write-Host "Failed to delete indicator $indicatorName. Status Code = $($response.StatusCode)"
                    return [PSCustomObject]@{ Success = $false; StatusCode = $response.StatusCode } 
                } else {
                    # Uncomment the line below to see which indicators were successfully deleted
                    # Write-Host "Successfully deleted indicator $indicatorName."
                    return [PSCustomObject]@{ Success = $true; StatusCode = $response.StatusCode }
                    Write-Host $response.message
                }
            }
        } | Receive-Job -Wait -AutoRemoveJob

        $successfulDeletions = ($results | Where-Object { $_.Success }).Count
        $failedDeletions = ($results | Where-Object { -not $_.Success }).Count
        # Writes the number of successful and failed deletions, as well as the time taken to delete the indicators for each page
        Write-Host "This loop had:`n $successfulDeletions deleted indicators.`n $failedDeletions failed deletions."
        Write-Host "Time taken: $((Get-Date).Subtract($startTime).Seconds) seconds."
        # If there are more indicators to delete, set the getAllIndicatorsUri to the nextLink
        if ($null -ne $responseBody.nextLink) {
            $getAllIndicatorsUri = $responseBody.nextLink
        } else {
            $getAllIndicatorsUri = $null
        }

    } while ($getAllIndicatorsUri -ne $null)
}

# Get the Log Analytics API headers. Requires login with az login first.
function Get-LaAPIHeaders {
    $AzureAccessToken = (Get-AzAccessToken).Token
    $LaAPIHeaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $LaAPIHeaders.Add("Content-Type", "application/json")
    $LaAPIHeaders.Add("Authorization", "Bearer $AzureAccessToken")
    return $LaAPIHeaders
}

# Call the Get-AllThreatIndicators function
Get-AllThreatIndicators