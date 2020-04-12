
%if 0

    Lzd - Educational decompressor for the lzip format
    Copyright (C) 2013-2019 Antonio Diaz Diaz.

    This program is free software. Redistribution and use in source and
    binary forms, with or without modification, are permitted provided
    that the following conditions are met:

    1. Redistributions of source code must retain the above copyright
    notice, this list of conditions and the following disclaimer.

    2. Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

%endif


	struc state
.st:	resw 1		; initialise to zero
	endstruc

amount_states equ 12

	align 2
next_states:
.:
	times 4 db 0
	db 1, 2, 3, 4, 5, 6, 4, 5
.amount: equ $ - .
%if .amount != amount_states
 %error Invalid next_states array content
%endif


State:
		; INP:	ds:bx -> state structure
		; OUT:	CY if st < 7 (is_char() == true)
		;	NC if st >= 7 (is_char() == false)
.is_char:
	cmp byte [bx + state.st], 7
	retn

.set_char:
	push bx
	mov al, byte [bx + state.st]
	mov bx, next_states
	cs xlatb
	pop bx
.end:
	mov byte [bx + state.st], al
	retn

.set_match:
	call .is_char
	mov al, 7
	jc .end
	mov al, 10
	jmp .end

.set_rep:
	call .is_char
	mov al, 8
.common_set_rep:
	jc .end
	mov al, 11
	jmp .end

.set_short_rep:
	call .is_char
	mov al, 9
	jmp .common_set_rep


  min_dictionary_size:		equ 1 << 12
  max_dictionary_size:		equ 1 << 29
  literal_context_bits:		equ 3
  literal_pos_state_bits:	equ 0		; not used
  pos_state_bits:		equ 2
  pos_states:			equ 1 << pos_state_bits
  pos_state_mask:		equ pos_states - 1

  len_states:			equ 4
  dis_slot_bits:		equ 6
  start_dis_model:		equ 4
  end_dis_model:		equ 14
  modeled_distances:		equ 1 << ( end_dis_model / 2 )		; 128
  dis_align_bits:		equ 4
  dis_align_size:		equ 1 << dis_align_bits

  len_low_bits:			equ 3
  len_mid_bits:			equ 3
  len_high_bits:		equ 8
  len_low_symbols:		equ 1 << len_low_bits
  len_mid_symbols:		equ 1 << len_mid_bits
  len_high_symbols:		equ 1 << len_high_bits
  max_len_symbols:		equ len_low_symbols + len_mid_symbols + len_high_symbols

  min_match_len:		equ 2		; must be 2

  bit_model_move_bits:		equ 5
  bit_model_total_bits:		equ 11
  bit_model_total:		equ 1 << bit_model_total_bits


	struc bit_model
.probability:	resd 1		; initialise to bit_model_total / 2
	endstruc

	struc len_model
.choice1:	resb bit_model_size
.choice2:	resb bit_model_size
.bm_low:	resb bit_model_size * pos_states * len_low_symbols
.bm_mid:	resb bit_model_size * pos_states * len_mid_symbols
.bm_high:	resb bit_model_size * len_high_symbols
	endstruc

	struc lzip_header
.magic:			resd 1
.version:		resb 1
.coded_dict_size:	resb 1
	endstruc

	struc lzip_trailer
.uncompressed_checksum:	resd 1
.uncompressed_size:	resq 1
.member_size:		resq 1
	endstruc

	struc range_decoder
.member_pos:		resq 1
.code:			resd 1
.range:			resd 1
	endstruc

		; INP:	ds:bx -> range_decoder structure
		; CHG:	es
		; CHG:	NC if success
		;	CY if error
Range_decoder.init:
	push ds
	pop es
	mov ax, 6
	mov di, bx		; -> .member_pos
	stosw			; low word of .member_pos
	xor ax, ax
	stosw
	stosw
	stosw			; high words of .member_pos
	stosw
	stosw			; .code
	dec ax
	stosw
	stosw			; .range
	mov cx, 5
.loop:
	call getbyteshiftcode
	jc .ret
	loop .loop
				; (NC)
.ret:
	retn

		; CHG:	NC if success
		;	CY if error
getbyteshiftcode:
	push ax
	mov ax, word [bx + range_decoder.code + 1]
	mov word [bx + range_decoder.code + 2], ax
	mov ah, byte [bx + range_decoder.code]
	call Range_decoder.get_byte
	mov word [bx + range_decoder.code], ax
	pop ax
	retn

		; INP:	ds:bx -> range_decoder structure
		; OUT:	al = byte read
		; CHG:	NC if success
		;	CY if error
Range_decoder.get_byte:
	add word [bx + range_decoder.member_pos], 1
	adc word [bx + range_decoder.member_pos + 2], 0
	adc word [bx + range_decoder.member_pos + 4], 0
	adc word [bx + range_decoder.member_pos + 6], 0
	jc .ret
	call get_byte
.ret:
	retn

		; INP:	ds:bx -> range_decoder structure
		;	cx = num_bits
		; OUT:	NC if success,
		;	 dx:ax = symbol
		;	CY if error
		; CHG:	di, cx
Range_decoder.decode:
	xor dx, dx
	xor ax, ax
	jcxz .end
.loop:
	shr word [bx + range_decoder.range + 2], 1
	rcr word [bx + range_decoder.range], 1
	shl ax, 1
	rcl dx, 1
	mov di, word [bx + range_decoder.code + 2]
	cmp di, word [bx + range_decoder.range + 2]
	jne @F
	mov di, word [bx + range_decoder.code]
	cmp di, word [bx + range_decoder.range]
@@:				; code >= range ?
	jnae @F			; no, skip -->
	mov di, word [bx + range_decoder.range]
	sub word [bx + range_decoder.code], di
	mov di, word [bx + range_decoder.range + 2]
	sbb word [bx + range_decoder.code + 2], di
	inc ax			; symbol |= 1 (lowest bit always was zero)
@@:
	call normaliserange
	jc .ret
	loop .loop
.end:
	clc
.ret:
	retn


		; CHG:	NC if success
		;	CY if error
normaliserange:
	cmp byte [bx + range_decoder.range + 3], 0
	clc			; (NC)
	jnz @F
	push ax
	mov ax, word [bx + range_decoder.range + 1]
	mov word [bx + range_decoder.range + 2], ax
	mov ah, byte [bx + range_decoder.range]
	mov al, 0
	mov word [bx + range_decoder.range], ax
	pop ax
	call getbyteshiftcode
@@:
	retn


		; INP:	ds:bx -> range_decoder structure
		;	es:di -> bit_model structure
		; OUT:	dx:ax = read bit
		;	NC if zero read
		;	CY if one read
		;	! If an error occurs, skips its own stack frame
		;	   and returns CY with the next caller's stack frame.
Range_decoder.decode_bit:
	xor ax, ax
	lframe near
	lvar dword,	bound
	lenter
	lvar dword,	symbol
	 push ax
	 push ax

	mov dx, word [bx + range_decoder.range + 2]
	mov ax, word [bx + range_decoder.range]
	mov cx, bit_model_total_bits
