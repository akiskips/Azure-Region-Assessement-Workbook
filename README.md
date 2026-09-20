# Azure Region Migration: Resource Discovery Workbook

An Azure Monitor workbook for discovering resources, reviewing their regional distribution, and inspecting selected paired-region configurations before planning a regional migration. It uses read-only Azure Resource Graph queries; it does not migrate or modify resources.

Use the workbook for interactive discovery across subscriptions, or run the [16 standalone service queries](KQL/README.md) directly in Resource Graph Explorer. The workbook includes a general **Discovery** view and a **Paired region specific services** view with checkbox-based service selection. Both views support checkbox-based tag filtering with **Any** or **All** matching to narrow results by environment, owner, cost center, or other indexed resource tags.

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
| Source regions | Filters resources by their indexed location. Global and unlocated resources are retained. The paired-region view also considers Cosmos DB account locations; Backup and ASR queries also consider vault and indexed replication locations. |
| Resource groups | Narrows the inventory and configuration queries. |
| Tags (key = value) | Checkbox multi-select of indexed resource tag pairs in the selected subscriptions. **All** (the default) disables tag filtering, including for untagged resources. |
| Match selected tags | **Any** (the default) matches at least one selected pair; **All** requires every selected pair on the same resource. |
| View | Switches between **Discovery** and **Paired region specific services**. |
| Services | Checkbox multi-select dropdown for the paired-region view. Select one or more services, or **All** (the default). |
| Evidence | Filters only the paired-region view by detected configuration, documented behavior, or items needing verification. |

There is no target-region selector. This workbook assesses existing resources and configuration evidence; it does not check destination service availability, SKU support, quota, or restore eligibility. Verify these separately for your intended destination.

### Filter by Tags

Tag filtering uses the checkbox picker only; custom key/value entry is not supported. Reimport the updated workbook JSON to add the tag controls to an existing workbook.

1. Select the subscriptions to inspect, then open **Tags (key = value)**.
2. Replace the default **All** selection with one or more tag pairs, such as `environment = production` and `owner = platform`.
3. Set **Match selected tags** to **Any** or **All**. The resource counts and detail tables use the same tag filter.

With those two example pairs selected:

| Match selected tags | Included resources |
| --- | --- |
| **Any** | Resources tagged `environment = production`, `owner = platform`, or both. |
| **All** | Resources carrying both `environment = production` and `owner = platform`. |

To select several values for one key, such as production or staging, use **Any**. Requiring both values with **All** normally returns no resources because a tag key has one value. To reset the filter, select **All** in the **Tags (key = value)** picker; this is separate from the **All** match mode.

Tag keys are matched case-insensitively and shown in lowercase; values are matched exactly, including case. Empty tag values are supported. Selecting **All** in the Tags picker turns filtering off regardless of the match mode. With specific pairs selected, untagged resources are excluded. Tags are read from the resource itself, not inherited from its subscription or resource group.

The filter applies before counts and detail limits in both views. **Backup and ASR** uses vault tags, not tags on the protected workload; items without indexed matching vault tags are excluded when filtering is active. Subscription coverage remains independent of tag filters. Tag choices come from selected subscriptions and are not narrowed by the other controls; Resource Graph result limits and indexing can leave choices incomplete in large scopes.

### Discovery

Review resource counts by region, type, and resource group, then inspect the resource inventory. The view also includes indexed backup items, Azure Site Recovery replication targets, and accessible subscriptions. Subscription coverage is independent of the source-region, resource-group, and tag filters.

Use table filtering to inspect returned rows and the table's Excel export action to export them. The resource ID column is configured as an Azure resource link.

### Paired Region Specific Services

Review the 16 service groups below. The **Resources by service and evidence** table shows one row per indexed resource, with its name, evidence, paired-configuration detection status, configuration type (such as GRS), and resource link. The follow-up table exposes additional observed properties and verification actions.

- **Detected configuration** means selected configuration properties were observed in Resource Graph. It does not prove successful replication or restore.
- **Documented service behavior** identifies service-managed recovery, not an observed customer-controlled replication setting. This category covers Key Vault, eligible Data Factory candidates, Device Registry, Event Grid system topics, IoT Hub candidates without an observed DR opt-out, and Storage Mover. It does not confirm that the resource's region supports the behavior.
- **Needs verification** means the query did not find its selected configuration signals. Missing or unindexed properties do not prove a feature is disabled.
- **Paired configuration detected** is narrower than Evidence. PostgreSQL/MySQL and Cosmos DB replicas can produce detected evidence without proving paired-region geo-backups are enabled. A selected Notification Hubs recovery region does not establish Azure pairing.
- **Not assessed** identifies dependencies or service settings the query cannot validate, including App Service backups, AKS backup protection, Storage Actions target accounts, and Fabric capacity DR settings. These resources remain **Needs verification**.

