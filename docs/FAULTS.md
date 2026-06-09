# 🔍 Fault-finding მისიები — `faults.json` სქემა (Phase 1)

დეფექტის-ძებნის მისიები აღწერილია `ElectricSim/Core/Data/faults.json`-ში
(იტვირთება `GameData.loadFaults()`-ით — იგივე პატერნი, რაც levels/jobs).

> **Phase 1:** მონაცემები + დეფექტის ინჟექცია + დიაგნოსტიკის ძრავა. **UI არ არის**
> (გაზომვა/ხელსაწყოები/ვერიფიკაცია მოგვიანებით).

## იდეა
თითო მისია ინახავს **ჯანსაღ** წინასწარ-აწყობილ ფარს (`board`) + `fault`
(ცვლილება, რომელიც დეფექტს ამატებს) + `fix` (სწორი შესწორება). ერთი და იგივე
ტიპი `BoardEdit` გამოიყენება ინჟექციისა და შესწორებისთვის.

- დეფექტიანი ფარი = `board` (აგებული) + `fault` გამოყენებული.
- შესწორებული ფარი = დეფექტიანი + `fix` გამოყენებული.
- ძრავა (`FaultEngine`) აფასებს ფარს არსებული `CircuitSolver`-ით.

## ველები
| ველი | ტიპი | სავალდებულო | აღწერა |
|---|---|:---:|---|
| `id` | string | ✅ | უნიკალური id. |
| `georgianTitle` | string | ✅ | სათაური (ka). |
| `customerName` / `location` | string | ✅ | კლიენტი / ლოკაცია (ka). |
| `difficulty` | int (1–5) | ✅ | სირთულე. |
| `tier` | `free`/`pro` | ✅ | ფასიანობა (არსებული `isPro`). |
| `customerComplaint` | string | ✅ | კლიენტის ჩივილი (ka). |
| `symptoms` | [string] | ✅ | სიმპტომები (ka). |
| `faultType` | FaultType | ✅ | სწორი დიაგნოზი (იხ. ქვემოთ). |
| `phase` | `single`/`three` | ⛔️ | nil → single. |
| `board` | PrebuiltBoard | ✅ | ჯანსაღი საბაზისო ფარი (components + wires). |
| `fault` | BoardEdit | ✅ | დეფექტის ინჟექცია. |
| `fix` | BoardEdit | ✅ | სწორი შესწორება. |
| `xpReward` / `cashReward` | int | ✅ | ჯილდო. |

### `FaultType` (ნებადართული მნიშვნელობები)
`shortCircuitLN`, `shortCircuitLPE`, `missingPE`, `reversedPolarity`,
`earthLeakage`, `missingRCD`, `wrongBreakerSize`, `overloadedCable`,
`wrongCableSize`, `sharedNeutral`, `nuisanceRCDTrip`, `failedSPD`, `missingSPD`,
`wrongPhaseSequence`, `unbalanced3ph`, `looseNeutral`.

> დიაგნოსტიკის ძრავა solver-ით აღმოჩენად დეფექტებს პირდაპირ ცნობს
> (wrongBreakerSize, missingPE, earthLeakage, shortCircuitLN/LPE,
> reversedPolarity, missingRCD, overloadedCable, unbalanced3ph). solver-ით
> აღმოუჩენელ დეფექტებს (sharedNeutral, nuisanceRCDTrip, failedSPD,
> wrongPhaseSequence, looseNeutral, wrongCableSize) `setFaultFlag` მარკერი
> წარმოადგენს — `diagnose` მათ უპირატესობას ანიჭებს, `boardPasses` კი
> მარკერის გაწმენდას ითხოვს. ასე ყველა 15 batch-1 მისია გადის ტესტებს.