@@:
	shr dx, 1
	rcr ax, 1
	loop @B

	push ax
	push dx
	mul word [es:di + bit_model.probability]
				; dx:ax = low word + first high word
	mov word [bp + ?bound + 2], dx
	mov word [bp + ?bound], ax
				; = low word + first high word
	pop ax
	mul word [es:di + bit_model.probability]
				; ax = second high word (dx overflow)
	add word [bp + ?bound + 2], ax
	pop ax
	mul word [es:di + bit_model.probability + 2]
				; ax = third high word (dx overflow)
	add word [bp + ?bound + 2], ax
				; = full uint32_t result

	mov dx, word [bp + ?bound + 2]
	mov ax, word [bp + ?bound]
	mov cx, bit_model_move_bits

	cmp word [bx + range_decoder.code + 2], dx
	jne @F
	cmp word [bx + range_decoder.code], ax
@@:
	jnb .not_code_below_bound
	mov word [bx + range_decoder.range], ax
	mov word [bx + range_decoder.range + 2], dx
	mov ax, bit_model_total
	xor dx, dx
	sub ax, word [es:di + bit_model.probability]
	sbb dx, word [es:di + bit_model.probability + 2]
@@:
	shr dx, 1		; fixme: may need sar
	rcr ax, 1
	loop @B
	add word [es:di + bit_model.probability], ax
	adc word [es:di + bit_model.probability + 2], dx
	mov word [bp + ?symbol + 2], cx
	mov word [bp + ?symbol], cx
	jmp .after_if

.not_code_below_bound:
	sub word [bx + range_decoder.range], ax
	sbb word [bx + range_decoder.range + 2], dx
	sub word [bx + range_decoder.code], ax
	sbb word [bx + range_decoder.code + 2], dx

	mov ax, word [es:di + bit_model.probability]
	mov dx, word [es:di + bit_model.probability + 2]
@@:
	shr dx, 1
	rcr ax, 1
	loop @B
	sub word [es:di + bit_model.probability], ax
	sbb word [es:di + bit_model.probability + 2], dx
	mov word [bp + ?symbol + 2], cx
	inc cx			; = 1
	mov word [bp + ?symbol], cx

.after_if:
	call normaliserange
	jc .error
	mov ax, word [bp + ?symbol]
	mov dx, word [bp + ?symbol + 2]
	cmp al, 1		; CY if 0, NC if 1
	cmc			; NC if 0, CY if 1
	lleave
	lret

.error:
	mov sp, bp		; drop our stack frame's variables
	pop bp			; drop our stack frame
	mov sp, bp		; drop next stack frame's variables
	pop bp			; drop next stack frame
	stc			; CY = error
	retn


		; INP:	ds:bx -> range_decoder structure
		;	es:di -> bit_model structure array
		;	cx = num_bits
		; OUT:	NC if success,
		;	 dx:ax = symbol
		;	CY if failure
		; CHG:	cx, si
Range_decoder.decode_tree:
	xor ax, ax
	lframe near
	lenter
	lvar dword,	symbol
	 push ax
	inc ax
	 push ax		; ?symbol = 1
	push cx
	jcxz .end
.loop:
	push cx
	push di
	mov ax, bit_model_size
	cmp word [bp + ?symbol + 2], 0
	jne .error
	mul word [bp + ?symbol]
	test dx, dx
	jnz .error
	add di, ax		; index into bit_model array
	jc .error
	shl word [bp + ?symbol], 1
	rcl word [bp + ?symbol + 2], 1
	call Range_decoder.decode_bit
	adc word [bp + ?symbol], 0
	adc word [bp + ?symbol + 2], 0
				; add in the decoded bit (note *both* adc ops)
	pop di
	pop cx
	loop .loop
.end:
	pop cx
	mov ax, 1
	xor dx, dx		; = 1
	jcxz @FF
@@:
	shl ax, 1
	rcl dx, 1
	loop @B
@@:				; = 1 << num_bits
	sub word [bp + ?symbol], ax
	sbb word [bp + ?symbol + 2], dx
				; symbol - ( 1 << num_bits )
	mov ax, word [bp + ?symbol]
	mov dx, word [bp + ?symbol + 2]
				; return symbol
	db __TEST_IMM8		; (NC, skip stc)
.error:
	stc
	lleave
	lret


		; INP:	ds:bx -> range_decoder structure
		;	es:di -> bit_model structure array
		;	cx = num_bits
		; OUT:	NC if success,
		;	 dx:ax = reversed_symbol
		;	CY if failure
		; CHG:	cx, si
Range_decoder.decode_tree_reversed:
	push cx
	call Range_decoder.decode_tree
	pop cx
	jc .ret
	lframe near
	lenter
	lvar dword,	symbol
	 push dx
	 push ax
	xor ax, ax
	xor dx, dx		; = reversed_symbol
	jcxz .end
.loop:
	shr word [bp + ?symbol + 2], 1
	rcr word [bp + ?symbol], 1
	rcl ax, 1
	rcl dx, 1
	loop .loop
.end:
	clc
	lleave
.ret:
	lret


		; INP:	ds:bx -> range_decoder structure
		;	es:di -> bit_model structure array
		;	al = match_byte
		; OUT:	NC if success,
		;	 al = return value (symbol & 0FFh)
		;	CY if error
Range_decoder.decode_matched:
	lframe near
	lenter
	lvar word,	match_byte
	 push ax
	lvar dword,	symbol
	xor dx, dx
	 push dx
	inc dx
	 push dx		; initialise ?symbol = 1

	mov cx, 8
.loop:
	xor dx, dx
	mov dh, byte [bp + ?match_byte]
	dec cx
	shr dh, cl		; match_byte >> i
	inc cx
	and dh, 1		; & 1
	push dx
	add dx, 100h
	add dx, word [bp + ?symbol]
	cmp word [bp + ?symbol + 2], 0
	jne .error
	push di
	push cx
	mov ax, bit_model_size
	mul dx
	test dx, dx
	jnz .error
	add di, ax
	jc .error
	call Range_decoder.decode_bit
	pop cx
	pop di
	pop dx
	rcl word [bp + ?symbol], 1
	rcl word [bp + ?symbol + 2], 1
	cmp ax, dx		; if( match_bit != bit )
	jne .inner_next		; do the following -->
.next:
	loop .loop
.end:
	xor ax, ax
	mov al, byte [bp + ?symbol]
	db __TEST_IMM8		; (NC, skip stc)
.error:
	stc

	lleave code
	lret


.inner_loop:
	cmp word [bp + ?symbol + 2], 0
	jne .error
	mov ax, bit_model_size
	mul word [bp + ?symbol]
	test dx, dx
	jnz .error
	call Range_decoder.decode_bit
	rcl word [bp + ?symbol], 1
	rcl word [bp + ?symbol + 2], 1

.inner_next:
	cmp word [bp + ?symbol + 2], 0
	jne @F
	cmp word [bp + ?symbol], 100h
