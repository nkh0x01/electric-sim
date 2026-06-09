# 💼 Career Mode — `jobs.json` სქემა (ავტორებისთვის)

Career Mode-ის სამუშაოები აღწერილია **მხოლოდ JSON-ით** ფაილში
`ElectricSim/Core/Data/jobs.json` (იტვირთება `GameData.loadJobs()`-ით, იგივე
პატერნი, რაც `levels.json`). ახალი სამუშაოს დასამატებლად კოდის შეცვლა **არ
არის საჭირო** — დაამატე ობიექტი მასივში.

> Phase 1: მონაცემები + პერსისტენცია. UI მოგვიანებით.

## ველები

| ველი | ტიპი | სავალდებულო | აღწერა |
|---|---|:---:|---|
| `id` | string | ✅ | უნიკალური იდენტიფიკატორი (მაგ. `"job_kitchen_socket"`). |
| `georgianTitle` | string | ✅ | სამუშაოს სათაური (ka). |
| `customerName` | string | ✅ | კლიენტის სახელი (ka) — flavor. |
| `location` | string | ✅ | ლოკაცია (ka) — flavor. |
| `category` | JobCategory | ✅ | სამუშაოს ტიპი (იხ. ქვემოთ). |
| `difficulty` | int (1...5) | ✅ | სირთულე (1 = ყველაზე მარტივი). |
| `tier` | `"free"` \| `"pro"` | ✅ | ფასიანობა — არსებული `isPro` gating-ის გასაღები. |
| `jobBrief` | string | ✅ | დავალების ტექსტი (ka). |
| `componentsAvailable` | [string] | ✅ | ხელმისაწვდომი კომპონენტების `templateId`-ები (პალიტრა). |
| `requiredComponents` | [string] | ✅ | გადასაჭრელად საჭირო `templateId`-ები (ქვესიმრავლე). |
| `xpReward` | int | ✅ | XP ჯილდო (ერთხელ, პირველ დასრულებაზე). |
| `cashReward` | int | ✅ | ფულადი ჯილდო (ერთხელ). |
| `unlocks` | [string] | ✅ | რას ხსნის დასრულება (კომპონენტის/ხელსაწყოს id; ცარიელი `[]` თუ არაფერს). |
| `goal` | LevelGoal | ✅ | წარმატების კრიტერიუმი — იგივე ფორმატი, რაც დონეებში (`poweredLoads`, `description`). მაგ.: `{"poweredLoads":{"socket":2},"description":"..."}`. სამუშაო „გადაჭრილია“, როცა ეს მიზანი დაკმაყოფილდება (workbench-ის იგივე solver-ით). |

### `JobCategory` (ნებადართული მნიშვნელობები)
`tutorial`, `residential`, `commercial`, `industrial`, `faultfinding`,
`renewable`, `inspection`.

### `tier` / gating
ფასიანობა იმართება არსებული `EntitlementStore.isPro`-ით (არ იფორკება):
`isProLocked(job, isPro) == (!isPro && job.tier == "pro")`.
- **Apprentice (შეგირდი) დონის სამუშაოები → `tier: "free"`** — სრულად
  გასავლელია Pro-ს გარეშე, **მხოლოდ ბაზისური კომპონენტებით**.
- **Residential და ზემოთ → `tier: "pro"`** (ერთიანი `pro_unlock` IAP).

### ბაზისური (უფასო) კომპონენტები
უფასო სამუშაოს `componentsAvailable` / `requiredComponents` უნდა შეიცავდეს
**მხოლოდ** ამ `templateId`-ებს (kind-ები: `mainSwitch`, `mcb`, `rcd`, `lamp`,
`socket`; + კაბელი):
`main_2p`, `mcb_b10`, `mcb_b16`, `rcd_30`, `lamp_60`, `socket_16`.
ამას ამოწმებს ტესტი `testFreeJobsUseOnlyBasicComponents`.

### `difficulty` მნიშვნელობა
1 = ერთი დატვირთვა, მინიმალური წრედი … 5 = რთული, მრავალხაზიანი/სპეც.
(Phase 1 placeholder-ები 1–2 დიაპაზონშია.)

## კარიერული წოდებები (XP ზღვრები)
ცენტრალიზებულია `CareerRank`-ში (`Career.swift`), ადვილად რეგულირებადი:

| წოდება | XP | ka |
|---|---|---|
| apprentice | 0 | შეგირდი |
| residential | 300 | საცხოვრებელი ობიექტების ელექტრიკოსი |
| commercial | 900 | კომერციული ობიექტების ელექტრიკოსი |
| industrial | 1800 | სამრეწველო ელექტრიკოსი |
| renewable | 3000 | განახლებადი ენერგიის სპეციალისტი |
| master | 5000 | ოსტატი ელექტრიკოსი |

წოდება გამოითვლება `totalXP`-დან — ცალკე შესანახი არ სჭირდება.

## მასივების მაგალითები
```json
"componentsAvailable": ["main_2p", "rcd_30", "mcb_b16", "socket_16"],
"requiredComponents":  ["main_2p", "rcd_30", "mcb_b16", "socket_16"],
"unlocks": ["tool_multimeter_pro"]
```
ხელმისაწვდომი `templateId`-ები იხ. `ElectricSim/Core/Data/components.json`.

## სრული მაგალითი — ახალი უფასო სამუშაო
```json
{
  "id": "job_kitchen_socket",
  "georgianTitle": "სამზარეულოს როზეტი",
  "customerName": "ლევან ჩხეიძე",
  "location": "გლდანი, თბილისი",
  "category": "tutorial",
  "difficulty": 2,
  "tier": "free",
  "jobBrief": "სამზარეულოში დააკავშირე როზეტი RCD-ის დაცვით (2.5mm²).",
  "componentsAvailable": ["main_2p", "rcd_30", "mcb_b16", "socket_16"],
  "requiredComponents": ["main_2p", "rcd_30", "mcb_b16", "socket_16"],
  "xpReward": 80,
  "cashReward": 80,
  "unlocks": [],
  "goal": { "poweredLoads": { "socket": 1 }, "description": "როზეტი უნდა მუშაობდეს RCD-ით." }
}
```

> წესი: უფასო (Apprentice) სამუშაო **სრულად გასავლელი უნდა იყოს** ბაზისური
> კომპონენტებით და Pro-ს გარეშე — ამას ავტომატური ტესტები იცავს.
