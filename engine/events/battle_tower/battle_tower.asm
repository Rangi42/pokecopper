BattleTowerRoomMenu:
; special
	call InitBattleTowerChallengeRAM
	farcall _BattleTowerRoomMenu
	ret

BattleTowerBattle:
	xor a ; FALSE
	ld [wBattleTowerBattleEnded], a
	call _BattleTowerBattle
	ret

InitBattleTowerChallengeRAM:
	xor a
	ld [wBattleTowerBattleEnded], a
	ld [wNrOfBeatenBattleTowerTrainers], a
	ld [wcf65], a
	ld [wcf66], a
	ret

_BattleTowerBattle:
.loop
	call .do_dw
	call DelayFrame
	ld a, [wBattleTowerBattleEnded]
	cp TRUE
	jr nz, .loop
	ret

.do_dw
	ld a, [wBattleTowerBattleEnded]
	ld e, a
	ld d, 0
	ld hl, .dw
	add hl, de
	add hl, de
	ld a, [hli]
	ld h, [hl]
	ld l, a
	jp hl

.dw
	dw RunBattleTowerTrainer
	dw SkipBattleTowerTrainer

RunBattleTowerTrainer:
	ld a, [wOptions]
	push af
	ld hl, wOptions
	set BATTLE_SHIFT, [hl] ; SET MODE

	ld a, [wInBattleTowerBattle]
	push af
	or 1
	ld [wInBattleTowerBattle], a

	xor a
	ld [wLinkMode], a
	farcall StubbedTrainerRankings_Healings
	farcall HealParty
	call ReadBTTrainerParty
	call Clears5_a89a

	predef StartBattle

	farcall LoadPokemonData
	farcall HealParty
	ld a, [wBattleResult]
	ld [wScriptVar], a
	and a ; WIN?
	jr nz, .lost
	ld a, BANK(sNrOfBeatenBattleTowerTrainers)
	call GetSRAMBank
	ld a, [sNrOfBeatenBattleTowerTrainers]
	ld [wNrOfBeatenBattleTowerTrainers], a
	call CloseSRAM
	ld hl, wStringBuffer3
	ld a, [wNrOfBeatenBattleTowerTrainers]
	add "1"
	ld [hli], a
	ld a, "@"
	ld [hl], a

.lost
	pop af
	ld [wInBattleTowerBattle], a
	pop af
	ld [wOptions], a
	ld a, TRUE
	ld [wBattleTowerBattleEnded], a
	ret

ReadBTTrainerParty:
; Initialise the BattleTower-Trainer and his mon
	call CopyBTTrainer_FromBT_OT_TowBT_OTTemp

; Check the nicknames for illegal characters, and replace bad nicknames
; with their species names.
	ld de, wBT_OTTempMon1Name
	ld c, MON_NAME_LENGTH
	farcall CheckStringForErrors
	jr nc, .skip_mon_1

	ld a, [wBT_OTTempMon1]
	ld [wNamedObjectIndexBuffer], a
	call GetPokemonName
	ld l, e
	ld h, d
	ld de, wBT_OTTempMon1Name
	ld bc, MON_NAME_LENGTH
	call CopyBytes

.skip_mon_1
	ld de, wBT_OTTempMon2Name
	ld c, MON_NAME_LENGTH
	farcall CheckStringForErrors
	jr nc, .skip_mon_2
	ld a, [wBT_OTTempMon2]
	ld [wNamedObjectIndexBuffer], a
	call GetPokemonName
	ld l, e
	ld h, d
	ld de, wBT_OTTempMon2Name
	ld bc, MON_NAME_LENGTH
	call CopyBytes

.skip_mon_2
	ld de, wBT_OTTempMon3Name
	ld c, MON_NAME_LENGTH
	farcall CheckStringForErrors
	jr nc, .skip_mon_3
	ld a, [wBT_OTTempMon3]
	ld [wNamedObjectIndexBuffer], a
	call GetPokemonName
	ld l, e
	ld h, d
	ld de, wBT_OTTempMon3Name
	ld bc, MON_NAME_LENGTH
	call CopyBytes

.skip_mon_3
; Add the terminator character to each of these names
	ld a, "@"
	ld [wBT_OTTempMon1NameEnd - 1], a
	ld [wBT_OTTempMon2NameEnd - 1], a
	ld [wBT_OTTempMon3NameEnd - 1], a
; Fix errors in the movesets
	call CheckBTMonMovesForErrors
