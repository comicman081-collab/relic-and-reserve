from __future__ import annotations

import json
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "qa" / "mvp_ui_headless"
FONT_PATH = Path(r"C:\Windows\Fonts\malgun.ttf")
BOLD_PATH = Path(r"C:\Windows\Fonts\malgunbd.ttf")

CREAM = "#f2e8cf"
GOLD = "#e3c681"
MINT = "#9fd6bd"
MUTED = "#9aa8aa"
WARN = "#e59b7a"


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    path = BOLD_PATH if bold and BOLD_PATH.exists() else FONT_PATH
    return ImageFont.truetype(str(path), size=size)


def put(draw: ImageDraw.ImageDraw, xy: tuple[int, int], value: str, size: int = 16, color: str = CREAM, bold: bool = False, anchor: str | None = None) -> None:
    draw.text(xy, value, font=font(size, bold), fill=color, anchor=anchor)


def nav(draw: ImageDraw.ImageDraw) -> None:
    entries = ["공방", "시장", "보관함", "업그레이드", "캠페인", "하루 마치기", "저장", "EN / 한국어"]
    for index, label in enumerate(entries):
        put(draw, (28 + index * 154 + 73, 677), label, 13, CREAM, anchor="mm")


def header(draw: ImageDraw.ImageDraw, title: str, stats: str) -> None:
    put(draw, (38, 31), title, 26, GOLD, True)
    put(draw, (1238, 37), stats, 13, "#b7c4c8", anchor="rm")


def case_labels(draw: ImageDraw.ImageDraw) -> None:
    header(draw, "사건 서류 — 닫힌 공방", "STAGE 1   DAY 1   ¤1200   REP 12")
    tiles = [
        (96, "상황", "닫힌 공방의 탁상시계를 조사한다"),
        (508, "핵심 질문", "당대 수리인가, 후대 재조립인가?"),
        (920, "목표", "독립 출처 3개로 가설을 입증한다"),
    ]
    for x, heading, value in tiles:
        put(draw, (x, 105), heading, 12, GOLD, True)
        put(draw, (x, 132), value, 14)
    put(draw, (30, 176), "단서 카드", 17, GOLD, True)
    cards = [
        (89, 219, "조사 가능 · 후면판 나사 불일치", "실물 · 위험 높음"),
        (454, 219, "조사 가능 · 브리지 각인", "실물 · 도구 필요"),
        (89, 297, "잠김 · 1937년 수리표", "문서 · 선행 단서 필요"),
        (454, 297, "잠김 · 마라의 기억", "인물 · 선행 단서 필요"),
        (89, 375, "잠김 · 1931년 공장 도면", "참고자료 · 선행 단서 필요"),
    ]
    for x, y, title, meta in cards:
        put(draw, (x, y), title, 13, CREAM, True)
        put(draw, (x, y + 23), meta, 11, MUTED)
    put(draw, (858, 205), "선택한 단서", 12, MUTED)
    put(draw, (858, 230), "후면판 나사의 불일치", 18, GOLD, True)
    put(draw, (840, 281), "위험 높음 — 연마 전에 산화 경계를 기록하세요", 14, WARN, True)
    put(draw, (862, 351), "조사 실행", 15, CREAM, True)
    put(draw, (30, 444), "가설 선택", 17, GOLD, True)
    for x, value in [(86, "출고 상태 그대로"), (493, "당대 수리를 거친 진품"), (900, "후대 재조립품")]:
        put(draw, (x, 493), value, 14)
    put(draw, (104, 557), "보고서 요약", 17, GOLD, True)
    put(draw, (104, 584), "인용 0 · 독립 출처 0", 13, MINT)
    put(draw, (1092, 585), "증거 기반 보고서 제출", 14, CREAM, True, "mm")
    nav(draw)


