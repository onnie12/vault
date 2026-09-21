# Categories and automatic classification: design

- **Phase:** 2
- **Status:** not started. Networking and IT Support keyword rules are still open (see "Open items")
- **Code (planned):** `VaultCore/Sources/VaultCore/Classifier.swift`, `FrontMatter.swift`, `Vault/Resources/DefaultCategories.json`, `Vault/Features/Categories/`
- **Rules that apply:** CLAUDE.md sections 7.1 (classifier lives in `VaultCore`, Foundation only), 13 (tests first)

## Goal

Sort every document into exactly one category (CLAUDE.md section 14, question 5) with **deterministic keyword and file-type rules**, no AI. Rules are data, not hard-coded `if` chains, so Onni can edit them in Settings.

## Default categories

Onni added Networking, IT Support and Personal on 2026-09-20 (CLAUDE.md section 14, question 6).

| Order | Name | SF Symbol | Decided by |
|---|---|---|---|
| 1 | Studying | `graduationcap` | keywords |
| 2 | Linux | `terminal` | extensions and keywords |
| 3 | Coding | `chevron.left.forwardslash.chevron.right` | extensions and keywords |
| 4 | Networking | `network` | keywords |
| 5 | IT Support | `wrench.and.screwdriver` | keywords |
| 6 | Images | `photo` | file type only |
| 7 | Personal | `person.crop.circle` | **manual only, no rules** |
| 8 | Other | `tray` | fallback |

Order is both the display order of the filter chips and the tie-break in step 6 of the algorithm, so Studying beats every technical category on a tie. Deliberate: school material stays in Studying even when its topic is bash or subnetting (CLAUDE.md section 14, question 9).

**Personal ships with an empty rule list on purpose.** "Personal" has no distinctive vocabulary the way Linux does, so any keyword rule would misfire. Documents reach it only when Onni moves them there by hand, which sets `categoryIsManual` and makes the choice permanent. This keeps the `einkaufsliste.md` test valid.

## Algorithm (priority from top to bottom)

1. **Manual choice.** If `categoryIsManual == true`, keep it. Nothing overrides this.
2. **Front matter.** If a Markdown file starts with YAML front matter containing `category: <name>` and that name matches a category (case-insensitive), use it.
3. **GitHub folder.** If the file came from GitHub and its top-level folder name matches a category name (case-insensitive), use it.
4. **Images.** If the file's `UTType` conforms to `.image`, use Images.
5. **Scoring.** For each keyword category, compute a score:
   - Every rule is a case-insensitive regular expression with a weight.
   - Body pass: over the first 20,000 characters of the text content, score += weight x number of matches, **capped at 3 matches per rule**.
   - Name pass: run the same rules over `fileName + " " + title` and add that score too (so name and title matches count double, since the title is usually also in the body).
   - File extension in the category's extension list: +5.
6. Highest score wins if it is **3 or more**. Ties go to the lower Order number.
7. Otherwise: Other.

`VaultCore` cannot import `UniformTypeIdentifiers` on Linux, so step 4 takes a precomputed `isImage: Bool` from the app instead of a `UTType`.

## Default rules (`DefaultCategories.json` in the app bundle)

Order numbers below follow the 8-category table. Networking, IT Support and Personal are **not in this JSON yet**: Personal gets an entry with empty `rules`, the other two need rules first (open items).