@@:
	jb .inner_loop
	jmp .end

	lleave ctx


		; INP:	ds:bx -> range_decoder structure
		;	es:di -> len_model structure
		;	dx:ax = pos_state
		; OUT:	NC if success,
		;	 dx:ax = return
		;	CY if error
		; CHG:	cx, si
Range_decoder.decode_len:
	lframe near
	lenter
	lvar dword,	pos_state
	 push dx
	 push ax
	lvar word,	len_model_struc
	 push di

	lea di, [di + len_model.choice1]
	call Range_decoder.decode_bit
	 pop di
	 push di
	jc .not_decode_bit_choice1_equals_zero

	lea di, [di + len_model.bm_low]
	mov ax, len_low_symbols * bit_model_size
	mul word [bp + ?pos_state]
	test dx, dx
	jnz .error
	cmp word [bp + ?pos_state + 2], dx
	jne .error
	add di, ax
	jc .error
	mov cx, len_low_bits
	call Range_decoder.decode_tree
	jmp .ret_CF

.not_decode_bit_choice1_equals_zero:
	lea di, [di + len_model.choice2]
	call Range_decoder.decode_bit
	 pop di
	 push di
	jc .not_decode_bit_choice2_equals_zero

	lea di, [di + len_model.bm_mid]
	mov ax, len_mid_symbols * bit_model_size
	mul word [bp + ?pos_state]
	test dx, dx
	jnz .error
	cmp word [bp + ?pos_state + 2], dx
	jne .error
	add di, ax
	jc .error
	mov cx, len_mid_bits
	call Range_decoder.decode_tree
	pushf
	add ax, len_low_symbols & 0FFFFh
	adc dx, len_low_symbols >> 16
	popf
	jmp .ret_CF

.not_decode_bit_choice2_equals_zero:
	lea di, [di + len_model.bm_high]
	mov cx, len_high_bits
	call Range_decoder.decode_tree
	pushf
	add ax, (len_low_symbols + len_mid_symbols) & 0FFFFh
	adc dx, (len_low_symbols + len_mid_symbols) >> 16
	popf
.ret_CF:
	 pop di			; pop from ?len_model_struc
	lleave
	lret

.error:
	stc
	jmp .ret_CF


	struc lz_decoder
.partial_data_pos:	resq 1
.range_decoder:		resb range_decoder_size
			alignb 4
.dictionary_size:	resd 1
; .buffer:		resd 1
.pos:			resd 1
.stream_pos:		resd 1
.pos_wrapped:		resb 1
	endstruc


		; INP:	ds:bx -> lz_decoder structure, localvariables structure
		;	dx:ax = distance
		; OUT:	al = ax = byte from buffer
		; CHG:	dx, cx, di, es
LZ_decoder.peek:
	cmp word [bx + lz_decoder.pos + 2], dx
	jne @F
	cmp word [bx + lz_decoder.pos], ax
@@:
	jna .not_pos_above_distance

	push bx
	 push word [bx + destinationbuffer_constant + 2]
	 push word [bx + destinationbuffer_constant]

	push dx
	push ax

	mov ax, word [bx + lz_decoder.pos]
	mov dx, word [bx + lz_decoder.pos + 2]

.common:
	pop cx
	pop bx
	neg bx
	neg cx
	sbb bx, byte 0		; neg bx:cx = - distance

	sub cx, 1
	sbb bx, 0		; - 1

	add cx, ax
	adc bx, dx		; + pos

	call normalise_pointer_with_displacement_bxcx
	 pop di
	 pop es
	pop bx
	xor ax, ax
	mov al, byte [es:di]
	retn

.not_pos_above_distance:
	cmp byte [bx + lz_decoder.pos_wrapped], 0
	je .not_pos_wrapped

	push bx
	 push word [bx + destinationbuffer_constant + 2]
	 push word [bx + destinationbuffer_constant]

	push dx
	push ax

	mov ax, word [bx + lz_decoder.pos]
	mov dx, word [bx + lz_decoder.pos + 2]
	add ax, word [bx + lz_decoder.dictionary_size]
	adc dx, word [bx + lz_decoder.dictionary_size + 2]
	jmp .common

.not_pos_wrapped:
	xor ax, ax
	retn


		; INP:	ds:bx -> lz_decoder structure
		;	al = byte to write to buffer
		; OUT:	NC if success
		;	CY if error
		; CHG:	cx, dx, ax, di, es
LZ_decoder.put_byte:
	push bx
	 push word [bx + destinationbuffer_constant + 2]
	 push word [bx + destinationbuffer_constant]
	mov cx, word [bx + lz_decoder.pos]
	mov bx, word [bx + lz_decoder.pos + 2]
	mov dx, bx
	call normalise_pointer_with_displacement_bxcx
	 pop di
	 pop es
	pop bx
	add cx, 1
	adc dx, 0

	cmp word [bx + destination_length + 2], dx
	jne @F
	cmp word [bx + destination_length], cx
@@:
	jb .ret

	stosb
	mov word [bx + lz_decoder.pos], cx
	mov word [bx + lz_decoder.pos + 2], dx
%if 0
	cmp dx, word [bx + lz_decoder.dictionary_size + 2]
	jne @F
	cmp cx, word [bx + lz_decoder.dictionary_size]
@@:
	jnae .not_pos_above_equal_dictionary_size

	call LZ_decoder.flush_data

.not_pos_above_equal_dictionary_size:
%endif
	clc
.ret:
	retn


		; INP:	ds:bx -> lz_decoder structure
		; OUT:	si:di:dx:ax = data position
LZ_decoder.data_position:
	xor si, si
	xor di, di
	mov dx, word [bx + lz_decoder.pos + 2]
	mov ax, word [bx + lz_decoder.pos]
	add ax, word [bx + lz_decoder.partial_data_pos]
	adc dx, word [bx + lz_decoder.partial_data_pos + 2]
	adc di, word [bx + lz_decoder.partial_data_pos + 4]
	adc si, word [bx + lz_decoder.partial_data_pos + 6]
	retn


		; OUT:	NC if success,
		;	 al = byte
		;	CY if error
		; CHG:	-
LZ_decoder.get_byte:
	push bx
	lea bx, [bx + lz_decoder.range_decoder]
	call Range_decoder.get_byte
	pop bx
	retn


		; INP:	ds:bx -> lz_decoder structure
		; OUT:	si:di:dx:ax = member position
LZ_decoder.member_position:
	mov ax, word [bx + lz_decoder.range_decoder + range_decoder.member_pos]
	mov dx, word [bx + lz_decoder.range_decoder + range_decoder.member_pos + 2]
	mov di, word [bx + lz_decoder.range_decoder + range_decoder.member_pos + 4]
	mov si, word [bx + lz_decoder.range_decoder + range_decoder.member_pos + 6]
	retn


	struc localvariables
lz_decoder_struc:
		resb lz_decoder_size
		alignb 4
