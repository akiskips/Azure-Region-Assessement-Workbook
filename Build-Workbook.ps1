#Requires -Version 7.0
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$pairedRegionServices = @(
    'Storage', 'Backup', 'SQL', 'Key Vault', 'PostgreSQL / MySQL', 'Cosmos DB',
    'Data Factory', 'Device Registry', 'Event Grid', 'IoT Hub', 'Notification Hubs',
    'Storage Actions', 'Storage Mover', 'Microsoft Fabric', 'App Service / Environment', 'AKS'
)
$discovery = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'discovery.kql') -Raw).Trim()
$discovery += "`n| where service in ('$($pairedRegionServices -join "', '")')"
$backup = (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'backup-context.kql') -Raw).Trim()

function New-TextItem([string]$Name, [string]$Text) {
    $item = @{ type = 1; name = $Name; content = @{ json = $Text } }
    return $item
}

function New-QueryItem([string]$Name, [string]$Title, [string]$Query, [int]$Size = 0) {
    return @{
        type = 3
        name = $Name
        content = @{
            version = 'KqlItem/1.0'
            title = $Title
            query = $Query
            size = $Size
            queryType = 1
            resourceType = 'microsoft.resourcegraph/resources'
            crossComponentResources = @('{Subscriptions}')
            visualization = 'table'
            showExportToExcel = $true
            noDataMessage = 'No indexed rows match this scope. Check subscription access and filters. Resource Graph may not index every resource or configuration.'
            gridSettings = @{
                filter = $true
                formatters = @(@{ columnMatch = 'id'; formatter = 5; formatOptions = @{ showIcon = $true } })
            }
        }
    }
}

function New-Choice([string]$Name, [string]$Label, [string[]]$Values, [string]$Default, [switch]$WithoutDefaultItems) {
    return @{
        id = $Name
        version = 'KqlParameterItem/1.0'
        name = $Name
        label = $Label
        type = 2
        isRequired = $true
        multiSelect = $false
        value = $Default
        jsonData = ConvertTo-Json -InputObject @($Values | ForEach-Object {
            if ($WithoutDefaultItems) {
                [ordered]@{ value = $_; label = $_ }
            } else {
                @{ value = $_; label = $_; selected = ($_ -eq $Default) }
            }
        }) -Compress
    }
}

function New-ScopedPicker([string]$Name, [string]$Label, [string]$Query) {
    return @{
        id = $Name
        version = 'KqlParameterItem/1.0'
        name = $Name
        label = $Label
        type = 2
        isRequired = $true
        multiSelect = $true
        quote = "'"
        delimiter = ','
        value = @('value::all')
        typeSettings = @{ additionalResourceOptions = @('value::all'); selectAllValue = '*' }
        query = $Query
        queryType = 1
        resourceType = 'microsoft.resourcegraph/resources'
        crossComponentResources = @('{Subscriptions}')
    }
}

$scopeQuery = @'
Resources
| where '*' in ({SourceRegions}) or location in~ ({SourceRegions}) or isempty(location) or location =~ 'global'
| where '*' in ({ResourceGroups}) or resourceGroup in~ ({ResourceGroups})
'@

