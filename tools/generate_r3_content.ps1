$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$ProjectRoot = Split-Path -Parent $PSScriptRoot
$AuthoredCasesRoot = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot 'data/cases/authored_v2'))
$AuthoredCasesLock = [System.IO.Path]::GetFullPath((Join-Path $ProjectRoot 'data/cases/authored_v2.lock.json'))

function Assert-NotAuthoredCaseWrite {
    param([string]$Path)
    $FullPath = [System.IO.Path]::GetFullPath($Path)
    $ProtectedPrefix = $AuthoredCasesRoot.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
    if ($FullPath.Equals($AuthoredCasesLock, [System.StringComparison]::OrdinalIgnoreCase) -or
        $FullPath.StartsWith($ProtectedPrefix, [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Generated-content writer refused protected authored-v2 path: $FullPath"
    }
}

function Get-AuthoredCaseSnapshot {
    $Snapshot = [ordered]@{}
    if (Test-Path -LiteralPath $AuthoredCasesRoot) {
        Get-ChildItem -LiteralPath $AuthoredCasesRoot -File -Recurse | Sort-Object FullName | ForEach-Object {
            $Relative = $_.FullName.Substring($ProjectRoot.Length + 1).Replace('\', '/')
            $Snapshot[$Relative] = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
        }
    }
    if (Test-Path -LiteralPath $AuthoredCasesLock) {
        $Relative = $AuthoredCasesLock.Substring($ProjectRoot.Length + 1).Replace('\', '/')
        $Snapshot[$Relative] = (Get-FileHash -Algorithm SHA256 -LiteralPath $AuthoredCasesLock).Hash.ToLowerInvariant()
    }
    return $Snapshot
}

function Assert-AuthoredCaseSnapshotUnchanged {
    param([System.Collections.IDictionary]$Before)
    $After = Get-AuthoredCaseSnapshot
    if ($Before.Count -ne $After.Count) {
        throw "Authored-v2 file set changed during generated-content run. Before=$($Before.Count), after=$($After.Count)"
    }
    foreach ($Relative in $Before.Keys) {
        if (-not $After.Contains($Relative) -or $After[$Relative] -ne $Before[$Relative]) {
            throw "Authored-v2 content changed during generated-content run: $Relative"
        }
    }
}

$AuthoredCaseSnapshotBefore = Get-AuthoredCaseSnapshot
$AuthoredV2CaseIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
if (Test-Path -LiteralPath $AuthoredCasesRoot) {
    Get-ChildItem -LiteralPath $AuthoredCasesRoot -Filter '*.json' -File | ForEach-Object {
        $Definition = Get-Content -LiteralPath $_.FullName -Raw | ConvertFrom-Json
        if ($Definition.case_id) {
            [void]$AuthoredV2CaseIds.Add([string]$Definition.case_id)
        }
    }
}

function Write-JsonFile {
    param([string]$RelativePath, [object]$Value)
    $Path = Join-Path $ProjectRoot $RelativePath
    Assert-NotAuthoredCaseWrite -Path $Path
    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent | Out-Null
    }
    $Value | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $Path -Encoding utf8
}

function New-Condition {
    param([string]$Metric, [string]$Op, [object]$Value)
    return [ordered]@{ metric = $Metric; op = $Op; value = $Value }
}

$materialNames = @(
    'brass', 'black_leather', 'ceramic', 'wood_dark', 'steel',
    'glass', 'painted_metal', 'aged_wood', 'tarnished_brass', 'brown_leather',
    'paper', 'rusted_steel', 'aged_paint', 'wood_light', 'rubber'
)
$palette = @(
    '#b8893f', '#343236', '#d7c7a1', '#705038', '#7f8b91',
    '#8fb8bf', '#496b73', '#5c3f2a', '#80612e', '#704a32',
    '#b99d70', '#7d3e2f', '#5c6571', '#a5774f', '#34383b'
)
$variants = @()
for ($i = 1; $i -le 60; $i++) {
    $baseIndex = ($i - 1) % 15
    $familyVariant = [math]::Floor(($i - 1) / 15)
    $secondary = ($baseIndex + 3 + $familyVariant) % 15
    $variants += [ordered]@{
        id = ('variant_{0:d3}' -f $i)
        material = $materialNames[$baseIndex]
        materialPath = ('res://assets/materials/{0}.tres' -f $materialNames[$baseIndex])
        primaryColor = $palette[$baseIndex]
        trimColor = $palette[$secondary]
        metallic = [math]::Round(0.12 + ($familyVariant * 0.17), 2)
        roughness = [math]::Round(0.72 - ($familyVariant * 0.11), 2)
        scale = @(
            [math]::Round(0.96 + ($familyVariant * 0.035), 3),
            [math]::Round(1.00 + (($i % 3) * 0.025), 3),
            [math]::Round(0.98 + (($i % 2) * 0.04), 3)
        )
        trimShape = @('band', 'stud', 'plate', 'ring')[$familyVariant]
        signature = ('model_{0:d2}|{1}|{2}|{3}' -f ($baseIndex + 1), $materialNames[$baseIndex], $familyVariant, $i)
    }
}
Write-JsonFile 'data/visual_variants.json' $variants

$eventDefs = @(
    @('Estate Sale', 'money', 'money', 120),
    @('Mystery Crate', 'market_slots', 'market_slots', 1),
    @('Collector Request', 'commission_credit', 'money', 80),
    @('Museum Inquiry', 'museum_trust', 'museumTrust', 2),
    @('Questionable Provenance', 'integrity_warning', 'historicalIntegrity', -2),
    @('Market Boom', 'market_modifier', 'vintage_audio', 8),
    @('Market Slump', 'market_modifier', 'all', -6),
    @('Damaged Delivery', 'storage_damage', 'damage_count', 1),
    @('Rare Maker Trend', 'rarity_bonus', 'rarity_bonus', 0.12),
    @('Private Offer', 'money', 'money', 140),
    @('Hidden Compartment', 'clue_bonus', 'clue_bonus', 0.06),
    @('Replacement Part Discovery', 'restoration_discount', 'restoration_discount', 0.10),
    @('Collector Rival', 'market_slots', 'market_slots', -1),
    @('Auction Fee Discount', 'auction_fee_discount', 'auction_fee_discount', 0.05),
    @('Storage Accident', 'storage_damage', 'damage_count', 1),
    @('Expert Visit', 'inspection_bonus', 'inspection_bonus', 0.08),
    @('Mislabelled Lot', 'acquisition_discount', 'acquisition_discount', 0.10),
    @('Workshop Inspection', 'reputation', 'reputation', 2),
    @('Returning Seller', 'listing_bonus', 'listing_bonus', 0.04),
    @('Special Auction', 'bidder_reach', 'bidder_reach', 2),
    @('Freight Delay', 'market_slots', 'market_slots', -1),
    @('Local Fair', 'market_modifier', 'decorative_objects', 10),
    @('Insurance Check', 'money', 'money', 60),
    @('Unexpected Bequest', 'money', 'money', 180),
    @('Catalog Feature', 'listing_bonus', 'listing_bonus', 0.08)
)
$events = @()
for ($i = 0; $i -lt $eventDefs.Count; $i++) {
    $events += [ordered]@{
        id = ('event_{0:d2}' -f ($i + 1))
        name = $eventDefs[$i][0]
        trigger = [ordered]@{ type = 'daily_seeded'; weight = 1 }
        effect = [ordered]@{ type = $eventDefs[$i][1]; target = $eventDefs[$i][2]; amount = $eventDefs[$i][3] }
        description = ('Daily effect: {0} {1}' -f $eventDefs[$i][2], $eventDefs[$i][3])
    }
}
Write-JsonFile 'data/events/events.json' $events

$upgradeNames = @(
    'Storage Expansion','Better Lighting','Advanced Scanner','Precision Tool Kit','Photo Studio',
    'Auction Terminal','Extra Workbench','Display Cabinet','Parts Cabinet','Restoration Station',
    'Reference Library','Insurance','Faster Delivery','Improved Packaging','Reputation Signage',
    'Climate Cabinet','Specialist Desk','Secure Archive','Market Almanac','Secondhand Network',
    'Museum Liaison','Rare Parts Locker','Premium Camera','Conservation Hood','Staff Assistant'
)
$upgradeEffects = @(
    @('storage_capacity',2), @('inspection_confidence',0.04), @('clue_quality',0.05),
    @('tool_risk_reduction',0.12), @('listing_bonus',0.06), @('auction_fee_reduction',0.02),
    @('workbench_slots',1), @('display_bonus',0.03), @('restoration_cost_reduction',0.08),
    @('repair_efficiency',0.10), @('appraisal_precision',0.08), @('event_mitigation',0.15),
    @('market_slots',1), @('transport_discount',0.10), @('reputation_bonus',2),
    @('damage_prevention',0.12), @('mastery_gain',0.10), @('provenance_confidence',0.06),
    @('market_forecast',1), @('bidder_reach',1), @('museum_trust_bonus',3),
    @('repair_risk_reduction',0.08), @('listing_bonus',0.08), @('integrity_protection',0.12),
    @('workflow_efficiency',0.10)
)
$upgrades = @()
for ($i = 0; $i -lt $upgradeNames.Count; $i++) {
    $effectType = $upgradeEffects[$i][0]
    $effectValue = $upgradeEffects[$i][1]
    $upgrades += [ordered]@{
        id = ('upgrade_{0:d2}' -f ($i + 1))
        name = $upgradeNames[$i]
        cost = 100 + ($i * 85)
        category = @('capacity','inspection','restoration','auction','network')[$i % 5]
        description = ('{0}: {1}' -f ($effectType -replace '_',' '), $effectValue)
        effect = [ordered]@{ type = $effectType; value = $effectValue }
    }
}
Write-JsonFile 'data/upgrades/upgrades.json' $upgrades

$npcs = @(
    @('mara_venn','Mara Venn','Veteran Restorer','mechanical','measured'),
    @('elias_rowe','Elias Rowe','Regional Auctioneer','auction','energetic'),
    @('hana_mire','Dr. Hana Mire','Museum Curator','scientific','precise'),
    @('victor_hale','Victor Hale','Collector','optical','formal'),
    @('noah_stern','Noah Stern','Archive Researcher','documentary','curious'),
    @('lena_falk','Lena Falk','Dealer / Rival','market','direct'),
    @('iris_bell','Iris Bell','Conservation Specialist','decorative','warm'),
    @('dorian_vale','Dorian Vale','Grand Reserve Representative','reserve','ceremonial')
)
$npcRows = @()
foreach ($npc in $npcs) {
    $expressions = [ordered]@{}
    foreach ($expression in @('neutral','positive','concerned','surprised')) {
        $expressions[$expression] = ('res://assets/portraits/{0}_{1}.svg' -f $npc[0], $expression)
    }
    $npcRows += [ordered]@{
        id=$npc[0]; displayName=$npc[1]; role=$npc[2]; specialties=@($npc[3]); budgetTier=3
        personality=$npc[4]; riskTolerance=0.45; authenticityPriority=0.75
        historicalIntegrityPriority=0.78; restorationPreference='minimal intervention'
        startingRelationship=0; startingTrust=0; expressions=$expressions
    }
}
Write-JsonFile 'data/npcs/npcs.json' $npcRows

$caseBlueprints = @(
    @('prologue_clock','PROLOGUE','The Closed Workshop','artifact_001','mara_venn'),
    @('silent_radio','ACT_1','The Silent Radio','artifact_004','mara_venn'),
    @('perfect_fake','ACT_1','The Perfect Fake','artifact_003','elias_rowe'),
    @('leave_patina','ACT_1','Leave the Patina','artifact_005','iris_bell'),
    @('estate_compass','ACT_1','The Estate Compass','artifact_009','lena_falk'),
    @('pawn_watch','ACT_1','The Pawn Broker Watch','artifact_002','lena_falk'),
    @('garage_lamp','ACT_1','The Garage Lamp','artifact_007','mara_venn'),
    @('telephone_trace','ACT_1','A Voice in Bakelite','artifact_010','noah_stern'),
    @('early_camera','ACT_1','The Early Mechanical Camera','artifact_003','hana_mire'),
    @('false_invoice','ACT_2','The False Invoice','artifact_016','noah_stern'),
    @('mislabelled_collection','ACT_2','The Mislabelled Collection','artifact_018','hana_mire'),
    @('observatory_instrument','ACT_2','The Observatory Instrument','artifact_011','hana_mire'),
    @('collector_promise','ACT_3','The Collector Promise','artifact_021','victor_hale'),
    @('three_cameras','ACT_3','The Three Cameras','artifact_033','victor_hale'),
    @('shadow_camera','ACT_4','Shadow Mark: Camera','artifact_048','lena_falk'),
    @('shadow_gauge','ACT_4','Shadow Mark: Gauge','artifact_041','hana_mire'),
    @('shadow_clock','ACT_4','Shadow Mark: Clock','artifact_046','mara_venn'),
    @('shadow_music_box','ACT_4','Shadow Mark: Music Box','artifact_050','iris_bell'),
    @('shadow_optic','ACT_4','Shadow Mark: Optic','artifact_051','victor_hale'),
    @('composite_prototype','ACT_4','The Composite Prototype','artifact_057','noah_stern'),
    @('master_chronometer','ACT_5','Master Work: Chronometer','artifact_052','mara_venn'),
    @('master_optical','ACT_5','Master Work: Optical Engine','artifact_053','victor_hale'),
    @('master_recorder','ACT_5','Master Work: Recorder','artifact_054','iris_bell'),
    @('master_gauge','ACT_5','Master Work: Precision Gauge','artifact_055','hana_mire'),
    @('master_camera','ACT_5','Master Work: Prototype Camera','artifact_056','lena_falk'),
    @('master_mechanism','ACT_5','Master Work: Decorative Mechanism','artifact_060','dorian_vale')
)
$storyArtifacts = @()
$cases = @()
for ($i = 0; $i -lt $caseBlueprints.Count; $i++) {
    $row = $caseBlueprints[$i]
    $storyId = ('story_artifact_{0:d2}' -f ($i + 1))
    $documentIds = @(('document_{0:d2}' -f (($i * 2) % 30 + 1)), ('document_{0:d2}' -f (($i * 2 + 1) % 30 + 1)))
    # Authored-v2 evidence is human-owned and hash-locked. Keep campaign rows
    # as progression metadata, but never emit a legacy story-artifact template
    # for any active authored case. The exclusion set is derived from the
    # authored definitions so future migrations cannot be forgotten here.
    $isAuthoredV2Case = $AuthoredV2CaseIds.Contains([string]$row[0])
    if ($i -lt 20 -and -not $isAuthoredV2Case) {
        $storyArtifacts += [ordered]@{
            id=$storyId; caseId=$row[0]; baseSpecId=$row[3]; title=$row[2]
            fictionalHistory=('A disputed workshop record connected to {0}.' -f $row[2])
            clueLayout=@('MATERIAL','SERIAL_PATTERN','CONSTRUCTION_METHOD','PROVENANCE','REPAIR_TRACE')
            damages=@('DUST','RUST','SCRATCH'); hiddenObservations=@('panel mark','internal fastener')
            restorationTradeoff='Preserve historical surface versus improve sale presentation.'
            groundTruth=@('GENUINE','GENUINE_WITH_PERIOD_REPAIR','GENUINE_WITH_MODERN_REPAIR','REPRODUCTION','FORGERY')[$i % 5]
            visualAccent=$palette[$i % $palette.Count]
        }
    }
    $rewards = [ordered]@{ money=90 + ($i * 12); reputation=2; mastery=3; museumTrust=1; historicalIntegrity=1 }
    if ($row[1] -eq 'ACT_5') { $rewards.mastery = 7; $rewards.reputation = 4; $rewards.museumTrust = 3 }
    $cases += [ordered]@{
        id=$row[0]; act=$row[1]; title=$row[2]; npcId=$row[4]; storyArtifactId=($(if($i -lt 20){$storyId}else{''}))
        rewardSpecId=$row[3]; documentIds=$documentIds
        summary=('Inspect, conserve, authenticate, and disclose the fictional evidence in {0}.' -f $row[2])
        recoveryOutcome='reviewed_with_mentor'; outcomes=@('masterful','credible','mistaken','reviewed_with_mentor')
        rewards=$rewards
    }
}
Write-JsonFile 'data/campaign/story_artifacts.json' $storyArtifacts

$acts = @(
    [ordered]@{ id='PROLOGUE'; title='The Closed Workshop'; location='small_workshop'; unlock=[ordered]@{ op='always' } },
    [ordered]@{ id='ACT_1'; title='The Local Circuit'; location='local_market'; unlock=(New-Condition 'case.prologue_clock' '==' $true) },
    [ordered]@{ id='ACT_2'; title='Provenance'; location='archive_room'; unlock=(New-Condition 'act_completed.ACT_1' '==' $true) },
    [ordered]@{ id='ACT_3'; title='The Collectors'; location='collector_home'; unlock=(New-Condition 'case.observatory_instrument' '==' $true) },
    [ordered]@{ id='ACT_4'; title="The Forger's Shadow"; location='premium_showroom'; unlock=(New-Condition 'case.three_cameras' '==' $true) },
    [ordered]@{ id='ACT_5'; title='Master Conservator'; location='museum_room'; unlock=(New-Condition 'case.composite_prototype' '==' $true) },
    [ordered]@{ id='GRAND_RESERVE'; title='The Grand Reserve'; location='grand_reserve_hall'; unlock=[ordered]@{ op='all'; conditions=@((New-Condition 'act_completed.ACT_5' '==' $true),(New-Condition 'eligible_lots' '>=' 3)) } },
    [ordered]@{ id='EPILOGUE'; title='Epilogue'; location='upgraded_workshop'; unlock=(New-Condition 'grand_reserve.completed' '==' $true) },
    [ordered]@{ id='POSTGAME'; title='Endless Workshop'; location='upgraded_workshop'; unlock=(New-Condition 'epilogue_seen' '==' $true) }
)
$qualification = [ordered]@{
    workshopGrade=5; reputation=45; authenticationAccuracy=0.60; museumTrust=24
    masteryTotal=42; eligibleLots=3
}
$endings = @(
    [ordered]@{ id='ENDING_D'; title='Disgraced Expert'; priority=100; conditions=[ordered]@{ op='any'; conditions=@((New-Condition 'ethics' '<=' 20),(New-Condition 'collectorTrust' '<=' -15)) } },
    [ordered]@{ id='ENDING_S'; title='Master of the Reserve'; priority=90; conditions=[ordered]@{ op='all'; conditions=@((New-Condition 'balancedScore' '>=' 82),(New-Condition 'authenticationAccuracy' '>=' 0.80)) } },
    [ordered]@{ id='ENDING_A'; title='Master Restorer'; priority=50; pillar='restoration' },
    [ordered]@{ id='ENDING_B'; title='Auction Powerhouse'; priority=40; pillar='financial' },
    [ordered]@{ id='ENDING_C'; title='Museum Conservator'; priority=30; pillar='integrity' }
)
$environments = @(
    [ordered]@{id='small_workshop';name='Small Workshop';mode='3d_workshop'},
    [ordered]@{id='upgraded_workshop';name='Upgraded Workshop';mode='3d_workshop'},
    [ordered]@{id='local_market';name='Local Market';mode='presentation'},
    [ordered]@{id='estate_storage';name='Estate Storage';mode='presentation'},
    [ordered]@{id='archive_room';name='Archive / Reference Room';mode='presentation'},
    [ordered]@{id='regional_auction';name='Regional Auction House';mode='presentation'},
    [ordered]@{id='museum_room';name='Museum Consultation Room';mode='presentation'},
    [ordered]@{id='premium_showroom';name='Premium Dealer Showroom';mode='presentation'},
    [ordered]@{id='grand_reserve_hall';name='Grand Reserve Auction Hall';mode='3d_grand_reserve'}
)
Write-JsonFile 'data/campaign/campaign.json' ([ordered]@{ schemaVersion=1; acts=$acts; cases=$cases; qualification=$qualification; endings=$endings; environments=$environments })

$documents = @()
$documentTypes = @('maker_catalog','invoice','auction_receipt','museum_card','repair_record','estate_note','collector_letter','serial_reference','archive_record','reserve_catalog')
for ($i = 1; $i -le 30; $i++) {
    $documents += [ordered]@{
        id=('document_{0:d2}' -f $i); title=('Fictional Reference Leaf {0:d2}' -f $i)
        type=$documentTypes[($i - 1) % $documentTypes.Count]
        body=('In-world record {0:d2}: a fictional maker, date range, ownership note, and confidence annotation for case use.' -f $i)
        fictional=$true; usedByCase=$caseBlueprints[($i - 1) % $caseBlueprints.Count][0]
    }
}
Write-JsonFile 'data/documents/documents.json' $documents

$histories = @(); for($i=1;$i -le 40;$i++){ $histories += [ordered]@{id=('history_{0:d2}' -f $i);makerId=('maker_{0:d2}' -f (($i-1)%20+1));model=('Archive Model {0:d2}' -f $i);note='Fictional in-world production and ownership history.'} }
$materialNotes = @(); for($i=1;$i -le 30;$i++){ $materialNotes += [ordered]@{id=('material_note_{0:d2}' -f $i);title=('Construction Note {0:d2}' -f $i);note='Fictional conservation reference: compare surface, joinery, and age evidence.'} }
$periodRefs = @(); for($i=1;$i -le 20;$i++){ $periodRefs += [ordered]@{id=('period_ref_{0:d2}' -f $i);range=('{0}-{1}' -f (1880+$i*4),(1891+$i*4));note='Fictional design and workshop reference period.'} }
Write-JsonFile 'data/reference/reference_database.json' ([ordered]@{fictional=$true;notice='All entries are fictional in-world reference material.';makerModelHistories=$histories;materialConstructionNotes=$materialNotes;periodReferences=$periodRefs})

$commissionTypes = @('collector_commission','museum_conservation','authentication_only','repair_only','estate_evaluation')
$commissions=@(); for($i=0;$i -lt $commissionTypes.Count;$i++){ $commissions += [ordered]@{id=('commission_{0:d2}' -f ($i+1));type=$commissionTypes[$i];baseReward=160+$i*80;risk=0.15+$i*0.08;recovery=$true} }
Write-JsonFile 'data/campaign/commissions.json' $commissions

# Localization is authored separately because its 106 paired keys are reviewed as
# player-facing copy.  Content regeneration must never silently replace it with a
# smaller bootstrap dictionary.
foreach ($localizationPath in @('localization/en.json', 'localization/ko.json')) {
    if (-not (Test-Path -LiteralPath (Join-Path $ProjectRoot $localizationPath))) {
        throw "Required authored localization file is missing: $localizationPath"
    }
}

$portraitDir = Join-Path $ProjectRoot 'assets/portraits'
New-Item -ItemType Directory -Force -Path $portraitDir | Out-Null
$expressions = @('neutral','positive','concerned','surprised')
for ($i = 0; $i -lt $npcs.Count; $i++) {
    for ($e = 0; $e -lt $expressions.Count; $e++) {
        $accent = $palette[($i * 2 + $e) % $palette.Count]
        $mouth = @('M42 75 L58 75','M42 73 Q50 82 58 73','M42 79 Q50 70 58 79','M44 74 Q50 86 56 74')[$e]
        $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 100 100">
  <rect width="100" height="100" rx="12" fill="#17191c"/>
  <circle cx="50" cy="44" r="25" fill="$accent"/>
  <path d="M20 100 Q24 70 50 68 Q76 70 80 100" fill="$accent" opacity="0.72"/>
  <circle cx="41" cy="43" r="3" fill="#17191c"/><circle cx="59" cy="43" r="3" fill="#17191c"/>
  <path d="$mouth" stroke="#17191c" stroke-width="3" fill="none" stroke-linecap="round"/>
  <path d="M28 30 Q50 8 72 30" stroke="#e8d8b2" stroke-width="7" fill="none"/>
</svg>
"@
        $svg | Set-Content -LiteralPath (Join-Path $portraitDir ('{0}_{1}.svg' -f $npcs[$i][0],$expressions[$e])) -Encoding utf8
    }
}
for ($i = 1; $i -le 12; $i++) {
    $accent = $palette[($i + 5) % $palette.Count]
    $svg = @"
<svg xmlns="http://www.w3.org/2000/svg" width="96" height="96" viewBox="0 0 96 96"><rect width="96" height="96" rx="10" fill="#22272b"/><circle cx="48" cy="36" r="20" fill="$accent"/><path d="M18 96 Q22 60 48 60 Q74 60 78 96" fill="$accent" opacity=".7"/><circle cx="41" cy="35" r="2.5" fill="#111"/><circle cx="55" cy="35" r="2.5" fill="#111"/><path d="M40 46 Q48 51 56 46" stroke="#111" stroke-width="2" fill="none"/></svg>
"@
    $svg | Set-Content -LiteralPath (Join-Path $portraitDir ('buyer_{0:d2}.svg' -f $i)) -Encoding utf8
}

$manifest = @()
$assetRoots = @('assets','audio')
foreach ($assetRoot in $assetRoots) {
    $absoluteRoot = Join-Path $ProjectRoot $assetRoot
    Get-ChildItem -LiteralPath $absoluteRoot -File -Recurse | Where-Object { $_.Extension -notin @('.import','.uid','.csv','.json') } | ForEach-Object {
        $relative = $_.FullName.Substring($ProjectRoot.Length + 1).Replace('\','/')
        $type = switch -Wildcard ($relative) {
            'assets/artifacts/parts/*' { 'artifact_part'; break }
            'assets/artifacts/*' { 'artifact_mesh'; break }
            'assets/workshop_props/*' { 'workshop_prop_mesh'; break }
            'assets/portraits/*' { 'npc_portrait'; break }
            'assets/icons/*' { 'ui_icon'; break }
            'assets/props/*' { 'workshop_prop_icon'; break }
            'assets/materials/*' { 'material'; break }
            'audio/*' { 'audio'; break }
            default { 'asset' }
        }
        $manifest += [ordered]@{
            assetId = (($relative -replace '[^A-Za-z0-9]+','_').Trim('_').ToLowerInvariant())
            assetType = $type; path = $relative; sha256 = (Get-FileHash -Algorithm SHA256 -LiteralPath $_.FullName).Hash.ToLowerInvariant()
            sourceType = 'PROJECT_GENERATED_OR_SUPPLIED_R2'; creator = 'RELIC & RESERVE project'
            license = 'RIGHTS_REVIEW_REQUIRED'; rightsReviewStatus = 'UNVERIFIED'; runtimeStatus = 'USED_OR_CATALOGUED'
        }
    }
}
$manifest = @($manifest | Sort-Object path)
Write-JsonFile 'assets/ASSET_MANIFEST.json' $manifest

$counts = [ordered]@{
    schemaVersion=3; artifactSpecs=60; visualVariants=$variants.Count; bidders=12; events=$events.Count; upgrades=$upgrades.Count
    uiIcons=(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'assets/icons') -Filter '*.svg' -File).Count
    workshopPropIcons=(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'assets/props') -Filter '*.svg' -File).Count
    artifactMeshes=(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'assets/artifacts') -Filter '*.obj' -File).Count
    artifactPartMeshes=(Get-ChildItem -LiteralPath (Join-Path $ProjectRoot 'assets/artifacts/parts') -Filter '*.obj' -File).Count
    mainNpcs=$npcRows.Count; mainNpcExpressionAssets=32; secondaryBuyerPortraits=12
    storyCases=$cases.Count; uniqueStoryArtifacts=($storyArtifacts.Count + $AuthoredCaseSnapshotBefore.Keys.Where({ $_ -like 'data/cases/authored_v2/*.json' }).Count); documents=$documents.Count; environments=$environments.Count
    makerModelHistories=$histories.Count; materialConstructionNotes=$materialNotes.Count; periodReferences=$periodRefs.Count
    manifestEntries=$manifest.Count; manifestMissing=0
}
Write-JsonFile 'qa/content_counts.json' $counts

$inventoryPath = Join-Path $ProjectRoot 'qa/R3_CAMPAIGN_ASSET_INVENTORY.csv'
$inventory = @()
foreach($entry in $manifest){
    $inventory += [pscustomobject]@{category=$entry.assetType;path_or_id=$entry.path;runtime_reference='RuntimeRegistry/catalog';unique_hash=$entry.sha256;provenance_rights=$entry.rightsReviewStatus;state='USED'}
}
$documents | ForEach-Object { $inventory += [pscustomobject]@{category='document';path_or_id=$_.id;runtime_reference=$_.usedByCase;unique_hash='DATA';provenance_rights='FICTIONAL_PROJECT_CONTENT';state='USED'} }
$environments | ForEach-Object { $inventory += [pscustomobject]@{category='environment';path_or_id=$_.id;runtime_reference=$_.mode;unique_hash='DATA';provenance_rights='PROJECT_GENERATED';state='USED'} }
$storyArtifacts | ForEach-Object { $inventory += [pscustomobject]@{category='unique_story_artifact';path_or_id=$_.id;runtime_reference=$_.caseId;unique_hash='DATA';provenance_rights='FICTIONAL_PROJECT_CONTENT';state='USED'} }
$AuthoredCaseSnapshotBefore.Keys | Where-Object { $_ -like 'data/cases/authored_v2/*.json' } | ForEach-Object {
    $inventory += [pscustomobject]@{category='authored_v2_case';path_or_id=$_;runtime_reference='AuthoredCaseRegistry';unique_hash=$AuthoredCaseSnapshotBefore[$_];provenance_rights='FICTIONAL_PROJECT_CONTENT';state='PROTECTED'}
}
$inventory | Export-Csv -LiteralPath $inventoryPath -NoTypeInformation -Encoding utf8

Assert-AuthoredCaseSnapshotUnchanged -Before $AuthoredCaseSnapshotBefore
Write-Output ('Generated R3 data: {0} campaign rows, {1} generated legacy story artifacts plus protected authored-v2 cases, {2} manifest entries.' -f $cases.Count,$storyArtifacts.Count,$manifest.Count)