### `BoardEdit` (ინჟექცია/შესწორება)
ცარიელი `{}` — არაფერს ცვლის. ველები:
| ველი | ტიპი | აღწერა |
|---|---|---|
| `setRatingA` | `{componentID: A}` | ავტომატის ნომინალის შეცვლა. |
| `setLeakageMa` | `{componentID: mA}` | გაჟონვის დაყენება (`0` = გაწმენდა / გამოცვლა). |
| `setAllCsaMm2` | double | ყველა სადენის კვეთა (mm²). |
| `addWires` | [PrebuiltWire] | სადენების დამატება (მაგ. PE). |
| `removeWires` | [PrebuiltWire] | სადენების წაშლა (ემთხვევა ფეხებით; `csa` სავალდებულოა decode-ისთვის, იგნორირდება). |
| `setFaultFlag` | `{componentID: FaultType}` | არა-ელექტრული (solver-ით აღმოუჩენადი) დეფექტის მარკერი კომპონენტზე (მაგ. `looseNeutral`, `failedSPD`, `sharedNeutral`, `nuisanceRCDTrip`, `wrongPhaseSequence`, `wrongCableSize`). `FaultEngine.diagnose` მარკერს უპირატესობას ანიჭებს; `boardPasses` მოითხოვს მის გაწმენდას. |
| `clearFaultFlag` | [componentID] | მითითებული კომპონენტების `setFaultFlag` მარკერის გაწმენდა (fix-ში). |

`PrebuiltWire`: `{ "from": {"c":"<id>","p":"<port>"}, "to": {...}, "csa": 2.5, "color": "brown" }`
(ფეხის სუფიქსები: `L/N/PE`, `Lin/Lout/Nin/Nout`, `in/out`).

## IEC წესები (ძრავა)
ავტომატი ≤ კაბელის ampacity (1.5→16A, 2.5→20A, 4→25A, 6→32A, 10→40A);
30mA RCD როზეტებზე; ყველა ხაზს PE; პოლარობა სწორი.

## სრული მაგალითი — არასწორი ნომინალის ავტომატი (free, batch-1 #1)
```json
{
  "id": "fault_bedroom_wrong_breaker",
  "georgianTitle": "საძინებლის გადამეტებული ავტომატი",
  "customerName": "გიორგი ლომიძე",
  "location": "ბინა ვაკეში",
  "difficulty": 1,
  "tier": "free",
  "customerComplaint": "ხაზზე არაფერი ითიშება, მაგრამ კედელი თბება.",
  "symptoms": ["კაბელი თბება", "ავტომატი არ ითიშება", "განათება მუშაობს"],
  "faultType": "wrongBreakerSize",
  "phase": "single",
  "board": {
    "components": [
      { "templateId": "supply_1ph", "id": "supply" },
      { "templateId": "main_2p", "id": "main" },
      { "templateId": "mcb_b16", "id": "brk" },
      { "templateId": "lamp_60", "id": "lamp" }
    ],
    "wires": [
      { "from": {"c":"supply","p":"L"}, "to": {"c":"main","p":"Lin"}, "csa": 1.5, "color": "brown" },
      { "from": {"c":"main","p":"Lout"}, "to": {"c":"brk","p":"in"}, "csa": 1.5, "color": "brown" },
      { "from": {"c":"brk","p":"out"}, "to": {"c":"lamp","p":"L"}, "csa": 1.5, "color": "brown" },
      { "from": {"c":"supply","p":"N"}, "to": {"c":"main","p":"Nin"}, "csa": 1.5, "color": "blue" },
      { "from": {"c":"main","p":"Nout"}, "to": {"c":"lamp","p":"N"}, "csa": 1.5, "color": "blue" },
      { "from": {"c":"supply","p":"PE"}, "to": {"c":"lamp","p":"PE"}, "csa": 1.5, "color": "yellowGreen" }
    ]
  },
  "fault": { "setRatingA": { "brk": 32 } },
  "fix":   { "setRatingA": { "brk": 16 } },
  "xpReward": 100,
  "cashReward": 120
}
```
ეს ფარი: 32A ავტომატი 1.5mm² კაბელზე → `breakerExceedsCable` → დიაგნოზი
`wrongBreakerSize`. შესწორება — 16A ავტომატი (≤ 16A, 1.5mm²-ის ლიმიტი).