```json
[
  {
    "name": "Studying", "symbol": "graduationcap", "color": "#E8A33D", "order": 1,
    "extensions": [],
    "rules": [
      { "pattern": "\\bM\\d{3}\\b", "weight": 4 },
      { "pattern": "\\b(ÜK|UEK)\\s?\\d{3}\\b", "weight": 4 },
      { "pattern": "\\blernziel(e)?\\b", "weight": 3 },
      { "pattern": "\\bzusammenfassung\\b", "weight": 3 },
      { "pattern": "\\bpr(ü|ue)fung\\b", "weight": 3 },
      { "pattern": "\\b(lernkarte|karteikarte)n?\\b", "weight": 3 },
      { "pattern": "\\brepetition\\b", "weight": 2 },
      { "pattern": "\\b(ü|ue)bung(en)?\\b", "weight": 2 },
      { "pattern": "\\bmodul\\b", "weight": 2 },
      { "pattern": "\\bstudy guide\\b", "weight": 3 },
      { "pattern": "\\bcheat ?sheet\\b", "weight": 3 },
      { "pattern": "\\bflash ?cards?\\b", "weight": 3 },
      { "pattern": "\\blearning objectives?\\b", "weight": 3 },
      { "pattern": "\\bexam\\b", "weight": 2 },
      { "pattern": "\\bquiz\\b", "weight": 2 }
    ]
  },
  {
    "name": "Linux", "symbol": "terminal", "color": "#4C9A6A", "order": 2,
    "extensions": ["sh", "bash", "zsh", "service", "conf"],
    "rules": [
      { "pattern": "```(bash|sh|shell|zsh|console)\\b", "weight": 3 },
      { "pattern": "\\bsudo\\s", "weight": 3 },
      { "pattern": "\\b(systemctl|journalctl)\\b", "weight": 3 },
      { "pattern": "\\b(pacman|yay|apt|apt-get|dnf|flatpak)\\s", "weight": 3 },
      { "pattern": "\\b(grub|fstab|os-prober)\\b", "weight": 3 },
      { "pattern": "\\b(manjaro|arch linux|cachyos|fedora|ubuntu|debian)\\b", "weight": 3 },
      { "pattern": "\\b(kde|plasma|wayland|x11)\\b", "weight": 2 },
      { "pattern": "(^|\\s)/(etc|usr|var|boot)/", "weight": 2 },
      { "pattern": "\\b(chmod|chown|ssh|tailscale)\\b", "weight": 1 },
      { "pattern": "\\blinux\\b", "weight": 2 }
    ]
  },
  {
    "name": "Coding", "symbol": "chevron.left.forwardslash.chevron.right", "color": "#4A7BD0", "order": 3,
    "extensions": ["swift", "go", "py", "js", "ts", "tsx", "jsx", "java", "kt", "c", "h", "cpp", "cs", "rs", "rb", "php", "sql"],
    "rules": [
      { "pattern": "```(go|swift|python|py|js|javascript|ts|typescript|java|kotlin|c|cpp|csharp|rust|sql)\\b", "weight": 3 },
      { "pattern": "\\bpackage main\\b", "weight": 3 },
      { "pattern": "\\bfunc\\s+\\w+\\(", "weight": 2 },
      { "pattern": "\\b(struct|class|interface|enum)\\s+\\w+", "weight": 1 },
      { "pattern": "\\b(git commit|pull request|merge conflict)\\b", "weight": 2 },
      { "pattern": "\\b(compiler|debugger|stack trace)\\b", "weight": 2 },
      { "pattern": "\\bapi\\b", "weight": 1 },
      { "pattern": "\\balgorithm(us)?\\b", "weight": 2 }
    ]
  },
  { "name": "Images", "symbol": "photo", "color": "#B05FC4", "order": 6, "matchesImageTypes": true, "extensions": [], "rules": [] },
  { "name": "Other", "symbol": "tray", "color": "#8E8E93", "order": 8, "isFallback": true, "extensions": [], "rules": [] }
]
```

## Required test cases (write these as unit tests first)

A Python prototype of the algorithm and the three keyword categories above produced the expected result for the six keyword and extension cases (every row except the image, front matter and manual ones) on 2026-09-20, for example Studying 24 vs Coding 13 for the M319 file. The Swift version must match. Adding Networking and IT Support rules can change these scores: re-run all of them after.

| Input | Expected |
|---|---|
| `m319-zusammenfassung.md`: "# M319 Lernziele" plus two Go code blocks | Studying |
| `fix-grub.md`: `sudo grub-install`, `/etc/default/grub` | Linux |
| `main.go` | Coding |
| `backup.sh` | Linux |
| `diagram.png` | Images |
| `einkaufsliste.md`: "Milch, Brot" | Other (**not** Personal: Personal has no rules) |
| Markdown with front matter `category: Coding` but full of Linux words | Coding |
| Document manually moved to Other, then "Re-run classification" | stays Other |
| Document manually moved to Personal, then "Re-run classification" | stays Personal |
| `m122-bash-pruefung.md`: "M122 Prüfung", several bash code blocks | Studying (confirmed by Onni 2026-09-20) |
| `m117-subnetting.md`: "M117 Lernziele", VLAN and subnet mask tables | Studying (school beats topic) |
| `vlan-trunk-cisco.md`: no school markers, VLAN, trunk, Cisco IOS commands | Networking |

The last two need the Networking rules first.

## UI

- **Library:** category chip on each row. Filter chips at the top: All, then each category with its document count. The Images category shows a thumbnail grid (`LazyVGrid`) instead of a list.
- **Move to category** in swipe actions and the context menu. Sets `categoryIsManual = true`.
- **Settings > Categories:** add, rename, reorder, pick SF Symbol and color, edit keyword rules.
- **Settings > Re-run classification:** reclassifies every document with `categoryIsManual == false`. Never touches manual ones.
- Default categories are seeded on first launch from `DefaultCategories.json`.
- **Deleting a category:** move its documents to Other explicitly, then delete. Do not rely on the `.nullify` delete rule for this.

## Open items (decide in Phase 2, before tuning)

1. **Networking rules.** Candidate vocabulary: subnet, VLAN, trunk, OSI, DHCP, DNS, routing, switch, Cisco IOS, CIDR. Overlaps Linux on `ssh`, `firewall`, `iptables`, `dns`. Write the overlap test cases before choosing weights.
2. **IT Support rules.** Candidate vocabulary: Windows, Active Directory, ticket, printer, Outlook, Intune, GPO. Overlaps both Linux and Networking. Same approach.
3. **Colors** for Networking, IT Support and Personal. Propose, then confirm with Onni.
