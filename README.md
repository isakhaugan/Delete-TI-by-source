# Delete Threat Indicators Script

This PowerShell script is created to delete all threat indicators by a specific source from the Log Analytics workspace.  
It was generated after having a MISP instance that was overly willing to share, refused to delete old indicators, and updated the expiry date of old indicators every day. Definitely not because of a lack of knowledge on my part.

## Disclaimer

I am not a good programmer especially not in PowerShell, so any input, suggestions, or improvements are highly welcome!

## Prerequisites

To run this script, you must have the Az PowerShell module installed. For more information, see [here](https://docs.microsoft.com/powershell/azure/install-az-ps).

Make sure you are logged in with `az login` prior to executing the script.

## Usage

Follow the instructions below to use the script:

1. **Define Variables**: Set the necessary variables including `SubscriptionId`, `LogAnalyticsResourceGroup`, `LogAnalyticsWorkspaceName`, and `LaAPIHeaders`.

```powershell
$SubscriptionId = "Insert your subscription ID here"
$LogAnalyticsResourceGroup = "Insert your Log Analytics resource group here"
$LogAnalyticsWorkspaceName = "Insert your Log Analytics workspace name here"
```
2. **Function `Get-AllThreatIndicators`**: This is the main function that handles the fetching and deletion of threat indicators. You can change the PAGE_SIZE to control the number of indicators to delete per page and sort order according to your requirements. I added sort order so that one can run multiple instances of the script with a lower chance of deleting the same indicators (this causes an error, but does not crash the script).

3. **Function `Get-LaAPIHeaders`**: This function handles authentication. 


## License

This project is open source. Feel free to use, modify and distribute it as per your needs.

## Contact

Feel free to create an issue for questions, bugs, or enhancements. Any contributions or feedback is highly appreciated!