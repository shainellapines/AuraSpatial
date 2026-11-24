# Connecting AuraSpatial to Firebase (on a Mac)

Follow the steps **in order**. Each one ends with a **✅ Check** that tells you what you should see. Don't move on until the check matches.

You'll use two windows side by side:

- **Xcode**, with your AuraSpatial project open
- **Safari or Chrome**, at **https://console.firebase.google.com**, signed in with the Google account that owns the **AuraSpatial** project

Already done (from the lab): the Firebase project `auraspatial-13d74` exists, and the iOS app `mseuf.edu.ph.AuraSpatial` is registered.

---

## Step 1: Make sure Xcode has the newest code

The Firebase code is only in the **latest** AuraSpatial zip. If your project is older, adding Firebase won't change anything.

1. In Xcode's left panel (the **Project navigator**, ⌘1), open **AuraSpatial > AuraSpatial > Repositories**.
2. Look for these three files:
   - `Backend`
   - `FirebaseAuthStore`
   - `FirestoreStores`

**✅ Check:** all three are there. Skip to Step 2.

**If they're missing:**
1. Quit Xcode (⌘Q).
2. Unzip the latest `AuraSpatial-Updated.zip` (double-click it in Finder).
3. In Finder, open your project folder. Replace its inner **AuraSpatial** folder (the one that contains App, Audio, Controllers…) with the one from the zip.
   > Don't replace `AuraSpatial.xcodeproj`. If your plist file is in the old folder, copy it out first and put it back afterwards.
4. Open the project again and redo the check.

---

## Step 2: Turn on Email/Password sign-in (browser)

1. In the Firebase console, click the **AuraSpatial** project.
2. In the left menu, click **Security**, then **Authentication**.
3. If you see **Get started**, click it.
4. Click the **Sign-in method** tab at the top.
5. Click **Email/Password**.
6. Turn on the **first** switch only (**Email/Password**). Leave "Email link (passwordless sign-in)" **off**.
7. Click **Save**.

**✅ Check:** the list shows **Email/Password · Enabled**.

---

## Step 3: Create the database (browser)

1. In the left menu, click **Databases and storage**, then **Firestore** (under **NoSQL**).
   > Not *Realtime Database* and not *SQL Connect*.
2. Click **Create database**.
3. If it asks for an edition: **Standard edition** → **Next**.
4. Database ID: leave it as `(default)`.
5. Location: **asia-southeast1 (Singapore)** → **Next**.
   > ⚠️ This can't be changed later, so double-check it.
6. Choose **Start in production mode** → **Create**.

**✅ Check:** you're on the **Data** tab and the database is empty. That's correct; the app fills it.

*Already created the database before? Skip to Step 4.*

---

## Step 4: Paste the security rules (Xcode → browser)

The rules make sure each user can only see their own layouts.

1. In **Finder**, open your project folder, then the **Firebase** folder inside it (next to `AuraSpatial.xcodeproj`).
2. Right-click **firestore.rules** → **Open With** → **TextEdit**.
3. Select all (**⌘A**) and copy (**⌘C**).
4. In the browser, on the Firestore page, click the **Rules** tab.
5. Click inside the editor, select all (**⌘A**), and press **Delete**.
6. Paste (**⌘V**).
7. Click **Publish**.

**✅ Check:** "Rules published" appears, and the first line is `rules_version = '2';`.

> Red error in the editor? Part of the text was missed. Clear it and paste the whole file again.

---

## Step 5: Add the Firebase package (Xcode)

1. In the top menu bar: **File** > **Add Package Dependencies…**
2. A window opens. Click the search field at the **top-right corner** of that window, paste this, and press **Return**:

   ```
   https://github.com/firebase/firebase-ios-sdk
   ```

3. Click **firebase-ios-sdk** when it appears in the list.
4. On the right side, check these two settings:
   - **Dependency Rule:** Up to Next Major Version (keep the number as it is)
   - **Add to Project:** AuraSpatial
5. Click **Add Package** (bottom right).
6. **Wait.** Xcode downloads Firebase, which can take 2–5 minutes. Don't click anything while it's working.
7. A second window lists Firebase products. Each row has a menu on the right called **Add to Target**, set to **None**. Change exactly these three to **AuraSpatial**:
   - **FirebaseAuth**
   - **FirebaseCore**
   - **FirebaseFirestore**

   The list is alphabetical, so scroll down to the "Firebase…" names. Leave all the others on **None**.
