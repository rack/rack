---
name: release
description: How Rack patch releases are cut from the stable branches, including moving changelog entries out of Unreleased on main, backporting them, bumping versions, tagging, pushing gems, and publishing the matching security advisories. Use when asked to release, cut a patch version, prepare a release changelog, or publish advisories after a security fix.
---

# Releasing Rack

This skill captures the maintainers' process for shipping patch releases, usually one per supported series carrying a batch of security fixes. It picks up where the `security-triage` skill leaves off (fixes merged to `main` with changelog entries under `## Unreleased`) and ends with gems on RubyGems and advisories published. Follow the phases in order; the order matters because advisories must not go public before the gems exist.

## Context

- Releases are cut from the stable branches, never from `main`. Branches are named `<major>-<minor>-stable`, for example `3-2-stable`, `3-1-stable`, `2-2-stable`. `main` is unreleased development and its version constant is not what ships.
- Per `SECURITY.md` and the version support table in `README.md`, the current series receives bug fixes and security patches, the previous series receives security patches only, and 2.2 receives security patches through April 2027. Confirm the list against the README at release time rather than assuming.
- Find the remote that points at `rack/rack` with `git remote -v`; its name varies between checkouts. Fetch `main`, every stable branch, and tags before starting.
- The version constant differs per branch. On `3-2-stable`, `lib/rack/version.rb` has `VERSION = "3.2.x"` and `RELEASE = VERSION`. On `3-1-stable` and `2-2-stable`, `RELEASE = "3.1.x"` is the release version and `VERSION` is the Rack protocol version. Bump the constant that holds the gem version.
- Releases use the Bundler gem tasks (`rake release`), which build the gem, create an annotated tag `vX.Y.Z` with the message `Version X.Y.Z`, push the tag, and push the gem to RubyGems. The `officialrelease` task in `Rakefile` is legacy and unused. Past tags all point at a commit titled `Bump patch version.`.
- GitHub Releases are created for some tags and not others. They are optional and not part of this process unless a maintainer asks.

## Changelog model

`CHANGELOG.md` follows Keep A Changelog. Release headings have the form `## [3.2.7] - 2026-08-13`. Security entries have the form:

```markdown
### Security

- [CVE-YYYY-NNNNN](https://github.com/advisories/GHSA-xxxx-xxxx-xxxx) One-sentence description of the issue.
```

Use the CVE as the link text when it is assigned and the GHSA identifier otherwise, with the same link target either way. CVE assignment can take weeks and does not hold the release. When a CVE arrives after the entry has shipped, update the link text on `main` and on each stable branch that carries the entry.

The file on `main` is the master copy and holds every series. Sections are grouped by series in descending order: all `3.2.x` sections, then the `3.1.x` block, then the `2.2.x` block, and so on. A new `3.1.x` section goes at the top of the `3.1.x` block, not at the top of the file.

Each stable branch carries its own copy. `3-2-stable` mirrors `main` and includes the `3.1.x` and `2.2.x` sections. `3-1-stable` and `2-2-stable` contain only their own series. Keep these copies consistent with `main`; when they drift, `main` wins and the stable branch is corrected.

Security entries are written under `## Unreleased` on `main` when the fix merges. They do not stay there. At release time they move into the release section for each series that ships them, which is what Phase 1 does. Past releases that skipped this step needed a follow-up commit titled `Copy missing ... entries to changelog`, so do not skip it.

## Phase 1: Prepare the changelog on main

1. Confirm every fix in the batch has merged to `main` and has its entry under `## Unreleased`, each linking its CVE or, if not yet assigned, its GHSA identifier. Confirm there is nothing else waiting that the release coordinator wants in the same release.
2. Choose the next patch version for each series being released, for example `3.2.8`, `3.1.23`, `2.2.25`, and the release date.
3. On a branch from `main`, edit `CHANGELOG.md`:
   - Add a `## [X.Y.Z] - YYYY-MM-DD` section at the top of each series block being released.
   - Move the `### Security` entries from `## Unreleased` into each new section. Only include an entry in a series it actually fixes; a fix that does not apply to 2.2, or that was not backported there, is omitted from the 2.2 section.
   - Move any non-security `### Fixed` entries that are also being backported to the latest series into its section. Entries for changes that only exist on `main` stay under `## Unreleased`.
   - Remove the `### Security` heading from `## Unreleased` if it is now empty.
4. Commit as `Update changelog.` and land it on `main` by pull request unless the release coordinator says to push directly. This commit is the source for every stable branch in Phase 2.

## Phase 2: Backport to each stable branch

Work on one stable branch at a time, oldest series first, so the oldest release can go out while newer ones are still in CI.

