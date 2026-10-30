# Privacy Policy for OmniPilot

**Effective Date:** October 30, 2026  
**Last Updated:** October 30, 2026  
**Developer / Organization:** DartNexusLab ([Ali Asghar](mailto:aliasgharinnocent@yahoo.com))  
**Application ID:** `com.dartnexuslab.omnipilot`  
**Contact Email:** [aliasgharinnocent@yahoo.com](mailto:aliasgharinnocent@yahoo.com)

---

## 1. Introduction

**OmniPilot** ("we", "our", or "the App"), developed by **DartNexusLab**, respects and values your privacy. This Privacy Policy explains how information is handled when you use the OmniPilot mobile application, including our use of Android system permissions, on-device automation capabilities, and cloud services.

By installing or using OmniPilot, you agree to the collection and use of information in accordance with this policy.

---

## 2. Information We Collect and Process

### A. Information Stored Locally and in Cloud Firestore
- **Period Attendance & Academic Data:** When you save student attendance records, data such as student name, roll number, academic period, attendance breakdown (present days, leaves, unexcused absences, late arrivals), evaluation standing, and faculty remarks are processed and synchronized with **Google Cloud Firestore**.
- **Licensing & Device Status:** A demo licensing verification record is maintained in Firestore (`licensing/demo_status`) to manage authorized evaluation runs.

### B. User Prompts and Inquiries
- Natural language voice or text prompts provided to the in-app assistant are processed using **Firebase AI Logic (Gemini 2.0 Flash)** to understand form-filling instructions, execute search queries, and coordinate automation actions.
- General knowledge search queries may query publicly available web indexes (Google Search Grounding, Google News RSS, Wikipedia) to synthesize answers for you.

### C. Information We DO NOT Collect
- **Passwords or Sensitive Credentials:** OmniPilot strictly ignores password and secure input fields during screen inspection.
- **Personal Financial Information:** No credit card, banking, or biometric data is collected or requested.
- **Background Keylogging:** The App does not monitor, record, or track keystrokes outside of active assistant command executions initiated by you.

---

## 3. Android System Permissions & Declarations

To perform cross-app assistant automation and period record assistance, OmniPilot requests specific high-level Android system permissions. In strict accordance with Google Play Developer Program Policies:

### A. Accessibility Service (`BIND_ACCESSIBILITY_SERVICE`)
- **Purpose:** OmniPilot uses Android's `AccessibilityService` API exclusively to assist users in reading visible form fields (`android.widget.EditText`), inspecting screen elements, and autofilling student attendance forms and structured notes into third-party applications when requested by the user.
- **User Control:** The Accessibility Service is only activated after explicit user opt-in in Android Settings. Users can disable the service at any time in Android Settings > Accessibility > OmniPilot.
- **Privacy Assurance:** The Accessibility Service does not alter user settings without permission, does not prevent users from disabling any service, does not work around built-in privacy controls, and does not record or transmit audio, personal phone calls, or screen content to third-party advertisers.

### B. Display Over Other Apps (`SYSTEM_ALERT_WINDOW`)
- **Purpose:** Enables the interactive Floating AI Overlay bubble and heads-up HUD so users can trigger OmniPilot actions while viewing external forms or note-taking apps.
- **User Control:** Granted explicitly via the Android "Display over other apps" settings toggle.

### C. Foreground Service (`FOREGROUND_SERVICE` & `FOREGROUND_SERVICE_SPECIAL_USE`)
- **Purpose:** Keeps the draggable floating bubble active while the user interacts with external apps. A persistent notification is displayed in the notification drawer whenever this foreground service is active, ensuring complete user awareness.

---

## 4. Third-Party Services & Subprocessors

OmniPilot integrates with trusted Google Cloud and Firebase infrastructure to deliver core functionality:
- **Google Firebase Core & Cloud Firestore:** Used for secure database storage and server synchronization. [Google Privacy Policy](https://policies.google.com/privacy).
- **Firebase AI Logic (Gemini API):** Used for multimodal natural language comprehension and tool orchestration. User prompts sent to the Gemini API are governed by the [Google Cloud Responsible AI Practices](https://cloud.google.com/responsible-ai).
- **Firebase App Check:** Protects backend resources from unauthorized bots and abuse using device attestation.

We do not sell, rent, or trade your personal data to third-party advertising networks or data brokers.

---

## 5. Data Retention & Deletion

- Attendance records stored in Cloud Firestore remain accessible to authorized evaluators and educators.
- Users can request permanent deletion of their data, accounts, or stored attendance records at any time by emailing our Data Protection contact at [aliasgharinnocent@yahoo.com](mailto:aliasgharinnocent@yahoo.com) with the subject line *"Data Deletion Request"*. All associated records will be purged within 30 days.

---

## 6. Children's Privacy

OmniPilot is designed for use by teachers, school administrators, students, and professionals. It does not knowingly collect personal identifiable information directly from children under the age of 13 without institutional or parental consent. If you believe a child has provided personal information to us without appropriate consent, please contact us immediately for prompt deletion.

---

## 7. Security Measures

We implement industry-standard administrative, physical, and technical security safeguards:
- Transport Layer Security (TLS/HTTPS) encryption for all client-to-cloud communications.
- Hardware-backed app signing keystores and release locks.
- Firebase security rules restricting access to authenticated sessions.

---

## 8. Changes to This Privacy Policy

We may update this Privacy Policy from time to time to reflect operational, legal, or regulatory requirements. Any updates will be published in this document and updated in the official repository.

---

## 9. Contact Us

If you have any questions, feedback, or data privacy requests regarding OmniPilot, please contact:

**Ali Asghar**  
Lead Developer & Security Architect  
**DartNexusLab**  
Email: [aliasgharinnocent@yahoo.com](mailto:aliasgharinnocent@yahoo.com)  
Project Repository: [https://github.com/aliasghar08/OmniPilot](https://github.com/aliasghar08/OmniPilot)