bit_models_start:
bm_literal:	resb bit_model_size * (1 << literal_context_bits) * 300h
bm_match:	resb bit_model_size * amount_states * pos_states
bm_rep:		resb bit_model_size * amount_states
bm_rep0:	resb bit_model_size * amount_states
bm_rep1:	resb bit_model_size * amount_states
bm_rep2:	resb bit_model_size * amount_states
bm_len:		resb bit_model_size * amount_states * pos_states
bm_dis_slot:	resb bit_model_size * len_states * (1 << dis_slot_bits)
bm_dis:		resb bit_model_size * (modeled_distances - end_dis_model + 1)
bm_align:	resb bit_model_size * dis_align_size
match_len_model:resb len_model_size
rep_len_model:	resb len_model_size
bit_models_end:
zeros_start:
rep0:		resd 1
rep1:		resd 1
rep2:		resd 1
rep3:		resd 1
state_struc:	resb state_size
		alignb 16
zeros_end:
sourcebuffer_incrementing:	resd 1		; increments
source_remaining:		resd 1		; decrements
destinationbuffer_constant:	resd 1		; stays constant
destination_length:		resd 1		; stays constant
		alignb 16
	endstruc
%if lz_decoder_struc != 0
 %error Expecting lz_decoder structure at start of localvariables structure
%endif
%assign STRUCSIZE localvariables_size
%warning localvariables has STRUCSIZE bytes


		; INP:	ds:bx -> range_decoder structure
		;	thus ds:(bx - lz_decoder.range_decoder)
		;	 -> lz_decoder structure, localvariables structure
		; OUT:	NC if success,
		;	 al = value read
		;	CY if error
get_byte:
	sub word [bx - lz_decoder.range_decoder + source_remaining], 1
	sbb word [bx - lz_decoder.range_decoder + source_remaining + 2], 0
	jc .ret
	push dx
	push si
	mov dx, ds
	lds si, [bx - lz_decoder.range_decoder + sourcebuffer_incrementing]
	lodsb
	 push ds
	 push si
	call normalise_pointer
	mov ds, dx
	 pop word [bx - lz_decoder.range_decoder + sourcebuffer_incrementing]
	 pop word [bx - lz_decoder.range_decoder + sourcebuffer_incrementing + 2]
	pop si
	pop dx
	clc
.ret:
	retn


		; INP:	ds:bx -> localvariables structure,
		;	 source_remaining, sourcebuffer_incrementing,
		;	 destinationbuffer_constant, destination_length
		;	 all pre-initialised
		;	dx:ax = dictionary size
		; OUT:	NC if success
		;	CY if error
		; CHG:	all
LZ_decoder.decode_member:
	lframe near
	lvar dword,	distance
	lvar dword,	len_state
	lvar dword,	len
	lvar dword,	dis_slot
	lvar word,	pos_state
	lenter
	lvar dword,	localvariables
	 push ds
	 push bx
	lea cx, [bx + lz_decoder.range_decoder]
	lvar word,	range_decoder
	 push cx
	lea cx, [bx + state_struc]
	lvar word,	state_struc
	 push cx

	 push dx
	 push ax			; preserve dictionary size
	push ds
	pop es
	mov di, bx
	mov cx, fromdwords(dwords(lz_decoder_size)) / 2
	xor ax, ax
	rep stosw			; initialise lz_decoder structure

	mov bx, word [bp + ?range_decoder]
	call Range_decoder.init		; initialise embedded range_decoder
	mov bx, word [bp + ?localvariables]

	 pop word [bx + lz_decoder.dictionary_size]
	 pop word [bx + lz_decoder.dictionary_size + 2]
					; set dictionary size

	lea di, [bx + bit_models_start]
	mov cx, (bit_models_end - bit_models_start) / bit_model_size
	xor dx, dx
	mov ax, bit_model_total / 2	; initial value for bit_model
@@:
	stosw
	xchg ax, dx
	stosw
	xchg ax, dx			; initialise this bit_model
	loop @B				; loop for all bit_model and len_model

	; lea di, [bx + zeros_start]
	xor ax, ax
	mov cl, (zeros_end - zeros_start) / 2
	rep stosw

.loop:
	mov bx, word [bp + ?localvariables]
	call LZ_decoder.data_position
	and ax, pos_state_mask
	mov cx, ax			; = pos_state
	mov word [bp + ?pos_state], cx

	push ds
	pop es
	lea di, [bx + bm_match]		; es:di -> bm_match 2D array
	mov ax, bit_model_size * pos_states
	mul word [bx + state_struc + state.st]
					; dx:ax = first index is state
	test dx, dx
	jnz .error
%rep bit_model_size
	add ax, cx			; = second index is pos_state
	jc .error
%endrep
	add di, ax			; es:di -> bm_match[state()][pos_state]
	jc .error
	mov bx, [bp + ?range_decoder]	; ds:bx -> range_decoder structure
	call Range_decoder.decode_bit
	mov bx, [bp + ?localvariables]
	jc .1st_bit_not_zero

.1st_bit_zero:
	xor ax, ax
	xor dx, dx
	call LZ_decoder.peek		; al = prev_byte

	mov cl, 8 - literal_context_bits
	shr al, cl			; = literal_state
	push ds
	pop es
	lea di, [bx + bm_literal]	; -> 2D array bm_literal
	mov cx, bit_model_size * 300h
	mul cx				; first index is literal_state
	test dx, dx
	jnz .error
	add di, ax			; es:di -> bm_literal[literal_state]
	jc .error

	mov bx, word [bp + ?state_struc]
	call State.is_char
	jnc .not_is_char
.is_char:
	mov cx, 8
	mov bx, word [bp + ?range_decoder]
	call Range_decoder.decode_tree
	jmp @F

.not_is_char:
	mov bx, word [bp + ?localvariables]
	mov ax, word [bx + rep0]
	mov dx, word [bx + rep0 + 2]
	push es
	push di
	call LZ_decoder.peek
	pop di
	pop es
	mov bx, word [bp + ?range_decoder]
	call Range_decoder.decode_matched
@@:
	jc .error
	mov bx, word [bp + ?localvariables]
	call LZ_decoder.put_byte
	jc .error
	mov bx, word [bp + ?state_struc]
	call State.set_char
	jmp .loop


.1st_bit_not_zero:
	mov bx, word [bp + ?localvariables]
	push ds
	pop es
	lea di, [bx + bm_rep]		; es:di -> bm_rep array
	mov ax, bit_model_size
	mul word [bx + state_struc + state.st]
					; dx:ax = index is state
	test dx, dx
	jnz .error
	add di, ax			; es:di -> bm_rep[state()]
	jc .error
	mov bx, [bp + ?range_decoder]	; ds:bx -> range_decoder structure
	call Range_decoder.decode_bit
	mov bx, [bp + ?localvariables]
	jnc .2nd_bit_zero

