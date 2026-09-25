# Endurhönnun: widgets, app og fídusar

Mockups: [`docs/redesign/index.html`](redesign/index.html) (opnaðu í vafra; takkarnir efst skipta milli stöðu: nýtt reset, bið, löng bið, +1 banked). Tölur í mockups eru dæmagögn.

Allt byggir á gögnum sem appið hefur nú þegar: `state.events`, `scheduled`, `WatchSignal.resetChancePercent` / `forecastWindow` og `ResetStats.averageIntervalDays` (sjá `Sources/CodexResetCore/API/DTOs.swift`).

## Val

Glóð fyrir bæði widgets og app, með banked sem stærstu töluna og hreyfðan karakter. Smíðað í `GlodMood.swift`, `GlodCharacter.swift`, `GlodWidgetViews.swift`, `PokeGlodIntent.swift` og `GlodStage.swift`. Útfærslan er lýst í DESIGN.md.

## Þrjár widget-týpur (2×2 og 4×2)

| Stíll | Hugmynd | 2×2 | 4×2 |
| --- | --- | --- | --- |
| **A · Glóð** | Logi-karakter með skap. Glaður eftir reset, þreyttur þegar biðin fer yfir meðalbilið, fær gullpening við banked | Logi, `10d 7h`, peningar | Logi + talbóla, FULL, peningakrukka með banked |
| **B · Arcade** | LED stigatafla, pixla-letur, amber og mint (enginn arcade-rauður, sbr. DESIGN.md) | `DAYS SINCE RESET`, stór tala, `CREDITS 02` sem hjörtu | Tvö panel (P1 FULL / CREDITS) og ticker með NEXT og líkum |
| **C · Hringur** | Candy gradient hringur sem fyllist frá síðasta full reset að meðalbili | Hringur `10d of ~12d`, banked pill | Hringur + tími síðan full, forecast-líkur, pills |

Stílvalið er per widget með `AppIntentConfiguration`. Núverandi High-End verður áfram sjálfgefið svo widgets sem notendur eru þegar með breytast ekki. WidgetKit spilar ekki stöðugar hreyfimyndir; skipti milli timeline-færslna nota `contentTransition` og `transition`.

## Þrjú útlit á appinu

1. **Bento**: flísar með hring, banked + „Nota eitt“, næsta reset, graf yfir bil og afrek. Fylgir kerfisútliti.
2. **Norðurljós**: dökkt, risastór teljari yfir norðurljósa-gradient, lárétt tímalína yfir resets.
3. **Glóð**: leikjavætt, sami karakter og widget A, peningakrukka og afrek.

## Fídusar

- Stílval á widgets (AppIntentConfiguration)
- Tölfræði-flipi: bil milli resets, meðalbil, lengsta bið, resets á mánuði (Swift Charts)
- Forecast-spjald úr `WatchSignal`
- Live Activity með niðurtalningu að scheduled reset (ActivityKit)
- Control Center takki „Used banked reset“ (`ControlWidgetButton`, iOS 18) sem notar `MarkBankedResetUsedIntent`
- Afrek, reiknuð staðbundið (nýtt `AchievementLog` í `PersistedState`)
- Deilispjald með `ImageRenderer` + `ShareLink`
- Konfetti og haptic innan celebration-gluggans
- Alternate app icons per þema
- StandBy stillingar
- Íslensk þýðing (valkvætt)

## Áfangar

1. **Grunnur**: `WidgetStyle`, `Mood` og `ResetStatsDerivation` í `CodexResetCore` með `swift test` prófum. Sameiginleg þema-tokens. DESIGN.md uppfært.
2. **Widgets**: Glóð, Arcade, Hringur í small og medium, accented útgáfa, Control Center takki.
3. **Appið**: valið útlit á Status, tölfræði-flipi, forecast, fögnuður, deilispjald (afrek ef útlit 3 er valið).
4. **Kerfið**: Live Activity, push-to-start frá worker (viðbót í `backend/`), alternate icons, þýðing.

Hvert áfangi er sér PR. iOS-hlutinn er bara compileaður á Mac-runner í GitHub Actions (sjá README).

## App Store

Engin OpenAI lógó eða merki. Glóð er eigin karakter; ef hann færi að líkjast merki OpenAI gæti það fallið undir App Review Guidelines 5.2. „Not affiliated with OpenAI“ og tilvísun í Codex Resets heldur sér.

## Heimildir

- https://developer.apple.com/documentation/widgetkit/appintentconfiguration
- https://developer.apple.com/documentation/widgetkit/controlwidget
- https://developer.apple.com/documentation/activitykit
- https://developer.apple.com/design/human-interface-guidelines/widgets
- https://developer.apple.com/documentation/swiftui/imagerenderer
- https://developer.apple.com/app-store/review/guidelines/#intellectual-property
- https://codex-resets.com/api/docs
