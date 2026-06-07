# AI-სურათების პრომპტი კომპონენტებისთვის (რეალისტური)

თითო პრომპტი დააგენერირე AI-ით (Midjourney / DALL·E / SDXL და ა.შ.), შემდეგ ჩასვი
`ElectricSim/App/Assets.xcassets/comp_<name>.imageset/`-ში იგივე სახელით (PNG).
აპი ავტომატურად აჩვენებს ფოტოს. კვადრატი 1024×1024, ერთ batch-ში ერთი სტილით.

## მთავარი სტილი (suffix ყველასთვის)
> ", photorealistic studio product photograph, isolated on pure white seamless
> background, centered, front view at eye level, soft studio lighting, subtle
> contact shadow, ultra-detailed, e-commerce catalog style, neutral unbranded,
> square 1:1, 1024x1024, no text, no logos, no watermark."

## სრული, კოპირებადი პრომპტები

- **comp_mcb** — A single-pole miniature circuit breaker (MCB), white modular DIN-rail device with a black ON/OFF toggle switch
- **comp_mpcb** — A motor protection circuit breaker, black modular DIN-rail device with a rotary current dial and test button
- **comp_rcd** — A residual current device (RCD/RCCB), white two-module DIN-rail device with a blue test button and a toggle switch
- **comp_rcbo** — An RCBO combined residual-current circuit breaker, narrow white DIN-rail module with a toggle and test button
- **comp_mainSwitch** — A main isolator load-break switch, white DIN-rail device with a large black handle
- **comp_spd** — A surge protection device (SPD), white DIN-rail module with a green and red status indicator window
- **comp_contactor** — A modular contactor, white and grey DIN-rail contactor block
- **comp_relay** — A modular plug-in relay with a clear plastic housing on a socket base
- **comp_lightSwitch** — A modern European wall light switch, single white rocker on a square frame
- **comp_busbar** — A copper pin/comb busbar used to connect circuit breakers on a DIN rail
- **comp_wago** — A lever-type wire connector block, grey body with five orange levers
- **comp_lamp** — A warm glowing incandescent light bulb
- **comp_dimmer** — A rotary light dimmer with a control knob on a white wall plate
- **comp_socket** — A European Schuko wall power socket (type F), white
- **comp_socket3ph** — A red three-phase industrial CEE power socket
- **comp_boiler** — A white wall-mounted electric water heater storage tank
- **comp_oven** — A built-in electric oven with a stainless steel front and glass door
- **comp_heater** — A white electric convector panel heater
- **comp_airConditioner** — A white wall-mounted split air conditioner indoor unit
- **comp_motor** — A blue three-phase industrial electric motor with a cooling fan housing
- **comp_smartSwitch** — A smart wifi wall switch with a white glass touch panel
- **comp_smartRelay** — A small smart wifi relay module with short wire leads
- **comp_smartDimmer** — A smart wifi light dimmer module
- **comp_smartMeter** — A smart electric energy meter with a digital LCD display, DIN-rail mounted
- **comp_supply** — A main electrical service panel / energy meter box

თითო პრომპტი = „A {SUBJECT}" + ზემოთა suffix.

## ჩასმა
1. დააგენერირე PNG (გამჭვირვალე ან თეთრი ფონი).
2. ჩაანაცვლე ფაილი `Assets.xcassets/comp_<name>.imageset/comp_<name>.png` (იგივე სახელით),
   ან Xcode-ში წაშალე imageset და ხელახლა დაამატე იმავე სახელით.
3. გაუშვი აპი — ბანქოებზე ფოტო ავტომატურად გამოჩნდება.