.2nd_bit_not_zero:
	push ds
	pop es
	lea di, [bx + bm_rep0]		; es:di -> bm_rep0 array
	mov ax, bit_model_size
	mul word [bx + state_struc + state.st]
					; dx:ax = index is state
	test dx, dx
	jnz .error
	add di, ax			; es:di -> bm_rep0[state()]
	jc .error
	mov bx, [bp + ?range_decoder]	; ds:bx -> range_decoder structure
	call Range_decoder.decode_bit
	mov bx, [bp + ?localvariables]
	jc .3rd_bit_not_zero

.3rd_bit_zero:
	push ds
	pop es
	lea di, [bx + bm_len]		; es:di -> bm_len 2D array
	mov ax, bit_model_size * pos_states
	mul word [bx + state_struc + state.st]
					; dx:ax = first index is state
	test dx, dx
	jnz .error
	mov cx, bit_model_size
@@:
	add ax, word [bp + ?pos_state]
	jc .error
	loop @B
	add di, ax			; es:di -> bm_len[state()]
	jc .error
	mov bx, [bp + ?range_decoder]	; ds:bx -> range_decoder structure
	call Range_decoder.decode_bit
	mov bx, [bp + ?localvariables]
	jc .4th_bit_not_zero

.4th_bit_zero:
	mov bx, [bp + ?state_struc]
	call State.set_short_rep
	mov bx, word [bp + ?localvariables]
	mov ax, word [bx + rep0]
	mov dx, word [bx + rep0 + 2]
	call LZ_decoder.peek
	call LZ_decoder.put_byte
	jc .error
	jmp .loop

.3rd_bit_not_zero:
	push ds
	pop es
	lea di, [bx + bm_rep1]		; es:di -> bm_rep1 array
	mov ax, bit_model_size
	mul word [bx + state_struc + state.st]
					; dx:ax = index is state
	test dx, dx
	jnz .error
	add di, ax			; es:di -> bm_rep1[state()]
	jc .error
	mov bx, [bp + ?range_decoder]	; ds:bx -> range_decoder structure
	call Range_decoder.decode_bit
	mov bx, [bp + ?localvariables]
	jc .3rd_bit_not_zero.4th_bit_not_zero

.3rd_bit_not_zero.4th_bit_zero:
	push word [bx + rep1 + 2]
	push word [bx + rep1]
	pop word [bp + ?distance]
	pop word [bp + ?distance + 2]
	jmp .3rd_bit_not_zero.common

.3rd_bit_not_zero.4th_bit_not_zero:
	push ds
	pop es
	lea di, [bx + bm_rep2]		; es:di -> bm_rep2 array
	mov ax, bit_model_size
	mul word [bx + state_struc + state.st]
					; dx:ax = index is state
	test dx, dx
	jnz .error
	add di, ax			; es:di -> bm_rep2[state()]
	jc .error
	mov bx, [bp + ?range_decoder]	; ds:bx -> range_decoder structure
	call Range_decoder.decode_bit
	mov bx, [bp + ?localvariables]
	jc .3rd_bit_not_zero.4th_bit_not_zero.5th_bit_not_zero

.3rd_bit_not_zero.4th_bit_not_zero.5th_bit_zero:
	push word [bx + rep2 + 2]
	push word [bx + rep2]
	pop word [bp + ?distance]
	pop word [bp + ?distance + 2]
	jmp .3rd_bit_not_zero.4th_bit_not_zero.common

.3rd_bit_not_zero.4th_bit_not_zero.5th_bit_not_zero:
	push word [bx + rep3 + 2]
	push word [bx + rep3]
	pop word [bp + ?distance]
	pop word [bp + ?distance + 2]	; distance = rep3
	push word [bx + rep2 + 2]
	push word [bx + rep2]
	pop word [bx + rep3]
	pop word [bx + rep3 + 2]	; rep3 = rep2

.3rd_bit_not_zero.4th_bit_not_zero.common:
	push word [bx + rep1 + 2]
	push word [bx + rep1]
	pop word [bx + rep2]
	pop word [bx + rep2 + 2]	; rep2 = rep1

.3rd_bit_not_zero.common:
	mov bx, [bp + ?localvariables]
	push word [bx + rep0 + 2]
	push word [bx + rep0]
	pop word [bx + rep1]
	pop word [bx + rep1 + 2]	; rep1 = rep0
	push word [bp + ?distance + 2]
	push word [bp + ?distance]
	pop word [bx + rep0]
	pop word [bx + rep0 + 2]	; rep0 = distance

.4th_bit_not_zero:
	mov bx, [bp + ?state_struc]
	call State.set_rep
	mov bx, word [bp + ?localvariables]
	mov ax, word [bp + ?pos_state]
	xor dx, dx			; dx:ax = pos_state variable
	push ds
	pop es
	lea di, [bx + rep_len_model]	; -> len_model to use
	mov bx, [bp + ?range_decoder]	; -> range_decoder structure
	call Range_decoder.decode_len	; dx:ax = length
	jc .error
	add ax, min_match_len
	adc dx, 0
	jc .error
	mov word [bp + ?len], ax
	mov word [bp + ?len + 2], dx
	jmp .handle_match

.2nd_bit_zero:
	mov bx, [bp + ?localvariables]

	push word [bx + rep2 + 2]
	push word [bx + rep2]
	pop word [bx + rep3]
	pop word [bx + rep3 + 2]	; rep3 = rep2

	push word [bx + rep1 + 2]
	push word [bx + rep1]
	pop word [bx + rep2]
	pop word [bx + rep2 + 2]	; rep2 = rep1

	push word [bx + rep0 + 2]
	push word [bx + rep0]
	pop word [bx + rep1]
	pop word [bx + rep1 + 2]	; rep1 = rep0

	mov ax, word [bp + ?pos_state]
	xor dx, dx			; dx:ax = pos_state variable
	push ds
	pop es
	lea di, [bx + match_len_model]	; -> len_model to use
	mov bx, [bp + ?range_decoder]	; -> range_decoder structure
	call Range_decoder.decode_len	; dx:ax = length
	jc .error

	mov word [bp + ?len_state], ax
	mov word [bp + ?len_state + 2], dx
	test dx, dx
	jnz @F
	cmp ax, len_states - 1
	jb @FF
@@:
	mov word [bp + ?len_state], len_states - 1
	and word [bp + ?len_state + 2], 0
@@:

	add ax, min_match_len
	adc dx, 0
	jc .error

	mov word [bp + ?len], ax
	mov word [bp + ?len + 2], dx

	mov ax, bit_model_size * (1 << dis_slot_bits)
	mul word [bp + ?len_state]	; first index is len_state
	mov bx, dx
	mov cx, ax

	mov ax, bit_model_size * (1 << dis_slot_bits)
	mul word [bp + ?len_state + 2]
	add bx, ax			; bx:cx = first index into array
	jc .error
	test dx, dx
	jnz .error

	push ds
	pop es
	mov di, word [bp + ?localvariables]
	lea di, [di + bm_dis_slot]	; -> 2D array bm_dis_slot
	 push es
	 push di
	call normalise_pointer_with_displacement_bxcx
	 pop di
	 pop es				; -> 1D array at bm_dis_slot[len_state]
	mov bx, word [bp + ?range_decoder]
	mov cx, dis_slot_bits
	call Range_decoder.decode_tree
	mov bx, word [bp + ?localvariables]
	mov word [bx + rep0], ax
	mov word [bx + rep0 + 2], dx

	cmp dx, 0
	jne @F
	cmp ax, start_dis_model
