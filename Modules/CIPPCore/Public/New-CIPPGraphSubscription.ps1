function New-CIPPGraphSubscription {
    [CmdletBinding()]
    param (
        $TenantFilter,
        [bool]$auditLogAPI = $false,
        $TypeofSubscription,
        $Resource,
        $EventType,
        $APIName = "Create Webhook",
        $ExecutingUser
    )
    $CIPPID = (New-Guid).GUID
    $expiredate = (Get-Date).AddDays(1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffZ")
    $params = @{
        changeType         = $TypeofSubscription
        notificationUrl    = "https://webhook.site/9650bc4a-0120-41de-8ffd-6616e71244e1?EventType=$EventType&CIPPID=$CIPPID"
        resource           = $Resource
        expirationDateTime = $expiredate
    } | ConvertTo-Json
    $WebhookTable = Get-CIPPTable -TableName webhookTable

    try {
        if ($auditLogAPI) {
            $AuditLogParams = @{
                webhook = @{
                    "address" = "https://webhook.site/9650bc4a-0120-41de-8ffd-6616e71244e1/"
                }
            } | ConvertTo-Json
            $AuditLog = New-GraphPOSTRequest -uri "https://manage.office.com/api/v1.0/$($TenantFilter)/activity/feed/subscriptions/start?contentType=$EventType&PublisherIdentifier=$($TenantFilter)" -tenantid $TenantFilter -type -scope "https://manage.office.com/.default" POST -body $AuditLogparams -verbose
            $WebhookRow = @{
                PartitionKey           = [string]$TenantFilter
                RowKey                 = [string]$CIPPID
                EventType              = [string]$EventType
                Resource               = "M365AuditLogs"
                Expiration             = "None"
                WebhookNotificationUrl = [string]$Auditlog.webhook.address
            }
            $null = Add-AzDataTableEntity @WebhookTable -Entity $WebhookRow
        }
        else {
            $GraphRequest = New-GraphPostRequest -uri "https://graph.microsoft.com/beta/subscriptions" -tenantid $TenantFilter -type POST -body $params -verbose
            #If creation is succesfull, we store the GUID in the storage table webhookTable to make sure we can check against this later on. 
            #We store the GUID as rowkey, the event type, the resource, and the expiration date as properties, we also add the Tenant name so we can easily find this later on.
            #We don't store the return, because Ms decided that a renewal or re-authenticate does not change the url, but does change the id...
            $WebhookRow = @{
                PartitionKey           = [string]$TenantFilter
                RowKey                 = [string]$CIPPID
                EventType              = [string]$EventType
                Resource               = [string]$Resource
                Expiration             = [string]$expiredate
                WebhookNotificationUrl = [string]$GraphRequest.notificationUrl
            }
            $null = Add-AzDataTableEntity @WebhookTable -Entity $WebhookRow
            #todo: add remove webhook function, add check webhook function, add list webhooks function
            #add refresh webhook function based on table. 
        }
        Write-LogMessage -user $ExecutingUser -API $APIName -message "Created Webhook subscription for $($TenantFilter)" -Sev "Info" -tenant $TenantFilter
        return "Created Webhook subscription for $($TenantFilter)"
    }
    catch {
        Write-LogMessage -user $ExecutingUser -API $APIName -message "Failed to create Webhook Subscription: $($_.Exception.Message)" -Sev "Error" -tenant $TenantFilter
        Return "Failed to create Webhook Subscription: $($_.Exception.Message)" 
    }

}
