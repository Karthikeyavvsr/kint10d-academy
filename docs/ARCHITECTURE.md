# Architecture and decisions

## Records and isolation
The server derives the owner from trusted hosting identity. Every SELECT and UPDATE scopes by owner; inserts use the same identity. Clients cannot choose an owner. Records are keyed by owner and record key, with a string value, revision and timestamp.

## Conflict handling
First writes use INSERT OR IGNORE at revision 1. Later writes update only if the stored revision equals the client revision. A mismatch returns 409. Device drafts remain available for export, cloud reload and explicit recovery.

This is per-record concurrency, not collaborative editing. Conflicting notes require a human decision. A lost response after a successful write may produce a conflict on retry; reconcile rather than blindly replay.

## Privacy boundaries
The service worker does not cache authenticated pages. Device draft keys include the authenticated user ID. Exports are ordinary files. Hosting must establish trusted identity and control the identity headers; do not substitute unverified public request headers.

## Learning evidence
Opened, read, quiz correctness and self-reported recall are different records. Successful recall doubles the review interval, capped at 30 days; a miss schedules tomorrow. Capstone submission is self-reported, not independent review.

## Tradeoffs
One responsive reader avoids parallel native implementations. D1 provides durable relational storage. Versioned JSON makes content reviewable. Deterministic visual labs need no GPU, external inference or broker data. Calendar export offers reminders without falsely claiming a background push service.

## Test boundaries
Local browser tests use the starter's loopback-only mock identity. A separate browser context simulates another device. Tests do not cover real hosted OAuth, a physical phone, background push delivery or an independent penetration test.
