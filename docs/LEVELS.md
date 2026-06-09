# 🎚 დონეების სქემა (`levels.json`) — ავტორებისთვის

ყველა დონე აღწერილია **მხოლოდ JSON-ით** ფაილში
`ElectricSim/Core/Data/levels.json`. ახალი დონის დასამატებლად კოდის შეცვლა
**არ არის საჭირო** — უბრალოდ დაამატე ახალი ობიექტი მასივში.

ფაილი არის ობიექტების მასივი. თითო ობიექტი = ერთი დონე.

---

## ველები

| ველი | ტიპი | სავალდებულო | აღწერა |
|---|---|:---:|---|
| `id` | string | ✅ | უნიკალური იდენტიფიკატორი (მაგ. `"lvl_kitchen"`). |
| `index` | int | ✅ | რიგი. განსაზღვრავს **გავლის თანმიმდევრობას** (პატარა → ადრე). უფასო დონეებს მიეცი პატარა index-ები. |
| `title` | string | ✅ | სათაური (ka). |
| `brief` | string | ✅ | დავალების ტექსტი (ka). |
| `hint` | string | ✅ | მინიშნება (ka) — ნაჩვენებია „?“ ღილაკზე. |
| `phase` | `"single"` \| `"three"` | ✅ | ერთ- თუ სამფაზიანი ფარი. |
| `palette` | [PaletteEntry] | ✅ | რა კომპონენტების დადება შეუძლია მოთამაშეს (ცარიელი `[]` faultFind-ზე). |
| `goal` | LevelGoal | ✅ | გამარჯვების პირობა. |
| `category` | LevelCategory | ⛔️ | დაჯგუფება UI-ში. თუ აკლია — გამოითვლება რეჟიმიდან/ფაზიდან. |
| `difficulty` | int (1...5) | ⛔️ | სირთულე (წერტილებად ჩანს სიაში). default `1`. |
| `tier` | `"free"` \| `"pro"` | ⛔️ | ფასიანობა. თუ აკლია — heuristic: `build`+`single`+`index≤3` → free, სხვა → pro. |
| `mode` | LevelMode | ⛔️ | `"build"` (default), `"faultFind"`, `"sandbox"`. |
| `prebuilt` | PrebuiltBoard | ⛔️ | წინასწარ აწყობილი ფარი (მხოლოდ `faultFind`-ისთვის). |

### `LevelCategory` (დაჯგუფება + რიგი)
`"tutorial"` → `"singlePhase"` → `"panelAssembly"` → `"faultFinding"` →
`"threePhase"` → `"sandbox"`.

### `LevelMode`
- `"build"` — ცარიელი ფარი (მხოლოდ კვება), ააწყობ ნულიდან.
- `"faultFind"` — `prebuilt` ფარი დეფექტით; მოთამაშე პოულობს/ასწორებს.
- `"sandbox"` — თავისუფალი, მიზნის გარეშე (ყოველთვის Pro).

### `panelAssembly` კატეგორია (ფარის აწყობა)
თუ `category = "panelAssembly"`, დონეზე ერთვება **დამატებითი ვალიდაცია**:
რელსზე სწორი თანმიმდევრობა **მთავარი → SPD → RCD → ავტომატები (busbar-ით) →
ხაზები** და ავტომატების სავარცხელი ზოლით კვება RCD-ის გამოსასვლელიდან.
არასწორ წყობაზე მოთამაშე მიიღებს ქართულ ახსნას (მაგ. „RCD უნდა იყოს
ავტომატების წინ“). `mode` დატოვე ცარიელი (`build`).

### `PaletteEntry`
```json
{ "templateId": "mcb_b16", "max": 2, "csaOptions": [2.5, 4] }
```
| ველი | ტიპი | აღწერა |
|---|---|---|
| `templateId` | string ✅ | შაბლონის id `components.json`-დან. |
| `max` | int ✅ | მაქს. რამდენი დაიდება ფარზე. |
| `csaOptions` | [double] ⛔️ | დასაშვები კაბელის კვეთები (mm²) ამ ხაზზე. |