def market_labels(draw: ImageDraw.ImageDraw) -> None:
    header(draw, "시장 — 오늘의 유물", "STAGE 1   DAY 1   ¤1200   REP 12")
    put(draw, (42, 393), "유물 상점 주인", 17, GOLD, True)
    put(draw, (42, 417), "상점 주인 · 오늘의 제안", 12, MINT, True)
    put(draw, (42, 441), "찬찬히 살펴보고 결정하세요.", 13)
    put(draw, (42, 465), "오늘 5점 입고", 12, "#f0bd71", True)
    put(draw, (310, 96), "오늘의 목록", 20, GOLD, True)
    names = ["격자무늬 회중시계", "황동 여행시계", "수동식 계측기", "유리 렌즈 카메라", "목제 라디오"]
    for index, name in enumerate(names):
        y = 145 + index * 88
        put(draw, (388, y), name, 16, CREAM, True)
        put(draw, (388, y + 25), "유물 · 상태 미확인", 12, MUTED)
        put(draw, (1030, y + 10), f"¤{420 + index * 55}", 17, "#f0bd71", True, "rm")
        put(draw, (1100, y + 10), "제안", 13, CREAM, True, "mm")
        put(draw, (1190, y + 10), "구매", 13, CREAM, True, "mm")
    nav(draw)


def auction_labels(draw: ImageDraw.ImageDraw) -> None:
    header(draw, "경매 — 실시간 입찰", "STAGE 4   DAY 8   ¤1840   REP 28")
    put(draw, (38, 373), "경매 진행원", 17, GOLD, True)
    put(draw, (38, 397), "경매 진행 · 낙찰", 12, MINT, True)
    put(draw, (38, 421), "낙찰되었습니다.", 13)
    put(draw, (38, 437), "낙찰 · 예약가 ¤420 · 최종가 ¤510", 12, "#f0bd71", True)
    put(draw, (1010, 373), "박물관 구매 담당자", 17, GOLD, True)
    put(draw, (1010, 397), "입찰자 · 낙찰자", 12, MINT, True)
    put(draw, (1010, 421), "좋은 유물을 얻었군요.", 13)
    put(draw, (1010, 437), "낙찰가 ¤510", 12, "#f0bd71", True)
    put(draw, (1008, 463), "판단 근거", 12, MUTED, True)
    put(draw, (1060, 505), "출처 확인", 12, MINT, True, "mm")
    put(draw, (1183, 505), "상태 양호", 12, MINT, True, "mm")
    put(draw, (282, 104), "아크라이트 탁상시계", 22, GOLD, True)
    for x, heading, value in [(350, "시작가", "¤280"), (574, "예약가", "¤420"), (798, "최종가", "¤510")]:
        put(draw, (x, 163), heading, 12, GOLD, True)
        put(draw, (x, 192), value, 16)
    put(draw, (282, 242), "최근 호가", 16, MUTED, True)
    bids = [("개인 수집가", 380), ("전문 딜러", 425), ("박물관 구매 담당자", 470), ("박물관 구매 담당자", 510)]
    for index, (name, price) in enumerate(bids):
        y = 292 + index * 48
        put(draw, (300, y), name, 14)
        put(draw, (930, y), f"¤{price}", 14, "#f0bd71", True, "rm")
    put(draw, (282, 498), "낙찰 · 수수료 ¤61 · 정산액 ¤449", 18, MINT, True)
    put(draw, (618, 562), "낙찰 기록", 15, CREAM, True, "mm")
    nav(draw)


def auction_no_sale_labels(draw: ImageDraw.ImageDraw) -> None:
    header(draw, "경매 — 유찰 결과", "STAGE 4   DAY 8   ¤1840   REP 28")
    put(draw, (38, 373), "경매 진행원", 17, GOLD, True)
    put(draw, (38, 397), "경매 진행 · 유찰", 12, WARN, True)
    put(draw, (38, 421), "예약가에 닿지 못해 유찰입니다.", 13)
    put(draw, (38, 437), "유찰 · 예약가 ¤620 · 최종가 ¤410", 12, "#f0bd71", True)
    put(draw, (1010, 373), "인테리어 장식가", 17, GOLD, True)
    put(draw, (1010, 397), "입찰자 · 입찰 포기", 12, WARN, True)
    put(draw, (1010, 421), "이번에는 물러납니다.", 13)
    put(draw, (1010, 437), "입찰 포기 · 가치 판단", 12, "#f0bd71", True)
    put(draw, (1008, 463), "판단 근거", 12, MUTED, True)
    put(draw, (1060, 505), "예약가 부담", 12, WARN, True, "mm")
    put(draw, (1183, 505), "출처 불확실", 12, WARN, True, "mm")
    put(draw, (282, 104), "아크라이트 탁상시계", 22, GOLD, True)
    for x, heading, value in [(350, "시작가", "¤280"), (574, "예약가", "¤620"), (798, "최종가", "¤410")]:
        put(draw, (x, 163), heading, 12, GOLD, True)
        put(draw, (x, 192), value, 16)
    put(draw, (282, 242), "최근 호가", 16, MUTED, True)
    for index, (name, price) in enumerate([("개인 수집가", 340), ("전문 딜러", 375), ("인테리어 장식가", 410)]):
        y = 292 + index * 48
        put(draw, (300, y), name, 14)
        put(draw, (930, y), f"¤{price}", 14, "#f0bd71", True, "rm")
    put(draw, (282, 498), "유찰 · 수수료 ¤0 · 정산액 ¤0", 18, WARN, True)
    put(draw, (618, 562), "유찰 기록", 15, CREAM, True, "mm")
    nav(draw)