Coverage is based on [Azure services that support multiple regions](https://learn.microsoft.com/azure/reliability/regions-multiregion-support?tabs=built-in-multiregion-support), reviewed on 2026-09-20. The view focuses on features that use Azure region pairs, including dependent storage and backup configurations. A checkmark in the source's **Paired regions** column means a feature can operate between paired regions, not necessarily that it requires a fixed Azure pair.

| Service group | Paired-region feature and assessment |
| --- | --- |
| Storage | Detects Standard GRS, RA-GRS, GZRS and RA-GZRS account SKUs. Covers account-level redundancy for Blob Storage, ADLS Gen2, Files, Queue and Table Storage, subject to service/account support. |
| Backup | Detects indexed vault geo-redundancy or Cross Region Restore (CRR). Workload protection and recovery points require separate verification. |
| SQL | Detects current Geo/GeoZone backup redundancy for SQL Database and Managed Instance resources; requested redundancy and customer-selected replicas do not prove paired backups. |
| Key Vault | Documents service-managed replication with regional exceptions. Managed HSM is excluded because it has a separate multiregion model. |
| PostgreSQL / MySQL | Detects flexible-server geo-backups separately from read replicas. |
| [Cosmos DB](https://learn.microsoft.com/azure/cosmos-db/periodic-backup-storage-redundancy) | Detects explicit `Periodic` backup policy with `Geo` redundancy. Missing properties do not confirm the documented default; account replica locations are separate. |
| [Data Factory](https://learn.microsoft.com/azure/reliability/reliability-data-factory) | Documents Microsoft-managed metadata failover in paired regions. Brazil South and Southeast Asia are flagged as unsupported; integration runtimes and linked stores require separate recovery planning. |
| [Device Registry](https://learn.microsoft.com/azure/reliability/reliability-device-registry) | Inventories namespaces, legacy assets/asset endpoint profiles and schema registries for documented service-managed paired replication. Verify current regional eligibility and dependent services. |
| [Event Grid](https://learn.microsoft.com/azure/reliability/reliability-event-grid) | Detects `dataResidencyBoundary=WithinGeopair` for custom topics/domains; system topics use documented behavior. `WithinRegion` disables Geo-DR. Namespaces and Azure Arc topics are excluded. Only metadata is replicated, not event data. |
| [IoT Hub](https://learn.microsoft.com/azure/reliability/reliability-iot-hub) | Documents paired-region recovery and exposes the `enableDataResidency` flag. An observed `true` flags DR opt-out; missing/false values alone do not prove eligible regional replication. |
| [Notification Hubs](https://learn.microsoft.com/azure/reliability/reliability-notification-hubs) | Inspects namespace `replicationRegion`: `Default` requests the default paired recovery region, `None` disables metadata DR, and named flexible regions require pairing verification. Registrations and installations are not replicated. |
| [Storage Actions](https://learn.microsoft.com/azure/reliability/reliability-storage-actions) | Inventories storage tasks. Continuity depends on each assignment's target storage account geo-redundancy, which this query does not correlate or validate. |
| [Storage Mover](https://learn.microsoft.com/azure/reliability/reliability-storage-mover) | Documents Microsoft-managed configuration metadata replication in paired regions. Source/target data and agents need separate protection; agents require re-registration after failover. |
| [Microsoft Fabric](https://learn.microsoft.com/azure/reliability/reliability-fabric) | Inventories Azure Fabric capacities only. Check the OneLake DR capacity switch, workspace replication status, service presence in the pair and tenant home-region dependencies in Fabric. Power BI and non-OneLake items have separate behavior. |
| [App Service / Environment](https://learn.microsoft.com/azure/app-service/manage-backup) | Inventories apps and App Service Environments, excluding Function Apps. Verify custom backups and their destination account's geo-redundancy; neither app nor environment existence proves protection. |
| [AKS](https://learn.microsoft.com/azure/backup/azure-kubernetes-service-backup-overview) | Inventories clusters for Vault Tier backup review. Verify backup instances, recovery points, vault GRS/CRR and restore prerequisites. This is not cross-region cluster replication. |

The workbook does not compute or validate region pairs. Service inclusion alone does not mean geo-redundancy is enabled. SQL, PostgreSQL/MySQL and Cosmos DB replicas are separate from backup pairing and can use independently selected regions.

Services whose listed capabilities use customer-selected regions, such as API Management, App Configuration, Container Registry, Event Hubs, Service Bus, Managed Redis, Monitor Logs, NetApp Files, SignalR, Web PubSub and Managed HSM, are not added merely because they can operate across a pair. Nonregional services such as DNS, Front Door, Traffic Manager and Entra ID are also outside this view. Site Recovery and VM replication remain in **Discovery > Backup and ASR**. Standalone queries in [KQL/README.md](KQL/README.md) cover all 16 service groups, with configuration filters or inventory requiring verification as documented in that folder.

## Standalone Service Queries

The [KQL query index](KQL/README.md) provides one read-only query for each of the 16 service groups. These queries run independently of the workbook and require no workbook parameter substitution.

1. Open **Resource Graph Explorer** in the Azure portal.
2. Select the subscriptions you want to inspect.
3. Open a query from the index, paste its contents into the query editor, and select **Run query**.
4. Review its evidence and configuration fields, then verify findings using the relevant service APIs.

Standalone queries include all regions, resource groups, and tags in the selected subscription scope by default; workbook tag selections do not apply to them. See the index for optional filters and service-specific caveats. Storage, Backup, SQL and PostgreSQL/MySQL queries filter matching configuration signals; the other queries include inventory for service-managed recovery or further verification. Their results are therefore not always identical to the workbook's broader inventory.

## Limits and Troubleshooting

- Detail tables are capped at **1,000 rows**. Count tables are calculated before that cap. Narrow subscriptions or resource groups and reconcile separate exports for larger inventories; table filtering cannot retrieve omitted rows.
- Resource Graph indexing, access restrictions, and unavailable properties can leave gaps. A zero count is not proof that no resources or protection exist.
- Resource location metadata is not a complete map of data residency, dependencies, replicas, or failover destinations.
- Empty results: check subscription access, source regions, resource groups, Tags and tag match mode, and (in the paired-region view) Service and Evidence selections.
- Backup and ASR results require workload-level verification of recovery points, restore permissions, retention, and replication health.
- Treat exported results as potentially sensitive inventory. Do not publish subscription details, resource identifiers, tags, or backup information without authorization.
- Local workbook build and structural checks have passed. All 16 standalone queries passed Kusto syntax parsing and checks for workbook-placeholder absence and service coverage. These checks do not establish Azure Resource Graph runtime compatibility; live query execution and portal rendering have not been comprehensively validated.

## Repository Files

| File | Purpose |
| --- | --- |
| [Azure-Regional-Migration.workbook.json](Azure-Regional-Migration.workbook.json) | Generated workbook to import into Azure Monitor. |
| [Build-Workbook.ps1](Build-Workbook.ps1) | Workbook generator and source for layout, controls, and table definitions. |
| [discovery.kql](discovery.kql) | Shared service-configuration discovery query. |
| [backup-context.kql](backup-context.kql) | Backup and ASR discovery query. |
| [tag-filter.kql](tag-filter.kql) | Shared tag-filter fragment inserted by the generator into resource and backup queries; not a standalone query. |
| [KQL/README.md](KQL/README.md) | Index and usage guidance for 16 standalone per-service queries; these are not consumed by the workbook generator. |

To customize the workbook, edit the generator or KQL sources, then run this command from the repository directory in PowerShell 7 or later:

```powershell
./Build-Workbook.ps1
```

This overwrites the generated workbook JSON. Reimport the updated JSON through Advanced Editor. The generator expands the internal `{TagFilter}` and `{TagColumn}` markers using [tag-filter.kql](tag-filter.kql). The root-level [discovery.kql](discovery.kql) and [backup-context.kql](backup-context.kql) templates also contain workbook parameter placeholders; neither template runs directly in Resource Graph Explorer without expansion and substitution. The standalone queries listed in [KQL/README.md](KQL/README.md) do not contain those placeholders. Changes to standalone queries do not update the workbook; keep corresponding service logic aligned when customizing either version.

## References

- [Azure services that support multiple regions](https://learn.microsoft.com/azure/reliability/regions-multiregion-support?tabs=built-in-multiregion-support)
- [Azure region pairs and nonpaired regions](https://learn.microsoft.com/azure/reliability/regions-paired)
- [Azure Monitor Workbooks overview](https://learn.microsoft.com/azure/azure-monitor/visualize/workbooks-overview)
- [Manage Azure workbooks](https://learn.microsoft.com/azure/azure-monitor/visualize/workbooks-manage)
- [Azure Resource Graph overview and permissions](https://learn.microsoft.com/azure/governance/resource-graph/overview)

## License

This project is licensed under the [MIT License](LICENSE).