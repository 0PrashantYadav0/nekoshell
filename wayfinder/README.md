# Wayfinder map (local markdown tracker)

No issue tracker is configured for this repo, so the map lives here as markdown.

- `MAP.md` is the map (label `wayfinder:map`). It is an index, never a store.
- `tickets/NNNN-slug.md` are the child tickets. Frontmatter carries the tracker fields.
- A ticket is **claimed** when `assignee` is non-empty. Claim before doing any work.
- A ticket is **blocked** while any id in `blocked_by` is still `status: open`.
- The **frontier** is every ticket that is open, unassigned and unblocked.
- Resolve a ticket by appending `## Resolution`, setting `status: closed`, and adding one line to `MAP.md` under "Decisions so far".
- Never resolve more than one non-research ticket per session.
