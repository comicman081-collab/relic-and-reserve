extends SceneTree
func _init(): call_deferred("capture")
func snap(main:Node3D,name:String):
    await process_frame
    await process_frame
    var img=get_root().get_viewport().get_texture().get_image()
    img.save_png("res://qa/renders/"+name+".png")
func capture():
    var rr=load("res://scripts/runtime_registry.gd").new(); rr.name="RuntimeRegistry"; get_root().add_child(rr)
    var gs=load("res://scripts/game_state.gd").new(); gs.name="GameState"; get_root().add_child(gs)
    await process_frame
    var main=load("res://scenes/Main.tscn").instantiate(); get_root().add_child(main)
    await process_frame
    await snap(main,"01_title")
    main.show_workshop(); await snap(main,"02_workshop")
    main.show_market(); await snap(main,"03_market")
    gs.reset_game(); gs.buy_artifact(0); main.show_inventory(); await snap(main,"04_inventory")
    var a=gs.inventory[0]; main.load_artifact(a); main.show_inspection(); await snap(main,"05_workbench_clock_dirty")
    gs.select_tool("soft_brush"); gs.clean(a,"soft_brush"); main.load_artifact(a); main.show_inspection(); await snap(main,"06_cleaning")
    gs.disassemble(a,"panel"); main.load_artifact(a); main.show_inspection(); await snap(main,"07_disassembly")
    gs.inspect_clue(a,"MATERIAL"); gs.inspect_clue(a,"SERIAL_PATTERN"); main.show_authentication(); await snap(main,"08_authentication")
    main.show_appraisal(); await snap(main,"09_appraisal")
    gs.list_auction(a,30,40,a.confidence); main.show_auction(); await snap(main,"10_live_auction")
    main.show_upgrades(); await snap(main,"11_upgrades")
    print("R2_SCREENSHOTS_CREATED")
    quit(0)
