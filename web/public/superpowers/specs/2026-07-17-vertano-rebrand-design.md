# Vertano — Rebrand and Repositioning

> **Superseded in part (2026-07-17, later the same day):** Fahd decided
> the site keeps its existing court-transcript branding and its existing
> home (GitHub Pages + web app in one place); only the NAME changes.
> The in-place rename shipped in commit 9b02bc1 with vertano.app as the
> custom domain over the same Pages site. The visual-identity and
> hero-repositioning sections below did not ship and are parked; the
> app-rename inventory, migrations, and sequencing sections remain the
> plan of record for v0.3.0. Multi-page SEO expansion is welcome later,
> in the existing branding.

Date: 2026-07-17 · Status: Draft for review. Executes AFTER the
cross-platform parity PRs merge (web #27-#29, android #10-#12), so every
surface is touched exactly once.

## The decision this records

StenoDrop becomes **Vertano** (ver-TAH-no; Latin *verto*, "I turn, I
translate"; Italian-flavored phonology kept deliberately — the
Vespa/illy/Americano premium signal). `vertano.app` registered on
Cloudflare 2026-07-17. `vertano.com` is held by an apparent
surname-owner, renewed through 2034: treated as permanently
unobtainable. This is the second and final rename (VibeTranscribe →
StenoDrop → Vertano); the migration machinery built for the first one
is the template.

**This is a repositioning, not a coat of paint.** New ICP: the American
non-technical customer who pays for software. The Urdu-first,
open-source, court-transcript identity was built for a different
audience; it becomes supporting material, not the front door.

Pre-flight gate (human, two minutes): a formal search on
tmsearch.uspto.gov for "vertano" before any public surface changes.
The informal screen (web, GitHub, app stores, domain landscape) is
clean.

## Positioning

- **Hero story**: their problems, their words. Voice memos that pile
  up. Meetings and lectures they'll never re-listen to. YouTube videos
  they want as text. Drop it on Vertano, get clean text back, nothing
  leaves the machine.
- **Multilingual becomes the proof, not the headline**: "works in 100
  languages" is the trust-builder under the fold; Urdu-first stays true
  in the product and honest on the site, but the hero speaks to the
  ICP.
- **Privacy stays the moat** and gets simpler language: "your files
  never leave your computer" beats "on-device inference".
- **Visual identity**: retire the court-transcript/paper-tape/seal
  system and the stenographer persona entirely. Direction: premium
  Italian-craft minimalism — the espresso-machine aesthetic the name
  invokes. Warm neutrals, one confident accent, a wordmark-first logo
  (a "V" mark; no mascot, no bird). Type set that reads consumer, not
  terminal. The web app and site share the system.

## Pricing (examined, per the repositioning mandate)

Constraint: the site currently promises "Free", "$0, no strings", MIT,
and the seal literally says FREE. The repo stays MIT and the local
pipeline stays free — reneging would burn the existing goodwill for
nothing. The honest options for revenue, to decide separately from this
spec's execution:

1. **Free local, paid cloud**: the stenodrop-server large-model cloud
   mode becomes the paid tier (it costs real money to run; the site
   already frames it as rate-limited). Cleanest story: "free on your
   machine, forever; pay only if you want our servers' bigger model."
2. **Paid convenience distribution**: Mac App Store / Play Store listing
   at a consumer price (signed, notarized, auto-updating) while the
   GitHub build stays free. Common OSS pattern, zero promise broken.
3. **Stay free everywhere**, monetize never or later.

The rebrand does not depend on which is chosen, but the new site copy
must not repeat "free forever" louder than we mean it. Recommendation:
soften to "free on your device" (true under all three options) and
decide 1 vs 2 within a month.

## Rename inventory (the coat-of-paint layer, per platform)

**Repos** (GitHub auto-redirects old URLs — proven by
vibetranscribe→stenodrop):
`stenodrop`→`vertano`, `stenodrop-android`→`vertano-android`,
`stenodrop-server`→`vertano-server`, `stenodrop-ios`→`vertano-ios`.
Local dirs follow (`~/Code/vertano` etc.).

**Mac app**:
- Bundle id `com.fahdi.stenodrop` → `com.fahdi.vertano`, app name,
  window title, icon. CRITICAL: changing the bundle id orphans
  UserDefaults (model tier, target languages, language picker) — ship a
  one-time defaults migration reading the old domain, mirroring the
  existing `migrateLegacyModelIfNeeded` pattern.
- `~/Library/Application Support/StenoDrop/models/` →
  `.../Vertano/models/` with move-not-redownload migration (the
  VibeTranscribe precedent, now two hops deep: check both old paths).
- `~/Documents/StenoDrop/` recordings folder → `Vertano` (migrate by
  move; leave a note file behind is overkill — just move).
- make-app.sh Info.plist strings, e2e/smoke scripts, README.

**Android**:
- `applicationId` decision is NOW OR NEVER: the app is sideload-only
  (Play Store pending), so changing `com.stenodrop.android` →
  `com.vertano.android` today costs existing sideloaders a manual
  reinstall (no upgrade path across ids) but avoids being stuck with a
  dead brand's id on Play Store forever. Decision: change it, before
  the Play listing exists. In-app name, notification channel names,
  DataStore file migration (or accept settings reset for the tiny
  sideload audience — spec says: accept reset, release-note it).

**Web app + site**:
- Hosting decision (2026-07-17): vertano.app is served from Fahd's own
  server alongside his other product marketing sites, NOT GitHub Pages —
  a separate Claude session sets up DNS + vhost + TLS there (see the
  cowork handoff prompt). The Pages copy at `fahdi.github.io/stenodrop`
  stays up and redirecting during transition. Note .app is
  HSTS-preloaded: the vhost must serve valid TLS before the domain
  works in any browser.
- Full site rebuild per the Positioning section (this is the big work
  item — new hero, new sections, new visual system, new OG/social
  assets, llms.txt, sitemap, robots, structured data, favicon).
- Web app UI restyle to the new system; storage keys migrate or reset
  (localStorage is origin-bound — the domain cutover resets them
  anyway; release-note it).

**Server**: repo rename, README, container/image names, the CORS
allowed-origin list gains `https://vertano.app` (keep the github.io
origin during transition).

**Releases**: next tag is `v0.3.0` under the Vertano name with signed
zip/exe/AppImage naming `Vertano-0.3.0-*`; old StenoDrop releases stay
up untouched. Release notes lead with the rename + migration notes.

## Sequencing

1. Parity PRs land and merge (agents resume post-limit-reset).
2. USPTO human check.
3. One rebrand branch per repo: code renames + migrations + tests
   (migration paths get unit tests; the two-hop model migration
   especially).
4. Site repositioning (largest single item; new copy written for the
   ICP, no em dashes, "free on your device" framing).
5. Repo renames on GitHub (last, so in-flight PRs/issues don't break).
6. DNS cutover, v0.3.0 releases, memory/docs updated.

## Out of scope

- Choosing the pricing option (separate decision, within a month).
- vertano.com acquisition attempts (optional someday; broker outreach
  with a walk-away number).
- iOS (repo renamed, nothing else exists yet).
- Trademark *registration* (filing is a separate, optional step;
  clearance is the gate here).