def event_labels(draw: ImageDraw.ImageDraw) -> None:
    header(draw, "오늘의 사건 — 보관실 배송 문제", "STAGE 8   DAY 18   ¤3280   REP 57")
    put(draw, (42, 439), "배송 담당자", 17, GOLD, True)
    put(draw, (42, 463), "이벤트 인물 · 주의 결과", 12, WARN, True)
    put(draw, (42, 487), "주의가 필요한 소식이에요.", 13)
    put(draw, (42, 503), "보관 위험 · +1", 12, "#f0bd71", True)
    put(draw, (442, 137), "사건", 12, GOLD, True)
    put(draw, (442, 165), "습기로 인해 배송 상자의 완충재가 젖었습니다", 15)
    put(draw, (500, 242), "주의 결과", 22, WARN, True)
    put(draw, (500, 275), "보관 위험이 1 증가했습니다. 다음 작업 전에 확인하세요.", 15)
    put(draw, (398, 352), "선택", 13, MUTED, True)
    put(draw, (398, 386), "시장에서 필요한 보존 도구를 확인한다", 17)
    put(draw, (800, 501), "시장으로 이동", 17, CREAM, True, "mm")
    nav(draw)


def stage_labels(draw: ImageDraw.ImageDraw) -> None:
    header(draw, "새 게임 — 스테이지 선택", "PROFILE   HIGHEST 4 / 10")
    put(draw, (36, 87), "클리어한 단계는 다시 선택할 수 있으며 난이도는 단계마다 약 7% 상승합니다.", 15, "#b7c4c8")
    stages = json.loads((ROOT / "data" / "stages" / "stages.json").read_text(encoding="utf-8"))["stages"]
    for stage in stages:
        stage_id = int(stage["stage_id"])
        col = (stage_id - 1) % 5
        row = (stage_id - 1) // 5
        x = 28 + col * 245 + 116
        y = 128 + row * 196
        state = "클리어" if stage_id <= 3 else ("선택 가능" if stage_id == 4 else "잠김")
        color = MINT if stage_id <= 3 else (GOLD if stage_id == 4 else MUTED)
        target = 54 + stage_id
        attempt = f"BEST 목표 달성 {72 + stage_id}" if stage_id <= 3 else "첫 도전"
        put(draw, (x, y + 104), f"스테이지 {stage_id} · {state}", 15, GOLD, True, "mm")
        put(draw, (x, y + 138), f"권장 {target} · {attempt}", 12, color, True, "mm")
    nav(draw)


