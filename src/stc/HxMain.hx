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

import grig.midi.MidiMessage;
import grig.midi.MessageType;
import grig.midi.MidiOut;
import grig.midi.MidiIn;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;


class HxMain extends Node {

    var mobScene:PackedScene;
    var score:HxScore;
    var spawnLocation:PathFollow3D;
    var player:HxPlayer;
    var mobTimer:Timer;

    var retry:ColorRect;

    var rendering = false;
    var midiIn:MidiIn;
    var midiOut:MidiOut;

    var jumpPressed = false;
    
    override function _ready() {
        if (Engine.singleton().is_editor_hint()) // skip if in editor
            return;

        mobScene = ResourceLoader.singleton().load("res://scenes/mob.tscn", "", 1).as(PackedScene);
        score = get_node("UserInterface/ScoreLabel").as(HxScore);
        spawnLocation = get_node("SpawnPath/SpawnLocation").as(PathFollow3D);
        player = get_node("Player").as(HxPlayer);
        retry = get_node("UserInterface/Retry").as(ColorRect);

        
        mobTimer = get_node("MobTimer").as(Timer);
        mobTimer.on_timeout.connect(Callable.fromObjectMethod(this, "onMobTimer"), 0);
        
        player.onHit.connect(Callable.fromObjectMethod(this, "onPlayerHit"), 0);
        
        retry.hide();

        trace(MidiIn.getApis());
        midiOut = new MidiOut(grig.midi.Api.Unspecified);

        midiIn = new MidiIn(grig.midi.Api.Unspecified);
        midiIn.setCallback(function (_msg:MidiMessage, delta:Float) {
            //trace(_msg.toArray());
            //trace(delta);

            if (_msg.messageType == 240)
                rendering = false;

            switch (_msg.messageType) {
                case MessageType.NoteOn: {
                    trace("NoteOn: " + _msg.byte1 + " " + _msg.byte2 + " " + _msg.byte3 );

                    var col = Math.floor(Math.random() * 127);
                    switch (_msg.byte2) {
                        case 51: {
                            _lightButton(_msg.byte2, col);
                            if (_msg.byte3 > 0)
                                player.left(true);
                            else
                                player.left(false);
                        }
                        case 52: {
                            _lightButton(_msg.byte2, col);
                            if (_msg.byte3 > 0)
                                player.down(true);
                            else
                                player.down(false);
                        }
                        case 53: {
                            _lightButton(_msg.byte2, col);
                            if (_msg.byte3 > 0)
                                player.right(true);
                            else
                                player.right(false);
                        }
                        case 62: {
                            _lightButton(_msg.byte2, col);
                            if (_msg.byte3 > 0)
                                player.up(true);
                            else
                                player.up(false);
                        }
                        case 67: {
                            _lightButton(_msg.byte2, col);
                            if (_msg.byte3 > 0) {
                                if (!jumpPressed) {
                                    jumpPressed = true;
                                    player.jump();
                                }
                            } else {
                                if (jumpPressed) {
                                    jumpPressed = false;
                                }
                            }
                        }
                    }
                }
                //case MessageType.NoteOff: trace("NoteOff: " + _msg.byte1 + " " + _msg.byte2 + " " + _msg.byte3 );
                default:
            }
        });

        midiIn.getPorts().handle(function(outcome) {
            switch outcome {
                case Success(ports):
                    trace(ports);
                    midiIn.openPort(0, 'grig.midi').handle(function(midiOutcome) {
                        switch midiOutcome {
                            case Success(_):
                                //mainLoop(midiIn);
                            case Failure(error):
                                trace(error);
                        }
                    });
                case Failure(error):
                    trace(error);
            }
        });

        midiOut.getPorts().handle(function(outcome) {
            switch outcome {
                case Success(ports):
                    trace(ports);
                    midiOut.openPort(1, "grig.midi").handle(function(midiOutcome) {
                        switch midiOutcome {
                            case Success(_):
                                //_main(midiOut);
                                trace(midiOut);
                                _setupUpMidiController();

                            case Failure(error):
                                trace(error); 
                        }
                    });
                case Failure(error):
                    trace(error);
            }
        });
    }

    override function _exit_tree() {
        midiOut.closePort();
        midiIn.closePort();
    }

    @:export
    function onMobTimer() {
        spawnLocation.set_progress_ratio(Math.random());

        final mob = mobScene.instantiate(0).as(HxMob);
        mob.translate(spawnLocation.get_position());
        add_child(mob, false, 0);
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

        // if (midiOut.isPortOpen()) {
        //     if (!rendering) {
        //         _renderText(midiOut, "Hello from HxGodot", 4);
        //         trace("fooo");
        //         rendering = true;
        //     }
        // }
    }

    override function _unhandled_input(event:InputEvent) {
        if (event.is_action_pressed("ui_accept", false, false) && retry.is_visible()) {
            get_tree().reload_current_scene();
        }
    }

    function _setupUpMidiController() {
        _clearAllColors();

        var col = Math.floor(Math.random() * 127);
        _lightButton(51, col); // left
        _lightButton(52, col); // down
        _lightButton(53, col); // right
        _lightButton(62, col); // up

        var col = Math.floor(Math.random() * 127);
        _lightButton(67, col); // jump
    }

    function _clearAllColors() {
        var buf = new BytesBuffer();

        buf.addByte(240);
        buf.addByte(0);
        buf.addByte(32);
        buf.addByte(41);
        buf.addByte(2);
        buf.addByte(16);

        buf.addByte(14);
        buf.addByte(0);
        buf.addByte(247);

        midiOut.sendMessage(MidiMessage.ofBytesData(buf.getBytes().getData()));
    }

    function _lightButton(_code:Int, _color:Int) {
        var buf = new BytesBuffer();

        //(240,0,32,41,2,16,10,<LED>,<Colour>,247)
        buf.addByte(240);
        buf.addByte(0);
        buf.addByte(32);
        buf.addByte(41);
        buf.addByte(2);
        buf.addByte(16);

        buf.addByte(10);
        buf.addByte(_code);
        buf.addByte(_color); // color
        buf.addByte(247);

        midiOut.sendMessage(MidiMessage.ofBytesData(buf.getBytes().getData()));
    }

    static function _renderText(_out:MidiOut, _str:String, _speed:Int) {
        var buf = new BytesBuffer();

        // Header bytes
        buf.addByte(240);
        buf.addByte(0);
        buf.addByte(32);
        buf.addByte(41);
        buf.addByte(2);
        buf.addByte(16);

        buf.addByte(20); // scrolling

        buf.addByte(Math.floor(Math.random() * 127)); // color
        buf.addByte(0); // loop

        buf.addByte(_speed);

        buf.add(Bytes.ofString(_str));

        buf.addByte(247); // end

        _out.sendMessage(MidiMessage.ofBytesData(buf.getBytes().getData()));
    }
}
