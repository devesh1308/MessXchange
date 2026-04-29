# MessXchange 🍽️

**MessXchange** is a smart, secure, and real-time mess/canteen management mobile application built with Flutter and Firebase. It digitalizes student meal passes, automates credit tracking, and provides mess administrators with a live dashboard and secure QR scanning system to prevent fraud.

## ✨ Key Features

### 👨‍🎓 For Students
* **Dynamic Digital Meal Pass:** Generates a secure QR code that refreshes every 60 seconds to completely eliminate screenshot sharing and unauthorized entries.
* **Credit Management:** Real-time visibility of remaining mess credits.
* **Meal Skipping & Refunds:** Students can mark meals as "skipped" in advance, triggering an automated credit refund based on grace-period logic.

### 👨‍🍳 For Mess Administrators
* **Secure QR Scanner:** Built-in mobile scanner with "Gatekeeper Logic" that instantly validates the 60-second rule, checks for sufficient credits, and blocks duplicate scans for the same meal.
* **Real-Time Dashboard:** Live-updating analytics showing daily meal attendance (Breakfast, Lunch, Dinner) using highly optimized Firestore streams.
* **One-Tap Verification:** Seamlessly deducts credits and logs attendance to the database in milliseconds.

## 🛠️ Tech Stack

* **Framework:** [Flutter](https://flutter.dev/) (Dart)
* **Backend (BaaS):** [Firebase](https://firebase.google.com/)
  * **Database:** Cloud Firestore (Real-time NoSQL)
  * **Authentication:** Firebase Auth
* **State Management:** Provider
* **Key Packages:** * `mobile_scanner` (QR scanning)
  * `qr_flutter` (QR generation)
  * `cloud_firestore` (Database transactions)

## 🚀 Getting Started

Follow these steps to run the project locally on your machine.

### Prerequisites
* [Flutter SDK](https://docs.flutter.dev/get-started/install) installed.
* A connected physical device or emulator.
* A Firebase project set up.

### Installation

1. **Clone the repository**
   ```bash
   git clone [https://github.com/your-username/MessXchange.git](https://github.com/your-username/MessXchange.git)
   cd MessXchange

2. **Install Dependencies**
   ```bash
   flutter pub get

3.**Connect to Firebase**

Register your app in your Firebase Console.

Download the google-services.json file and place it in android/app/.

Download the GoogleService-Info.plist file and place it in ios/Runner/.


4. **Run The App**
   ```bash
   flutter run
🔐 Security Highlights
Screenshot Fraud Prevention: The QR code embeds a live timestamp combined with the user_id. The admin scanner rejects any code older than 60 seconds.

Duplicate Scan Protection: Database transactions check for exact-match date strings (YYYY-MM-DD) and meal types before deducting credits, ensuring a student cannot be scanned twice for the same meal.

Atomic Transactions: Uses Firestore runTransaction to ensure credit deductions and attendance logging either succeed together or fail together, preventing data mismatch.
