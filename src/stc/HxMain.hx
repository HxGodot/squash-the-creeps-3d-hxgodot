package stc;

import godot.ColorRect;
import godot.Engine;
import godot.InputEvent;
import godot.Node;
import godot.Object;
import godot.PackedScene;
import godot.PathFollow3D;
import godot.ResourceLoader;
import godot.Timer;
import godot.variant.Callable;
import godot.variant.GDString;
import godot.variant.Vector3;


class HxMain extends Node {

    var mobScene:PackedScene;
    var score:HxScore;
    var spawnLocation:PathFollow3D;
    var player:HxPlayer;
    var mobTimer:Timer;

    var retry:ColorRect;
    
    override function _ready() {
        if (Engine.singleton().is_editor_hint()) // skip if in editor
            return;

        mobScene = ResourceLoader.singleton().load("res://scenes/mob.tscn", "PackedScene", ResourceLoaderCacheMode.CACHE_MODE_REUSE).as(PackedScene);
        score = get_node("UserInterface/ScoreLabel").as(HxScore);
        spawnLocation = get_node("SpawnPath/SpawnLocation").as(PathFollow3D);
        player = get_node("Player").as(HxPlayer);
        retry = get_node("UserInterface/Retry").as(ColorRect);
        
        mobTimer = get_node("MobTimer").as(Timer);
        mobTimer.on_timeout.connect(Callable.fromObjectMethod(this, "onMobTimer"), 0);
        
        player.onHit.connect(Callable.fromObjectMethod(this, "onPlayerHit"), 0);
        
        retry.hide();
    }

    @:export
    function onMobTimer() {
        spawnLocation.set_progress_ratio(Math.random());
        final mob = mobScene.instantiate().as(HxMob);
        mob.translate(spawnLocation.get_position());
        add_child(mob);
        mob.initialize(player.get_position());
        mob.onSquashed.connect(Callable.fromObjectMethod(score, "onMobSquashed"), ObjectConnectFlags.CONNECT_ONE_SHOT);
    }

    @:export
    function onPlayerHit() {
        mobTimer.stop();
        retry.show();
    }

    override function _process(_delta:Float) {
        if (Engine.singleton().is_editor_hint()) // skip if in editor
            return;

        if (godot.Input.singleton().is_action_just_pressed("GC")) {
            cpp.NativeGc.run(true);
        }
    }

    override function _unhandled_input(_event:InputEvent) {
        if (_event.is_action_pressed("ui_accept", false, false) && retry.is_visible())
            get_tree().reload_current_scene();
        else if (_event.is_action_pressed("Quit Game"))
            get_tree().quit();
    }
}