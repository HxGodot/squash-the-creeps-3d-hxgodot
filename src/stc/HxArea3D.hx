package stc;

import godot.Area3D;

class HxArea3D extends Area3D {
    @:export
    public function onBodyEntered(body:godot.Node3D) {
        trace('We successfully detected ${body.get_name()}');
    }
}