---
name: security-triage
description: End-to-end process for handling a Rack security report (GitHub Security Advisory) from receipt to backported release. Use when asked to triage, review, accept, describe, fix, merge, or backport a security advisory, or to review a review document for one.
---

# Security triage for Rack

This skill captures the maintainers' process for taking a security report through to a fix on every supported branch. Follow the steps in order. Releasing the result is covered by the `release` skill. When a step is unclear, ask, then update this file with the answer.

## Context

- Reports arrive as GitHub Security Advisories (GHSA) on `rack/rack`. A temporary private fork named `rack/rack-ghsa-<id>` may hold a fix PR. Often there is no fix yet and we write it.
- Find the remote that points at `rack/rack` with `git remote -v`; its name varies between checkouts (`upstream`, `origin`, or something else). Fetch it before relying on branch state. Stable branches are named `<major>-<minor>-stable`, for example `3-2-stable`, `3-1-stable`, `2-2-stable`.
- Per `SECURITY.md`, the current release series and the previous one receive fixes. Older series (for example 2.2) may still be patched by maintainer decision.
- `gh api repos/rack/rack/security-advisories` lists advisories, including those in `triage`. Use it to read the original report and to inspect past accepted descriptions for format.

## Phase 1: Review the report

1. Read the advisory description. If a fix PR exists in the private fork, read it and record the commit SHA you reviewed.
2. Reproduce the issue locally against `main` and against each candidate backport target (checkouts of the released tags, for example `v3.2.7`, `v3.1.19`, `v2.2.24`). Do not trust the reporter's version range; verify it.
3. Look for related open PRs and issues on `rack/rack` that touch the same code and note merge interactions.
4. Work in temporary copies under `/tmp`, never in the working checkout. Isolate `GEM_HOME` and `GEM_PATH` if the system gem path has incompatible native extensions.
5. Report findings in the conversation, not in a document in the checkout. Include the PR SHAs reviewed, results per version, test counts, and what was not verified.

### Duplicate reports

The same issue is often reported more than once, sometimes months apart. Search the open reports for the same component and mechanism before working on any of them.

- Choose one report as the canonical advisory. Normally this is the earliest, because the first reporter found it first. Prefer a later report when it is materially better: the reporter is engaged and responsive, it comes with a proposed fix and tests, or it describes the real scope accurately while the earlier one does not. A submitted advisory with an active author or a proposed fix is worth more than a low-effort report that arrived first. Both timing and quality matter; say which you chose and why.
- Close the others as duplicates with a short comment thanking the reporter and explaining that an earlier report covers the same issue and that they will be credited on the published advisory. Reporters cannot see each other's private advisories, so do not link them.
- Add every reporter to the credits of the canonical advisory. Carry over any reproduction, affected version, or impact detail from the duplicates that the canonical report lacks.
- Handle the set as one issue from then on: one fix, one description, one CVE, one severity.

## Phase 2: Obtain or create the fix

1. If a fix PR exists, review it for correctness. Check that it does not change behavior outside the vulnerable path and that existing limits and accounting are preserved.
2. If no fix exists, or the proposed one is inadequate, write one:
   - Keep the change minimal and local to the vulnerable code path.
   - Add regression tests that fail without the fix and pass with it. Test the reproduction shape from the report, not just the general mechanism.
   - Follow the style of previous security fixes in `git log` for the same file (commit subject, test placement, limit constants with `private_constant`).
   - When we author the fix, develop it in a temporary copy under `/tmp`, then push it to a new branch in the advisory's private fork and open a pull request there so the other maintainers can review it before it merges from the advisory page.
3. Apply the fix to a temporary copy of `main` and confirm:
   - The reproduction no longer triggers the issue.
   - New regression tests fail without the fix and pass with it.
   - The affected test file passes, then the full test suite passes. Record the counts.
4. Temporary private forks behave differently from ordinary repositories. Their pull requests target `rack/rack` `main`, the fork cannot itself be forked, and status checks do not run on them. A pull request opened by the reporter did not pick up a maintainer's later push to its branch (`git ls-remote` showed the branch had moved, but the pull request head stayed put), while a pull request opened by a maintainer did follow pushes. After pushing to an existing branch, confirm with `gh api repos/rack/<fork>/pulls/<n> --jq .head.sha` that the pull request followed. If it did not, change the pull request's base branch and back or close and reopen it, or push the history to a new branch, open a new pull request, and close the stale one. Merge private fork pull requests from the advisory page.

## Phase 3: Decide, then accept or close

First decide whether this is a security issue at all. Accepting creates a CVE, a coordinated release on every supported branch, and a public advisory, so the bar is real attacker impact.

- **Accept** when an unauthenticated or low-privilege attacker can cause a concrete confidentiality, integrity, or availability impact in a default or common configuration, and the fix is not something applications could be expected to already have in place.
- **Close and request a PR** when the report is a bug without attacker leverage: a correctness fix, a hardening suggestion, a pre-existing documented limitation, a problem only reachable with a non-default configuration the maintainers consider unsafe anyway, or a resource cost already bounded by existing limits. Close the advisory with a short note explaining the decision and asking the reporter to open a normal pull request or issue. Thank them for the report either way.
- When unsure, reproduce first, then compare against past accepted and closed advisories for the same component.

