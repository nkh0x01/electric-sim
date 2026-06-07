# App Store-ზე გამოქვეყნება და მონეტიზაცია

ეს გზამკვლევი აღწერს, როგორ გამოაქვეყნო **ელექტრიკის სიმულატორი** App Store-ზე
და როგორ მუშაობს მონეტიზაცია. ბრენდი: **gadget.ge**. დაფინანსება: **Tsili.Ge**.

---

## 💰 მონეტიზაციის მოდელი (freemium)

ამ ტიპის საგანმანათლებლო/სიმულატორ თამაშისთვის ოპტიმალურია **freemium**:

| | უფასო | Pro (ერთჯერადი შესყიდვა) |
|---|---|---|
| Phase 1 — ერთფაზიანი მონტაჟი | ✅ | ✅ |
| Phase 2 — დეფექტის ძებნა | ✅ | ✅ |
| Phase 3 — 3 ფაზა + მოტორი | 🔒 | ✅ |
| რეკლამა | ბანერი | ❌ არ არის |

- **არ** გამოვიყენეთ წინასწარ გადახდადი (paid-upfront) მოდელი — ის ამცირებს მოცვას.
- **არ** გამოვიყენეთ გამოწერა (subscription) — ზედმეტია ერთჯერადი კონტენტისთვის.
- **Pro** — `NonConsumable` შესყიდვა StoreKit 2-ით (`EntitlementStore`).
- **რეკლამა** — აბსტრაჰირებული `AdManager`-ით; ამჟამად „house ads" (gadget.ge,
  Tsili.Ge), რომელიც მონაცემებს არ აგროვებს.

---

## 🛒 In-App Purchase-ის გამართვა (App Store Connect)

1. **Bundle ID:** `ge.gadget.electricsim` (დარეგისტრირდეს Apple Developer-ში).
2. App Store Connect → ახალი აპი → შეავსე ka ლოკალიზაცია.
3. **In-App Purchases → +** → **Non-Consumable**:
   - Product ID: `pro_unlock`  ← ემთხვევა `EntitlementStore.proProductID`-ს
   - Reference Name: `ElectricSim Pro Unlock`
   - ფასი: შენი არჩევანით (მაგ. ₾ ტიერი).
   - ლოკალიზაცია (ka): „ელექტრიკი Pro".
4. დაამატე **paid apps agreement** და საბანკო/საგადასახადო ინფო (აუცილებელია IAP-ისთვის).

### ლოკალური ტესტირება (Xcode, Sandbox-ის გარეშე)
- Xcode → **Edit Scheme → Run → Options → StoreKit Configuration** → აირჩიე
  `Products.storekit` (რეპოს ფესვშია).
- გაუშვი აპი — Pro შესყიდვა იმუშავებს ტესტ-რეჟიმში.

---

## 📦 გამოქვეყნების ნაბიჯები

1. **ხელმოწერა:** Xcode → Target → Signing & Capabilities → აირჩიე შენი Team
   (Automatic signing). `CODE_SIGNING_ALLOWED` CI-ში გამორთულია მხოლოდ build-ის
   შესამოწმებლად — რეალური archive ხელმოწერას საჭიროებს.
2. **ვერსია/ბილდი:** `MARKETING_VERSION` და `CURRENT_PROJECT_VERSION` (pbxproj).
3. **აიქონი:** ჩაანაცვლე `Assets.xcassets/AppIcon` 1024×1024 სურათით.
4. **Archive:** Product → Archive → Distribute App → App Store Connect.
5. **მეტამონაცემები:** `fastlane/metadata/ka/` უკვე შევსებულია ქართულად
   (`name`, `subtitle`, `description`, `keywords`, `release_notes`…). ატვირთვა:
   ```bash
   cd electric-sim-ios
   fastlane deliver --app_identifier ge.gadget.electricsim
   ```
   (ან ხელით App Store Connect-ში).
6. **სკრინშოტები:** 6.7" და 5.5" iPhone + 12.9" iPad (App Store-ის მოთხოვნა).
7. **კონფიდენციალურობა:** App Privacy განყოფილებაში მონიშნე „Data Not Collected"
   (house ads-ისთვის). `PrivacyInfo.xcprivacy` უკვე ჩაშენებულია.
8. **Encryption:** `ITSAppUsesNonExemptEncryption = false` (Info.plist) — დამატებითი
   კითხვები არ დაისმება.

---

## 📣 AdMob-ის ჩართვა (არასავალდებულო, შემოსავლის გასაზრდელად)

ამჟამად რეკლამა „house ads"-ია. რეალური ქსელისთვის:

1. დაამატე **Google Mobile Ads SDK** (Swift Package):
   `https://github.com/googleads/swift-package-manager-google-mobile-ads`
2. შეცვალე `AdManager` ან `AdBannerView` AdMob-ის ბანერით (`GADBannerView`).
3. `Info.plist`:
   - `GADApplicationIdentifier` = შენი AdMob App ID.
   - `SKAdNetworkItems` = AdMob-ის მიერ მოწოდებული ქსელების სია.
4. **ATT:** თუ პერსონალიზებულ რეკლამას იყენებ, მოითხოვე ნებართვა
   `ATTrackingManager`-ით (`NSUserTrackingUsageDescription` უკვე დამატებულია, ქართულად).
5. **განაახლე `PrivacyInfo.xcprivacy`** — დაამატე შეგროვებული მონაცემთა ტიპები
   და `NSPrivacyTracking = true` (საჭიროებისამებრ), წინააღმდეგ შემთხვევაში App Store
   უარყოფს ბილდს.
6. განაახლე `PRIVACY.md` და App Privacy განყოფილება.

> 💡 რეკომენდაცია: გამოიყენე **rewarded** ან მსუბუქი **banner** რეკლამა; მოერიდე
> აგრესიულ interstitial-ებს სწავლის პროცესში.

---

## 🤝 ბრენდი და დაფინანსება

- **gadget.ge** — შემქმნელი/გამომცემელი. ნახსენებია: „შესახებ" ეკრანი,
  სარეკლამო ბანერი, App Store-ის აღწერა, `PRIVACY.md`. ბმული: gadget.ge.
- **Tsili.Ge** — დაფინანსების/მხარდაჭერის არხი. ნახსენებია: „შესახებ" ეკრანის
  „მხარდაჭერა" სექცია, სარეკლამო ბანერი, release notes. ბმული: tsili.ge.

ორივე ბმული თავმოყრილია `AdManager`-ში (`Monetization.swift`) და `AboutView`-ში
(`StoreViews.swift`) — განახლება ერთ ადგილას.
