package main


import fcore "../vendor/fmod/core"
import fstudio "../vendor/fmod/studio"
import "core:fmt"


SoundState :: struct {
	system:          ^fstudio.SYSTEM,
	core_system:     ^fcore.SYSTEM,
	bank:            ^fstudio.BANK,
	strings_bank:    ^fstudio.BANK,
	master_ch_group: ^fcore.CHANNELGROUP,
}
sound_st: SoundState

init_sound :: proc() {
	using fstudio
	using sound_st

	fmod_error_check(System_Create(&system, fcore.VERSION))

	fmod_error_check(System_Initialize(system, 512, INIT_NORMAL, INIT_NORMAL, nil))

	fmod_error_check(
		System_LoadBankFile(system, "assets/fmod/Master.bank", LOAD_BANK_NORMAL, &bank),
	)
	fmod_error_check(
		System_LoadBankFile(
			system,
			"assets/fmod/Master.strings.bank",
			LOAD_BANK_NORMAL,
			&strings_bank,
		),
	)


	// 	 fmod_error_check(FMOD_Studio_System_Initialize(sound_st.system, 512, xx FMOD_STUDIO_INIT.NORMAL, xx FMOD_INIT.NORMAL, null));

	//  // load bank files
	//  fmod_error_check(FMOD_Studio_System_LoadBankFile(sound_st.system, "assets/fmod/Master.bank", xx FMOD_STUDIO_LOAD_BANK.NORMAL, *sound_st.bank));
	//  // pretty sure the strings are used so we can have a handle when playing events, idk tho
	//  fmod_error_check(FMOD_Studio_System_LoadBankFile(sound_st.system, "assets/fmod/Master.strings.bank", xx FMOD_STUDIO_LOAD_BANK.NORMAL, *sound_st.strings_bank));
}


update_sound :: proc() {
	using fstudio
	using sound_st

	fmod_error_check(System_Update(system))
}

INVALID_POS :: v2{99999, 99999}
play_sound :: proc(
	name: string,
	pos := INVALID_POS,
	cooldown_ms: f32 = 40.0,
) -> ^fstudio.EVENTINSTANCE {
	using fstudio
	using sound_st

	event_desc: ^EVENTDESCRIPTION
	fmod_error_check(System_GetEvent(system, fmt.ctprint(name), &event_desc))

	instance: ^EVENTINSTANCE
	fmod_error_check(EventDescription_CreateInstance(event_desc, &instance))

	// force cooldown
	fmod_error_check(
		EventInstance_SetProperty(instance, .EVENT_PROPERTY_COOLDOWN, cooldown_ms / 1000.0),
	)

	fmod_error_check(EventInstance_Start(instance))

	// 3D
	attributes: fcore._3D_ATTRIBUTES
	attributes.position = {pos.x, 0, pos.y}
	attributes.forward = {0, 0, 1}
	attributes.up = {0, 1, 0}
	fmod_error_check(EventInstance_Set3DAttributes(instance, &attributes))

	// auto-release when sound finished
	fmod_error_check(EventInstance_Release(instance))

	return instance
}
fmod_error_check :: proc(result: fcore.RESULT) {
	assert(result == .OK, fcore.error_string(result))
}


stop_sound :: proc(instance: ^fstudio.EVENTINSTANCE) {
	using fstudio
	using sound_st
	fmod_error_check(EventInstance_Stop(instance, .STOP_ALLOWFADEOUT))
}
