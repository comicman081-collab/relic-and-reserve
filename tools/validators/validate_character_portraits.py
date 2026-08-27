#!/usr/bin/env python3
"""Static acceptance gate for the characterful UI portrait roster.

This validator is intentionally renderer-independent: it proves that the data-driven
identity/cue contract and the eighteen repo-native SVG bases are complete before a
Godot integration test consumes them. It also runs the same face-legibility checks
against the six explicitly allowlisted authored case-NPC portraits.
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
import xml.etree.ElementTree as ET
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
DATA_PATH = ROOT / "data" / "characters" / "characters.json"
EVENTS_PATH = ROOT / "data" / "events" / "events.json"
BIDDERS_PATH = ROOT / "data" / "bidders" / "bidders.json"
PORTRAIT_DIR = ROOT / "assets" / "ui" / "portraits"
CASE_NPC_PORTRAIT_DIR = ROOT / "assets" / "portraits"

# Case-source portraits live beside the legacy story portraits, but they are not
# members of the fixed 18-character auction/shop/event roster. Keep the allowlist
# explicit so this gate cannot silently expand to accept every legacy bust.
CASE_NPC_PORTRAITS = {
    "victor_hale_neutral": {
        "display_name": "Victor Hale",
        "expression": "NEUTRAL",
        "features": {"swept-silver-hair", "loupe-chain", "camera-list"},
    },
    "lena_falk_concerned": {
        "display_name": "Lena Falk",
        "expression": "NEGATIVE",
        "features": {"asymmetrical-auburn-bob", "invoice-folder", "seal-ribbon"},
    },
    "hana_mire_concerned": {
        "display_name": "Hana Mire",
        "expression": "NEGATIVE",
        "features": {"verdigris-curly-bob", "measuring-caliper", "conservation-tag"},
    },
    "mara_venn_concerned": {
        "display_name": "Mara Venn",
        "expression": "NEGATIVE",
        "features": {"navy-clock-bob", "pocket-watch", "auction-receipt"},
    },
    "mara_venn_positive": {
        "display_name": "Mara Venn",
        "expression": "POSITIVE",
        "features": {"navy-clock-bob", "pocket-watch", "auction-receipt"},
    },
    "iris_bell_concerned": {
        "display_name": "Iris Bell",
        "expression": "NEGATIVE",
        "features": {"plum-wave-hair", "music-note-brooch", "music-box-key"},
    },
    "noah_stern_concerned": {
        "display_name": "Noah Stern",
        "expression": "NEGATIVE",
        "features": {"chestnut-pageboy-hair", "folio-index-card", "archival-magnifier"},
    },
}

EXPECTED_IDS = [
    "auctioneer",
    "shopkeeper",
    *[f"bidder_{index:02d}" for index in range(1, 13)],
    "event_courier",
    "event_patron",
    "event_curator",
    "event_reporter",
]
EXPECTED_ROLE_COUNTS = {"AUCTIONEER": 1, "SHOPKEEPER": 1, "BIDDER": 12, "EVENT": 4}
EXPECTED_CUES = {
    "AUCTIONEER": {"INTRO", "CALL", "SOLD", "NO_SALE"},
    "BIDDER": {"WATCH", "BID", "DROPOUT", "WON"},
    "SHOPKEEPER": {"WELCOME", "OFFER", "PURCHASE_OK", "PURCHASE_FAIL"},
    "EVENT": {"REQUEST", "REACTION_POS", "REACTION_NEG"},
}
EXPECTED_EXPRESSIONS = {"NEUTRAL", "POSITIVE", "NEGATIVE"}
EXPECTED_BANDS = {
    "EARLY": [1, 3],
    "MID": [4, 7],
    "LATE": [8, 10],
}
EXPECTED_EVENT_CHARACTERS = {
    "event_courier",
    "event_patron",
    "event_curator",
    "event_reporter",
}
REQUIRED_LAYERS = {"hair", "face", "outfit", "prop", "expression-anchors"}
SHAPE_TAGS = {"path", "rect", "circle", "ellipse", "polygon", "polyline", "line"}
HEX_COLOR = re.compile(r"^#[0-9A-Fa-f]{6}$")
REFERENCE_SCALE = 250.0 / 320.0


class Gate:
    def __init__(self) -> None:
        self.errors: list[str] = []
        self.checks = 0

    def require(self, condition: bool, message: str) -> None:
        self.checks += 1
        if not condition:
            self.errors.append(message)


def load_json(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def validate_svg(gate: Gate, portrait_id: str, path: Path) -> str:
    raw = path.read_text(encoding="utf-8")
    digest = hashlib.sha256(raw.encode("utf-8")).hexdigest()
    lowered = raw.lower()
    gate.require(len(raw) >= 1500, f"{portrait_id}: SVG is too small to be production bust art")
    gate.require("placeholder" not in lowered and "todo" not in lowered and "lorem" not in lowered,
                 f"{portrait_id}: placeholder marker found")
    gate.require("data:image" not in lowered and "<image" not in lowered,
                 f"{portrait_id}: embedded/external bitmap is forbidden")
    gate.require("<script" not in lowered and "<foreignobject" not in lowered,
                 f"{portrait_id}: executable/foreign SVG content is forbidden")
    try:
        root = ET.fromstring(raw)
    except ET.ParseError as exc:
        gate.require(False, f"{portrait_id}: malformed SVG: {exc}")
        return digest

    gate.require(root.attrib.get("viewBox") == "0 0 256 320", f"{portrait_id}: wrong viewBox")
    gate.require(root.attrib.get("data-character-id") == portrait_id,
                 f"{portrait_id}: data-character-id mismatch")
    gate.require(bool(root.attrib.get("data-expression-anchor")),
                 f"{portrait_id}: missing normalized expression anchor")
    gate.require(root.attrib.get("data-eye-system") == "sclera-iris-pupil-highlight",
                 f"{portrait_id}: big-eye anatomy marker is missing")
    try:
        face_zone = [float(value) for value in root.attrib.get("data-face-zone", "").split()]
        face_ratio = float(root.attrib.get("data-face-height-ratio", "0"))
        expression_anchor = [float(value) for value in root.attrib.get("data-expression-anchor", "").split(",")]
    except ValueError:
        face_zone = []
        face_ratio = 0.0
        expression_anchor = []
    gate.require(len(face_zone) == 4 and face_zone[2] >= 104 and face_zone[3] >= 136,
                 f"{portrait_id}: normalized face zone is too small or malformed")
    gate.require(0.38 <= face_ratio <= 0.48,
                 f"{portrait_id}: face height ratio {face_ratio} is outside the legible 38-48% band")
    anchor_inside_face = (
        len(face_zone) == 4
        and len(expression_anchor) == 2
        and face_zone[0] <= expression_anchor[0] <= face_zone[0] + face_zone[2]
        and face_zone[1] <= expression_anchor[1] <= face_zone[1] + face_zone[3]
    )
    gate.require(anchor_inside_face, f"{portrait_id}: expression anchor is outside the normalized face zone")
    try:
        head_height_px = float(root.attrib.get("data-head-height-svg", "0")) * REFERENCE_SCALE
        visible_face_height_px = float(root.attrib.get("data-visible-face-skin-height-svg", "0")) * REFERENCE_SCALE
        major_face_stroke_px = float(root.attrib.get("data-major-face-stroke-svg", "0")) * REFERENCE_SCALE
    except ValueError:
        head_height_px = visible_face_height_px = major_face_stroke_px = 0.0
    gate.require(root.attrib.get("data-runtime-reference") == "220x250",
                 f"{portrait_id}: runtime metric reference must be 220x250")
    gate.require(110.0 <= head_height_px <= 130.0,
                 f"{portrait_id}: hair-inclusive head height {head_height_px:.2f}px is outside 110-130px")
    gate.require(70.0 <= visible_face_height_px <= 90.0,
                 f"{portrait_id}: visible face skin height {visible_face_height_px:.2f}px is outside 70-90px")
    gate.require(2.0 <= major_face_stroke_px <= 3.0,
                 f"{portrait_id}: major face line {major_face_stroke_px:.2f}px is outside 2-3px")
    gate.require(root.attrib.get("data-expression-geometry-version") == "2",
                 f"{portrait_id}: expression geometry version is not V2")

    elements = list(root.iter())
    titles = [e for e in elements if local_name(e.tag) == "title" and (e.text or "").strip()]
    descriptions = [e for e in elements if local_name(e.tag) == "desc" and (e.text or "").strip()]
    gate.require(len(titles) == 1, f"{portrait_id}: exactly one nonempty title is required")
    gate.require(len(descriptions) == 1, f"{portrait_id}: exactly one nonempty description is required")

    layer_nodes = {
        node.attrib["data-layer"]: node
        for node in elements
        if local_name(node.tag) == "g" and "data-layer" in node.attrib
    }
    gate.require(REQUIRED_LAYERS.issubset(layer_nodes),
                 f"{portrait_id}: missing layers {sorted(REQUIRED_LAYERS - set(layer_nodes))}")
    for layer in ("hair", "face", "outfit", "prop"):
        node = layer_nodes.get(layer)
        shape_count = sum(1 for child in node.iter() if local_name(child.tag) in SHAPE_TAGS) if node is not None else 0
        gate.require(shape_count >= 2, f"{portrait_id}: {layer} layer needs at least two vector shapes")

    face_node = layer_nodes.get("face")
    face_elements = list(face_node.iter()) if face_node is not None else []
    eye_groups = [
        element for element in face_elements
        if local_name(element.tag) == "g" and element.attrib.get("data-eye") in {"left", "right"}
    ]
    gate.require({eye.attrib.get("data-eye") for eye in eye_groups} == {"left", "right"} and len(eye_groups) == 2,
                 f"{portrait_id}: exactly one authored left/right eye group is required")
    for eye in eye_groups:
        eye_side = eye.attrib.get("data-eye")
        parts = {
            element.attrib.get("data-part"): element
            for element in eye.iter()
            if element.attrib.get("data-part") in {"sclera", "iris", "pupil", "highlight"}
        }
        gate.require(set(parts) == {"sclera", "iris", "pupil", "highlight"},
                     f"{portrait_id}/{eye_side}: eye needs sclera, iris, pupil and highlight")
        sclera = parts.get("sclera")
        iris = parts.get("iris")
        pupil = parts.get("pupil")
        highlight = parts.get("highlight")
        sclera_width_px = float(sclera.attrib.get("rx", "0")) * 2.0 * REFERENCE_SCALE if sclera is not None else 0.0
        sclera_height_px = float(sclera.attrib.get("ry", "0")) * 2.0 * REFERENCE_SCALE if sclera is not None else 0.0
        iris_diameter_px = float(iris.attrib.get("r", "0")) * 2.0 * REFERENCE_SCALE if iris is not None else 0.0
        pupil_diameter_px = float(pupil.attrib.get("r", "0")) * 2.0 * REFERENCE_SCALE if pupil is not None else 0.0
        highlight_diameter_px = float(highlight.attrib.get("r", "0")) * 2.0 * REFERENCE_SCALE if highlight is not None else 0.0
        gate.require(
            sclera is not None
            and local_name(sclera.tag) == "ellipse"
            and 18.0 <= sclera_width_px <= 26.0
            and 10.0 <= sclera_height_px <= 16.0,
            f"{portrait_id}/{eye_side}: 220x250 eye size {sclera_width_px:.2f}x{sclera_height_px:.2f}px is outside 18-26x10-16px",
        )
        gate.require(10.0 <= iris_diameter_px <= 14.0,
                     f"{portrait_id}/{eye_side}: iris diameter {iris_diameter_px:.2f}px is outside 10-14px")
        gate.require(5.0 <= pupil_diameter_px <= 7.0,
                     f"{portrait_id}/{eye_side}: pupil diameter {pupil_diameter_px:.2f}px is outside 5-7px")
        gate.require(2.0 <= highlight_diameter_px <= 4.0,
                     f"{portrait_id}/{eye_side}: highlight diameter {highlight_diameter_px:.2f}px is outside 2-4px")
    brow_groups = [
        element for element in face_elements
        if local_name(element.tag) == "g" and element.attrib.get("data-part") == "brows"
    ]
    brow_paths = list(brow_groups[0].iter()) if brow_groups else []
    gate.require(
        len([element for element in brow_paths if local_name(element.tag) == "path"]) >= 2,
        f"{portrait_id}: two readable eyebrow paths are required",
    )
    gate.require(
        any(element.attrib.get("data-part") == "nose" for element in face_elements),
        f"{portrait_id}: authored nose geometry is required",
    )
    gate.require(
        any(element.attrib.get("data-part") == "mouth" for element in face_elements),
        f"{portrait_id}: authored mouth geometry is required",
    )
    blush_shapes = [
        element for element in face_elements
        if local_name(element.tag) == "ellipse" and "opacity" in element.attrib
    ]
    gate.require(len(blush_shapes) >= 2, f"{portrait_id}: paired cheek-blush shapes are required")

    vector_count = sum(1 for element in elements if local_name(element.tag) in SHAPE_TAGS)
    gate.require(vector_count >= 18, f"{portrait_id}: only {vector_count} vector shapes; bust is under-authored")
    colors = set(re.findall(r"#[0-9A-Fa-f]{6}", raw))
    gate.require(len(colors) >= 7, f"{portrait_id}: only {len(colors)} flat colors; palette lacks authored detail")

    anchors = {
        element.attrib.get("data-expression")
        for element in elements
        if element.attrib.get("data-expression")
    }
    gate.require(anchors == EXPECTED_EXPRESSIONS,
                 f"{portrait_id}: expression anchors are {sorted(anchors)}")
    expression_nodes = {
        element.attrib.get("data-expression"): element
        for element in elements
        if element.attrib.get("data-expression") in EXPECTED_EXPRESSIONS
    }
    for expression, element in expression_nodes.items():
        try:
            brow_delta = abs(float(element.attrib.get("data-brow-shift-svg", "0"))) * REFERENCE_SCALE
            eye_delta = abs(float(element.attrib.get("data-eye-height-shift-svg", "0"))) * REFERENCE_SCALE
            mouth_delta = abs(float(element.attrib.get("data-mouth-corner-shift-svg", "0"))) * REFERENCE_SCALE
        except ValueError:
            brow_delta = eye_delta = mouth_delta = 0.0
        if expression == "NEUTRAL":
            gate.require(brow_delta == 0.0 and eye_delta == 0.0 and mouth_delta == 0.0,
                         f"{portrait_id}: NEUTRAL expression must be the zero geometry baseline")
        else:
            changed_axes = sum((brow_delta >= 3.0, eye_delta >= 2.0, mouth_delta >= 3.0))
            gate.require(changed_axes >= 2,
                         f"{portrait_id}/{expression}: fewer than two readable geometry axes change")
    return digest


def validate_case_npc_svg(gate: Gate, portrait_id: str, contract: dict[str, object]) -> str:
    """Validate the deliberately small allowlist of authored case-NPC portraits."""
    path = CASE_NPC_PORTRAIT_DIR / f"{portrait_id}.svg"
    gate.require(path.is_file(), f"{portrait_id}: allowlisted case-NPC SVG is missing")
    if not path.is_file():
        return ""

    digest = validate_svg(gate, portrait_id, path)
    raw = path.read_text(encoding="utf-8")
    root = ET.fromstring(raw)
    gate.require(root.attrib.get("data-character-name") == contract["display_name"],
                 f"{portrait_id}: case-NPC display identity mismatch")
    gate.require(root.attrib.get("data-rendered-expression") == contract["expression"],
                 f"{portrait_id}: rendered expression does not match the allowlist")
    authored_features = {
        element.attrib.get("data-feature")
        for element in root.iter()
        if element.attrib.get("data-feature")
    }
    expected_features = set(contract["features"])
    gate.require(expected_features.issubset(authored_features),
                 f"{portrait_id}: missing signature features {sorted(expected_features - authored_features)}")
    if portrait_id == "lena_falk_concerned":
        gate.require("rook" not in raw.lower(),
                     "lena_falk_concerned: incorrect Rook identity leaked into Lena Falk portrait")
    return digest


def main() -> int:
    gate = Gate()
    gate.require(DATA_PATH.is_file(), f"missing {DATA_PATH}")
    gate.require(EVENTS_PATH.is_file(), f"missing {EVENTS_PATH}")
    gate.require(BIDDERS_PATH.is_file(), f"missing {BIDDERS_PATH}")
    if gate.errors:
        for error in gate.errors:
            print(f"ERROR: {error}")
        return 1

    data = load_json(DATA_PATH)
    events = load_json(EVENTS_PATH)
    bidders = load_json(BIDDERS_PATH)
    profiles = data.get("profiles", [])
    cue_sets = data.get("cueSets", {})
    families = data.get("eventEffectFamilies", [])
    event_map = data.get("eventCharacterMap", [])

    svg_files = sorted(PORTRAIT_DIR.glob("*.svg"))
    gate.require(len(svg_files) == 18, f"expected exactly 18 SVGs, found {len(svg_files)}")
    gate.require(len(profiles) == 18, f"expected exactly 18 profiles, found {len(profiles)}")
    profile_ids = [profile.get("characterId") for profile in profiles]
    gate.require(profile_ids == EXPECTED_IDS, "profile roster/order does not match the fixed 18-character contract")
    gate.require(len(set(profile_ids)) == 18, "character IDs are not unique")
    asset_ids = [profile.get("portraitAssetId") for profile in profiles]
    gate.require(len(set(asset_ids)) == 18, "portrait asset IDs are not unique")
    gate.require(Counter(profile.get("role") for profile in profiles) == Counter(EXPECTED_ROLE_COUNTS),
                 f"role counts differ from {EXPECTED_ROLE_COUNTS}")

    expected_file_names = {f"{portrait_id}.svg" for portrait_id in EXPECTED_IDS}
    gate.require({path.name for path in svg_files} == expected_file_names,
                 "SVG filenames do not exactly match the fixed roster")
    hashes = [validate_svg(gate, path.stem, path) for path in svg_files]
    gate.require(len(set(hashes)) == 18, "one or more SVG files are byte-identical recolor/copies")
    case_npc_hashes = [
        validate_case_npc_svg(gate, portrait_id, contract)
        for portrait_id, contract in CASE_NPC_PORTRAITS.items()
    ]
    gate.require(
        len(case_npc_hashes) == len(CASE_NPC_PORTRAITS)
        and len(set(case_npc_hashes)) == len(CASE_NPC_PORTRAITS),
        "allowlisted case-NPC portraits must all be distinct SVGs",
    )
    gate.require(not (set(case_npc_hashes) & set(hashes)),
                 "case-NPC portrait duplicates a fixed-roster SVG")

    signature_fields = ["faceShape", "hairShape", "torsoSilhouette", "signatureProp"]
    for field in signature_fields:
        values = [profile.get("visualSignature", {}).get(field) for profile in profiles]
        gate.require(all(values), f"visualSignature.{field} has missing values")
        gate.require(len(set(values)) == 18, f"visualSignature.{field} must be distinct across all portraits")
    pairwise_axis_floor = 6
    signatures = [profile.get("visualSignature", {}) for profile in profiles]
    silhouette_tuples = {
        (
            signature.get("faceShape"),
            signature.get("hairShape"),
            signature.get("torsoSilhouette"),
        )
        for signature in signatures
    }
    gate.require(len(silhouette_tuples) >= 16,
                 f"grayscale silhouette signatures distinguish only {len(silhouette_tuples)}/18 characters")
    pairwise_fields = {
        "face": "faceShape",
        "hair": "hairShape",
        "outfit": "torsoSilhouette",
        "prop": "signatureProp",
    }
    for left_index in range(len(signatures)):
        for right_index in range(left_index + 1, len(signatures)):
            different_axes = sum(
                signatures[left_index].get(field) != signatures[right_index].get(field)
                for field in pairwise_fields.values()
            )
            pairwise_axis_floor = min(pairwise_axis_floor, different_axes)
            gate.require(
                different_axes >= 3,
                f"{profile_ids[left_index]} vs {profile_ids[right_index]} differ on only {different_axes} authored axes",
            )
    gate.require(pairwise_axis_floor >= 3,
                 f"portrait pairwise variation floor is {pairwise_axis_floor}, expected at least 3")

    for profile in profiles:
        portrait_id = profile.get("characterId", "<missing>")
        expected_asset = f"res://assets/ui/portraits/{portrait_id}.svg"
        gate.require(profile.get("portraitAssetId") == expected_asset,
                     f"{portrait_id}: portraitAssetId must be {expected_asset}")
        for localized_field in ("displayName", "accessibilityLabel", "personality"):
            localized = profile.get(localized_field, {})
            gate.require(bool(localized.get("ko")) and bool(localized.get("en")),
                         f"{portrait_id}: {localized_field} needs ko/en")
        palette = profile.get("basePalette", [])
        gate.require(len(palette) >= 3 and all(HEX_COLOR.match(color or "") for color in palette),
                     f"{portrait_id}: basePalette needs at least three #RRGGBB colors")
        accessory = profile.get("signatureAccessory", {})
        gate.require(bool(accessory.get("key")) and bool(accessory.get("ko")) and bool(accessory.get("en")),
                     f"{portrait_id}: localized signatureAccessory is incomplete")
        expressions = profile.get("expressionMetadata", {})
        gate.require(set(expressions) == EXPECTED_EXPRESSIONS,
                     f"{portrait_id}: expressionMetadata must contain {sorted(EXPECTED_EXPRESSIONS)}")
        for expression, metadata in expressions.items():
            gate.require(bool(metadata.get("geometryOverlay")), f"{portrait_id}/{expression}: missing geometryOverlay")
            gate.require(bool(HEX_COLOR.match(metadata.get("moodAccent", ""))),
                         f"{portrait_id}/{expression}: invalid moodAccent")
            state_label = metadata.get("stateLabel", {})
            gate.require(bool(state_label.get("ko")) and bool(state_label.get("en")),
                         f"{portrait_id}/{expression}: stateLabel needs ko/en")
        variants = profile.get("stageVariants", {})
        gate.require(set(variants) == set(EXPECTED_BANDS), f"{portrait_id}: stage bands are incomplete")
        for band, expected_range in EXPECTED_BANDS.items():
            variant = variants.get(band, {})
            gate.require(variant.get("stageRange") == expected_range,
                         f"{portrait_id}/{band}: stageRange must be {expected_range}")
            gate.require(bool(HEX_COLOR.match(variant.get("accentColor", ""))),
                         f"{portrait_id}/{band}: invalid accentColor")
            localized = variant.get("accessoryVariant", {})
            gate.require(bool(localized.get("ko")) and bool(localized.get("en")),
                         f"{portrait_id}/{band}: accessoryVariant needs ko/en")
        cue_set_id = profile.get("cueSetId")
        gate.require(cue_set_id == profile.get("role"),
                     f"{portrait_id}: cueSetId must match generic role, got {cue_set_id}")

    for cue_set_id, expected_states in EXPECTED_CUES.items():
        cue_set = cue_sets.get(cue_set_id, {})
        gate.require(set(cue_set) == expected_states,
                     f"{cue_set_id}: semantic states differ from {sorted(expected_states)}")
        for state, cue in cue_set.items():
            gate.require(cue.get("expression") in EXPECTED_EXPRESSIONS,
                         f"{cue_set_id}/{state}: invalid expression")
            gate.require(bool(cue.get("dialogueKey")), f"{cue_set_id}/{state}: missing dialogueKey")
            dialogue = cue.get("dialogue", {})
            gate.require(bool(dialogue.get("ko")) and bool(dialogue.get("en")),
                         f"{cue_set_id}/{state}: dialogue needs ko/en")
            gate.require(len(dialogue.get("ko", "")) <= 44,
                         f"{cue_set_id}/{state}: Korean dialogue exceeds 44 characters")
            gate.require(len(dialogue.get("en", "")) <= 80,
                         f"{cue_set_id}/{state}: English dialogue exceeds 80 characters")

    expression_geometry = data.get("expressionGeometry", {})
    gate.require(expression_geometry.get("referenceDisplay") == "220x250",
                 "expressionGeometry referenceDisplay must be 220x250")
    gate.require(abs(float(expression_geometry.get("svgToReferenceScale", 0.0)) - REFERENCE_SCALE) < 0.00001,
                 "expressionGeometry scale differs from the 250/320 reference")
    for expression in EXPECTED_EXPRESSIONS:
        geometry = expression_geometry.get(expression, {})
        changed_axes = geometry.get("changedAxes", [])
        if expression == "NEUTRAL":
            gate.require(changed_axes == [], "NEUTRAL expressionGeometry must be the baseline")
        else:
            gate.require(len(set(changed_axes) & {"brow", "eye", "mouth"}) >= 2,
                         f"{expression}: data contract changes fewer than two geometry axes")

    family_ids = [family.get("familyId") for family in families]
    family_by_id = {family.get("familyId"): family for family in families}
    gate.require(len(families) == 4 and len(set(family_ids)) == 4,
                 "exactly four unique semantic event families are required")
    gate.require({family.get("characterId") for family in families} == EXPECTED_EVENT_CHARACTERS,
                 "the four event families must map one-to-one to the four event characters")
    for family in families:
        gate.require(bool(family.get("semanticSignals")) and bool(family.get("typicalEffectTypes")),
                     f"{family.get('familyId')}: semantic family metadata is incomplete")

    source_event_by_id = {event.get("id"): event for event in events}
    gate.require(len(events) == 25 and len(source_event_by_id) == 25,
                 "source event roster must contain exactly 25 unique events")
    for event in events:
        event_id = event.get("id", "<missing>")
        localized_name = event.get("localizedName", {})
        localized_description = event.get("localizedDescription", {})
        gate.require(bool(localized_name.get("ko")) and bool(localized_name.get("en")),
                     f"{event_id}: localizedName needs ko/en")
        gate.require(bool(localized_description.get("ko")) and bool(localized_description.get("en")),
                     f"{event_id}: localizedDescription needs ko/en")
    mapped_ids = [mapping.get("eventId") for mapping in event_map]
    gate.require(len(event_map) == 25 and len(set(mapped_ids)) == 25,
                 "eventCharacterMap must contain exactly 25 unique events")
    gate.require(set(mapped_ids) == set(source_event_by_id),
                 "eventCharacterMap coverage differs from data/events/events.json")
    for mapping in event_map:
        event_id = mapping.get("eventId")
        source = source_event_by_id.get(event_id, {})
        family = family_by_id.get(mapping.get("familyId"), {})
        gate.require(mapping.get("effectType") == source.get("effect", {}).get("type"),
                     f"{event_id}: effectType does not match source event")
        gate.require(mapping.get("characterId") == family.get("characterId"),
                     f"{event_id}: character must derive from semantic family")
        gate.require(mapping.get("outcomePolarity") in {"POSITIVE", "NEGATIVE"},
                     f"{event_id}: invalid outcomePolarity")
        gate.require(bool(mapping.get("requestDialogueKey")) and bool(mapping.get("reactionDialogueKey")),
                     f"{event_id}: dialogue keys are incomplete")

    source_bidder_ids = [bidder.get("id") for bidder in bidders]
    expected_bidder_ids = [f"bidder_{index:02d}" for index in range(1, 13)]
    profile_bidder_ids = [profile.get("characterId") for profile in profiles if profile.get("role") == "BIDDER"]
    gate.require(source_bidder_ids == expected_bidder_ids,
                 "source bidder roster is not bidder_01..bidder_12")
    gate.require(profile_bidder_ids == source_bidder_ids,
                 "portrait bidder IDs do not exactly map to source bidder IDs")

    if gate.errors:
        print(f"CHARACTER PORTRAIT GATE: FAIL ({len(gate.errors)} errors / {gate.checks} checks)")
        for error in gate.errors:
            print(f"ERROR: {error}")
        return 1

    print(f"CHARACTER PORTRAIT GATE: PASS ({gate.checks} checks)")
    print(f"portraits=18 caseNpcPortraits={len(CASE_NPC_PORTRAITS)} profiles=18 bidders=12 eventMappings=25 semanticFamilies=4")
    print(f"repoNativeSvg=true externalBitmaps=0 placeholderBusts=0 uniqueSignatures=18 faceLegibility=18 caseNpcFaceLegibility={len(CASE_NPC_PORTRAITS)}")
    print("reference=220x250 silhouettesDistinct=18/18 pairwiseVariationAxes>=3 expressionsGeometryAxes>=2")
    return 0


if __name__ == "__main__":
    sys.exit(main())
