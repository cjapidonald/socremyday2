# CloudKit Record Types for ScoreMyDay

All CloudKit schema work for ScoreMyDay should target the `iCloud.donald.matrix`
container. The app continues to use Core Data with CloudKit mirroring, but the
managed object model now maps 1:1 to the custom record types documented below so
that field names match the production schema.

## `AppPrefs`

| Field | Type | Notes |
| --- | --- | --- |
| `dayCutoffHour` | Int64 | Daily cutoff hour (0–23). |
| `hapticsOn` | Int64 | Treated as a Boolean flag (`0` = false, `1` = true). |
| `id` | String | Backed by a UUID stored as a string. |
| `soundsOn` | Int64 | Treated as a Boolean flag (`0` = false, `1` = true). |
| `themeAccent` | String (optional) | Accent color hex string. |
| `themeStyleRaw` | String | Raw value of the selected `AppTheme`. |

Only the creating user has read/write access.

## `DeedCard`

| Field | Type | Notes |
| --- | --- | --- |
| `category` | String | Category name. |
| `colorHex` | String | Hex value for the card tint. |
| `createdAt` | Timestamp | Creation date. |
| `dailyCap` | Double (optional) | Maximum counted amount per day. |
| `emoji` | String | Emoji displayed on the card. |
| `id` | String | Backed by a UUID stored as a string. |
| `isArchived` | Int64 | Boolean flag (`0`/`1`). |
| `isPrivate` | Int64 | Boolean flag (`0`/`1`). |
| `name` | String | Display name for the card. |
| `pointsPerUnit` | Double | Points awarded per unit. |
| `polarityRaw` | Int64 | Raw value for `Polarity`. |
| `showOnStats` | Int64 | Boolean flag (`0`/`1`). |
| `sortOrder` | Int64 | Ordering hint. |
| `unitLabel` | String | User-visible unit label. |
| `unitTypeRaw` | Int64 | Raw value for `UnitType`. |

Each card maintains a to-many relationship with `DeedEntry` records through the
`entries` reference list.

## `DeedEntry`

| Field | Type | Notes |
| --- | --- | --- |
| `amount` | Double | Amount logged for the deed. |
| `computedPoints` | Double | Calculated points for the entry. |
| `deed` | Reference | References the owning `DeedCard` record. |
| `deedId` | String | Local mirror of the owning deed's identifier for predicate filtering. |
| `id` | String | Backed by a UUID stored as a string. |
| `note` | String (optional) | Optional note entered by the user. |
| `timestamp` | Timestamp | Time the entry was captured. |

`deed` is the canonical relationship used for CloudKit queries; `deedId`
remains available for lightweight Core Data predicates.

## `Users`

| Field | Type | Notes |
| --- | --- | --- |
| `roles` | List<Int64> | Reserved for future role-based access. |

Only the record creator has read/write access.

## `UserProfile`

| Field | Type | Notes |
| --- | --- | --- |
| `appleUserIdentifier` | String | Stable identifier returned by Sign in with Apple. |
| `email` | String (optional) | Last known email (if the user shared it). |
| `firstName` | String (optional) | First name from the initial authorization. |
| `lastName` | String (optional) | Last name from the initial authorization. |

`UserProfile` records are created/updated automatically when the user signs in
with Apple inside the Settings page. Only the user may read or write their
profile.

> **Note:** CloudKit automatically adds system fields (for example,
> `recordName`, `modificationDate`) that do not need to be manually managed.

Ensure these record types exist in both the development and production
environments of the `iCloud.donald.matrix` container before testing
sync features.
