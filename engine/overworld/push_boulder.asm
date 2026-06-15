TryPushingBoulder::
	ld a, [wStatusFlags1]
	bit BIT_STRENGTH_ACTIVE, a
	ret z
	ld a, [wMiscFlags]
	bit BIT_BOULDER_DUST, a
	ret nz
	xor a
	ldh [hSpriteIndex], a
	call IsSpriteInFrontOfPlayer
	ldh a, [hSpriteIndex]
	ld [wBoulderSpriteIndex], a
	and a
	jp z, ResetBoulderPushFlags
	ld hl, wSpritePlayerStateData1MovementStatus
	ld d, $0
	ldh a, [hSpriteIndex]
	swap a
	ld e, a
	add hl, de
	res BIT_FACE_PLAYER, [hl]
	call GetSpriteMovementByte2Pointer
	ld a, [hl]
	cp BOULDER_MOVEMENT_BYTE_2
	jp nz, ResetBoulderPushFlags
	ld hl, wMiscFlags
	bit BIT_TRIED_PUSH_BOULDER, [hl]
	set BIT_TRIED_PUSH_BOULDER, [hl]
	ret z ; the player must try pushing twice before the boulder will move
	ldh a, [hJoyHeld]
	and PAD_CTRL_PAD
	ret z
	predef CheckForCollisionWhenPushingBoulder
	ld a, [wTileInFrontOfBoulderAndBoulderCollisionResult]
	and a ; was there a collision?
	jp nz, ResetBoulderPushFlags
	ldh a, [hJoyHeld]
	ld b, a
	ld a, [wSpritePlayerStateData1FacingDirection]
	cp SPRITE_FACING_UP
	jr z, .pushBoulderUp
	cp SPRITE_FACING_LEFT
	jr z, .pushBoulderLeft
	cp SPRITE_FACING_RIGHT
	jr z, .pushBoulderRight
; push boulder down
	bit B_PAD_DOWN, b
	ret z
	ld de, PushBoulderDownMovementData
	jr .done
.pushBoulderUp
	bit B_PAD_UP, b
	ret z
	ld de, PushBoulderUpMovementData
	jr .done
.pushBoulderLeft
	bit B_PAD_LEFT, b
	ret z
	ld de, PushBoulderLeftMovementData
	jr .done
.pushBoulderRight
	bit B_PAD_RIGHT, b
	ret z
	ld de, PushBoulderRightMovementData
.done
	call MoveSprite
	ld a, SFX_PUSH_BOULDER
	call PlaySound
	; === RUMBLE BOULDER v2 - push: hard initial buzz ===
	push af
	ld a, 18          ; harder initial push buzz
	ld [$CD81], a
	ld a, $08
	ld [$CD82], a
	ld [$4000], a
	pop af
	; === END RUMBLE BOULDER v2 ===
	; === RUMBLE STRENGTH v1 - boulder push step ===
	push af
	ld a, $0B
	ld [$CD88], a
	pop af
	; === END RUMBLE STRENGTH v1 ===
	ld hl, wMiscFlags
	set BIT_BOULDER_DUST, [hl]
	ret

PushBoulderUpMovementData:
	db NPC_MOVEMENT_UP
	db -1 ; end

PushBoulderDownMovementData:
	db NPC_MOVEMENT_DOWN
	db -1 ; end

PushBoulderLeftMovementData:
	db NPC_MOVEMENT_LEFT
	db -1 ; end

PushBoulderRightMovementData:
	db NPC_MOVEMENT_RIGHT
	db -1 ; end

DoBoulderDustAnimation::
	ld a, [wStatusFlags5]
	bit BIT_SCRIPTED_NPC_MOVEMENT, a
	ret nz
	callfar AnimateBoulderDust
	; === RUMBLE BOULDER SETTLE v2 - soft settle ===
	push af
	ld a, $0D
	ld [$CD88], a
	ld a, 10          ; lighter settle buzz
	ld [$CD81], a
	ld a, $08
	ld [$CD82], a
	ld [$4000], a
	pop af
	; === END RUMBLE BOULDER SETTLE v2 ===
	call DiscardButtonPresses
	ld [wJoyIgnore], a
	call ResetBoulderPushFlags
	set BIT_PUSHED_BOULDER, [hl]
	ld a, [wBoulderSpriteIndex]
	ldh [hSpriteIndex], a
	call GetSpriteMovementByte2Pointer
	ld [hl], $10
	; === RUMBLE BOULDER SETTLE v1 - boulder finishes moving ===
	push af
	ld a, $0C
	ld [$CD88], a
	ld a, 8
	ld [$CD81], a
	ld a, $08
	ld [$CD82], a
	ld [$4000], a
	pop af
	; === END RUMBLE BOULDER SETTLE v1 ===
	ld a, SFX_CUT
	jp PlaySound

ResetBoulderPushFlags:
	ld hl, wMiscFlags
	res BIT_BOULDER_DUST, [hl]
	res BIT_TRIED_PUSH_BOULDER, [hl]
	ret