; Repair the trainer name if needed, then copy it to wOTPlayerName
	ld de, wBT_OTTempName
	ld c, NAME_LENGTH - 1
	farcall CheckStringForErrors
	jr nc, .trainer_name_okay
	ld hl, BT_ChrisName
	jr .done_trainer_name

.trainer_name_okay
	ld hl, wBT_OTTempName

.done_trainer_name
	ld de, wOTPlayerName
	ld bc, NAME_LENGTH - 1
	call CopyBytes
	ld a, "@"
	ld [de], a

	ld hl, wBT_OTTempTrainerClass
	ld a, [hli]
	ld [wOtherTrainerClass], a
	ld a, LOW(wOTPartyMonNicknames)
	ld [wBGMapBuffer], a
	ld a, HIGH(wOTPartyMonNicknames)
	ld [wBGMapBuffer + 1], a

	; Copy mon into Memory from the address in hl
	ld de, wOTPartyMon1Species
	ld bc, wOTPartyCount
	ld a, BATTLETOWER_PARTY_LENGTH
	ld [bc], a
	inc bc
.otpartymon_loop
	push af
	ld a, [hl]
	ld [bc], a
	inc bc
	push bc
	ld bc, PARTYMON_STRUCT_LENGTH
	call CopyBytes
	push de
	ld a, [wBGMapBuffer]
	ld e, a
	ld a, [wBGMapBuffer + 1]
	ld d, a
	ld bc, MON_NAME_LENGTH
	call CopyBytes
	ld a, e
	ld [wBGMapBuffer], a
	ld a, d
	ld [wBGMapBuffer + 1], a
	pop de
	pop bc
	pop af
	dec a
	and a
	jr nz, .otpartymon_loop
	ld a, -1
	ld [bc], a
	ret

BT_ChrisName:
	db "CHRIS@"

CopyBTTrainer_FromBT_OT_TowBT_OTTemp:
; copy the BattleTower-Trainer data that lies at 'wBT_OTTrainer' to 'wBT_OTTemp'
	ldh a, [rSVBK]
	push af
	ld a, BANK(wBT_OTTrainer)
	ldh [rSVBK], a

	ld hl, wBT_OTTrainer
	ld de, wBT_OTTemp
	ld bc, BATTLE_TOWER_STRUCT_LENGTH
	call CopyBytes

	pop af
	ldh [rSVBK], a

	ld a, BANK(sBattleTowerChallengeState)
	call GetSRAMBank
	ld a, BATTLETOWER_CHALLENGE_IN_PROGESS
	ld [sBattleTowerChallengeState], a
	ld hl, sNrOfBeatenBattleTowerTrainers
	inc [hl]
	call CloseSRAM
SkipBattleTowerTrainer:
	ret

BattleTowerAction:
	ld a, [wScriptVar]
	ld e, a
	ld d, 0
	ld hl, .dw
	add hl, de
	add hl, de
	ld a, [hli]
	ld h, [hl]
	ld l, a
	jp hl

.dw
	dw BattleTowerAction_CheckExplanationRead
	dw BattleTowerAction_SetExplanationRead
	dw BattleTowerAction_GetChallengeState
	dw BattleTowerAction_SetByteToQuickSaveChallenge
	dw BattleTowerAction_SetByteToCancelChallenge
	dw Function1707ac
	dw Function1707f4
	dw SaveBattleTowerLevelGroup
	dw LoadBattleTowerLevelGroup
	dw BattleTower_CheckSaveFileExistsAndIsYours
	dw Function1708b1
	dw CheckMobileEventIndex
	dw Function1708c8
	dw Function1708f0
	dw BattleTowerAction_EggTicket
	dw Function1709aa
	dw Function1709bb
	dw Function170a9c
	dw Function170aa0
	dw Function170aaf
	dw Function170abe
	dw Function170ad7
	dw Function170807
	dw Function17081d
	dw BattleTowerAction_LevelCheck
	dw BattleTowerAction_UbersCheck
	dw ResetBattleTowerTrainersSRAM
	dw BattleTower_GiveReward
	dw Function17071b
	dw Function170729
	dw BattleTower_RandomlyChooseReward
	dw BattleTower_SaveOptions

; Reset the save memory for BattleTower-Trainers (Counter and all 7 TrainerBytes)
ResetBattleTowerTrainersSRAM:
	ld a, BANK(sBTTrainers)
	call GetSRAMBank

	ld a, $ff
	ld hl, sBTTrainers
	ld bc, BATTLETOWER_STREAK_LENGTH
	call ByteFill

	xor a
	ld [sNrOfBeatenBattleTowerTrainers], a

	call CloseSRAM

	ret

