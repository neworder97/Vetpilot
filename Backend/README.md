# VetPilot accounts and scribe backend

This is backend infrastructure for the iOS app, not a website. No website has been created or deployed.

## Activation required

The IPA can record, edit transcripts and notes, create patient-specific PDFs, and use available on-device speech/translation without a cloud account. Cloud AI, Google/Apple sign-in, cloud note storage, and account deletion cannot be activated without an owner-controlled Supabase project and provider credentials. The app never claims these services are connected when configuration is absent.

1. Create a Supabase project under the app owner's account. Review its current terms, data location, retention and pricing before storing real patient/owner data.
2. Apply `supabase/migrations/202609240001_scribe.sql` using the project's migration workflow. It creates per-user note storage, atomic revision checks, and an explicit AI allowlist/quota.
3. Enable Google and Apple in Supabase Authentication. Create the required OAuth credentials in the app owner's Google Cloud and Apple Developer accounts. Set the provider callback URL to the exact callback supplied by Supabase. Allow the mobile redirect `vetpilot://auth/callback`. Apple web OAuth requires a Services ID and signing secret, with rotation managed by the owner. No provider secrets go in the IPA.
4. Deploy `vetpilot-scribe` and `vetpilot-account` from the `Backend` directory using Supabase CLI. Their gateway `verify_jwt=false` setting is intentional: both functions validate the bearer session with `/auth/v1/user` before processing any data. Never remove that identity check. Supabase's built-in service role secret is used only by the account-deletion function; the client never receives it.
5. Set the Edge Function secret `OPENAI_API_KEY`. Optional model overrides are `TRANSCRIPTION_MODEL` and `NOTE_MODEL`; defaults are `gpt-4o-mini-transcribe` and `gpt-4.1-mini`. Set provider usage budgets. Failed provider calls still consume a quota slot, preventing unlimited retries. AI access defaults to OFF for every account; explicitly enable approved testers in `scribe_ai_access`, with a daily request cap. Each 45-second transcription part consumes one request; note drafting and translation each consume one request.
6. Set GitHub Actions repository variables `VETPILOT_SUPABASE_URL` and `VETPILOT_SUPABASE_PUBLISHABLE_KEY`. Use only the publishable/anon client key, NEVER a service-role, secret, Apple, Google or AI key. The iOS workflow creates `FergusonVetPilot/VetPilotCloud.json` for the build. For a local Xcode build, create that ignored JSON with `{ "url": "https://YOUR_PROJECT.supabase.co", "publishableKey": "YOUR_PUBLIC_CLIENT_KEY" }`.
7. Run the iOS scribe workflow again, install the newly configured IPA, then validate provider sign-in, refresh, cancellation, account switching, AI transcription, translation, upload/download, conflict preservation and account deletion with synthetic records first.

The same Supabase user UUID and schema can serve a future website. Web origins are rejected unless explicitly listed in `ALLOWED_WEB_ORIGINS`; there is no wildcard CORS policy. Google and Apple may represent different accounts, especially with Hide My Email. Users should choose the same provider on each device. Account linking is not silently inferred from a pet name or an email string.

## Data boundaries

- App account tokens use iOS Keychain with this-device-only accessibility.
- Local encounters are partitioned by user UUID, with a separate guest workspace. Sign-out does not erase the account's local files. The Settings screen provides explicit local deletion.
- Audio and local notes are protected files excluded from device backup. Audio stays on-device unless the user opts into cloud transcription. Temporary transcription parts are deleted after each recording is processed.
- Note upload is explicit and includes transcript, patient identifiers and notes. Audio is not uploaded to note storage. No automatic synchronization or cloud upload occurs simply by signing in.
- Cloud data is protected by row-level access controls. Writes require an expected revision; conflicts never silently overwrite a newer remote record. Download preserves conflicting local content as a separate local copy.
- Deleting the cloud account cascades deletion of its cloud notes and usage rows. It does not erase local files or PDFs already exported/shared.
- AI requests use `store:false` for note generation. This is not a promise of zero provider retention; review current processor policies before clinical rollout. Logs must not contain clinical content, recordings, tokens or API credentials.
- My Clinic, custom medication settings, and sharing defaults remain device-local in this release. The new account sync scope is Scribe notes and transcripts.

## Validation and limits

`node --test Backend/tests/core.test.mjs` checks request bounds, patient identity, exact source evidence, history-only behavior and translations. The CI PostgreSQL tests cover unauthenticated/cross-account access, revision conflicts and quota enforcement. `deno check` verifies Edge Function types.

On-device transcription depends on iOS speech support and installed language assets; unsupported devices/languages fail visibly and preserve audio. On-device translation requires iOS 18+ and supported language pairs and does not execute in Apple's simulator. Physical-device testing must cover speech accuracy, microphone/Bluetooth changes, calls, screen lock, low storage, background audio, PDF sharing and language downloads. Software tests do not establish clinical accuracy or replace the doctor's review.

AI output and local verbatim drafting are clearly distinguished. History-only mode leaves Objective, Assessment and Plan blank. Multiple-patient statements and uncertain pronouns remain unassigned. Editing notes or source transcripts invalidates review status. Translations require their own review and are exported alongside the original source. Reviewer names are user-entered attestations, not verified electronic signatures.

No cloud credentials have been supplied or live services deployed by this implementation.
