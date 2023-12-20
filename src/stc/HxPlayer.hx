package stc;

import godot.Engine;
import godot.CharacterBody3D;
import godot.variant.Signal;
import godot.variant.Vector3;
import godot.AnimationPlayer;
import godot.Area3D;
import godot.Node;
import godot.Node3D;
import godot.variant.Callable;
import godot.variant.TypedSignal;
import godot.variant.Signal;

class HxPlayer extends CharacterBody3D {
    
    @:export public var speed(default,default):Float = 14;
    @:export public var fallAcceleration(default,default):Float = 75;
    @:export public var jumpImpulse(default,default):Float = 20;
    @:export public var bounceImpulse(default,default):Float = 16;
    @:export public var onHit:TypedSignal<()->Void>;

    var animPlayer:AnimationPlayer;
    var pivot:Node3D;
    
    static var MoveRight:godot.variant.StringName;
    static var MoveLeft:godot.variant.StringName;
    static var MoveForward:godot.variant.StringName;
    static var MoveBackward:godot.variant.StringName;
    static var Jump:godot.variant.StringName;

    static var grpMob:godot.variant.StringName;

    public function new() {
        super();
        onHit = Signal.fromObjectSignal(this, "onHit");
    }

    override function _ready() {
        if (Engine.singleton().is_editor_hint()) // skip if in editor
            return;

        MoveRight = "MoveRight";
        MoveLeft = "MoveLeft";
        MoveForward = "MoveForward";
        MoveBackward = "MoveBackward";
        Jump = "Jump";
        grpMob = "mob";

        animPlayer = this.get_node("AnimationPlayer").as(AnimationPlayer);
        pivot = this.get_node("Pivot").as(Node3D);

        // manual way of connecting functions to signals
        // this.get_node("MobDetector").as(Area3D).on_body_entered.connect(
        //     Callable.fromObjectMethod(this, "onMobDetected"), 0
        // );
    }

    override function _physics_process(_delta:Float):Void {
        if (Engine.singleton().is_editor_hint()) // skip if in editor
            return;

        var velocity = this.get_velocity();
        var direction = new Vector3(0, 0, 0);

        var input = godot.Input.singleton();
        if (input.is_action_pressed(MoveRight, false))
            direction.x += 1;
        if (input.is_action_pressed(MoveLeft, false))
            direction.x -= 1;
        if (input.is_action_pressed(MoveForward, false))
            direction.z -= 1;
        if (input.is_action_pressed(MoveBackward, false))
            direction.z += 1;

        direction.normalize();
        var len = direction.length();
        if (len > 0) {
            pivot.look_at(this.get_transform().origin + direction, Vector3.UP());
            animPlayer.set_speed_scale(4);
        } else 
            animPlayer.set_speed_scale(1);

        velocity.x = direction.x * speed;
        velocity.z = direction.z * speed;
        velocity.y -= fallAcceleration * _delta;

        if (this.is_on_floor() && input.is_action_just_pressed(Jump, false)) {
            velocity.y += jumpImpulse;
        }

        for (i in 0...get_slide_collision_count().toInt()) {
            var collision = get_slide_collision(i);
            if (collision != null) {
                for (j in 0...collision.get_collision_count().toInt()) {
                    var collider = collision.get_collider(j);
                    if (collider != null && collider.as(Node).is_in_group(grpMob)) {
                        if (Vector3.UP().dot(collision.get_normal(j)) > 0.1) {
                            collider.as(HxMob).squash();
                            velocity.y = bounceImpulse;
                        }
                    }
                }
            }
        }

        var rot = pivot.get_rotation();
        pivot.set_rotation(new Vector3(Math.PI / 6 * velocity.y / jumpImpulse, rot.y, rot.z));

        this.set_velocity(velocity);
        this.move_and_slide();
    }

    @:export
    public function onTouchingMob(_node:Node3D) {
        if (this.is_on_floor()) {
            onHit.emit();
            queue_free();
        }
    }
}