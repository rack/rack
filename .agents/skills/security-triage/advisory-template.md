# Advisory description template

Use `##` headings. Keep each section short and concrete. Code blocks are fine in Details. This matches past accepted Rack advisories such as GHSA-v569-hp3g-36wr and GHSA-7mqq-6cf9-v2qp.

```markdown
## Summary

One or two paragraphs. Name the class or method, what the attacker sends, and what happens. End with the consequence in one sentence (for example "This results in a denial of service condition for applications that accept multipart uploads.").

## Details

How the vulnerable code behaves, with a short code excerpt if it helps. Explain why existing limits do not apply. Mention which versions are affected and why, if the mechanism differs between versions.

## Impact

Who is affected (default configuration or opt-in middleware). What an unauthenticated attacker can achieve. What is not required (authentication, invalid syntax, large payloads, and so on).

## Mitigation

* Update to a patched version of Rack in which <one-line description of the fix>.
* <Configuration or deployment workaround, if any.>
* <Reverse proxy or application boundary mitigation, if any.>
```

Before replacing the reporter's description, paste the original verbatim into an advisory comment so it is preserved.