@@:
	jnae .not_rep0_ae_start_dis_model

.rep0_ae_start_dis_model:
	mov word [bp + ?dis_slot], ax
	mov word [bp + ?dis_slot + 2], dx

	shr dx, 1
	rcr ax, 1			; dis_slot >> 1
	sub ax, 1
	sbb dx, 0			; - 1
	jc .error
	jnz .error
	mov cx, ax			; = direct_bits
	xor dx, dx
	mov ax, 1
	and al, byte [bp + ?dis_slot]
	or al, 2
	push cx
	jcxz @FF
@@:
	shl ax, 1
	rcl dx, 1
	loop @B
@@:
	pop cx
	mov word [bx + rep0], ax
	mov word [bx + rep0 + 2], dx

	cmp word [bp + ?dis_slot + 2], 0
	jne @F
	cmp word [bp + ?dis_slot], end_dis_model
@@:
	jnb .not_dis_slot_below_end_dis_model

.dis_slot_below_end_dis_model:
	sub ax, word [bp + ?dis_slot]
	sbb dx, word [bp + ?dis_slot + 2]
					; dx:ax = index into bm_dis array
					;  = rep0 - dis_slot
	jc .error
	 push dx
	mov si, bit_model_size
	mul si
	mov di, ax
	mov bx, dx			; bx:di = low word + first high word
	 pop ax
	mul si				; ax = second high word, dx = overflow
	add bx, ax
	jc .error
	test dx, dx
	jnz .error
	push cx
	mov cx, di
	push ds
	pop es
	mov di, word [bp + ?localvariables]
	lea di, [di + bm_dis]		; es:di -> bm_dis array
	 push es
	 push di
	call normalise_pointer_with_displacement_bxcx
	 pop di
	 pop es				; index into the array
	pop cx
	mov bx, word [bp + ?range_decoder]
	call Range_decoder.decode_tree_reversed
	mov bx, word [bp + ?localvariables]
	add word [bx + rep0], ax
	adc word [bx + rep0 + 2], dx
	jmp .after_dis_slot_below

.not_dis_slot_below_end_dis_model:
	sub cx, dis_align_bits
	mov bx, word [bp + ?range_decoder]
	call Range_decoder.decode
	jc .error
	mov bx, word [bp + ?localvariables]
	mov cx, dis_align_bits
@@:
	shl ax, 1
	rcl dx, 1
	jc .error
	loop @B
	add word [bx + rep0], ax
	adc word [bx + rep0 + 2], dx

	mov cx, dis_align_bits
	push ds
	pop es
	lea di, [bx + bm_align]
	mov bx, word [bp + ?range_decoder]
	call Range_decoder.decode_tree_reversed
	jc .error
	mov bx, word [bp + ?localvariables]
	add word [bx + rep0], ax
	adc word [bx + rep0 + 2], dx

	cmp word [bx + rep0 + 2], -1	; rep0 = 0FFFF_FFFFh ?
	jne @F
	cmp word [bx + rep0], -1
@@:
	je .end				; yes, end -->

.not_rep0_ae_start_dis_model:

.after_dis_slot_below:
	mov bx, word [bp + ?state_struc]
	call State.set_match
	mov bx, word [bp + ?localvariables]
	mov dx, word [bx + rep0 + 2]
	mov ax, word [bx + rep0]

	cmp dx, word [bx + lz_decoder.dictionary_size + 2]
	jne @F
	cmp ax, word [bx + lz_decoder.dictionary_size]
@@:
	jae .error
		; fixme: not checking (rep0 >= pos && !pos_wrapped)

.handle_match:
	mov bx, word [bp + ?localvariables]

	cmp word [bp + ?len + 2], 0
	jne @F
	cmp word [bp + ?len], 0
@@:
	je .handle_match_empty

@@:
	mov dx, word [bx + rep0 + 2]
	mov ax, word [bx + rep0]
	call LZ_decoder.peek
	call LZ_decoder.put_byte
	jc .error
	sub word [bp + ?len], 1
	sbb word [bp + ?len + 2], 0
	jnz @B
	cmp word [bp + ?len], 0
	jne @B

.handle_match_empty:
	jmp .loop


.end:
	cmp word [bp + ?len + 2], min_match_len >> 16
	jne @F
	cmp word [bp + ?len], min_match_len & 0FFFFh
@@:
	jne .error

.done:
	db __TEST_IMM8			; (NC, skip stc)

.error:
	stc
	lleave
	lret


	align 4
lzip_header_bytes:
.:
	db "LZIP",1
.length: equ $ - .


		; INP:	ds:si -> source
		;	dx:cx = length of source
		;	es:di -> destination (below source)
		;	if _IMAGE_EXE:
		;	 bx = EXE mode flag (bit 0)
		;	else:
		;	 bx = 0
		;	ax = maximum amount in paragraphs of destination needed
		;	 (-1 if full source should be decompressed)
		; OUT:	NC if success
		;	CY if error,
		;	 bx = ?errordata (if _DEBUG0)
		; CHG:	ax, (bx), cx, dx, es, ds, si, di
		; STT:	UP
		;
		; Note:	The destination reaches up to below the source.
		; Note:	The input pointers need not be normalised yet.
		;	 Normalised means that the offset part is below 16.
depack:
	lframe near
%if _IMAGE_EXE || _DEBUG0 || _COUNTER
	lenter early
 %if _IMAGE_EXE
	lvar word,	exemode	; must be bp - 2!
	 push bx
  %if ?exemode != -2
   %error exemode variable must be directly below bp
  %endif
 %endif
 %if _DEBUG0 || _COUNTER
	xor bx, bx
 %endif
 %if _DEBUG0
	lvar word,	errordata
	 push bx
 %endif
%endif
	lvar word,	counter
%if _COUNTER
	 push bx		; initialise counter (high byte) to zero
%endif
	lvar dword,	src_behind_block
	lvar word,	frame_descriptor_flg_and_bd
	lenter

	call normalise_both_pointers

	lvar dword,	src
	 push ds
	 push si
	lvar dword,	final_dst
	 push es
	 push di
	lvar dword,	length_of_source
	 push dx
	 push cx

	cmp ax, -1		; no maximum specified ?
	je @FF			; retain -1 in ax -->
	test di, di		; do we need an additional paragraph ?
	jz @F			; no -->
	inc ax			; es + ax => paragraph after necessary part
@@:
	mov dx, es
	add ax, dx		; => paragraph after necessary part
		; If the normalised destination pointer's segment grows
		;  to this segment then enough has been decompressed.
d0	mov byte [bp + ?errordata], 40h
	jc .error		; should not carry
