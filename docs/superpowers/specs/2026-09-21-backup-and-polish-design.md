# Backup, restore and polish: design

- **Phase:** 6
- **Status:** not started
- **Rules that apply:** CLAUDE.md sections 3.1 (why backup exists), 7.2 (ZIPFoundation), 13 (never delete user documents automatically)

## Goal

With a free Apple ID the app has to be reinstalled every 7 days. Reinstalling over it keeps the data, but **deleting the app deletes everything**. Backup is the safety net.

## Backup

- "Back up Vault" in Settings: a ZIP with all document files plus `manifest.json` (document metadata, categories, rules), shared through the share sheet so Onni can save it to Files or elsewhere.
- Runs off the main actor with a progress view.

## Restore

- "Restore from backup" merges by content hash: a file whose hash already exists is not imported twice.
- Restore never deletes anything already in Vault.

## Polish

- Dynamic Type everywhere.
- VoiceOver labels on all buttons and rows.
- App icon.
- Empty states (no documents, no search results, empty category).
- Error messages in plain language.

## Open items (decide in Phase 6)

1. **Metadata conflict on restore.** Same content hash exists locally and in the backup, but title, category or favorite differ. Options: keep local, take backup, or keep local unless the backup's `updatedAt` is newer. Ask Onni.
2. **Categories on restore.** A backup category with the same name as a local one: merge rules, or keep local rules?
3. **Manifest versioning.** Add a `version` field from the first release so later formats can still read old backups.

## Testing

- Round trip test: back up, wipe an in-memory store, restore, compare.
- Restore into a store that already holds some of the same files: no duplicates, nothing deleted.