$items = [System.Collections.Generic.List[object]]::new()
$items.Add((New-TextItem 'title' @'
# Azure resource discovery

Resource inventory, regional distribution, service configurations, and backup protection across selected subscriptions.
'@))

$items.Add(@{
    type = 9
    name = 'parameters'
    content = @{
        version = 'KqlParameterItem/1.0'
        style = 'above'
        parameters = @(
            @{
                id = 'Subscriptions'
                version = 'KqlParameterItem/1.0'
                name = 'Subscriptions'
                type = 6
                isRequired = $true
                multiSelect = $true
                quote = "'"
                delimiter = ','
                value = @('value::5')
                typeSettings = @{ limitSelectTo = 1000; additionalResourceOptions = @('value::5'); includeAll = $true }
            }
            (New-ScopedPicker 'SourceRegions' 'Source regions' 'Resources | where isnotempty(location) | project value = tolower(location), label = tolower(location) | distinct value, label | order by label asc')
            (New-ScopedPicker 'ResourceGroups' 'Resource groups' 'Resources | where isnotempty(resourceGroup) | project value = resourceGroup, label = resourceGroup | distinct value, label | order by label asc')
            (New-Choice 'View' 'View' @('Discovery', 'Paired region specific services') 'Discovery')
            @{
                id = 'Service'
                version = 'KqlParameterItem/1.0'
                name = 'Service'
                label = 'Services (paired-region view only)'
                type = 2
                isRequired = $true
                multiSelect = $true
                quote = "'"
                delimiter = ','
                value = @('value::all')
                typeSettings = @{ additionalResourceOptions = @('value::all'); selectAllValue = '*' }
                jsonData = ConvertTo-Json -InputObject @($pairedRegionServices | ForEach-Object {
                    [ordered]@{ value = $_; label = $_ }
                }) -Compress
            }
            (New-Choice 'Evidence' 'Evidence (paired-region view only)' @('All', 'Detected configuration', 'Documented service behavior', 'Needs verification') 'All')
        )
    }
})

$items.Add((New-TextItem 'inventory-warning' @'
## Discovery

All indexed resource types in the selected subscription, source-region, and resource-group scope. Global and unlocated resources are retained. Location is resource metadata, not a complete map of replicas or dependencies.

**Detail limit: 1,000 rows.** Counts are calculated before the cap; larger inventories require narrower subscription or resource-group scopes. Access and indexing gaps can still apply.
'@))
$items.Add((New-QueryItem 'inventory-count' 'Resource inventory counts' ($scopeQuery + @'

| summarize IndexedResources = count()
| extend DetailStatus = iff(IndexedResources > 1000, 'TRUNCATED: narrow subscriptions / resource groups before export', 'Within 1000-row detail cap; access and indexing gaps still apply')
'@)))
$items.Add((New-QueryItem 'inventory-regions' 'Resources by region' ($scopeQuery + "`n| summarize Resources = count() by location | order by Resources desc | limit 1000")))
$items.Add((New-QueryItem 'inventory-types' 'Resources by type' ($scopeQuery + "`n| summarize Resources = count() by type | order by Resources desc | limit 1000")))
$items.Add((New-QueryItem 'inventory-groups' 'Resources by subscription and resource group' ($scopeQuery + "`n| summarize Resources = count() by subscriptionId, resourceGroup | order by Resources desc | limit 1000")))
$items.Add((New-QueryItem 'inventory-detail' 'Discovered resources' ($scopeQuery + @'

| project name, type, location, subscriptionId, resourceGroup, kind, sku = tostring(sku.name), zones, tags, id
| order by id asc
| limit 1000
'@)))

$items.Add((New-TextItem 'scope-warning' @'
## Paired region specific services

Paired-region features and dependencies from [Azure services that support multiple regions](https://learn.microsoft.com/azure/reliability/regions-multiregion-support?tabs=built-in-multiregion-support): Storage, Backup, SQL, Key Vault, PostgreSQL/MySQL, Cosmos DB, Data Factory, Device Registry, Event Grid, IoT Hub, Notification Hubs, Storage Actions, Storage Mover, Microsoft Fabric, App Service/Environment, and AKS.

Inclusion does not prove geo-redundancy is enabled or supported in the resource's region. Service-managed behavior requires regional verification. Event Grid and Notification Hubs protect metadata, not event payloads or device registrations. App Service, AKS, Storage Actions and Fabric need dependent-resource or service-level checks. Customer-selected replicas are separate from paired backups; flexible Notification Hubs recovery regions do not establish Azure pairing.

Missing properties and unindexed relationships require verification; they do not prove a feature is disabled. Counts precede the **1,000-row** detail cap. Target service availability and recovery access require separate verification.

**Paired configuration detected** refers only to observed paired-region settings, not replication health or regional eligibility. **Not detected - verify** is not proof of a disabled feature. Evidence can report a detected replica or flexible recovery region without proving a paired configuration. **Not assessed** identifies dependencies or settings this query cannot validate.
'@))
$items.Add((New-QueryItem 'candidate-count' 'Configuration discovery counts' ($discovery + @'

| summarize MatchingResources = count(), Detected = countif(evidence == 'Detected configuration'), DocumentedBehavior = countif(evidence == 'Documented service behavior'), NeedsVerification = countif(evidence == 'Needs verification')
| extend DetailStatus = iff(MatchingResources > 1000, 'TRUNCATED: narrow subscriptions/resource groups and reconcile all partitions', 'Within 1000-row detail cap; access and indexing gaps still apply')
'@) 1))
$items.Add((New-QueryItem 'candidate-summary' 'Resources by service and evidence' ($discovery + @'

| project name, service, evidence, ['Paired configuration detected'] = pairedConfigurationDetected, ['Paired-region configuration'] = pairedRegionConfiguration, id
| order by service asc, evidence asc, name asc, id asc
| limit 1000
'@)))
$items.Add((New-QueryItem 'candidate-detail' 'Resource configurations and required follow-up' ($discovery + "`n| order by id asc | limit 1000")))

$items.Add((New-TextItem 'backup-warning' @'
## Backup and ASR

Protected items and replication targets in the selected subscription, source-region, and resource-group scope. Service/Evidence filters do not apply. Region screening uses vault and indexed ASR source/recovery regions; missing vault locations are retained.

A vault may protect workloads in other regions. These rows do not prove geo-redundancy or successful restore. Blank fields require service-level verification. **Detail limit: 1,000 rows.**
'@))
$items.Add((New-QueryItem 'backup-count' 'Protected-item count - before the detail row cap' ($backup + "`n| summarize MatchingItems = count() | extend DetailStatus = iff(MatchingItems > 1000, 'TRUNCATED: partition by subscription / vault resource group', 'Within detail cap; reconcile service inventory')")))
$items.Add((New-QueryItem 'backup-detail' 'Backup items and ASR replication targets' ($backup + "`n| order by id asc | limit 1000")))

$items.Add((New-TextItem 'coverage-warning' @'
## Coverage

Subscription access in the selected scope, independent of source-region, resource-group, and Service/Evidence filters. Missing subscriptions and resources may indicate access or indexing gaps; a zero count does not prove absence.
'@))
$items.Add((New-QueryItem 'subscription-scope' 'Accessible subscriptions in selected scope' @'
ResourceContainers
| where type =~ 'microsoft.resources/subscriptions'
| project subscriptionId, subscriptionName = name, state = tostring(properties.state)
| order by subscriptionName asc
'@))

$pairedRegionItems = @('scope-warning', 'candidate-count', 'candidate-summary', 'candidate-detail')
foreach ($item in $items) {
    if ($item.name -in @('title', 'parameters')) {
        continue
    }
    $view = if ($item.name -in $pairedRegionItems) { 'Paired region specific services' } else { 'Discovery' }
    $item.conditionalVisibility = @{ parameterName = 'View'; comparison = 'isEqualTo'; value = $view }
}

$workbook = @{
    version = 'Notebook/1.0'
    items = $items.ToArray()
    '$schema' = 'https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json'
}
$output = Join-Path $PSScriptRoot 'Azure-Regional-Migration.workbook.json'
$workbook | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $output -Encoding utf8NoBOM
Write-Output "Created $output"