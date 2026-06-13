VBlank::

	push af
	push bc
	push de
	push hl

	ldh a, [hLoadedROMBank]
	ld [wVBlankSavedROMBank], a

	ldh a, [hSCX]
	ldh [rSCX], a
	ldh a, [hSCY]
	ldh [rSCY], a

	ld a, [wDisableVBlankWYUpdate]
	and a
	jr nz, .ok
	ldh a, [hWY]
	ldh [rWY], a
.ok

	call AutoBgMapTransfer
	call VBlankCopyBgMap
	call RedrawRowOrColumn
	call VBlankCopy
	call VBlankCopyDouble
	call UpdateMovingBgTiles
	call hDMARoutine
	ld a, BANK(PrepareOAMData)
	ldh [hLoadedROMBank], a
	ld [rROMB], a
	call PrepareOAMData

	; VBlank-sensitive operations end.

	call Random

	; === RUMBLE VBLANK v2 - safe bit3 only, preserve RAM bank ===
	ld a, [$C6F9]
	and a
	jr z, .rumbleOff
	dec a
	ld [$C6F9], a
	jr nz, .rumbleDone
	; Motor still running, ensure bit3 set
	ld a, [wROMBank]
	and $F7           ; keep RAM bank bits, clear bit3 just in case
	or $08            ; set bit3 = rumble on
	ld [$4000], a
	jr .rumbleDone
.rumbleOff
	; Timer hit zero - turn motor off, preserve RAM bank
	ld a, [wROMBank]
	and $F7           ; clear bit3 only = rumble off
	ld [$4000], a
.rumbleDone
	; === END RUMBLE VBLANK v2 ===

	ldh a, [hVBlankOccurred]
	and a
	jr z, .skipZeroing
	xor a
	ldh [hVBlankOccurred], a

.skipZeroing
	ldh a, [hFrameCounter]
	and a
	jr z, .skipDec
	dec a
	ldh [hFrameCounter], a

.skipDec
	call FadeOutAudio

	ld a, [wAudioROMBank] ; music ROM bank
	ldh [hLoadedROMBank], a
	ld [rROMB], a

	cp BANK(Audio1_UpdateMusic)
	jr nz, .checkForAudio2
.audio1
	call Audio1_UpdateMusic
	jr .afterMusic
.checkForAudio2
	cp BANK(Audio2_UpdateMusic)
	jr nz, .audio3
.audio2
	call Music_DoLowHealthAlarm
	call Audio2_UpdateMusic
	jr .afterMusic
.audio3
	call Audio3_UpdateMusic
.afterMusic

	farcall TrackPlayTime ; keep track of time played

	ldh a, [hDisableJoypadPolling]
	and a
	call z, ReadJoypad

	ld a, [wVBlankSavedROMBank]
	ldh [hLoadedROMBank], a
	ld [rROMB], a

	pop hl
	pop de
	pop bc
	pop af
	reti


DelayFrame::
; Wait for the next vblank interrupt.
; As a bonus, this saves battery.

DEF NOT_VBLANKED EQU 1

	ld a, NOT_VBLANKED
	ldh [hVBlankOccurred], a
.halt
	halt
	ldh a, [hVBlankOccurred]
	and a
	jr nz, .halt
	ret
