# GitHub sync: design

- **Phase:** 4
- **Status:** not started. Document repo name deferred to Phase 4 (CLAUDE.md section 14, question 2; suggestion `onnie12/vault-inbox`)
- **Code (planned):** `VaultCore/Sources/VaultCore/GitHubDiff.swift`, `Vault/Services/GitHubClient.swift`, `Vault/Services/KeychainStore.swift`, `Vault/Features/Sync/`
- **Rules that apply:** CLAUDE.md sections 3.1 (no background refresh), 4 (this is the allowed "automatic" path), 10 (token only in the Keychain)

## Goal

The automatic part of Vault. Claude writes documents into a private GitHub repo, and Vault pulls them through the official GitHub REST API. Automatic only for new documents, and only in Claude sessions that can push to GitHub.

## Setup Onni does once

1. Create a **private** repo.
2. Create a **fine-grained personal access token**: repository access = only that repo, permission Contents = **Read-only**, with an expiry date.
3. Paste owner, repo, branch and token into Vault Settings.

## Token handling

- Keychain, `kSecClassGenericPassword`, service `vault.github`, `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`. The normal Keychain works without the Keychain Sharing capability.
- Never write the token to logs, UserDefaults, SwiftData, files or git.
- On HTTP 401, show "Token expired or invalid" with a button to replace it.

## API calls

Confirm the current `X-GitHub-Api-Version` on docs.github.com before building. `2022-11-28` is the one known.

- Headers: `Authorization: Bearer <token>`, `Accept: application/vnd.github+json`, `X-GitHub-Api-Version: <current>`.
- List files: `GET https://api.github.com/repos/{owner}/{repo}/git/trees/{branch}?recursive=1`. Use entries with `type == "blob"`. If the response has `"truncated": true`, walk the subtrees instead.
- Download a file: `GET /repos/{owner}/{repo}/git/blobs/{sha}` with `Accept: application/vnd.github.raw+json` (raw bytes).
- Authenticated rate limit is 5,000 requests per hour. Download only changed blobs.

## Diff logic (in `VaultCore`, unit tested)

- `sourceKey` = file path, `sourceRevision` = blob SHA.
- New path: import.
- Same path, new SHA: replace the file content, keep the document ID, favorite flag and manual category. Re-run classification only if `categoryIsManual == false`.
- Path gone from the repo: set `sourceRemoved = true` and show a badge. **Never delete automatically.**
- Ignore: dot files, `.github/`, root `README.md`.

## When it runs

On launch, when the scene becomes active (at most once every 5 minutes), on pull to refresh, and via the Sync button in the library toolbar (shown only when GitHub is configured). No background refresh: forbidden capability.

## Repo conventions (so Claude can write into it)

- Folder = category hint: `studying/`, `linux/`, `coding/`, `networking/`, `it-support/`, `images/`, `inbox/` (`inbox` means "classify by rules"). The classifier's folder step matches folder names case-insensitively against category names, so `it-support` must be mapped to "IT Support" explicitly (or the folder named to match). Decide which in Phase 4.
- Markdown files may start with front matter:

```markdown
---
title: M319 Lernziele Zusammenfassung
category: Studying
created: 2026-09-20
source: claude
---
```

## Claude side (tell Onni plainly)

This only happens automatically in Claude sessions that can push to GitHub (for example Claude Code, or a session with GitHub access to that repo). In a normal claude.ai chat without that access he uses share sheet, Files inbox or paste. Offer to write a small "save to Vault" skill (SKILL.md) that tells Claude to commit documents with the front matter above into the right folder.

## Testing

- `GitHubDiff` unit tests in `VaultCore`: new, changed, removed, ignored paths.
- `GitHubClient` tests with a stubbed `URLProtocol`: 200, 401, truncated tree.
- Device check (Phase 4 acceptance): add a file to the repo, open Vault, it appears in the right category; change it, it updates; delete it, it gets the "removed" badge and stays.
