# CloudKit Schema Update: App Prefs Theme Accent

This repository's Core Data model defines an optional `themeAccent` attribute on the `AppPrefs` entity. When mirrored to CloudKit, the field is expected to appear as `CD_themeAccent` on the `CD_AppPrefs` record type. If the field is missing from CloudKit, CloudKit pushes of app preferences that include an accent color will fail.

## Adding the `CD_themeAccent` field

You can add the field by using either the CloudKit Dashboard or the `cktool` command-line utility.

### CloudKit Dashboard

1. Open the [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/).
2. Select the development environment for the ScoreMyDay container.
3. Navigate to the **Data** tab and choose the `CD_AppPrefs` record type.
4. Add a new field with the following configuration:
   - **Name:** `CD_themeAccent`
   - **Type:** `String`
   - **Optional:** Enabled
   - **Queryable:** Enabled
   - **Sortable:** Enabled
5. Save the schema changes.

### `cktool`

If you prefer to automate the change, you can use `cktool`:

```bash
cktool record-type-field create \
  --container <container-identifier> \
  --environment development \
  --record-type CD_AppPrefs \
  --name CD_themeAccent \
  --type STRING \
  --optional true \
  --queryable true \
  --sortable true
```

After the field is created, deploy the schema to the development environment:

```bash
cktool schema deploy --container <container-identifier> --environment development
```

## Verifying the change

Run a development build that exercises CloudKit sync for `AppPrefs` (for example, by changing the accent color in Settings). Verify that the sync uploads succeed and no errors referencing a missing `CD_themeAccent` field appear in the console.

> **Note:** CloudKit operations cannot be performed from within this automated environment. Execute the steps above locally while signed in with the appropriate Apple Developer credentials.
