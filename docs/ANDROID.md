# Android beta build

Capacitor packages the frontend locally and connects to the same Supabase database as the web release. Email verification and password recovery links open https://farmstead-psi.vercel.app/. Configure that origin in Supabase Auth first.

Requirements: Node 22+, JDK 21, Android SDK platform 36 and build tools 36.0.0. The SDK license must be accepted by the project owner before installing SDK packages.

1. Install dependencies with `npm ci`.
2. Set the two public VITE Supabase variables from `.env.example` in `.env.local`.
3. Run `npm run build` and `node scripts/prepare-android.mjs`.
4. Set `ANDROID_HOME` or create `android/local.properties` for the installed SDK.
5. Run `cd android && ./gradlew assembleRelease`.
6. Sign the unsigned release APK with a privately retained release key using Android's apksigner. Never commit the key/password. Keep a private backup for future updates.

No APK has been compiled or signed yet. End-to-end account creation, email delivery, shared farm use, and testing on a physical Android device remain release acceptance steps. This is not a Play Store release.
