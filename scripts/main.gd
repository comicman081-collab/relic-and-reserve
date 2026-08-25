extends Node2D
var screen="title"; var selected:Dictionary={}; var log_lines=[]; var rotate_drag=false; var title_font=ThemeDB.fallback_font
func _ready():
    GameState.state_changed.connect(_on_state); queue_redraw()
func _on_state(): queue_redraw()
func _input(e):
    if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT and e.pressed: _click(e.position)
    if e is InputEventMouseMotion and rotate_drag and selected.size()>0: selected.rotation+=e.relative.x*0.5; queue_redraw()
    if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_LEFT: rotate_drag=e.pressed
    if e is InputEventKey and e.pressed and e.keycode==KEY_ESCAPE: screen="workshop"; queue_redraw()
func _draw():
    draw_rect(Rect2(0,0,1280,720),Color("#17191c"));
    if screen=="title": _title()
    elif screen=="workshop": _workshop()
    elif screen=="market": _market()
    elif screen=="inventory": _inventory()
    elif screen=="inspection": _inspection()
    elif screen=="auction": _auction()
    elif screen=="upgrades": _upgrades()
    elif screen=="debug": _debug()
func txt(s,p,size=18,col=Color("#f2e8cf")): draw_string(title_font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,size,col)
func panel(r,col=Color("#252a2e")): draw_style_box(_box(col,12,Color("#a7834a"),1),r)
func _box(c,r,bw,ww): var b=StyleBoxFlat.new(); b.bg_color=c; b.corner_radius_top_left=r;b.corner_radius_top_right=r;b.corner_radius_bottom_left=r;b.corner_radius_bottom_right=r;b.border_color=bw;b.set_border_width_all(ww); return b
func button(label,r): panel(r,Color("#363c40")); txt(label,Vector2(r.position.x+16,r.position.y+30),17,Color("#f2e8cf"))
func _title():
    draw_circle(Vector2(640,180),92,Color("#b98c4a")); draw_circle(Vector2(640,180),70,Color("#262a2e")); txt("RELIC & RESERVE",Vector2(340,330),52,Color("#e8d8b2")); txt("AN ARTIFACT RESTORATION & AUCTION SIMULATOR",Vector2(350,365),16,Color("#a8b0ad")); button("NEW GAME",Rect2(490,430,300,54)); button("CONTINUE",Rect2(490,500,300,54)); txt("Cloud R1 • fictional makers • deterministic market",Vector2(420,620),14,Color("#87908e"))
func header(name): txt(name,Vector2(42,54),28,Color("#e8d8b2")); txt("DAY %d   ¤ %d   REP %d"%[GameState.day,GameState.money,GameState.reputation],Vector2(850,48),16,Color("#d6b36a")); draw_line(Vector2(36,72),Vector2(1244,72),Color("#7f633e"),1)
func nav():
    button("WORKSHOP",Rect2(35,650,135,42)); button("MARKET",Rect2(180,650,120,42)); button("INVENTORY",Rect2(310,650,135,42)); button("UPGRADES",Rect2(455,650,135,42)); button("SAVE",Rect2(600,650,100,42)); button("DEBUG",Rect2(710,650,100,42))
func _workshop():
    header("WORKSHOP / CONSERVATION FLOOR"); panel(Rect2(34,100,760,520),Color("#3a3128"));
    for i in range(7): draw_rect(Rect2(70+i*100,150+(i%2)*50,75,220+(i%3)*30),Color("#514337")); draw_rect(Rect2(58,480,680,20),Color("#a47b48"));
    txt("MAIN WORKBENCH",Vector2(90,530),16,Color("#f0d8a6")); panel(Rect2(830,105,410,500)); txt("CONSERVATION DESK",Vector2(860,145),20); txt("A warm, orderly studio for uncertain histories.",Vector2(860,178),14,Color("#a8b0ad"));
    var i=210; for line in ["INSPECTION DESK  •  magnifier / UV","STORAGE  •  %d lots"%GameState.inventory.size(),"PHOTO AREA  •  catalogue grade","DELIVERY AREA  •  padded cases","COMPUTER TERMINAL  •  market intel","PACKAGING AREA  •  safe dispatch"]: txt(line,Vector2(860,i),15,Color("#e8d8b2")); i+=42
    txt("Choose a station to continue the loop.",Vector2(860,490),14,Color("#c79a5a")); nav()
func _market():
    header("MARKET / TODAY'S LOTS"); txt("Seeded offers • trends move with inertia",Vector2(42,92),15,Color("#9ea9a5"));
    for i in range(3):
        var a=GameState.new_artifact(i+GameState.day%4); var y=135+i*145; panel(Rect2(40,y,1180,118),Color("#262b2e")); draw_rect(Rect2(60,y+18,90,82),Color(["#9d7646","#4d5960","#7a5f4d"][i])); txt(a.displayName,Vector2(180,y+35),20); txt("%s  •  %s  •  estimated ¤%d"%[a.category,a.actualEra,int(a.acquisitionPrice)],Vector2(180,y+68),15,Color("#b9c0b8")); txt("BUY ¤%d"%int(a.acquisitionPrice),Vector2(1060,y+68),17,Color("#d6b36a"));
    nav()
func _inventory():
    header("INVENTORY / ACQUIRED LOTS");
    if GameState.inventory.is_empty(): txt("No artifacts yet. Visit the market.",Vector2(60,150),22)
    for i in range(GameState.inventory.size()):
        var a=GameState.inventory[i]; var y=120+i*100; panel(Rect2(42,y,1170,78)); txt(a.displayName,Vector2(68,y+30),18); txt("clean %d  mech %d  clues %d  est ¤%d"%[a.cleanliness,a.mechanicalCondition,a.knownClues.size(),a.estimatedValue],Vector2(68,y+58),14,Color("#a8b0ad")); txt("OPEN",Vector2(1090,y+43),16,Color("#d6b36a"))
    nav()
