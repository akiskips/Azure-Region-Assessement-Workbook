# Azure Region Migration: Resource Discovery Workbook

An Azure Monitor workbook for discovering resources, reviewing their regional distribution, and inspecting selected paired-region configurations before planning a regional migration. It uses read-only Azure Resource Graph queries; it does not migrate or modify resources.

## Disclaimer

**This is a user-created project, not an official Microsoft product. It is not endorsed, supported, or maintained by Microsoft.**

The workbook is provided as-is, without warranty. Results are discovery aids, not a complete migration assessment, a guarantee of recoverability, or confirmation that a target region is supported. Independently verify findings using current Azure documentation and the relevant service APIs before making operational decisions. Support or feedback for this project should be directed to this repository's issues, not Microsoft support.

## Requirements

- Access to the Azure portal and the subscriptions you want to inspect.
- Read access to the resources being queried, for example through the Reader role at the appropriate scope. Resource Graph only returns resources you are authorized to read.
- Permission to save workbooks in the chosen resource group, for example the Workbook Contributor role, if you want to save a shared workbook. This does not grant access to the underlying resources.
- PowerShell 7 or later only if you want to rebuild the workbook. Importing the supplied JSON does not require PowerShell.

## Import the Workbook

1. Download [Azure-Regional-Migration.workbook.json](Azure-Regional-Migration.workbook.json) from this repository.
2. In the [Azure portal](https://portal.azure.com), open **Monitor > Workbooks** and create a new workbook.
3. Enter **Edit** mode and open **Advanced Editor** using the `</>` toolbar button.
4. Select **Gallery Template** if a template-type selector is shown. Replace the editor contents with the complete downloaded JSON. This file is workbook JSON, not an ARM deployment template.
5. Select **Apply**, then **Done Editing**.
6. Select your subscriptions and filters. Save the workbook with a name, subscription, resource group, and location when ready.

Saving the workbook does not grant other viewers access to your resources. Each viewer needs the appropriate permissions.

## Use the Workbook

| Control | Behavior |
| --- | --- |
| Subscriptions | Sets the subscription scope for Resource Graph queries. |
| Source regions | Filters resources by their indexed location. Global and unlocated resources are retained. Backup and ASR queries also consider vault and indexed replication locations. |
| Planned target region (context only) | Records planning context; it does not filter results or validate target availability, quotas, recovery destinations, or migration support. Defaults to `swedencentral`. |
| Resource groups | Narrows the inventory and configuration queries. |
| View | Switches between **Discovery** and **Paired region specific services**. |
| Service | Filters only the paired-region view. Defaults to **All**. |
| Evidence | Filters only the paired-region view by detected configuration, documented behavior, or items needing verification. |

### Discovery

Review resource counts by region, type, and resource group, then inspect the resource inventory. The view also includes indexed backup items, Azure Site Recovery replication targets, and accessible subscriptions. Subscription coverage is independent of the source-region and resource-group filters.

Use table filtering to inspect returned rows and the table's Excel export action to export them. The resource ID column is configured as an Azure resource link.

### Paired Region Specific Services

Review Storage, Backup vaults, SQL, Key Vault, and PostgreSQL/MySQL. The **Resources by service and evidence** table shows one row per resource, with its name, evidence, paired-configuration detection status, configuration type (such as GRS), and resource link. The follow-up table exposes additional observed properties and verification actions.

- **Detected configuration** means selected configuration properties were observed in Resource Graph. It does not prove successful replication or restore.
- **Documented service behavior** identifies Key Vault's service-managed behavior, not an observed customer-controlled replication setting. Regional exceptions apply.
- **Needs verification** means the query did not find its selected configuration signals. Missing or unindexed properties do not prove a feature is disabled.
- **Paired configuration detected** is narrower than Evidence. For example, a PostgreSQL/MySQL read replica can produce detected evidence without proving paired-region geo-backups are enabled.

SQL replicas and PostgreSQL/MySQL read replicas are separate from backup pairing and can use independently selected regions. Service inclusion alone does not mean geo-redundancy is enabled.

## Limits and Troubleshooting

- Detail tables are capped at **1,000 rows**. Count tables are calculated before that cap. Narrow subscriptions or resource groups and reconcile separate exports for larger inventories; table filtering cannot retrieve omitted rows.
- Resource Graph indexing, access restrictions, and unavailable properties can leave gaps. A zero count is not proof that no resources or protection exist.
- Resource location metadata is not a complete map of data residency, dependencies, replicas, or failover destinations.
- Empty results: check subscription access, source regions, resource groups, and (in the paired-region view) Service and Evidence selections.
- Backup and ASR results require workload-level verification of recovery points, restore permissions, retention, and replication health.
- The target-region list is static and may not reflect every current region or service restriction.
- Treat exported results as potentially sensitive inventory. Do not publish subscription details, resource identifiers, tags, or backup information without authorization.
- Local build and structural checks have been performed; live query execution and portal rendering have not been comprehensively validated.

## Repository Files

| File | Purpose |
| --- | --- |
| [Azure-Regional-Migration.workbook.json](Azure-Regional-Migration.workbook.json) | Generated workbook to import into Azure Monitor. |
| [Build-Workbook.ps1](Build-Workbook.ps1) | Workbook generator and source for layout, controls, and table definitions. |
| [discovery.kql](discovery.kql) | Shared service-configuration discovery query. |
| [backup-context.kql](backup-context.kql) | Backup and ASR discovery query. |

To customize the workbook, edit the generator or KQL sources, then run this command from the repository directory in PowerShell 7 or later:

```powershell
./Build-Workbook.ps1
```

This overwrites the generated workbook JSON. Reimport the updated JSON through Advanced Editor. The KQL files contain workbook parameter placeholders and require substitution before running them directly in Resource Graph Explorer.

## References

- [Azure Monitor Workbooks overview](https://learn.microsoft.com/azure/azure-monitor/visualize/workbooks-overview)
- [Manage Azure workbooks](https://learn.microsoft.com/azure/azure-monitor/visualize/workbooks-manage)
- [Azure Resource Graph overview and permissions](https://learn.microsoft.com/azure/governance/resource-graph/overview)

## License

This project is licensed under the [MIT License](LICENSE).