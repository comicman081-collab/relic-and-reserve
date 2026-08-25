extends SceneTree
var failures=[]
func _init():
    call_deferred("run")
func check(cond:bool,label:String):
    if not cond: failures.append(label)
func run():
    var gs=get_root().get_node("GameState")
    gs.reset_game()
    check(gs.money==1200,"new game money")
    check(gs.buy_artifact(0),"purchase")
    check(gs.inventory.size()==1,"inventory")
    var a=gs.inventory[0]
    gs.active_workpiece=a
    check(gs.clean(a,"soft_brush").length()>0,"clean")
    gs.repair(a)
    check(a.restorationCost>0,"repair cost")
    check(gs.authenticate(a).length()>0,"authentication")
    check(gs.appraise(a)>0,"appraisal")
    var result=gs.sell(a)
    check(result.hammer>=result.opening,"auction progression")
    check(gs.inventory.is_empty(),"inventory removal")
    check(gs.money!=1200,"money update")
    gs.save_game()
    check(gs.load_game(),"load")
    print(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"money":gs.money,"transactions":gs.transactions.size()}))
    quit(0 if failures.is_empty() else 1)
