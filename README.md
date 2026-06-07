# ⚡️ ელექტრიკის სიმულატორი (iOS)

რეალისტური, საგანმანათლებლო **ელექტრო-მონტაჟის სიმულატორი** iOS-ისთვის.
ემყარება **ევროპულ / IEC სტანდარტს (TN-C-S სისტემა)** და ასწავლის მომხმარებელს
სწორ მონტაჟს — ფარის (consumer unit) აწყობიდან კაბელის დაქსელვამდე.

> **სტატუსი:** Phase 1 სრულად — 1 ფაზა, MCB + RCD, ნათურა + როზეტი,
> სადენების დახაზვა, ვალიდაცია და „ჩართე ძაბვა" (Test) რეჟიმი.

---

## 📂 პროექტის სტრუქტურა

```
electric-sim-ios/
├── Package.swift                  # SwiftPM — solver-ის დამოუკიდებელი მოდული + ტესტები
├── ElectricSim.xcodeproj/         # Xcode პროექტი (SwiftUI აპლიკაცია)
├── ElectricSim/
│   ├── Core/                      # ⚙️ წმინდა ლოგიკა (Foundation only — ტესტირებადი)
│   │   ├── Domain.swift           # მონაცემთა მოდელი: Component, Wire, Board, Port…
│   │   ├── UnionFind.swift        # კავშირების დაჯგუფება (disjoint-set)
│   │   ├── CircuitSolver.swift    # 🧠 გრაფზე დაფუძნებული ამომხსნელი + ვალიდაცია
│   │   ├── CircuitSolver+Analysis.swift  # მულტიმეტრი / ფაზის ინდიკატორი
│   │   ├── SimulationResult.swift # შედეგი + ქართული შეტყობინებები
│   │   ├── Levels.swift           # დონეებისა და კომპონენტების მოდელი + JSON loader
│   │   └── Data/
│   │       ├── components.json    # კომპონენტების ბიბლიოთეკა
│   │       └── levels.json        # დონეები
│   └── App/                       # 📱 SwiftUI ინტერფეისი
│       ├── ElectricSimApp.swift   # @main
│       ├── GameState.swift        # პროგრესი (UserDefaults)
│       ├── Style.swift            # ფერები / იკონები
│       ├── Views/
│       │   ├── LevelListView.swift
│       │   ├── WorkbenchView.swift   # ფარი + wiring + ხელსაწყოები + „ჩართე ძაბვა"
│       │   └── ResultPanelView.swift
│       ├── Assets.xcassets
│       └── Resources/Info.plist
└── ElectricSimTests/
    └── CircuitSolverTests.swift   # short / overload / leakage / polarity / PE / ampacity
```

---

## 🚀 გაშვება

### აპლიკაცია (Xcode)
1. გახსენი `electric-sim-ios/ElectricSim.xcodeproj` Xcode 15+-ში.
2. აირჩიე სქემა **ElectricSim** და iPhone/iPad სიმულატორი (iOS 16+).
3. `⌘R` — გაშვება.

### Solver-ის ტესტები (Xcode-ის გარეშე, ტერმინალში)
```bash
cd electric-sim-ios
swift test
```
ეს ააგებს `ElectricSimCore`-ს (წმინდა Foundation მოდული) და გაუშვებს
ყველა სცენარს: მოკლე ჩართვა, გადატვირთვა, გაჟონვა, პოლარობა, მიწა, ampacity.

> 💡 `Core/` მთლიანად UI-ისგან დამოუკიდებელია, ამიტომ solver იცდება ნებისმიერ
> პლატფორმაზე, სადაც Swift toolchain არსებობს.

---

## 🎮 თამაშის ციკლი