BattleTower_GiveReward:
	ld a, BANK(sBattleTowerReward)
	call GetSRAMBank

	ld a, [sBattleTowerReward]
	call CloseSRAM
	ld [wScriptVar], a
	ld hl, wNumItems
	ld a, [hli]
	cp MAX_ITEMS
	ret c
	ld b, MAX_ITEMS
	ld a, [wScriptVar]
	ld c, a
.loop
	ld a, [hli]
	cp c
	jr nz, .next
	ld a, [hl]
	cp 95
	ret c
.next
	inc hl
	dec b
	jr nz, .loop
	ld a, POTION
	ld [wScriptVar], a
	ret

Function17071b:
	ld a, BANK(sBattleTowerChallengeState)
	call GetSRAMBank
	ld a, BATTLETOWER_WON_CHALLENGE
	ld [sBattleTowerChallengeState], a
	call CloseSRAM
	ret

Function170729:
	ld a, BANK(sBattleTowerChallengeState)
	call GetSRAMBank
	ld a, BATTLETOWER_RECEIVED_REWARD
	ld [sBattleTowerChallengeState], a
	call CloseSRAM
	ret

BattleTower_SaveOptions:
	farcall SaveOptions
	ret

BattleTower_RandomlyChooseReward:
; Generate a random stat boosting item.
.loop
	call Random
	ldh a, [hRandomAdd]
	and $7
	cp 6
	jr c, .okay
	sub 6
.okay
	add HP_UP
	cp LUCKY_PUNCH
	jr z, .loop
	push af
	ld a, BANK(sBattleTowerReward)
	call GetSRAMBank
	pop af
	ld [sBattleTowerReward], a
	call CloseSRAM
	ret

BattleTowerAction_CheckExplanationRead:
	call BattleTower_CheckSaveFileExistsAndIsYours
	ld a, [wScriptVar]
	and a
	ret z

	ld a, BANK(sBattleTowerSaveFileFlags)
	call GetSRAMBank
	ld a, [sBattleTowerSaveFileFlags]
	and 2
	ld [wScriptVar], a
	call CloseSRAM
	ret

BattleTowerAction_GetChallengeState:
	ld hl, sBattleTowerChallengeState
	ld a, BANK(sBattleTowerChallengeState)
	call GetSRAMBank
	ld a, [hl]
	ld [wScriptVar], a
	call CloseSRAM
	ret

BattleTowerAction_SetExplanationRead:
	ld a, BANK(sBattleTowerSaveFileFlags)
	call GetSRAMBank
	ld a, [sBattleTowerSaveFileFlags]
	or 2
	ld [sBattleTowerSaveFileFlags], a
	call CloseSRAM
	ret

BattleTowerAction_SetByteToQuickSaveChallenge:
	ld c, BATTLETOWER_SAVED_AND_LEFT
	jr asm_17079f

BattleTowerAction_SetByteToCancelChallenge:
	ld c, BATTLETOWER_NO_CHALLENGE
asm_17079f:
	ld a, BANK(sBattleTowerChallengeState)
	call GetSRAMBank
	ld a, c
	ld [sBattleTowerChallengeState], a
	call CloseSRAM
	ret

Function1707ac:
	ld a, BANK(s5_aa8c) ; aka BANK(s5_be46)
	call GetSRAMBank
	ld a, [s5_aa8c]
	ld b, a
	ld a, [s5_be46]
	ld [wScriptVar], a
	call CloseSRAM
	and a
	ret z
	ld a, b
	cp 2
	jr nc, .asm_1707ef
	push bc
	call UpdateTime
	pop bc
	ld a, BANK(s5_aa8c)
	call GetSRAMBank
	ld a, [s5_aa8b]
	call CloseSRAM
	ld c, a
	ld a, [wCurDay]
	sub c
	jr c, .asm_1707e5
	cp 8
	jr nc, .asm_1707ef
	ld a, b
	and a
	jr nz, .asm_1707ef
	ret
.asm_1707e5
	ld hl, wCurDay
	ld a, $8c
	sub c
	add [hl]
	cp 8
	ret c
.asm_1707ef
	ld a, 8
	ld [wScriptVar], a

