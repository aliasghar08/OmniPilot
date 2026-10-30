# Google Play Console Listing & Data Safety Guide for OmniPilot

This guide contains all copy-paste assets, store metadata, App Content declarations, Accessibility Service justifications, and Data Safety questionnaires required by the **Google Play Console** for **OmniPilot** (`com.dartnexuslab.omnipilot`).

---

## 1. Store Listing Details

### App Name
```text
OmniPilot: AI Form Assistant
```
*(30 characters max)*

### Short Description
```text
Universal Android cross-app AI copilot, Google search & smart form autofill.
```
*(75 of 80 characters)*

### Full Description
```text
OmniPilot is your universal Android Cross-App AI Copilot and Smart Attendance Automation Engine, powered by Gemini 2.0 Flash and Live Google Search Grounding.

Unlike standard chatbots restricted to their own screen, OmniPilot operates across your entire device using Android Accessibility and an Interactive Floating AI Overlay:

🌟 KEY CAPABILITIES:

1. 🌐 LIVE GOOGLE SEARCH & KNOWLEDGE ENGINE:
Ask any question regarding science, technology, current events, or coding. OmniPilot combines Gemini Google Search Grounding with live web indexes (Wikipedia, Google News) to synthesize grounded, source-cited insights.

2. 📝 RESEARCH & DIRECT APP WRITING:
Command OmniPilot to research any subject on Google and automatically write structured, verified notes into external note-taking apps like Fossify Notes, Google Keep, or Docs.

3. 📋 COMPLEX PERIOD ATTENDANCE & COMPLIANCE:
Manage multi-week, monthly, and full-semester attendance records with dropdowns, custom date ranges, attendance counts, radio button standings (Good Standing, Probation Warning, Shortage, Medical Exemption), compliance flags, and participation scores—synchronized in real time with Cloud Firestore.

4. 🤖 UNIVERSAL CROSS-APP AUTOMATION:
Use the floating HUD to inspect active screen inputs, verify existing writes, fill external forms, and trigger system actions without switching away from your current workflow.

5. 🛡️ PRIVACY FIRST & SECURE:
OmniPilot operates strictly with user consent. Password and secure input fields are never recorded, and no screen data is sold or shared with advertisers.

Transform your daily administrative workflow with OmniPilot today!
```

---

## 2. App Category & Contact Details

- **App Category:** Productivity / Education
- **Tags:** Productivity, Tools, Education, Artificial Intelligence, Automation
- **Email:** `aliasgharinnocent@yahoo.com`
- **Privacy Policy URL:**  
  `https://raw.githubusercontent.com/aliasghar08/OmniPilot/main/PRIVACY_POLICY.md`  
  *(or your GitHub Pages / custom website URL)*

---

## 3. App Content & Policy Declarations

### A. Privacy Policy
- Provide URL: `https://raw.githubusercontent.com/aliasghar08/OmniPilot/main/PRIVACY_POLICY.md`

### B. Ads
- Select: **"No, my app does not contain ads."**

### C. App Access
- Select: **"All functionality is available without special access"** (or provide test credentials if authentication is required for Firestore evaluator runs).

### D. Content Ratings (IARC Questionnaire)
- Category: **Utility, Productivity, Communication, or other**
- Violence / Sexual Material / Offensive Language: **No**
- Shares user's current physical location: **No**
- Digital purchases: **No**
- Expected Rating: **Everyone / PEGI 3**

### E. Target Audience and Content
- Target age group: **18 and over** (or 13-17, 18 and over)
- Could your store listing appeal to children? **No**

### F. Financial Features
- Select: **"My app doesn't provide any financial features."**

---

## 4. Accessibility Service Policy Declaration (`BIND_ACCESSIBILITY_SERVICE`)

Google Play requires a dedicated declaration and video demonstration for apps requesting `AccessibilityService`:

### Question 1: What is the primary purpose of the Accessibility Service in your app?
**Copy-paste response:**
```text
OmniPilot uses the Accessibility Service API (AttendanceAccessibilityService) to assist educators and professionals with assistive form-filling and cross-app text entry. Specifically, the service inspects visible input fields (android.widget.EditText) and populates repetitive academic period attendance evaluations, student identity counts, and structured notes into third-party educational and note-taking apps upon the user's explicit request.
```

### Question 2: Is the Accessibility Service used for any tool or feature not visible to the user?
**Select:** **No**

### Question 3: How does the app inform the user before requesting the permission?
**Copy-paste response:**
```text
The app provides a prominent in-app disclosure on the 'Cross-App AI' screen prior to redirecting the user to system settings. It explicitly details what permissions are requested, explains that the service only reads and writes editable form fields when triggered by the user via the floating overlay, and assures that password fields and personal credentials are never collected or transmitted.
```

---

## 5. Data Safety Form Responses

When completing the **Data Safety** section in the Google Play Console:

| Data Type | Collected? | Shared? | Purpose | Ephemeral? |
|-----------|------------|---------|---------|------------|
| **Name** (Student / User Name) | Yes | No | App functionality (Attendance records) | No (Stored in Firestore) |
| **User IDs** (Roll Number / Demo ID) | Yes | No | App functionality | No |
| **App Interactions** (Button clicks, form fills) | Yes | No | App functionality & analytics | Yes |
| **Crash logs & Diagnostics** | Yes | No | Analytics & Performance (Firebase) | No |
| **Location** | No | No | N/A | N/A |
| **Photos / Videos** | No | No | N/A | N/A |
| **Audio / Voice Recordings** | No | No | N/A | N/A |
| **Health & Fitness** | No | No | N/A | N/A |
| **Financial Info** | No | No | N/A | N/A |

### Security Practices
- **Data Encrypted in Transit?** Yes (All cloud communication uses HTTPS / TLS).
- **Can users request data deletion?** Yes (Users can email `aliasgharinnocent@yahoo.com` to request complete record deletion).

