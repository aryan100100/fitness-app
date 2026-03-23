# AUTH_SETUP.md — Authentication Setup Guide

This document covers all manual steps required to enable Google Sign In and Apple Sign In in the fitness app. These steps cannot be done in code — they require external dashboard/portal configuration.

---

## 1. Supabase Dashboard

### Run SQL Migration
1. Go to **Supabase Dashboard → SQL Editor**
2. Open and run `supabase_migration_auth.sql` (in the project root)
3. This sets up correct RLS policies for authenticated users

### Enable Google Provider
1. Go to **Authentication → Providers → Google**
2. Toggle **Enable**
3. Paste your **Google Client ID** (from step 2 below)
4. Paste your **Google Client Secret** (from step 2 below)
5. Click **Save**

### Enable Apple Provider
1. Go to **Authentication → Providers → Apple**
2. Toggle **Enable**
3. Paste your Apple **Service ID**, **Team ID**, **Key ID**, and **Private Key** (from step 4 below)
4. Click **Save**

### Configure Redirect URL
1. Go to **Authentication → URL Configuration**
2. Under **Redirect URLs**, add:
   ```
   com.yourapp.fitness://login-callback
   ```
   Replace `com.yourapp.fitness` with your actual bundle ID.
3. Also add:
   ```
   https://YOUR_SUPABASE_PROJECT_REF.supabase.co/auth/v1/callback
   ```

---

## 2. Google Cloud Console (for Google Sign In)

1. Go to [console.cloud.google.com](https://console.cloud.google.com)
2. Create or select your project
3. Go to **APIs & Services → Credentials**
4. Click **Create Credentials → OAuth 2.0 Client ID**
5. Set **Application type** to **iOS**
6. Enter your **Bundle ID** (e.g. `com.yourapp.fitness`)
7. Click **Create**
8. Copy the **Client ID** — paste it into:
   - Supabase Dashboard (step 1 above)
   - `ios/Runner/Info.plist` as the URL scheme (see step 5 below)
9. Also create a **Web** client ID (needed for Supabase OAuth token exchange):
   - Set **Application type** to **Web application**
   - Copy the **Client ID** and **Client Secret** for Supabase

> ⚠️ The iOS client ID goes in Info.plist. The Web client ID + Secret go in the Supabase dashboard.

---

## 3. iOS Info.plist Update

In `ios/Runner/Info.plist`, replace `YOUR_GOOGLE_CLIENT_ID` with your real reversed iOS client ID:

```xml
<key>CFBundleURLTypes</key>
<array>
  <dict>
    <key>CFBundleTypeRole</key>
    <string>Editor</string>
    <key>CFBundleURLSchemes</key>
    <array>
      <string>com.googleusercontent.apps.YOUR_IOS_GOOGLE_CLIENT_ID</string>
    </array>
  </dict>
</array>
```

The reversed client ID format looks like:
`com.googleusercontent.apps.1234567890-abcdefghijklmnop`

---

## 4. Apple Developer Portal (for Sign In with Apple)

1. Go to [developer.apple.com](https://developer.apple.com)
2. Go to **Certificates, Identifiers & Profiles → Identifiers**
3. Select your App ID and enable **Sign In with Apple** capability
4. Create a **Services ID**:
   - Enable **Sign In with Apple**
   - Set domain to your Supabase project URL
   - Set return URL to `https://YOUR_PROJECT.supabase.co/auth/v1/callback`
5. Create a **Key**:
   - Enable **Sign In with Apple**
   - Download the `.p8` private key file (you can only download it once)
6. Paste **Services ID**, **Team ID**, **Key ID**, and contents of `.p8` file into the Supabase Apple provider settings

---

## 5. Xcode — Sign In with Apple Capability

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the **Runner** target
3. Go to **Signing & Capabilities**
4. Click **+ Capability**
5. Search for and add **Sign In with Apple**
6. Ensure your provisioning profile has this capability enabled

---

## 6. Disable Anonymous Auth (Supabase)

After deploying this update, anonymous auth can optionally be disabled:
1. Go to **Authentication → Providers → Anonymous**
2. Toggle **Disable** (only after all users have migrated or are new users)

> ⚠️ If anonymous auth was previously used, keep it enabled until confirmed that all sessions are migrated.

---

## Checklist

- [ ] SQL migration run in Supabase
- [ ] Google provider enabled in Supabase (Web Client ID + Secret)  
- [ ] Apple provider enabled in Supabase
- [ ] Redirect URL configured in Supabase
- [ ] Google Cloud Console — iOS OAuth client created
- [ ] Google Cloud Console — Web OAuth client created  
- [ ] `ios/Runner/Info.plist` URL scheme updated with reversed iOS client ID
- [ ] Apple Developer — Services ID created with return URL
- [ ] Apple Developer — Key created, `.p8` file saved securely
- [ ] Xcode — Sign In with Apple capability added