Function1707f4:
	ld a, BANK(s5_be46) ; aka BANK(s5_aa8b) and BANK(s5_aa8c)
	call GetSRAMBank
	xor a
	ld [s5_be46], a
	ld [s5_aa8b], a
	ld [s5_aa8c], a
	call CloseSRAM
	ret

Function170807:
	call UpdateTime
	ld a, BANK(s5_b2f9) ; aka BANK(s5_b2fa)
	call GetSRAMBank
	ld a, [wCurDay]
	ld [s5_b2f9], a
	xor a
	ld [s5_b2fa], a
	call CloseSRAM
	ret

Function17081d:
	xor a
	ld [wScriptVar], a
	ld a, BANK(s5_b2f9) ; aka BANK(s5_b2fa)
	call GetSRAMBank
	ld a, [s5_b2f9]
	ld c, a
	ld a, [s5_b2fa]
	ld b, a
	call CloseSRAM
	cp 2
	jr nc, .asm_170853
	push bc
	call UpdateTime
	pop bc
	ld a, [wCurDay]
	sub c
	jr c, .asm_170849
	cp 11
	jr nc, .asm_170853
	ld a, b
	and a
	jr nz, .asm_170853
	ret

.asm_170849
	ld hl, wCurDay
	ld a, 140
	sub c
	add [hl]
	cp 11
	ret c
.asm_170853
	ld a, 1
	ld [wScriptVar], a
	ld a, BANK(s5_b2f9) ; aka BANK(s5_b2fa)
	call GetSRAMBank
	xor a
	ld [s5_b2f9], a
	ld [s5_b2fa], a
	call CloseSRAM
	ret

SaveBattleTowerLevelGroup:
	ld a, BANK(sBTChoiceOfLevelGroup)
	call GetSRAMBank
	ldh a, [rSVBK]
	push af
	ld a, BANK(wBTChoiceOfLvlGroup)
	ldh [rSVBK], a
	ld a, [wBTChoiceOfLvlGroup]
	ld [sBTChoiceOfLevelGroup], a
	pop af
	ldh [rSVBK], a
	call CloseSRAM
	ret

LoadBattleTowerLevelGroup: ; Load level group choice
	ld a, BANK(sBTChoiceOfLevelGroup)
	call GetSRAMBank
	ldh a, [rSVBK]
	push af
	ld a, BANK(wBTChoiceOfLvlGroup)
	ldh [rSVBK], a
	ld a, [sBTChoiceOfLevelGroup]
	ld [wBTChoiceOfLvlGroup], a
	pop af
	ldh [rSVBK], a
	call CloseSRAM
	ret

BattleTower_CheckSaveFileExistsAndIsYours:
	ld a, [wSaveFileExists]
	and a
	jr z, .nope
	farcall CompareLoadedAndSavedPlayerID
	jr z, .yes
	xor a ; FALSE
	jr .nope

.yes
	ld a, TRUE

.nope
	ld [wScriptVar], a
	ret

Function1708b1: ; BattleTowerAction $0a
	xor a
	ld [wMusicFade], a
	call MaxVolume
	ret

CheckMobileEventIndex: ; BattleTowerAction $0b something to do with GS Ball
	ld a, BANK(sMobileEventIndex)
	call GetSRAMBank
	ld a, [sMobileEventIndex]
	ld [wScriptVar], a
	call CloseSRAM
	ret

Function1708c8: ; BattleTowerAction $0c
	call UpdateTime
	ld a, BANK(s5_aa8b) ; aka BANK(s5_aa8c), BANK(s5_aa5d), BANK(s5_aa48), and BANK(s5_aa47)
	call GetSRAMBank
	ld a, [wCurDay]
	ld [s5_aa8b], a
	xor a
	ld [s5_aa8c], a
	ld a, [s5_aa5d]
	cp 2
	jr nc, .asm_1708ec
	ld a, [wCurDay]
	ld [s5_aa48], a
	ld a, 1
	ld [s5_aa47], a
.asm_1708ec
	call CloseSRAM
	ret

Function1708f0: ; BattleTowerAction $0d
	xor a ; FALSE
	ld [wScriptVar], a
	call UpdateTime
	ld a, BANK(s5_aa48) ; aka BANK(s5_aa47)
	call GetSRAMBank
	ld a, [s5_aa48]
	ld c, a
	ld a, [s5_aa47]
	call CloseSRAM
	and a
	ret z
	ld hl, wCurDay
	ld a, c
	cp [hl]
	jr nz, Function170923
	ld a, BANK(s5_aa5d)
	call GetSRAMBank
	ld a, [s5_aa5d]
	call CloseSRAM
	cp 5
	ret c
	ld a, TRUE
	ld [wScriptVar], a
	ret

