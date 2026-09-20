# Standalone Paired-Region Service Queries

These 16 read-only Azure Resource Graph queries cover the service groups in the workbook's **Paired region specific services** view. They provide configuration filters or review inventory based on the workbook's discovery logic. They do not modify the workbook and are not consumed by the workbook generator.

## Run a Query

1. Open **Resource Graph Explorer** in the Azure portal and select your subscriptions.
2. Open a query from the table below and paste its contents into the query editor.
3. Select **Run query**, then review the evidence and service-specific fields.

No workbook import or parameter replacement is required. Read access to the selected resources is required; results only include resources you are authorized to read. For workbook setup and overall limitations, see the [project README](../README.md).

## Query Index

| Query | Included resources |
| --- | --- |
| [storage-geo-redundancy.kql](storage-geo-redundancy.kql) | Storage accounts with Standard GRS, RA-GRS, GZRS, or RA-GZRS SKUs. |
| [backup-geo-redundancy.kql](backup-geo-redundancy.kql) | Recovery Services or Backup vaults with indexed geo-redundant storage or enabled Cross Region Restore. |
| [sql-geo-backups.kql](sql-geo-backups.kql) | SQL resources with current Geo or GeoZone backup redundancy. Requested redundancy alone does not qualify. |
| [postgresql-mysql-geo-backups.kql](postgresql-mysql-geo-backups.kql) | PostgreSQL/MySQL flexible servers with enabled geo-redundant backups. Read replicas alone do not qualify. |
| [key-vault-service-managed.kql](key-vault-service-managed.kql) | Key Vault inventory for service-managed replication review. Excludes Managed HSM; no replication setting is detected. Regional exceptions apply. |
| [cosmos-db-geo-backups.kql](cosmos-db-geo-backups.kql) | Cosmos DB accounts; distinguishes periodic Geo backups from customer-selected account replicas. |
| [data-factory-service-managed.kql](data-factory-service-managed.kql) | Data Factory metadata recovery review; flags Brazil South and Southeast Asia as unsupported for Microsoft-managed regional failover. |
| [device-registry-service-managed.kql](device-registry-service-managed.kql) | Device Registry namespaces, assets, asset endpoint profiles and schema registries for service-managed recovery review. |
| [event-grid-metadata-geo-dr.kql](event-grid-metadata-geo-dr.kql) | Event Grid topics, domains and system topics; reports metadata Geo-DR settings. Excludes namespaces and Azure Arc resources. |
| [iot-hub-service-managed.kql](iot-hub-service-managed.kql) | IoT hubs; reports DR opt-out and service-managed recovery requiring regional verification. |
| [notification-hubs-metadata-geo-dr.kql](notification-hubs-metadata-geo-dr.kql) | Notification Hubs namespaces; distinguishes default paired recovery, selected flexible regions and disabled metadata DR. |
| [storage-actions-dependency-review.kql](storage-actions-dependency-review.kql) | Storage tasks requiring assignment and target storage redundancy verification. |
| [storage-mover-service-managed.kql](storage-mover-service-managed.kql) | Storage Mover configuration metadata recovery review; does not assess migrated data protection. |
| [fabric-onelake-dr-review.kql](fabric-onelake-dr-review.kql) | Fabric capacities requiring OneLake DR and workspace replication verification. |
| [app-service-backup-review.kql](app-service-backup-review.kql) | App Service apps and environments requiring custom backup and destination storage review. Excludes Function Apps. |
| [aks-vault-tier-backup-review.kql](aks-vault-tier-backup-review.kql) | AKS clusters requiring Azure Backup Vault Tier protection and CRR verification. |

## Parameters and Scope

All queries run directly in Resource Graph Explorer without placeholder replacement. Select subscriptions in the portal before running them; use the same subscriptions as the workbook when comparing results. By default, they include all regions and resource groups in that subscription scope. To narrow a query, insert filters after the resource-type filter, for example:

```kusto
| where location in~ ('northeurope', 'westeurope') or isempty(location) or location =~ 'global'
| where resourceGroup in~ ('rg-app', 'rg-data')
```

When using these files in a workbook Resource Graph query step, bind the subscription scope to the workbook's Subscriptions parameter. These standalone queries do not automatically apply the workbook's region or resource-group parameters. Each file fixes the service and returns its applicable evidence categories without using the Service or Evidence controls. Workbook placeholders such as `{SourceRegions}` and `{ResourceGroups}` cannot be used directly in Resource Graph Explorer; unresolved placeholders cause `ParserFailure` errors at the `{` token.

The optional location filter above retains global and unlocated resources, matching the workbook convention. It screens indexed resource locations, not secondary regions or protected workload locations. These queries do not validate a restore destination.

For Cosmos DB, the workbook also matches configured account locations. To include those locations when narrowing the standalone query, use this location filter instead:

```kusto
| where location in~ ('northeurope', 'westeurope') or isempty(location) or location =~ 'global'
	or replace_string(tolower(tostring(properties.locations)), ' ', '') has_any ('northeurope', 'westeurope')
```

## Interpretation

The Storage, Backup, SQL and PostgreSQL/MySQL queries return only matching configuration signals. Key Vault and the eleven additional service queries return inventory for review, including documented behavior or resources needing verification, following the workbook's evidence rules. Missing properties or empty results do not prove geo-redundancy is disabled. Documented service behavior is not observed replication configuration or proof of regional eligibility.

Cosmos DB account replicas alone do not establish paired geo-backups. Event Grid and Notification Hubs metadata recovery does not protect event payloads or registrations/installations respectively. Storage Actions, Fabric, App Service and AKS rows do not establish that protection is configured; verify dependent storage, service settings and backup recovery points separately.

SQL replicas and PostgreSQL/MySQL read replicas are independent of paired geo-backups. Backup CRR is workload-specific. Verify replication health, current redundancy, regional exceptions, and restore support through the relevant service APIs before making migration decisions.

No explicit row limit is applied in these files; Resource Graph response limits still apply. Use pagination where supported or narrow the scope for complete inventory. Local structural checks do not replace live Azure Resource Graph execution.