8. Click **Add Package**.

**✅ Check:** at the very bottom of Xcode's left panel there's a new section, **Package Dependencies**, with **firebase-ios-sdk** inside it.

> Stuck or failed? **File > Packages > Reset Package Caches**, then repeat this step.

---

## Step 6: Check the plist file (Xcode)

The app only finds the Firebase settings if this file has the exact right name.

1. In the left panel, find the plist inside the **AuraSpatial** folder (next to App, Audio, Views). Its icon looks like a small table.
2. Click it once.
3. Open the right panel's **File inspector**: press **⌥⌘1** (Option + Command + 1).
4. Check:
   - **Name** says exactly **`GoogleService-Info.plist`**
   - Under **Target Membership**, **AuraSpatial** is ticked

**✅ Check:** both are right, and there's only **one** GoogleService file in the whole project.

**To fix the name:** click the file in the left panel, press **Return**, type `GoogleService-Info`, press **Return**.

**If the file is missing:** in the browser, click the **gear icon** (top left) > **Project settings** > scroll to **Your apps** > download **GoogleService-Info.plist**. In Finder, check that the downloaded file is named exactly `GoogleService-Info.plist` (rename it if it says "(1)"). Drag it onto the **AuraSpatial** folder in Xcode's left panel, tick **Copy items if needed** and the **AuraSpatial** target, then click **Finish**.

---

## Step 7: Build and run (Xcode)

1. At the top of Xcode, pick a simulator, for example **iPhone 17 Pro**.
2. **Product** > **Clean Build Folder** (**⇧⌘K**, Shift + Command + K).
3. **Product** > **Run** (**⌘R**).

The first build with Firebase is slow (several minutes). That's normal.

**✅ Check:** the app opens on the Welcome screen.

---

## Step 8: Test the connection

1. In the app, tap **Sign Up** and create a **new** account.
   > Old accounts were saved only on the device, so they don't exist in Firebase.
2. Open the **Profile** tab and scroll to **About**.

   **✅ Check:** **Database** says **Firebase Auth · Firestore**.

3. Go to **Canvas**, add 2–3 sounds, tap **•••** (top right) > **Save as Layout**, give it a name, then tap **Save**.
4. In the browser:
   - **Security > Authentication > Users:** your email is listed.
   - **Databases and storage > Firestore > Data:** open `users` → (a long ID) → `layouts`. Your layout is there.

**✅ Check:** both show up. **Firebase is connected.** 🎉

Optional: in **Saved Layouts**, tap **•••** on a layout > **Share to Community**. It appears in the **Community** tab and in Firestore under `community`.

---

## If something goes wrong

| What you see | What to do |
| --- | --- |
| About still says **On-device (JSON)** | Redo Step 6 (name and target), check Step 5's **Package Dependencies**, then Clean Build Folder (⇧⌘K) and run again. |
| Build errors mentioning **Firebase** | **File > Packages > Reset Package Caches**, then Clean Build Folder and run. |
| "Cannot find Backend in scope" | Your code is old. Redo Step 1. |
| **"Firebase blocked this request…"** | Rules weren't published. Redo Step 4. |
| **"The email or password is incorrect"** | You're using an old account. Sign up with a new one. |
| Sign Up fails mentioning sign-in method | Email/Password is off. Redo Step 2. |
| Firestore **Data** tab is empty | Save a layout while signed in, then click refresh in the browser. |
| **Delete Account** asks you to log in again | Log out, log in, then delete right away. Firebase requires a fresh login for this. |

---

### Good to know

- **What's stored where:** accounts in Firebase Authentication (the app never stores the password); profiles at `users/{uid}`; saved layouts at `users/{uid}/layouts`; shared posts, likes, and forks at `community`. Settings and listening stats stay on the phone.
- **Offline:** saving still works without internet and syncs later.
- **Old layouts:** layouts saved on the device before Firebase are uploaded to your account the first time you open Saved Layouts.
- **API key in the plist:** it's safe to keep it in the project and on GitHub. It only identifies your Firebase project; your data is protected by the rules from Step 4.