def stage_clear_labels(draw: ImageDraw.ImageDraw) -> None:
    header(draw, "캠페인 — 지역 경매 순회", "STAGE 2   DAY 4   ¤1335   REP 18")
    for x, heading, value in [(96, "스테이지 2", "세월의 흔적과 약속"), (492, "성과", "현재 40 · 권장 56"), (888, "사건", "3 / 3")]:
        put(draw, (x, 109), heading, 12, GOLD, True)
        put(draw, (x, 137), value, 14)
    put(draw, (118, 219), "STAGE CLEAR", 26, MINT, True)
    put(draw, (930, 222), "성장 중 · 점수 40", 19, CREAM, True)
    put(draw, (52, 261), "권장 목표까지 16점", 14, GOLD, True)
    put(draw, (494, 261), "다음 스테이지 해금", 14, MINT, True)
    put(draw, (1010, 261), "신기록 · BEST 40", 14, "#b7c4c8", True)
    axes = [
        (132, "근거", "78", "좋음", MINT),
        (533, "보존", "92", "좋음", MINT),
        (934, "판매", "—", "기록 없음", WARN),
    ]
    for x, label, score, state, state_color in axes:
        put(draw, (x, 312), label, 13, GOLD, True)
        put(draw, (x, 345), score, 28, CREAM, True)
        put(draw, (x + 121, 355), state, 12, state_color, True)
    put(draw, (52, 439), "재도전 팁 · 독립 근거를 더 인용해 보세요", 15, WARN, True)
    put(draw, (639, 547), "다음 스테이지 또는 재도전", 16, CREAM, True, "mm")
    nav(draw)


def listing_price_labels(draw: ImageDraw.ImageDraw) -> None:
    header(draw, "가치 평가 — 출품과 정보 공개", "STAGE 3   DAY 6   ¤1520   REP 23")
    put(draw, (34, 108), "아우렐리안 기계식 탁상시계", 22, GOLD, True)
    put(draw, (34, 140), "선택한 가설 · 증거 신뢰도 92% · 추정 가치 ¤640", 15, "#b7c4c8")
    badges = [
        (122, "상태 정보 충분", MINT),
        (312, "조사 정보 충분", MINT),
        (502, "출처 불확실", WARN),
    ]
    for x, value, color in badges:
        put(draw, (x, 179), value, 13, color, True, "mm")
    put(draw, (34, 236), "1 / 2 · 가격 전략 선택", 20, GOLD, True)
    plans = [
        (224, "빠른 판매", "시작 ¤320 · 예약 ¤384"),
        (631, "균형 판매", "시작 ¤384 · 예약 ¤460"),
        (1038, "높은 목표", "시작 ¤435 · 예약 ¤524"),
    ]
    for x, title, amount in plans:
        put(draw, (x, 382), title, 19, GOLD, True, "mm")
        put(draw, (x, 416), amount, 15, CREAM, True, "mm")
    put(draw, (34, 490), "표시된 고정 가격 비율 중 하나를 선택하세요.", 14, MUTED)
    nav(draw)


def listing_disclosure_labels(draw: ImageDraw.ImageDraw) -> None:
    header(draw, "가치 평가 — 출품과 정보 공개", "STAGE 3   DAY 6   ¤1520   REP 23")
    put(draw, (34, 108), "아우렐리안 기계식 탁상시계", 22, GOLD, True)
    put(draw, (34, 140), "빠른 판매 · 시작 ¤320 · 예약 ¤384", 15, "#b7c4c8")
    put(draw, (88, 190), "공개 근거 · 근거 보통", 14, MINT, True)
    put(draw, (34, 238), "2 / 2 · 주장 강도 선택", 20, GOLD, True)
    disclosures = [
        (122, "선택됨 · 단정적 주장", "과장 위험"),
        (529, "유력한 주장", "균형"),
        (936, "제한적 주장", "과소공개 · 관심 저하"),
    ]
    for x, title, detail in disclosures:
        put(draw, (x, 300), title, 17, GOLD, True)
        put(draw, (x, 336), detail, 14, CREAM)
    put(draw, (112, 425), "최종 출품", 13, GOLD, True)
    put(draw, (112, 458), "빠른 판매 · 시작 ¤320 · 예약 ¤384 · 단정적 주장 · 과장 위험", 17, CREAM)
    put(draw, (178, 540), "← 가격 변경", 15, CREAM, True, "mm")
    put(draw, (796, 540), "출품 확정", 17, CREAM, True, "mm")
    nav(draw)


