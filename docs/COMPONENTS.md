# 🧩 კომპონენტების სქემა (`components.json`)

კომპონენტების ბიბლიოთეკა აღწერილია `ElectricSim/Core/Data/components.json`-ში
(იტვირთება `GameData.loadTemplates()`-ით). თითო ობიექტი = ერთი შაბლონი.

## ველები
| ველი | ტიპი | სავალდებულო | აღწერა |
|---|---|:---:|---|
| `id` | string | ✅ | უნიკალური id (პალიტრებში/დონეებში მითითებული `templateId`). |
| `kind` | ComponentKind | ✅ | ტიპი (`mcb`, `rcd`, `lamp`, `socket`, `busbar`…). |
| `name` | string | ✅ | ქართული სახელი (აბრევიატურა ფრჩხილებში — იხ. i18n). |
| `category` | ComponentCategory | ⛔️ | პალიტრის სექცია. თუ აკლია — გამოითვლება `kind`-იდან. |
| `ratingA` | double | ⛔️ | ნომინალური დენი (A). |
| `curve` | `B`/`C`/`D` | ⛔️ | ავტომატის მახასიათებელი. |
| `mAtrip` | double | ⛔️ | RCD/RCBO გამშვები დენი (mA). |
| `powerW` | double | ⛔️ | დატვირთვის სიმძლავრე (W). |
| `requiresPE` | bool | ⛔️ | სჭირდება დამცავი მიწა. |
| `poles` | int | ⛔️ | პოლუსები/სლოტები. |
| `leakageMa` / `faultShortToN` | double/bool | ⛔️ | დეფექტის ინჟექცია (fault-find). |
| `priceGEL` | double | ⛔️ | ფასი BOM-ისთვის (₾). |

## `category` — პალიტრის დაჯგუფება
პალიტრა UI-ში იყოფა სექციებად ამ ველით (data-driven). ნებადართული მნიშვნელობები
და ქართული სათაურები (რიგით):

| `category` | ქართული სექცია | მაგ. kind-ები |
|---|---|---|
| `protection` | დამცავები | mcb, rcd, rcbo, spd, mpcb, fuse, currentTransformer |
| `supply` | კვება/წყარო | supply, mainSwitch, generator, solarPanel, ups, inverter, battery, transformer |
| `load` | დატვირთვა | lamp, dimmer, socket, boiler, oven, heater, airConditioner, motor, socket3ph |
| `control` | მართვა/ჭკვიანი | contactor, relay, lightSwitch, selectorSwitch, smart*, vfd |
| `auxiliary` | დამხმარე | busbar, wago, terminalBlock, emergencyStop, indicatorLight |

თუ `category` JSON-ში არ მიუთითე, ის ავტომატურად გამოითვლება `kind`-იდან
(`ComponentCategory.forKind`). თუ მიუთითებ, უნდა ემთხვეოდეს `kind`-ის ნაგულისხმევს
(ამას ამოწმებს ტესტი `testExplicitJSONCategoryMatchesKindDefault`).

## მაგალითი
```json
{
  "id": "rcd_30",
  "kind": "rcd",
  "name": "დიფ. დამცავი (RCD) 40A 30mA",
  "category": "protection",
  "ratingA": 40,
  "mAtrip": 30,
  "priceGEL": 45
}
```
