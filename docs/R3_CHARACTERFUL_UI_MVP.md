# RELIC & RESERVE — Characterful UI MVP

Status date: 2026-08-23 (Asia/Seoul)

This is a required part of the current ten-stage MVP. Finishing it is not permission to stop the remaining MVP work, declare the game complete, or create held Windows/package artifacts.

## Design rule

Characters are functional UI. A face, pose and role prop make the current speaker and transient reaction legible before the player reads a compact dialogue line. Critical gameplay facts still use a short icon-plus-text label.

The direction is informed by three interaction patterns without copying their characters or assets:

- Potionomics uses visible character reactions to make complicated shop and negotiation state clearer and more charming.
- Recettear pairs recognizable shop participants with compact conversation presentation during merchant interactions.
- Strange Horticulture makes a customer's arrival and request the readable front edge of a deduction/shop interaction and uses tactile presentation to draw attention.

All production portraits are original project-native SVG, rendered by Godot controls. External generated/downloaded bitmaps and imitations of existing game characters are prohibited.

## Exact production roster

There are exactly eighteen base bust portraits in `assets/ui/portraits/`:

| Asset ID | Runtime identity | Required visual signature |
|---|---|---|
| `auctioneer` | recurring auctioneer | plum tailcoat, gold gavel pin, swept hair |
| `shopkeeper` | recurring artifact merchant | ochre apron, loupe, inventory pouch |
| `bidder_01` | Private Collector | burgundy coat, monocle, cameo case |
| `bidder_02` | Professional Dealer | emerald lapel, ledger, pencil |
| `bidder_03` | Museum Buyer | navy suit, museum-column pin, folder |
| `bidder_04` | Interior Decorator | lilac scarf, color swatches, angular hair |
| `bidder_05` | Mechanical Enthusiast | brass goggles, wrench, rolled sleeves |
| `bidder_06` | Speculator | charcoal jacket, coin pin, sharp fringe |
| `bidder_07` | Historian | sepia cardigan, scroll tie, soft curls |
| `bidder_08` | Restoration Collector | teal apron, conservation brush, bun |
| `bidder_09` | Archive Curator | olive vest, round glasses, archive ribbon |
| `bidder_10` | Estate Broker | rust coat, key ring, side-part hair |
| `bidder_11` | Design Scholar | indigo collar, geometry brooch, asymmetrical glasses |
| `bidder_12` | Clockmaker | blue work coat, gear loupe, curled moustache |
| `event_courier` | delivery/storage events | coral cap, parcel strap, tag clipboard |
| `event_patron` | collector/estate/commission events | rose capelet, sealed request card |
| `event_curator` | museum/provenance/integrity events | turquoise jacket, white gloves, archive card |
| `event_reporter` | market/trend/weather events | amber beret, note card, tiny megaphone pin |

A recolor is never counted as a separate character. Every base has a distinct face, hair shape, torso silhouette and signature prop. The face occupies a substantial portion of the bust and remains readable at 220×250: both eyes show sclera, large iris/pupil and highlight, with distinct brows, nose/mouth and expression. Dot/slit eyes, accessory-only differentiation and circular-head/body placeholders fail the gate.

## Data and rendering contract

Character identity and transient presentation are separate:

```text
CharacterProfile
  character_id
  role
  display_name_key
  portrait_asset_id
  personality
  base_palette
  signature_accessory
  accessibility_label_key

CharacterCue
  character_id
  expression       # NEUTRAL | POSITIVE | NEGATIVE
  semantic_state
  dialogue_key
  palette_variant
  accessory_variant
```

One generic `PortraitDialoguePanel` consumes both records. It must not branch on a case, stage, bidder or event ID. The renderer exposes a programmatic `name + role + state + dialogue` label.

The semantic states are:

- auctioneer: `INTRO`, `CALL`, `SOLD`;
- bidder: `WATCH`, `BID`, `DROPOUT`, `WON`;
- shopkeeper: `WELCOME`, `OFFER`, `PURCHASE_OK`, `PURCHASE_FAIL`;
- event character: `REQUEST`, `REACTION_POS`, `REACTION_NEG`.

The base SVGs use one normalized face anchor. Expression overlays alter eyebrow, eye and mouth geometry while identity art remains stable. Mood color is supporting decoration only.

## Flow integration

### Auction

