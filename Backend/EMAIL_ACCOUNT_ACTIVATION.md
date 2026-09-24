# Email accounts — activation required

Both clients use the same Supabase Auth email/password signup and token endpoints and the existing user-scoped note schema. No Google or Apple provider setup is needed for this flow.

Enable email/password auth and email confirmation; set the Site URL to the VetPilot website. Configure production SMTP for confirmation delivery, Auth rate limits and password requirements. New client signups require 12 characters; enforce this server-side too. Deploy the existing migrations and functions. Configure the same project URL and publishable key in website runtime and the iOS build. Private/service-role keys never belong in clients.

Signup without a session displays a confirmation message; email confirmation is not bypassed. After confirming, users sign in on either platform. Scribe is account-only; existing guest data is retained, not silently uploaded to an account. Public reference tools remain available.

Scribe notes sync on open, every 60 seconds while active, after transcription, and on return to foreground. Device background scheduling cannot guarantee minute-by-minute syncing. Audio, My Clinic and medication settings are still local; expanding cloud storage for these remains separate unfinished work. Account recovery UI remains to be implemented before general release.

Website typecheck and mocked email endpoint tests passed. Live signup, confirmation delivery, cross-device sync and native compilation have not been verified for this change. Configure services and run two-user isolation and conflict tests before releasing a configured IPA.