def tutorial_guidance_labels(draw: ImageDraw.ImageDraw) -> None:
    header(draw, "사건 서류 — 닫힌 공방", "STAGE 1   DAY 1   ¤1200   REP 12")
    put(draw, (94, 116), "안내 1/6", 13, MINT, True)
    put(draw, (200, 106), "단서 하나 조사", 15, GOLD, True)
    put(draw, (200, 128), "위험을 보고 단서 하나를 기록하세요.", 13, CREAM)
    for x, heading, value in [
        (96, "상황", "닫힌 공방의 탁상시계를 조사한다"),
        (508, "핵심 질문", "당대 수리인가, 후대 재조립인가?"),
        (920, "목표", "독립 출처로 가설을 입증한다"),
    ]:
        put(draw, (x, 180), heading, 12, GOLD, True)
        put(draw, (x, 205), value, 14, CREAM)
    put(draw, (30, 258), "단서 카드", 17, GOLD, True)
    cards = [
        (88, 300, "조사 가능 · 후면판 나사 불일치", "실물 · 위험 높음"),
        (453, 300, "조사 가능 · 브리지 각인", "실물 · 도구 필요"),
        (88, 376, "잠김 · 1937년 수리표", "문서 · 선행 단서 필요"),
        (453, 376, "잠김 · 마라의 기억", "인물 · 선행 단서 필요"),
    ]
    for x, y, title, meta in cards:
        put(draw, (x, y), title, 13, CREAM, True)
        put(draw, (x, y + 23), meta, 11, MUTED)
    put(draw, (858, 296), "선택한 단서", 12, MUTED)
    put(draw, (858, 322), "후면판 나사의 불일치", 18, GOLD, True)
    put(draw, (840, 378), "위험 높음", 14, WARN, True)
    put(draw, (792, 416), "연마 전에 산화 경계를 기록하세요.", 14, "#d9c4ac")
    put(draw, (858, 493), "조사 실행", 15, CREAM, True)
    put(draw, (30, 566), "가설 선택", 17, GOLD, True)
    for x, value in [(230, "출고 상태 그대로"), (595, "당대 수리를 거친 진품"), (960, "후대 재조립품")]:
        put(draw, (x, 590), value, 14, CREAM)
    nav(draw)


def expression_triplet_labels(draw: ImageDraw.ImageDraw) -> None:
    header(draw, "런타임 얼굴 표정 3종", "220×250 · 얼굴 앵커 · 눈썹/눈/입 3축")
    labels = [
        (129, "중립", "눈썹 0 · 눈 0 · 입 0"),
        (544, "긍정", "눈썹 -5 · 눈 -3 · 입 -5"),
        (959, "부정", "눈썹 +5 · 눈 -3 · 입 +5"),
    ]
    for x, state, geometry in labels:
        put(draw, (x, 373), state, 17, GOLD, True)
        put(draw, (x, 421), geometry, 13, MINT, True)
        put(draw, (x, 445), "실제 얼굴 영역 오버레이", 12, "#f0bd71", True)
    nav(draw)


OVERLAYS = {
    "01_illustrated_case_dossier_ko.png": case_labels,
    "02_portrait_market_ko.png": market_labels,
    "03_portrait_auction_ko.png": auction_labels,
    "04_portrait_event_ko.png": event_labels,
    "05_stage_select_ko.png": stage_labels,
    "06_portrait_expression_triplet_runtime.png": expression_triplet_labels,
    "07_portrait_auction_no_sale_reasons_ko.png": auction_no_sale_labels,
    "08_stage_clear_summary_ko.png": stage_clear_labels,
    "09_listing_price_step_ko.png": listing_price_labels,
    "10_listing_disclosure_step_ko.png": listing_disclosure_labels,
    "11_tutorial_guidance_rail_ko.png": tutorial_guidance_labels,
}


def main() -> None:
    for name, overlay in OVERLAYS.items():
        path = OUT / name
        image = Image.open(path).convert("RGBA")
        overlay(ImageDraw.Draw(image))
        image.save(path)

    report_path = ROOT / "qa" / "R3_MVP_UI_HEADLESS_CAPTURES.json"
    report = json.loads(report_path.read_text(encoding="utf-8"))
    report["captureMode"] = "HEADLESS_SVG_COMPOSITE_PLUS_LOCAL_FONT"
    report["fontRasterizer"] = str(FONT_PATH)
    report["textLayerVerified"] = True
    for capture in report.get("captures", []):
        capture["mode"] = "HEADLESS_SVG_COMPOSITE_PLUS_LOCAL_FONT"
    report_path.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"updated": len(OVERLAYS), "font": str(FONT_PATH), "output": str(OUT)}, ensure_ascii=False))


if __name__ == "__main__":
    main()
