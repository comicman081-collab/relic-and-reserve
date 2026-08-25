# R3 Authored-v2 Prologue Dossier Visual QA

Status: **PASS_FOR_CAPTURED_SCREENS**

Godot 4.7.1 rendered four Korean 1280×720 screenshots from the live `Main.tscn` UI. The review confirmed:

- The initial dossier shows the case question, evidence ledger, a HIGH risk warning before investigation, tool requirements, and locked evidence dependencies.
- The discovered ledger distinguishes ARTIFACT, DOCUMENT, NPC, and REFERENCE sources and shows each finding's support/refute relationship.
- The report view shows all three hypotheses, the independent-source requirement, three selected citations, and an enabled evidence-backed submission action.
- The resolved view keeps conclusion accuracy (`정확`) separate from substantiation (`STRONG`) and reports three independent sources.
- Korean text is readable at 1280×720, scrolling preserves the fixed title/navigation, and no blank or clipped critical control was observed.

Evidence:

- `qa/golden_case_renders/01_prologue_dossier_risk_ko.png`
- `qa/golden_case_renders/02_prologue_dossier_evidence_ko.png`
- `qa/golden_case_renders/03_prologue_dossier_report_ko.png`
- `qa/golden_case_renders/04_prologue_dossier_result_ko.png`
- `qa/golden_case_renders/prologue_dossier_contact_sheet.png`
- `qa/R3_GOLDEN_CASE_VISUAL_QA.json`

The capture harness creates only PNG and QA-report evidence. It does not build or package Windows executables, PCK files, or archives.
