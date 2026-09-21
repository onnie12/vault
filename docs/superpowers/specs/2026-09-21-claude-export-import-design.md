# Claude data export import: design

- **Phase:** 5
- **Status:** not started. Blocked on a real export from Onni for the schema report
- **Code (planned):** `VaultCore/Sources/VaultCore/ClaudeExport.swift`, `Vault/Features/Import/`
- **Rules that apply:** CLAUDE.md sections 4 (this is the allowed backfill path), 7.2 (ZIPFoundation), 13 (never commit real export data)

## Goal

Backfill old material from the **official Claude data export**, a ZIP Onni requests himself.

## Facts [verified 2026-09-20]

- Onni starts it himself on claude.ai web or the desktop app: Settings > Privacy > Export data. It cannot be started from the iOS or Android app.
- The download link arrives by email, needs him signed in, and expires after 24 hours.
- According to a Baruch College library guide (updated 2026-09-05), the export does **not** contain uploaded images or the content of files Claude created (it only records that they existed). It says artifacts are not included either, but a community parser extracts artifacts from the export, so **check this against a real export**.

## Schema [unverified]

No official documentation. A community project (`lordjabez/claude-export-viewer`, last commit 2026-02-12) reads:

- ZIP files: `users.json`, `projects.json`, `memories.json`, `conversations.json` (matched by file name suffix).
- Conversation: `uuid`, `name`, `summary`, `created_at`, `updated_at`, `project_uuid`, `chat_messages[]`.
- Message: `uuid`, `text`, `sender` (`"human"` or `"assistant"`), `created_at`, `content[]`, `attachments[]` (`file_name`, `file_size`, `file_type`, `extracted_content`), `files[]` (`file_name`).
- Content block `type`: `text`, `thinking`, `tool_use`, `tool_result`, `token_budget`.
- Artifacts: `tool_use` blocks with `name == "artifacts"` and `input` = `command` (`create`, `update`, `rewrite`), `id`, `type`, `title`, `language`, `content`, `old_str`, `new_str`, `version_uuid`.
- Projects: `uuid`, `name`, `docs[]` (`uuid`, `filename`, `content`).

## Scope (decided 2026-09-20, CLAUDE.md section 14, question 8)

Import artifacts **and** project knowledge docs from `projects.json`. Do **not** import long assistant answers. Keep the long-answer path (over about 1,500 characters with at least one Markdown heading) behind a setting that defaults to off, in case he changes his mind.

## How to build it

1. **Before writing the importer**, ask Onni for a real export. Write a small dev-only script (Python is fine, not shipped) that prints: top-level files, number of conversations, counts of every content block `type`, every distinct `tool_use` `name` with counts, and the keys found in their `input`. Show him the result. Newer Claude features may use tool names other than `"artifacts"`.
2. The list of tool names that count as documents is a table in code, not a single hard-coded string.
3. Decode leniently: every field optional, unknown block types skipped, one broken conversation must not stop the import.
4. Rebuild each artifact per conversation and artifact `id`: `create` and `rewrite` set the full content, `update` replaces `old_str` with `new_str` once. If `old_str` is not found, keep the last good version and count a warning. Import only the final version.
5. File extension from artifact `type` (historical values, confirm against the real export): `text/markdown` -> `.md`, `text/html` -> `.html`, `image/svg+xml` -> `.svg`, `application/vnd.ant.code` -> by `language`, `application/vnd.ant.mermaid` -> `.mmd`, `application/vnd.ant.react` -> `.jsx`.
6. `sourceKey` = `export:<conversation-uuid>:<artifact-id>`, so importing a newer export updates instead of duplicating. `createdAt` = the message's `created_at`. Project docs use `export:project:<project-uuid>:<doc-uuid>`.
7. Accept either the `.zip` or a bare `conversations.json`. Run off the main actor with a progress view. Finish with a summary: imported, updated, skipped, warnings, and "N files are referenced but their content is not in the export".
8. Entry point: "Import Claude export" in the library `+` menu and in Settings.

## Privacy

Never commit Onni's real export or anything from it (`.gitignore` already blocks the usual file names). Test fixtures are synthetic copies of the structure only.

## Testing

- Synthetic fixtures in `Fixtures/`: create/update/rewrite chains, a failing `update`, an unknown block type, a broken conversation, a project with docs.
- Device check (Phase 5 acceptance): import his real export, check the summary numbers with him.