At 1280×720, the dominant current price or SOLD/NO SALE state and its one primary action occupy the first visual position. The active/final bidder portrait plus at most two short public reasons follow; the recurring auctioneer is the final supporting rail and never repeats the price in dialogue. Entry emits `INTRO`; bidding rows expose bidder portraits and `BID`/`DROPOUT`; the result exposes winner `WON` and auctioneer `SOLD`. Terminal results show exactly one aggregate key reason. Repeated automatic cues from the same bidder are debounced. Portrait updates never change the authoritative auction result or steal focus.

### Market purchase

The shopkeeper sits left of the compact lot list. Entry shows `WELCOME`, actual selection change shows `OFFER`, and a purchase attempt shows `PURCHASE_OK` or `PURCHASE_FAIL`. Scrolling without selection change does not spam dialogue. A failure always retains its short reason label.

### Activated daily event

The daily-event summary includes the mapped event character beside a compact result card. Activation displays `REQUEST` when the flow has a pre-resolution phase; the current automatic event flow at minimum displays the derived positive/negative reaction immediately with the authoritative applied result. The portrait never invents a choice that the runtime does not support.

Event-character mapping is by semantic effect family, not a renderer branch: delivery/storage → courier; estate/collector/commission → patron; museum/provenance/integrity → curator; market/trend/other daily conditions → reporter.

## Text and accessibility limits

- Speech is normally one Korean line, targets 24 characters, and never exceeds two rendered lines or roughly 44 characters.
- Portraits may replace emotional flavor such as confidence, surprise or satisfaction.
- Portraits may not replace price, reserve state, dropout state, insufficient-funds reason, risk, reliability, event result or a gameplay modifier.
- Portrait art without an action is not a Tab stop. Dialogue progression, when modal, supports Enter and Space.
- Expression and palette never carry critical meaning without a short shape/icon-plus-text state label.
- Locale refresh preserves the current auction/shop/event screen and focus. Dialogue is translation-key driven.
- Save files do not persist facial animation. Reload derives a cue from authoritative auction/shop/event state.

## Stage variation

Identity stays fixed. Stages 1–3 use the early wardrobe accent, 4–7 the mid accent and 8–10 the late accent. Only accent palette, a small accessory and slight pose may vary deterministically. Face, hair, torso silhouette and signature prop remain recognizable. An event character cannot appear in two consecutive unrelated event beats when another compatible member is available.

## Acceptance gate

1. Exactly eighteen distinct base portrait SVGs exist and all twelve bidders have unique asset IDs.
2. Every portrait contains a face, hair, upper-body outfit and signature prop. At the actual 220×250 rail size, the hair-inclusive head occupies roughly 44–52% of the bust height and both eyes retain visible sclera, a large iris/pupil and a 2–4 px highlight. Placeholder silhouettes, dot/slit eyes and faces that disappear after scaling are zero.
3. Auction entry, bids/dropouts and sale result show the correct auctioneer/bidder identity and semantic cue.
4. Market entry, selection, purchase success and failure show the correct shopkeeper cue.
5. Activated events show a mapped event character and an accurate result reaction.
6. Every flow uses the same generic portrait/dialogue renderer with no ID-specific renderer branches.
7. At 1280×720 speech never exceeds two lines and no raw ID/token reaches player-facing text.
8. The eighteen-character neutral contact sheet remains non-cloned in grayscale: at least 16/18 identities are immediately distinguishable by hair, face and shoulder silhouette, and every identity differs from the others on at least three high-visibility axes among face, eye, brow, hair, outfit and prop.
9. A representative expression-triplet sheet proves that `NEUTRAL`, `POSITIVE` and `NEGATIVE` alter at least two of brow, eye and mouth geometry. Color/blush alone never counts as an expression change, and no critical gameplay fact depends on expression alone.
10. Fresh headless in-flow captures prove that the V2 assets—not a stale import—remain large and face-legible in auction, market and event layouts. A validator PASS without these visual captures is not art approval.
11. Locale refresh and save/reload reconstruct the correct cue without breaking keyboard focus/navigation.
12. Stage variants are deterministic and leave M1, authored-case, stage, save and economy results unchanged.

Full-body characters, skeletal animation, Live2D, lip sync, voice/TTS, 3D NPCs, romance/free conversation, one unique person per event, bitmap portraits and more than eighteen base portraits are outside this MVP. They may be reconsidered only after the rest of the game work continues beyond this technical milestone.
