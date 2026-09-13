# Paired-Region Service Filters

These read-only Azure Resource Graph queries are separate, per-service filters based on the workbook's existing discovery logic. They do not modify the workbook and are not consumed by the workbook generator.

| Query | Included resources |
| --- | --- |
| [storage-geo-redundancy.kql](storage-geo-redundancy.kql) | Storage accounts with Standard GRS, RA-GRS, GZRS, or RA-GZRS SKUs. |
| [backup-geo-redundancy.kql](backup-geo-redundancy.kql) | Recovery Services or Backup vaults with indexed geo-redundant storage or enabled Cross Region Restore. |
| [sql-geo-backups.kql](sql-geo-backups.kql) | SQL resources with current Geo or GeoZone backup redundancy. Requested redundancy alone does not qualify. |
| [postgresql-mysql-geo-backups.kql](postgresql-mysql-geo-backups.kql) | PostgreSQL/MySQL flexible servers with enabled geo-redundant backups. Read replicas alone do not qualify. |
| [key-vault-service-managed.kql](key-vault-service-managed.kql) | Key Vault inventory for service-managed replication review. Excludes Managed HSM; no replication setting is detected. Regional exceptions apply. |

## Parameters and Scope

All queries run directly in Resource Graph Explorer without placeholder replacement. Select subscriptions in the portal before running them; use the same subscriptions as the workbook when comparing results. By default, they include all regions and resource groups in that subscription scope. To narrow a query, insert filters after the resource-type filter, for example:

```kusto
| where location in~ ('northeurope', 'westeurope') or isempty(location) or location =~ 'global'
| where resourceGroup in~ ('rg-app', 'rg-data')
```

When using these files in a workbook Resource Graph query step, bind the subscription scope to the workbook's Subscriptions parameter. These standalone queries do not automatically apply the workbook's region or resource-group parameters. Each file fixes the service and evidence category, so it does not use the Service or Evidence controls. Workbook placeholders such as `{SourceRegions}` and `{ResourceGroups}` cannot be used directly in Resource Graph Explorer; unresolved placeholders cause `ParserFailure` errors at the `{` token.

The optional location filter above retains global and unlocated resources, matching the workbook convention. It screens indexed resource locations, not secondary regions or protected workload locations. The planned target region does not filter these queries or validate a restore destination.

## Interpretation

Except for Key Vault, these queries return only matching configuration signals, unlike the workbook's broader inventory that also includes resources needing verification. Missing properties or empty results do not prove geo-redundancy is disabled. Key Vault rows represent documented service behavior, not observed replication configuration.

SQL replicas and PostgreSQL/MySQL read replicas are independent of paired geo-backups. Backup CRR is workload-specific. Verify replication health, current redundancy, regional exceptions, and restore support through the relevant service APIs before making migration decisions.

No explicit row limit is applied in these files; Resource Graph response limits still apply. Use pagination where supported or narrow the scope for complete inventory. Local structural checks do not replace live Azure Resource Graph execution.