1. Branch from `<remote>/<series>-stable`.
2. Cherry-pick the fix commits from `main`. Keep the original subjects; past backports do not carry a `cherry picked from` trailer. When a cherry-pick does not apply cleanly, re-implement against that branch's code, note the upstream commit in the message, and keep the regression tests.
3. Apply the changelog from Phase 1 to this branch's copy:
   - On the latest series branch, bring the whole set of new sections across so it keeps mirroring `main`.
   - On older series branches, add only that series' new section.
   - If the branch has its own `## Unreleased` entries (for example a bug fix backported earlier and not yet released), move them into the new release section too.
4. Run the reproduction for each security fix on this branch, then the affected spec files, then the full suite. The stable branches still test on Ruby 2.4 through 4.0, so expect older-Ruby compatibility breaks that `main` does not have and fix them in a separate commit.
5. Open a pull request against `<series>-stable` titled `Backport <subject> to <series>-stable` and wait for CI. Do not tag from a red branch.
6. Older branches can have different code and additional problems that need separate fixes. Do not assume the `main` result carries over; 2.2's multipart parser in particular differs from 3.x.

### Several advisories in one release

Each advisory keeps its own fix commits and changelog line, but the release is shared. Hold the version bump until every fix in the batch has merged to `main` and been backported to each target series. If one fix is not ready, the release coordinator decides whether to hold the release or ship without it, and adjust the changelog sections and advisory fixed versions to match what actually ships.

## Phase 3: Bump, tag, and push

For each series, oldest first (`2-2-stable`, then `3-1-stable`, then `3-2-stable`), once its backport has merged and CI is green:

1. On a clean checkout of the stable branch, set the release version in `lib/rack/version.rb` and confirm the changelog heading carries the same version and today's date.
2. Commit as `Bump patch version.` and push to the stable branch.
3. Run `rake release` from that checkout. Confirm the tag `vX.Y.Z` exists on the remote and points at the bump commit, and that `gem fetch rack -v X.Y.Z` succeeds.
4. Move to the next series.

The release coordinator runs the pushes to RubyGems. Prepare the branches and the commands, and report the state of each series, rather than pushing gems yourself unless told to.

## Phase 4: Set fixed versions and publish advisories

Do this only after every gem in the batch is on RubyGems.

1. On each advisory, set the affected products: ecosystem RubyGems, package `rack`, one row per series with the vulnerable range and patched version. Follow the shape of past published advisories, for example `< 2.2.25` patched in `2.2.25`, `>= 3.0, < 3.1.23` patched in `3.1.23`, `>= 3.2, < 3.2.8` patched in `3.2.8`. A series that is unsupported and not fixed is listed as affected with no patched version.
2. Confirm the description, severity, and credits are final. Do not wait for the CVE; GitHub attaches it to the published advisory when assigned.
3. Publish every advisory in the batch together, immediately after the gems are available, as `SECURITY.md` promises. The release coordinator publishes; prepare the advisories so publishing is one click each.
4. If a fix is backported to a further series later, update that advisory's affected products afterward so the new patched version is recorded. Published advisories can still be edited.

## Phase 5: After the release

- Check that `main` already contains the release sections from Phase 1. If anything changed on a stable branch during Phase 2 (a date, a wording fix, an extra entry), copy the change to `main` so the master copy stays correct.
- Update the version support table and the release notes paragraphs in `README.md` on `main` when a series changes support status or an end-of-support date is announced.
- Clean up temporary worktrees and leave every checkout on the branch it started on.

## Minor and major releases

A new minor or major version starts with a new stable branch, cut before anything is bumped or tagged. (Earlier minors such as 3.1.0 and 3.2.0 were tagged on `main` and branched afterwards; going forward, cut the branch first.)

1. Confirm with the release coordinator that `main` is at the intended cut point and that nothing else is waiting for the release.
2. Create `<major>-<minor>-stable` from `main` and push it to `rack/rack`, for example `git branch 3-3-stable <remote>/main && git push <remote> 3-3-stable`. `main` continues as development for the following version.
3. On the new stable branch, turn `## Unreleased` into `## [X.Y.0] - YYYY-MM-DD`, set the version in `lib/rack/version.rb`, commit as `Bump minor version.` or `Bump major version.`, wait for CI, then run `rake release` as in Phase 3.
4. On `main`, add the same `## [X.Y.0]` section below `## Unreleased` so the master changelog records the release, and leave `## Unreleased` empty for new work. The new branch already mirrors `main`, including the older series blocks.
5. Update `README.md` on `main`: the new series becomes the one receiving bug fixes and security patches, the previous series moves to security patches only, and the series that drops out of support gets an end-of-support entry. Update the per-series paragraphs under the change log heading to match. Backport the README change to the new stable branch.
6. Later patch releases for the new series follow Phases 1 to 5 like any other.

## Checklist before saying a step is done

- Every version mentioned exists on the remote as a tag and on RubyGems, checked, not inferred.
- Each stable branch's test suite was run and the counts are recorded.
- The changelog on `main` and on each released branch agrees on versions, dates, and entries.
- No advisory was published before its patched gems were available.