@@:
	lvar word,	dst_max_segment
	 push ax

	 push ds
	 push si
	call pointer_to_linear

	mov bx, dx
	mov cx, ax		; bx:cx = source linear

	 push es
	 push di
	call pointer_to_linear

%if _ALLOW_OVERLAPPING && 0
	add cx, word [bp + ?length_of_source]
	adc bx, word [bp + ?length_of_source + 2]
		; In case of allowing overlapping source and destination,
		;  the ?length_of_destination variable is set to
		;  ?src + ?length_of_source - ?dst, allowing to write to
		;  all of the source buffer (with the checks already in place
		;  from the default handling). Additional checks are done by
		;  calling check_pointers_not_overlapping. This is done after
		;  every change of ?dst to verify that the write pointer stays
		;  below-or-equal the read pointer.
		; This means the remaining source data may be corrupted by a
		;  write, but nothing after the source data is written to,
		;  so the error handling (in INIT1 after the data) still works.
%endif

	sub cx, ax
	sbb bx, dx		; bx:cx = source linear - destination linear

	sub cx, localvariables_size & 0FFFFh
	sbb bx, localvariables_size >> 16
	jbe .error		; make variables buffer available

	lvar dword,	length_of_destination
	 push bx		; push into [bp + ?length_of_destination + 2]
	 push cx		; push into [bp + ?length_of_destination]

	push es
	push di
	mov bx, localvariables_size >> 16
	mov cx, localvariables_size & 0FFFFh
	call normalise_pointer_with_displacement_bxcx
	pop di
	pop es

	lvar dword,	original_dst
	 push es
	 push di
	lvar dword,	dst
	 push es
	 push di

%if _ALLOW_OVERLAPPING && 0
	call check_pointers_not_overlapping
		; Note:	We initially check here that the write pointer is
		;	 low enough, ie below-or-equal the read pointer.
		;	 Doing this check here (as well as after any
		;	 copied match) allows us to drop the check done
		;	 after moving literal bytes.
d0	mov byte [bp + ?errordata], 1Bh
	jc .error
%endif


member_min_size equ 6 + 4 + 16

.loop_member:
	cmp word [bp + ?length_of_source + 2], 0
	jne @F
	cmp word [bp + ?length_of_source], member_min_size
@@:
	ja .got_member

	cmp word [bp + ?length_of_source + 2], 0
	jne @F
	cmp word [bp + ?length_of_source], 15
@@:
	ja .error
	jmp .end

.got_member:
	lds si, [bp + ?src]
	push cs
	pop es
	mov di, lzip_header_bytes
	mov cx, lzip_header_bytes.length
	repe cmpsb
	jne .error
	xor ax, ax
	lodsb

	 push ds
	 push si
	call normalise_pointer
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]

	push ax
	mov cx, ax
	mov ax, 1
	xor dx, dx
	and cl, 1Fh
@@:
	shl ax, 1
	rcl dx, 1
	loop @B

	mov bx, dx
	mov di, ax			; bx:di = dict_size
	mov cl, 4
@@:
	shr bx, 1
	rcr di, 1
	loop @B				; bx:di = dict_size / 16
	pop cx
	mov ch, cl
	mov cl, 5
	shr ch, cl
	mov cl, ch
	mov ch, 0
	jcxz @FF

	push dx
	push ax

	mov ax, di			; ax = low word of input
	mul cx
	xchg ax, bx			; ax = high word of input
	mov di, dx			; di:bx = low word + first high word
	mul cx				; = high word
	add di, ax			; add into sum
	jc .error
	test dx, dx			; overflows ?
	jnz .error
					; bx:di = dict_size / 16 * fraction
	pop ax
	pop dx
	sub ax, bx
	sbb dx, di
	jc .error

	cmp dx, min_dictionary_size >> 16
	jne @F
	cmp ax, min_dictionary_size & 0FFFFh
@@:
	jb .error

	cmp dx, max_dictionary_size >> 16
	jne @F
	cmp ax, max_dictionary_size & 0FFFFh
@@:
	ja .error

	lds bx, [bp + ?final_dst]
	push word [bp + ?dst + 2]
	push word [bp + ?dst]
	pop word [bx + destinationbuffer_constant]
	pop word [bx + destinationbuffer_constant + 2]
	push word [bp + ?length_of_destination + 2]
	push word [bp + ?length_of_destination]
	pop word [bx + destination_length]
	pop word [bx + destination_length + 2]
	push word [bp + ?src + 2]
	push word [bp + ?src]
	pop word [bx + sourcebuffer_incrementing]
	pop word [bx + sourcebuffer_incrementing + 2]
	push word [bp + ?length_of_source + 2]
	push word [bp + ?length_of_source]
	pop word [bx + source_remaining]
	pop word [bx + source_remaining + 2]

	call LZ_decoder.decode_member
	jc .error

	lds bx, [bp + ?final_dst]

	les si, [bx + sourcebuffer_incrementing]
	push word [bx + source_remaining + 2]
	push word [bx + source_remaining]
	pop ax
	pop dx
	sub ax, 4 + 16
	sbb dx, 0
	jb .error

	mov word [bp + ?length_of_source], ax
	mov word [bp + ?length_of_source + 2], dx

	add si, 4			; skip CRC

	es lodsw			; does the destination length match ?
	cmp ax, word [bx + destination_length]
	jne .error
	es lodsw
	cmp ax, word [bx + destination_length + 2]
	jne .error			; if no -->
	es lodsw
	test ax, ax
	jnz .error
	es lodsw
	test ax, ax
	jnz .error

	push si				; does the source length match ?
	call LZ_decoder.member_position
	test si, si
	jnz .error
	pop si
	test di, di
	jnz .error
	cmp word [es:si], ax
	jne .error
	inc si
	inc si
	cmp word [es:si], dx
	jne .error			; if no -->
	inc si
	inc si
	es lodsw
	test ax, ax
	jnz .error
	es lodsw
	test ax, ax
	jnz .error

	 push es
	 push si
	call normalise_pointer
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]

	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
	mov cx, word [bx + destination_length]
	mov bx, word [bx + destination_length + 2]

	sub word [bp + ?length_of_destination], cx
	sbb word [bp + ?length_of_destination + 2], bx

	call normalise_pointer_with_displacement_bxcx
	 pop word [bp + ?dst]
	 pop word [bp + ?dst + 2]

	jmp .loop_member

.end:


		; ds:si -> data
		; bx:ax = length of data
.final:
%if _COUNTER
	push ax
	mov al, '%'
	call disp_al
	pop ax
%endif
	les di, [bp + ?final_dst]
				; -> destination
	lds si, [bp + ?original_dst]
				; -> source
	 push ds
	 push si
	call pointer_to_linear	; dx:ax = linear ?original_dst
	mov cx, ax
	mov bx, dx		; bx:cx = linear ?original_dst
	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
	call pointer_to_linear
	sub ax, cx
	sbb dx, bx		; = linear dst minus linear original_dst

	mov cx, 4
	add ax, 15
	adc dx, 0