Function170923:
	ld a, BANK(s5_aa48) ; aka BANK(s5_aa47) and BANK(s5_aa5d)
	call GetSRAMBank
	xor a
	ld [s5_aa48], a
	ld [s5_aa47], a
	ld hl, s5_aa5d
	ld bc, MOBILE_LOGIN_PASSWORD_LENGTH
	call ByteFill
	call CloseSRAM
	ret

BattleTowerAction_EggTicket: ; BattleTowerAction $0e
	xor a ; FALSE
	ld [wScriptVar], a
	ld a, EGG_TICKET
	ld [wCurItem], a
	ld hl, wNumItems
	call CheckItem
	ret nc
	ld a, [wPartyCount]
	ld b, 0
	ld c, a
	ld hl, wPartySpecies
.loop
	ld a, [hli]
	cp EGG
	jr nz, .not_egg
	push hl
	ld hl, wPartyMonOT
	ld de, NAME_LENGTH_JAPANESE
	ld a, b
	and a
	jr z, .skip
.loop2
	add hl, de
	dec a
	jr nz, .loop2
.skip
	ld de, String_MysteryJP
	ld a, NAME_LENGTH_JAPANESE
.compare_loop
	push af
	ld a, [de]
	inc de
	cp [hl]
	inc hl
	jr nz, .different
	pop af
	dec a
	jr nz, .compare_loop
rept 4
	dec hl
endr
	ld a, "@"
	ld [hli], a
	ld [hli], a
	pop hl
	ld a, EGG_TICKET
	ld [wCurItem], a
	ld a, 1
	ld [wItemQuantityChangeBuffer], a
	ld a, -1
	ld [wCurItemQuantity], a
	ld hl, wNumItems
	call TossItem
	ld a, TRUE
	ld [wScriptVar], a
	ret

.different
	pop af
	pop hl
.not_egg
	inc b
	dec c
	jr nz, .loop
	ret

String_MysteryJP:
	db "なぞナゾ@@" ; MYSTERY

Function1709aa: ; BattleTowerAction $0f
	ldh a, [rSVBK]
	push af
	ld a, BANK(w3_d090)
	ldh [rSVBK], a
	ld a, [w3_d090]
	ld [wScriptVar], a
	pop af
	ldh [rSVBK], a
	ret

Function1709bb: ; BattleTowerAction $10
	xor a ; FALSE
	ld [wScriptVar], a
	ld a, BANK(s5_a800)
	call GetSRAMBank
	ld a, [s5_a800]
	call CloseSRAM
	cp 6
	jr nc, .invalid
	ld e, a
	ld d, 0
	ld hl, .jumptable
	add hl, de
	add hl, de
	ld a, [hli]
	ld h, [hl]
	ld l, a
	jp hl

.invalid
	ld a, BANK(s5_a800)
	call GetSRAMBank
	xor a
	ld [s5_a800], a
	call CloseSRAM
	ret

.jumptable:
	dw .NoAction
	dw .NoAction
	dw .DoAction1
	dw .DoAction1
	dw .Action4
	dw .Action5

.DoAction1:
	ld a, BANK(s5_a800)
	call GetSRAMBank
	ld a, 1
	ld [s5_a800], a
	call CloseSRAM

.NoAction:
	ret

.Action4:
	ld a, BANK(s5_b023) ; aka BANK(s5_a825) and BANK(s5_a826)
	call GetSRAMBank
	ld hl, s5_b023
	ld de, wc608
	ld bc, 105
	call CopyBytes
	ld a, [s5_a825]
	ld [wcd30], a
	ld a, [s5_a826]
	ld [wcd31], a
	call CloseSRAM
	farcall Function11b6b4
	farcall Function17d0f3
	ld a, TRUE
	ld [wScriptVar], a
	ret

.Action5:
	ld a, 0 ; ???
	call GetSRAMBank
	ld hl, wRTC
	ld de, wc608
	ld bc, 4
	call CopyBytes
	call CloseSRAM
	ld a, BANK(s5_b08c)
	call GetSRAMBank
	ld hl, s5_b08c
	ld de, wc608
	ld c, 4
.compare_loop
	ld a, [de]
	inc de
	cp [hl]
	jr nz, .different
	inc hl
	dec c
	jr nz, .compare_loop
	call CloseSRAM
	ld a, [wMapGroup]
	ld b, a
	ld a, [wMapNumber]
	ld c, a
	call GetMapSceneID
	ld a, d
	or e
	jr z, .no_scene
	ld a, [de]
	and a
	ret nz