1. დონე გაძლევს დავალებას (მაგ.: „დააკავშირე 1 ნათურა 1 ფაზაზე ავტომატით").
2. **პალიტრიდან** ალაგებ კომპონენტებს ფარზე (DIN rail).
3. **ხელსაწყო „სადენი"** არჩეული — შეეხები ორ ფეხს (terminal) და სადენი იხატება
   (ფერი ავტომატურად — IEC: ფაზა ყავისფერი, ნული ლურჯი, მიწა ყვითელ-მწვანე).
4. აჭერ **„ჩართე ძაბვა"** → სიმულატორი ამოწმებს და გიჩვენებს შედეგს
   (ნათურა ანათდება / ავტომატი იგდება / გამოდის ქართული ახსნა).

### ხელსაწყოები
| ხელსაწყო | დანიშნულება |
|---|---|
| სადენი | terminal → terminal დაკავშირება |
| მულტიმეტრი | ძაბვის გაზომვა ორ წერტილს შორის (V) |
| ფაზის ინდიკატორი | ფეხზე ფაზის შემოწმება |
| გამცლელი / სახრახნისი | მონტაჟის ხელსაწყოები (UX) |

---

## 🔌 ელექტრო-რეალიზმი

- **TN-C-S:** PEN ფარში იყოფა PE-დ და N-ად.
- **1 ფაზა:** L–N = 230V.
- **სადენის ფერები (IEC 60446):** PE → ყვითელ-მწვანე, N → ლურჯი,
  L/L1 → ყავისფერი, L2 → შავი, L3 → ნაცრისფერი.

### კაბელის კვეთა ↔ ავტომატის ნომინალი
| კვეთა | max ავტომატი | ტიპური ხაზი |
|------|------|------|
| 1.5mm² | 16A | განათება (B10) |
| 2.5mm² | 20A | როზეტი (B16) |
| 4mm² | 25A | |
| 6mm² | 32A | ბოილერი/ღუმელი |
| 10mm² | 40A | |

### ვალიდაციის წესები (solver-ში)
1. ყველა დატვირთვას PE უნდა ჰქონდეს — თუ არა → „დენის დაზიანების რისკი".
2. L–N, L–PE, N–PE მოკლე ჩართვა → არ დაიშვება.
3. როზეტი ვალდებულია იყოს RCD-ის (30mA) ქვემოთ.
4. ავტომატის ნომინალი ≤ კაბელის დასაშვები დენი.
5. პოლარობა: L და N არევა → შეცდომა.
6. 3 ფაზაზე — დატვირთვების ბალანსი L1/L2/L3-ზე (გაფრთხილება).

### დეფექტების სიმულაცია (Test რეჟიმი)
- **მოკლე ჩართვა** → MCB მაგნიტური (მყისიერი) გაგდება.
- **გადატვირთვა** → MCB თერმული (დაყოვნებით) გაგდება.
- **დენის გაჟონვა** → RCD (30mA) გაგდება.
- **მიწის გარეშე გაჟონვა** → შოკის რისკი.

---

## ➕ ახალი დონის დამატება

დონეები აღწერილია `ElectricSim/Core/Data/levels.json`-ში. დაამატე ახალი ობიექტი:

```json
{
  "id": "lvl_my_level",
  "index": 4,
  "title": "ჩემი დონე",
  "brief": "დავალების ტექსტი ქართულად…",
  "hint": "მინიშნება…",
  "phase": "single",
  "palette": [
    { "templateId": "main_2p", "max": 1 },
    { "templateId": "mcb_b16", "max": 2, "csaOptions": [2.5, 4] },
    { "templateId": "socket_16", "max": 2 }
  ],
  "goal": {
    "poweredLoads": { "socket": 2 },
    "description": "ორივე როზეტი უნდა იმუშაოს."
  }
}
```

- `palette[].templateId` მიუთითებს `components.json`-ში არსებულ შაბლონს.
- `goal.poweredLoads` — რომელი ტიპის რამდენი დატვირთვა უნდა აანთდეს გასამარჯვებლად
  (`lamp`, `socket`, `motor`).
- ახალი კომპონენტის ტიპი → დაამატე `components.json`-ში და, საჭიროების შემთხვევაში,
  `ComponentFactory`-ში (`Domain.swift`).

### fault-finding დონე (`prebuilt`)

დაამატე `"mode": "faultFind"` და `"prebuilt"` ბლოკი — წინასწარ აწყობილი ფარი
დეფექტით. ფეხის მისამართი = კომპონენტის `id` + ფეხის სუფიქსი (ისე, როგორც
`ComponentFactory` აგენერირებს: `L`, `N`, `PE`, `Lin`, `Lout`, `Nin`, `Nout`,
`in`, `out`).

```json
{
  "id": "lvl_fault_x",
  "index": 7,
  "title": "...", "brief": "...", "hint": "...",
  "phase": "single",
  "mode": "faultFind",
  "palette": [],
  "prebuilt": {
    "components": [
      { "templateId": "supply_1ph", "id": "supply" },
      { "templateId": "main_2p", "id": "main" },
      { "templateId": "mcb_b10", "id": "brk" },
      { "templateId": "lamp_60", "id": "lamp", "leakageMa": 80 }
    ],
    "wires": [
      { "from": { "c": "supply", "p": "L" }, "to": { "c": "main", "p": "Lin" }, "csa": 1.5, "color": "brown" }
    ]
  },
  "goal": { "poweredLoads": { "lamp": 1 }, "description": "..." }
}
```

დეფექტის ინჟექცია: `leakageMa` (გაჟონვა), `faultShortToN` (შიდა L→N short),
ან უბრალოდ გამოტოვებული/არასწორი `wire` (open circuit, ლ-ნ short, არასწორი csa).
`color` არასავალდებულოა (გამოითვლება გამტარიდან).

---

## 🗺 დონეების პროგრესია (Roadmap)

| ფაზა | შინაარსი | სტატუსი |
|---|---|---|
| **Phase 1** | 1 ფაზა, MCB + RCD, ნათურა + როზეტი, wiring + ვალიდაცია + Test | ✅ მზადაა |
| **Phase 2** | სრული ფარი, რამდენიმე ხაზი, fault-finding (3 დეფექტ-დონე) | ✅ მზადაა |
| **Phase 3** | 3 ფაზა (4P მთავარი), ფაზების ბალანსი, 3-ფაზიანი მოტორი | ✅ მზადაა |
| **Phase 4** | sandbox, level editor, achievements | ✅ მზადაა |

### Phase 4 — sandbox, რედაქტორი, მიღწევები

- **Sandbox** (`mode: "sandbox"`): თავისუფალი აწყობა მიზნისა და შეზღუდვის გარეშე —
  ერთფაზიანი (უფასო) და სამფაზიანი (Pro). სრული პალიტრა.
- **დონის რედაქტორი** (`LevelEditorView`, Pro): მომხმარებელი ქმნის საკუთარ დონეს
  (პალიტრა + მიზანი), ინახება ლოკალურად (`GameState.customLevels`, JSON).
- **მიღწევები** (`Achievements.swift`): 8 მიღწევა (პირველი ნათება, დეფექტის
  მონადირე, ბალანსის ოსტატი, მოტორის ოსტატი, უნაკლო მონტაჟი, sandbox-მშენებელი,
  შემოქმედი, მთავარი ელექტრიკოსი), ინახება ლოკალურად.

### Phase 3 — სამფაზა (`phase: "three"`)

- **4-პოლუსიანი მთავარი ამომრთველი** (L1/L2/L3 + N), სამფაზიანი კვება
  (L–L = 400V, L–N = 230V).
- **ფაზების ბალანსი:** solver ითვლის თითო ფაზის დენს რეალური ქსელიდან;
  დიდი დისბალანსი → გაფრთხილება. `goal.requireBalanced: true` ხდის
  დაბალანსებას სავალდებულოდ დონის გასავლელად.
- **3-ფაზიანი მოტორი:** მუშაობს მხოლოდ სამივე ფაზისა და PE-ს არსებობისას;
  დენი `I = P / (√3 · 400)`; C-ტიპის ავტომატი ინდუქციური დატვირთვისთვის.
- **დონე 7:** 3 ნათურის განაწილება L1/L2/L3-ზე (ბალანსი).
- **დონე 8:** 3-ფაზიანი მოტორის მიერთება C16-ით.

### Phase 2 — დეფექტის ძებნა (fault-finding)

`mode: "faultFind"` დონეები იწყება **წინასწარ აწყობილი, დეფექტიანი ფარით**
(`prebuilt` ველი `levels.json`-ში). მოთამაშე ხელსაწყოებით (მულტიმეტრი /
ფაზის ინდიკატორი) აღმოაჩენს ხარვეზს და ასწორებს — ამატებს გამოტოვებულ
სადენს, შლის ზედმეტს (ღილაკი „სადენების სია"), ან ცვლის გაუმართავ კომპონენტს.

- **დონე 4:** ნათურა არ ანათდება → აკლია ნულის სადენი (open circuit).
- **დონე 5:** ავტომატი მყისვე იგდება → მოკლე ჩართვა, ზედმეტი L–N სადენი.
- **დონე 6:** RCD იგდება → დატვირთვა დენს აჟონავს, საჭიროა გამოცვლა.

ახალი fault-find დონის დასამატებლად იხ. ქვემოთ მოცემული `prebuilt` ფორმატი.

---

## 💰 მონეტიზაცია (StoreKit 2) და Pro ტესტირება

მონეტიზაცია — **freemium**, ერთჯერადი (non-consumable) Pro განბლოკვა (გამოწერა **არა**):

- **უფასო:** პირველი **3 დონე** + მხოლოდ **1 ფაზა** + სარეკლამო ბანერი.
- **Pro:** ყველა დონე, **3 ფაზა**, **დეფექტის ძებნა**, **sandbox**, რეკლამის გარეშე.

კოდი: `App/Monetization.swift` → **`EntitlementStore`** (load Product · `purchase()` ·
`Transaction.updates` observe · `Transaction.currentEntitlements` launch-ზე → `isPro`).
Pro პროდუქტის id: **`pro_unlock`**. „Restore Purchases" — paywall-სა და „შესახებ"-ში.

### Pro-ს ტესტირება (3 გზა)
1. **`.storekit` ფაილი (ლოკალურად, sandbox-ის გარეშე):**
   Xcode → **Edit Scheme → Run → Options → StoreKit Configuration → `Products.storekit`** →
   გაუშვი → paywall-ზე „განბლოკვა" იმუშავებს ტესტ-რეჟიმში.
2. **DEBUG QA toggle:** „შესახებ" ეკრანზე (მხოლოდ DEBUG ბილდში) — **„Pro იძულებით ჩართვა"**
   გადამრთველი (`EntitlementStore.debugSetPro`). სწრაფი QA-სთვის.
3. **Sandbox tester (App Store Connect):** ASC → Users and Access → Sandbox →
   შექმენი sandbox ანგარიში; მოწყობილობაზე Settings → App Store → Sandbox Account →
   შედი; აპში ნამდვილი (ტესტ) შესყიდვა.

## 🎮 Game Center (GameKit)

- **ავტორიზაცია:** არ-მბლოკავი, გაშვებისას (`GameCenterManager.authenticate()`).
- **ლიდერბორდები:** `lb_fastest_wiring` (სწრაფი სწორი დაკაბელება, წმ),
  `lb_fewest_mistakes` (ყველაზე ცოტა შეცდომა).
- **მიღწევები:** `ach_phase1…4` (თითო ფაზა), `ach_perfect_wiring` (0 შეცდომა),
  `ach_faultfinder_fast` (დეფექტი ≤120წმ).
- **Capability:** `ElectricSim.entitlements` (`com.apple.developer.game-center`).

### App Store Connect — Game Center setup
1. Apple Developer → Identifiers → App ID-ს ჩაურთე **Game Center**.
2. Xcode → Target → Signing & Capabilities → **+ Capability → Game Center**.
3. ASC → შენი აპი → **Features → Game Center**:
   - დაამატე **Leaderboards** იდენტიფიკატორებით `lb_fastest_wiring`, `lb_fewest_mistakes`
     (Single recurring; type: fastest wiring — Low to High დროზე; mistakes — Low to High).
   - დაამატე **Achievements**: `ach_phase1`, `ach_phase2`, `ach_phase3`, `ach_phase4`,
     `ach_perfect_wiring`, `ach_faultfinder_fast`.
4. ID-ები კოდში: `App/GameCenterManager.swift` (`Leaderboard` / `Achievement`).

## 🌐 ლოკალიზაცია

`Localizable.strings` — **ka** (ნაგულისხმევი), **en** (შევსებული), **ru** (TODO).
ფაილები: `App/Resources/{ka,en,ru}.lproj/Localizable.strings`.
ქართული ტექსტები უცვლელია; გასაღების ჩასართავად UI-ში: `Text("key")` /
`String(localized: "key")`. ru თარგმანი TODO-ა.

## 📦 App Store მზაობა

ქართული მეტამონაცემები `fastlane/metadata/ka/`, `PrivacyInfo.xcprivacy`, `PRIVACY.md`,
bundle id **`ge.gadget.electricsim`**, და სრული გზამკვლევი:
**[docs/PUBLISHING.md](docs/PUBLISHING.md)**.

> 🇬🇪 შემქმნელი: **gadget.ge** ([gadget.ge](https://gadget.ge)).
> სპონსორი: **[Tsili.ge](https://tsili.ge)**.

---

## 🧱 კომპონენტების ბიბლიოთეკა

32 შაბლონი (`components.json`): კვება, მთავარი 2P/4P, SPD, RCD, RCBO, ავტომატები
B/C/**D**, **MPCB**, **კონტაქტორი**, **რელე**, **გამთიშველი**, **Wago/ზოლი**,
ნათურა, **დიმერი**, როზეტი, **ბოილერი/ღუმელი/გამახურებელი/კონდიციონერი**, მოტორი,
**3-ფაზ. როზეტი**, და **Smart home** (ამომრთველი/რელე/დიმერი/მრიცხველი).
კაბელი: კვეთა + **მასალა** (სპილენძი/ალუმინი, ampacity-დერეიტინგით).

## 📊 დატვირთვის გრაფი + ცალხაზოვანი ნახაზი (`Reports.swift`)

- **დატვირთვის სიმულაცია:** დენი/სიმძლავრე თითო ხაზსა და ფაზაზე, ფაზური ბალანსი,
  სრული მოხმარება → **CSV ექსპორტი** (ShareLink).
- **ცალხაზოვანი ნახაზი (SLD):** ფარის სტრუქტურა (კვება → დაცვები → ხაზები) →
  **PNG ექსპორტი** (ImageRenderer). უფასოში **1**, Pro-ში **ულიმიტო**.

---

## 🧪 ტესტ-სცენარები (`CircuitSolverTests`)

- ✅ სწორი ერთფაზიანი წრედი — ნათურა ანათებს
- ✅ როზეტი RCD-ის გარეშე → შეცდომა
- ✅ როზეტი RCD-ით → წარმატება
- ✅ მოკლე ჩართვა L–N → მაგნიტური გაგდება
- ✅ ავტომატი > კაბელი (B20 / 1.5mm²) → შეცდომა
- ✅ გადატვირთვა → თერმული გაგდება
- ✅ გაჟონვა (100mA) → RCD გაგდება
- ✅ გაჟონვა მიწის გარეშე → შოკის რისკი
- ✅ მიწის (PE) გარეშე → შეცდომა
- ✅ პოლარობის არევა → შეცდომა
- ✅ ღია წრედი → ნათურა არ ანათებს
- ✅ ampacity ცხრილი + IEC ფერები