### `LevelGoal`
```json
{ "poweredLoads": { "lamp": 1, "socket": 2 },
  "description": "...",
  "requireBalanced": true }
```
| ველი | ტიპი | აღწერა |
|---|---|---|
| `poweredLoads` | { kind: count } ✅ | რომელი დატვირთვა და რამდენი უნდა აანთდეს. |
| `description` | string ✅ | მიზნის ტექსტი (ka). |
| `requireBalanced` | bool ⛔️ | სამფაზიან დონეზე — სავალდებულოა თუ არა ფაზების ბალანსი. |

**`poweredLoads`-ის ნებადართული kind-ები** (დატვირთვები):
`lamp`, `dimmer`, `socket`, `boiler`, `oven`, `heater`, `airConditioner`,
`motor`, `socket3ph`, `indicatorLight`.

### `PrebuiltBoard` (მხოლოდ faultFind)
```json
"prebuilt": {
  "components": [
    { "templateId": "supply_1ph", "id": "supply" },
    { "templateId": "lamp_60", "id": "lamp", "leakageMa": 80 }
  ],
  "wires": [
    { "from": { "c": "supply", "p": "L" }, "to": { "c": "main", "p": "Lin" },
      "csa": 1.5, "color": "brown" }
  ]
}
```
- `components[].id` — instance id; ფეხის მისამართი = `id` + ფეხის სუფიქსი
  (`L`, `N`, `PE`, `Lin`, `Lout`, `Nin`, `Nout`, `in`, `out`, `L1`…).
- დეფექტის ინჟექცია: `leakageMa` (გაჟონვა), `faultShortToN` (შიდა L→N short),
  ან უბრალოდ გამოტოვებული/არასწორი `wire`.
- `color` არასავალდებულოა (გამოითვლება გამტარიდან).

---

## ✅ წესები (რომ დონე გასავალი იყოს)

1. **უფასო დონე სრულად გასავალი უნდა იყოს უფასო ნაკრებით.** `goal.poweredLoads`-ის
   ყველა kind უნდა იყოს `palette`-ში (ან `prebuilt`-ში). ამას ამოწმებს ავტო-ტესტი
   `testFreeLevelsAreCompletableByFreeUser`.
2. **ampacity:** არჩეული ავტომატის ნომინალი ≤ კაბელის დასაშვები დენი
   (1.5→16A, 2.5→20A, 4→25A, 6→32A, 10→40A). `csaOptions`-ში ჩადე მინიმუმ ერთი
   ვარგისი კვეთა.
3. **როზეტი** (`socket`, `socket3ph`) ყოველთვის უნდა იყოს **RCD/RCBO**-ის ქვემოთ.
4. **სამფაზიანი** დატვირთვა (`motor`) საჭიროებს სამივე ფაზას + PE.
5. index-ები ისე დაალაგე, რომ უფასო დონეები წინ იყოს (თანმიმდევრული გახსნა).

---

## 📝 სრული მაგალითი — ახალი უფასო დონე

```json
{
  "id": "lvl_my_kitchen",
  "index": 6,
  "title": "ჩემი სამზარეულო",
  "brief": "დააკავშირე ორი როზეტი RCD-ის დაცვით.",
  "hint": "მთავარი → RCD → ავტომატები (ზოლით) → როზეტები. ყველა 2.5mm².",
  "phase": "single",
  "category": "singlePhase",
  "difficulty": 2,
  "tier": "free",
  "palette": [
    { "templateId": "main_2p", "max": 1 },
    { "templateId": "rcd_30", "max": 1 },
    { "templateId": "busbar_l", "max": 1 },
    { "templateId": "mcb_b16", "max": 2, "csaOptions": [2.5, 4] },
    { "templateId": "socket_16", "max": 2 }
  ],
  "goal": {
    "poweredLoads": { "socket": 2 },
    "description": "ორივე როზეტი უნდა მუშაობდეს RCD-ით."
  }
}
```

ხელმისაწვდომი `templateId`-ები იხ. `ElectricSim/Core/Data/components.json`.
