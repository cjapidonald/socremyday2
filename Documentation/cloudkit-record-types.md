# CloudKit Record Types for ScoreMyDay

All CloudKit schema work for ScoreMyDay should target the `iCloud.com.Donald.scoremyday2` container. The app uses Core Data with CloudKit mirroring, which produces one CloudKit record type for each entity in the managed object model. The tables below summarize the expected record types and fields so that they can be verified or recreated in the CloudKit Dashboard.

## `CD_DeedCard`

| Field | Type | Notes |
| --- | --- | --- |
| `CD_id` | UUID | Primary identifier |
| `CD_name` | String | Name shown on the deed card |
| `CD_emoji` | String | Emoji associated with the deed |
| `CD_colorHex` | String | Hex value for the deed color |
| `CD_category` | String | Category name |
| `CD_polarityRaw` | Int64 | Stores the `Polarity` enum raw value |
| `CD_unitTypeRaw` | Int64 | Stores the `UnitType` enum raw value |
| `CD_unitLabel` | String | User-visible unit label |
| `CD_pointsPerUnit` | Double | Points awarded per unit |
| `CD_dailyCap` | Double (optional) | Maximum number of units counted per day |
| `CD_isPrivate` | Int64 (Boolean) | Backed by a Boolean in Core Data |
| `CD_showOnStats` | Int64 (Boolean) | Controls whether the deed appears in stats |
| `CD_createdAt` | Timestamp | Creation date |
| `CD_isArchived` | Int64 (Boolean) | Marks the deed as archived |
| `CD_sortOrder` | Int64 | Ordering hint |
| `CD_entries` | Reference list | Relationship to `CD_DeedEntry` records |

## `CD_DeedEntry`

| Field | Type | Notes |
| --- | --- | --- |
| `CD_id` | UUID | Primary identifier |
| `CD_deedId` | UUID | References the owning deed |
| `CD_timestamp` | Timestamp | Time the entry was captured |
| `CD_amount` | Double | Amount logged for the deed |
| `CD_computedPoints` | Double | Calculated points for the entry |
| `CD_note` | String (optional) | Optional note |
| `CD_deed` | Reference | Back-reference to the parent `CD_DeedCard` |

## `CD_AppPrefs`

| Field | Type | Notes |
| --- | --- | --- |
| `CD_id` | UUID | Primary identifier |
| `CD_dayCutoffHour` | Int64 | Daily cutoff hour |
| `CD_hapticsOn` | Int64 (Boolean) | Whether haptics are enabled |
| `CD_soundsOn` | Int64 (Boolean) | Whether sounds are enabled |
| `CD_themeAccent` | String (optional) | Accent color hex string |
| `CD_themeStyleRaw` | String | Stores the selected theme style |

> **Note:** CloudKit automatically adds system fields (e.g., `recordName`, `modificationDate`) that do not need to be manually managed.

Make sure that these record types exist in both the development and production environments of the `iCloud.com.Donald.scoremyday2` container before testing sync features.