func _inspection():
    header("INSPECTION / ROTATE • ZOOM • FIND CLUES"); panel(Rect2(38,102,730,500),Color("#332f2a")); draw_set_transform(Vector2(400,350),deg_to_rad(selected.get("rotation",0.0)),Vector2(selected.get("zoom",1.0),selected.get("zoom",1.0))); draw_rect(Rect2(-130,-95,260,190),Color("#b18a56")); draw_rect(Rect2(-105,-70,210,140),Color("#4b5558")); draw_circle(Vector2(30,-20),30,Color("#d4b06d")); draw_set_transform(Vector2.ZERO,0,Vector2.ONE); txt("DRAG TO ORBIT",Vector2(290,560),14,Color("#d6b36a"));
    panel(Rect2(800,102,440,500)); txt(selected.get("displayName","Artifact"),Vector2(830,140),20); txt("Clues found: %d / 6"%selected.get("knownClues",[]).size(),Vector2(830,176),16,Color("#a8b0ad")); var yy=210; for k in ["SERIAL_PATTERN","MATERIAL","PATINA","MECHANISM","WEAR_PATTERN","REPAIR_TRACE"]: button("FOUND  "+k if k in selected.get("knownClues",[]) else "SEARCH  "+k,Rect2(830,yy,350,38)); yy+=46
    button("CLEAN",Rect2(830,500,160,42)); button("REPAIR",Rect2(1005,500,160,42)); button("AUTHENTICATE",Rect2(830,552,335,42))
func _auction():
    header("AUCTION / LIVE CATALOGUE"); panel(Rect2(40,100,1180,500),Color("#2b2927")); txt(selected.get("displayName","Lot"),Vector2(76,150),24); txt("Opening bid • bidders evaluate history, condition, trend and confidence",Vector2(76,182),15,Color("#a8b0ad")); var res=GameState.auction(selected); txt("BID PROGRESSION",Vector2(76,230),18,Color("#d6b36a")); var y=270; for b in res.bids: txt("%s raises to ¤%d"%[b.bidder,b.amount],Vector2(100,y),17); y+=36; txt("HAMMER  ¤%d     FEE  ¤%d     NET  ¤%d"%[res.hammer,res.fee,res.net],Vector2(76,520),22,Color("#e8d8b2")); button("HAMMER & RECORD SALE",Rect2(850,520,300,48))
func _upgrades():
    header("UPGRADES / INVEST IN THE STUDIO"); for i in range(8): var y=110+i*62; panel(Rect2(50,y,1140,48)); txt(["Storage Expansion","Better Lighting","Advanced Scanner","Precision Tool Kit","Photo Studio","Auction Terminal","Reference Library","Improved Packaging"][i],Vector2(75,y+30),17); txt("BUY ¤%d"%(100+i*85),Vector2(1020,y+30),16,Color("#d6b36a")); nav()
func _debug():
    header("DEBUG PANEL / R1 QA"); panel(Rect2(60,110,1120,470)); var lines=["Add Money","Spawn Artifact","Reveal Ground Truth","Set Authenticity","Unlock Tools","Set Market Trend","Advance Day","Force Auction","Save","Load","Reset Save"]; for i in range(lines.size()): button(lines[i],Rect2(100+(i%3)*350,150+(i/3)*75,300,48)); txt("Deterministic master seed: %d"%GameState.master_seed,Vector2(100,540),16,Color("#a8b0ad")); nav()
func _click(p:Vector2):
    if screen=="title":
        if Rect2(490,430,300,54).has_point(p): GameState.reset_game(); screen="workshop"
        elif Rect2(490,500,300,54).has_point(p): screen="workshop" if GameState.load_game() else "workshop"
    elif screen=="workshop":
        if Rect2(180,650,120,42).has_point(p): screen="market"
        elif Rect2(310,650,135,42).has_point(p): screen="inventory"
        elif Rect2(455,650,135,42).has_point(p): screen="upgrades"
        elif Rect2(600,650,100,42).has_point(p): GameState.save_game(); log_lines.append("Saved")
        elif Rect2(710,650,100,42).has_point(p): screen="debug"
    elif screen=="market":
        for i in range(3):
            if Rect2(40,135+i*145,1180,118).has_point(p):
                if GameState.buy_artifact(i+GameState.day%4): screen="inventory"
        if Rect2(310,650,135,42).has_point(p): screen="inventory"
    elif screen=="inventory":
        for i in range(GameState.inventory.size()):
            if Rect2(42,120+i*100,1170,78).has_point(p): selected=GameState.inventory[i]; screen="inspection"
        if Rect2(180,650,120,42).has_point(p): screen="market"
    elif screen=="inspection" and selected.size()>0:
        if Rect2(830,500,160,42).has_point(p): GameState.clean(selected,"soft_brush")
        elif Rect2(1005,500,160,42).has_point(p): GameState.repair(selected)
        elif Rect2(830,552,335,42).has_point(p): GameState.authenticate(selected); screen="auction"
    elif screen=="auction" and Rect2(850,520,300,48).has_point(p): GameState.sell(selected); screen="workshop"
    elif screen=="upgrades" and Rect2(455,650,135,42).has_point(p): screen="workshop"
    elif screen=="debug":
        if Rect2(100,150,300,48).has_point(p): GameState.money+=1000
        elif Rect2(450,150,300,48).has_point(p): GameState.inventory.append(GameState.new_artifact())
        elif Rect2(100,375,300,48).has_point(p): GameState.day+=1
        elif Rect2(100,525,300,48).has_point(p): GameState.save_game()
    queue_redraw()