If accepting:

0. Accept the report in the GitHub advisory UI.
1. Copy the reporter's original description verbatim into a comment on the advisory so the original report is preserved.
2. Replace the description with a simplified version using the structure in `advisory-template.md`: `## Summary`, `## Details`, `## Impact`, `## Mitigation`. Match the tone and length of past accepted advisories (for example GHSA-v569-hp3g-36wr and GHSA-7mqq-6cf9-v2qp). Keep the reporter's credit. Rewrite the title at the same time: one sentence naming the mechanism and the impact, with identifiers in backticks and a full stop at the end, for example "`Rack::Static` `header_rules` bypass via URL-encoded path mismatch." Reporter titles are often long, hedged, or reference other CVEs, and the title is what appears in GHSA feeds and release notes.
3. Request a CVE from GitHub immediately after accepting. Assignment can take around three weeks, so it is not on the critical path: the fix merges and the release ships whether or not the CVE has arrived, and the advisory can be published without one. Confirm the request registered on the advisory page, since the API gives no pending state.
4. Set the credits to match published Rack advisories: the reporter as `reporter`, whoever authored the fix as `remediation_developer`, a maintainer who reviewed a reporter-authored fix as `remediation_reviewer`, and the maintainer coordinating the advisory as `coordinator`. GitHub keeps one type per login, so a person with two roles gets the higher-effort one: a reporter who also wrote the fix is credited as `remediation_developer`, and the coordinator stays `coordinator` even when they wrote the fix. Credits can be set at any point before publication, once it is known who wrote the fix.
5. Propose a severity: review the report against comparable past Rack advisories (same component and impact class), draft a CVSS 3.1 vector with a one-line justification per metric, and discuss it with the maintainer coordinating the advisory before setting it on the advisory. Denial of service in default-enabled parsing by an unauthenticated attacker has historically been rated medium or high depending on the resource exhausted and whether it is bounded.

## Phase 4: Merge to main

1. Confirm the PR targets the current `main` and CI checks pass.
2. Ensure the PR includes a changelog entry under `## Unreleased` / `### Security` in `CHANGELOG.md`, formatted exactly like existing entries:

   ```
   - [CVE-YYYY-NNNNN](https://github.com/advisories/GHSA-xxxx-xxxx-xxxx) One-sentence description of the issue.

   Use the CVE as the link text when it is assigned. Until then use the GHSA identifier, keeping the same link target.
   ```

   Do not wait for the CVE to merge. When it arrives later, update the link text in a follow-up `Update changelog.` commit on `main` and on each stable branch that carries the entry. The published advisory picks up the CVE automatically.
3. Merge the fix into `main`.

## Phase 5: Backport

1. The default targets are every series listed as supported in the `README.md` version support table (currently the latest series, the previous one, and 2.2 through April 2027). Confirm the list with the maintainers if the fix does not apply cleanly to one of them.
2. For each target, cherry-pick or re-apply the fix onto `<remote>/<series>-stable`, re-run the reproduction and the test suite on that branch, and add the changelog entry to that branch's `CHANGELOG.md` under a new patch version heading.
3. Do not assume the `main` result carries over. Older branches can have different parser code and additional problems that need separate fixes.
4. Open a PR per branch titled `Backport <subject> to <series>-stable`, then merge.
5. Changelog preparation, version bumps, tagging, and gem pushes follow the `release` skill. In particular, security entries move out of `## Unreleased` on `main` into per-series release sections before the stable branches are updated.

### Several advisories in one release

Security fixes are often batched so each supported series gets one patch release. When several advisories are in flight:

- Run Phases 1 to 3 independently for each advisory. Each keeps its own private fork, fix, description, CVE, and severity. Do not merge unrelated fixes into one pull request.
- Hold the version bump until every fix in the batch has merged to `main` and been backported to each target series. One release per series then carries all of them.
- List every advisory as a separate line under the same `### Security` heading in `CHANGELOG.md` on `main` and on each series branch.
- Set the same patched version on every advisory in the batch for a given series, then publish the advisories together once the gems are on RubyGems.
- If one fix is not ready, the release coordinator decides whether to hold the release or ship without it. Do not let a half-finished fix delay a release indefinitely.

## Phase 6: Set fixed versions and publish

1. Before publishing, set the affected products on the advisory: ecosystem RubyGems, package `rack`, one row per release series with the affected range and the patched version (for example `>= 3.2.0, < 3.2.8` patched in `3.2.8`). Include every backported series and mark unsupported older series as affected with no patched version if they are not fixed.
2. Confirm the patched versions are published to RubyGems and the changelog on each branch names them.
3. Confirm the description, credits, and severity are final. Publish whether or not the CVE has been assigned; GitHub attaches it to the published advisory when it arrives.
4. The release coordinator publishes the advisory, immediately after the patched gems are on RubyGems and together with any other advisories in the same release. There is normally no embargo; see `SECURITY.md`.

## Checklist before saying a step is done

- Every claim about a version was reproduced on that version, not inferred.
- Tests were run and the counts are recorded.
- Nothing was pushed, merged, commented, or edited on GitHub unless the user asked for that step.