@@:
	shr dx, 1
	rcr ax, 1
	loop @B
	mov cx, ax
	test dx, dx
d0	mov byte [bp + ?errordata], 84h
	jnz .error

	call x_mov_p

	db __TEST_IMM8			; (NC)
.error:
	stc

%if _COUNTER
	lahf
	mov al, 13
	call disp_al
	mov al, 10
	call disp_al
	sahf
%endif
d0	mov bx, word [bp + ?errordata]
	lleave code
	lret


		; INP:	ds:si = pointer
		;	es:di = pointer
		; OUT:	ds:si anti normalised
		;	es:di anti normalised
anti_normalise_both_pointers:
	 push ds
	 push si
	call anti_normalise_pointer
	 pop si
	 pop ds

	 push es
	 push di
	call anti_normalise_pointer
	 pop di
	 pop es
	retn


		; INP:	word [ss:sp + 2] = segment
		;	word [ss:sp] = offset
		;
		; Note:	Does not work correctly with pointers that point to
		;	 a HMA location. Do not use then!
anti_normalise_pointer:
	lframe near, nested
	lpar word,	segment
	lpar word,	offset
	lpar_return
	lenter
	push bx
	push cx

	xor bx, bx
	xor cx, cx
	 push word [bp + ?segment]
	 push word [bp + ?offset]
	call anti_normalise_pointer_with_displacement_bxcx
	 pop word [bp + ?offset]
	 pop word [bp + ?segment]

	pop cx
	pop bx
	lleave
	lret


		; INP:	word [ss:sp + 2] = segment
		;	word [ss:sp] = offset
		;	bx:cx = add/sub displacement
		; OUT:	dword [ss:sp] = anti-normalised address
		;
		; An anti-normalised pointer has an offset as high as possible,
		;  which is in the range 0FFF0h to 0FFFFh unless the pointed-to
		;  location is in the first 64 KiB of memory.
anti_normalise_pointer_with_displacement_bxcx:
	lframe near, nested
	lpar word,	segment
	lpar word,	offset
	lpar_return
	lenter
	push ax
	push dx

	 push word [bp + ?segment]
	 push word [bp + ?offset]
	call pointer_to_linear

	add ax, cx
	adc dx, bx			; dx:ax += bx:cx

	cmp dx, 1
	jb @F

	push ax
	or ax, 0FFF0h
	mov word [bp + ?offset], ax
	pop ax

	sub ax, 0FFF0h
	sbb dx, 0

%rep 4
	shr dx, 1
	rcr ax, 1
%endrep
	mov word [bp + ?segment], ax

	jmp .return

		; dx:ax = 0000:offset
@@:
	mov word [bp + ?offset], ax
	and word [bp + ?segment], 0

.return:
	pop dx
	pop ax
	lleave
	lret


		; Move paragraphs
		;
		; INP:	ds:si -> source
		;	es:di -> destination
		;	cx = number of paragraphs
		; CHG:	ax, bx, cx, dx
		; OUT:	ds:si -> after source (normalised)
		;	es:di -> after destination (normalised)
		; Note:	Doesn't work correctly on HMA; doesn't always wrap to LMA either.
		;	Do not provide a wrapped/HMA source or destination!
x_mov_p:
	call normalise_both_pointers
	mov ax, ds
	mov dx, es

	test cx, cx
	jz .return

	cmp ax, dx		; source above destination ?
	ja .up			; yes, move up (forwards) -->
	jb .check_down

	cmp si, di
	ja .up
	je .return		; pointers are the same, no need to move -->
.check_down:
	push ax
	add ax, cx		; (expected not to carry)
	cmp ax, dx		; end of source is above destination ?
	pop ax
	ja .down		; yes, move from top down -->
	jb .up
	cmp si, di
	ja .down

	; Here, the end of source is below-or-equal the destination,
	;  so they do not overlap. In this case we prefer moving up.
.up:
.uploop:
	sub cx, 0FFFh		; 64 KiB - 16 B left ?
	jbe .uplast		; no -->
	push cx
	mov cx, 0FFF0h /2
	rep movsw		; move 64 KiB - 16 B
	pop cx
	call normalise_both_pointers
	jmp short .uploop	; proceed for more -->
.uplast:
	add cx, 0FFFh		; restore counter
	shl cx, 1
	shl cx, 1
	shl cx, 1		; *8, paragraphs to words
	rep movsw		; move last part
	jmp short .return

.down:
	std			; _AMD_ERRATUM_109_WORKAROUND as below

	mov ax, cx
	xor bx, bx
	push cx
	mov cx, 4
@@:
	shl ax, 1
	rcl bx, 1
	loop @B
	sub ax, 2
	sbb bx, 0		; -> point at last word
		; (Cannot borrow here because we checked that cx
		;  was nonzero at the intro to this function, so
		;  bx:ax is at least 16 prior to this subtraction.)
	xchg ax, cx		; bx:cx = displacement to point to last word
	 push ds
	 push si
	call anti_normalise_pointer_with_displacement_bxcx
	 pop si
	 pop ds			; -> last word of source
	 push es
	 push di
	call anti_normalise_pointer_with_displacement_bxcx
	 pop di
	 pop es			; -> last word of destination
	pop cx

.dnloop:
	sub cx, 0FFFh		; 64 KiB - 16 B left ?
	jbe .dnlast		; no -->
	push cx
	mov cx, 0FFF0h /2
	rep movsw		; move 64 KiB - 16 B
	pop cx
	call anti_normalise_both_pointers
	jmp short .dnloop	; proceed for more -->
.dnlast:
	add cx, 0FFFh		; restore counter
	shl cx, 1
	shl cx, 1
	shl cx, 1		; *8, paragraphs to words


	numdef AMD_ERRATUM_109_WORKAROUND, 1
%if 0

Jack R. Ellis pointed out this erratum:

Quoting from https://www.amd.com/system/files/TechDocs/25759.pdf page 69:

109   Certain Reverse REP MOVS May Produce Unpredictable Behavior

Description

In certain situations a REP MOVS instruction may lead to
incorrect results. An incorrect address size, data size
or source operand segment may be used or a succeeding
instruction may be skipped. This may occur under the
following conditions:

* EFLAGS.DF=1 (the string is being moved in the reverse direction).

* The number of items being moved (RCX) is between 1 and 20.

* The REP MOVS instruction is preceded by some microcoded instruction
  that has not completely retired by the time the REP MOVS begins
  execution. The set of such instructions includes BOUND, CLI, LDS,
  LES, LFS, LGS, LSS, IDIV, and most microcoded x87 instructions.

Potential Effect on System

Incorrect results may be produced or the system may hang.

Suggested Workaround

Contact your AMD representative for information on a BIOS update.

%endif

%if _AMD_ERRATUM_109_WORKAROUND
	jcxz @FF
	cmp cx, 20
	ja @FF
@@:
	movsw
	loop @B
@@:
%endif
	rep movsw		; move first part
	cld
.return:
	jmp normalise_both_pointers