.no_scene
	ld a, TRUE
	ld [wScriptVar], a
	ret

.different
	call CloseSRAM
	ld a, BANK(s5_a800)
	call GetSRAMBank
	xor a
	ld [s5_a800], a
	call CloseSRAM
	ld [wScriptVar], a
	ld a, [wMapGroup]
	ld b, a
	ld a, [wMapNumber]
	ld c, a
	call GetMapSceneID
	ld a, d
	or e
	jr z, .no_scene_2
	xor a
	ld [de], a

.no_scene_2
	ret

Function170a9c:
	ld c, FALSE
	jr asm_170aa2

Function170aa0:
	ld c, TRUE
asm_170aa2:
	ld a, BANK(s5_aa8d)
	call GetSRAMBank
	ld a, c
	ld [s5_aa8d], a
	call CloseSRAM
	ret

Function170aaf:
	ld a, BANK(s5_aa8d)
	call GetSRAMBank
	ld a, [s5_aa8d]
	ld [wScriptVar], a
	call CloseSRAM
	ret

Function170abe:
	call BattleTower_CheckSaveFileExistsAndIsYours
	ld a, [wScriptVar]
	and a
	ret z

	ld a, BANK(sBattleTowerSaveFileFlags)
	call GetSRAMBank
	ld a, [sBattleTowerSaveFileFlags]
	and 1
	ld [wScriptVar], a
	call CloseSRAM
	ret

Function170ad7:
	ld a, BANK(sBattleTowerSaveFileFlags)
	call GetSRAMBank
	ld a, [sBattleTowerSaveFileFlags]
	or 1
	ld [sBattleTowerSaveFileFlags], a
	call CloseSRAM
	ret

BattleTowerAction_LevelCheck:
	ld a, BANK(s5_b2fb)
	call GetSRAMBank
	ld a, [s5_b2fb]
	call CloseSRAM
	ld c, 10
	call SimpleDivide
	ld a, b
	ld [wcd4f], a
	xor a
	ld [wScriptVar], a
	farcall BattleTower_LevelCheck
	ret nc
	ld a, BANK(s5_b2fb)
	call GetSRAMBank
	ld a, [s5_b2fb]
	call CloseSRAM
	ld [wScriptVar], a
	ret

BattleTowerAction_UbersCheck:
	ld a, BANK(s5_b2fb)
	call GetSRAMBank
	ld a, [s5_b2fb]
	call CloseSRAM
	ld c, 10
	call SimpleDivide
	ld a, b
	ld [wcd4f], a
	xor a
	ld [wScriptVar], a
	farcall BattleTower_UbersCheck
	ret nc
	ld a, BANK(s5_b2fb)
	call GetSRAMBank
	ld a, [s5_b2fb]
	call CloseSRAM
	ld [wScriptVar], a
	ret

LoadOpponentTrainerAndPokemonWithOTSprite:
	farcall Function_LoadOpponentTrainerAndPokemons
	ldh a, [rSVBK]
	push af
	ld a, BANK(wBT_OTTrainerClass)
	ldh [rSVBK], a
	ld hl, wBT_OTTrainerClass
	ld a, [hl]
	dec a
	ld c, a
	ld b, 0
	pop af
	ldh [rSVBK], a
	ld hl, BTTrainerClassSprites
	add hl, bc
	ld a, [hl]
	ld [wBTTempOTSprite], a

; Load sprite of the opponent trainer
; because s/he is chosen randomly and appears out of nowhere
	ld a, [wScriptVar]
	dec a
	sla a
	ld e, a
	sla a
	sla a
	sla a
	ld c, a
	ld b, 0
	ld d, 0
	ld hl, wMapObjects
	add hl, bc
	inc hl
	ld a, [wBTTempOTSprite]
	ld [hl], a
	ld hl, wUsedSprites
	add hl, de
	ld [hli], a
	ldh [hUsedSpriteIndex], a
	ld a, [hl]
	ldh [hUsedSpriteTile], a
	farcall GetUsedSprite
	ret

INCLUDE "data/trainers/sprites.asm"

CheckForBattleTowerRules:
	farcall _CheckForBattleTowerRules
	jr c, .ready
	xor a ; FALSE
	jr .end

.ready
	ld a, TRUE

.end
	ld [wScriptVar], a
	ret
