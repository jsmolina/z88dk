
	SECTION	code_psg

	PUBLIC	ay_wyz_stop
	PUBLIC	_ay_wyz_stop


	EXTERN	asm_wyz_stop

	defc ay_wyz_stop = asm_wyz_stop
	defc _ay_wyz_stop = ay_wyz_stop
	
