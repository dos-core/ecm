
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


	numdef COUNTER,		0, 256
%if (_COUNTER - 1) & _COUNTER
 %error COUNTER must be a power of two
%endif


amount_states equ 12

		numdef XLATBSEQ, 7
		numdef WARNXLATBSEQ, 0


%if _XLATBSEQ != 7
next_states.beforealign:
	align 2
next_states:
.:
	times 4 db 0
	db 1, 2, 3, 4, 5, 6, 4, 5
.amount: equ $ - .
 %if .amount != amount_states
  %error Invalid next_states array content
 %endif
 %assign XLATBTABSIZE $ - .beforealign
%else
 %assign XLATBTABSIZE 0
%endif


State:
		; INP:	ds:bx -> localvariables
		;	byte [bx + state.st]
		; OUT:	CY if st < 7 (is_char() == true)
		;	NC if st >= 7 (is_char() == false)
		; CHG:	-
.is_char:
	cmp byte [bx + state.st], 7
	retn


		; INP:	ds:bx -> localvariables
		;	byte [bx + state.st]
		; OUT:	byte [bx + state.st] = al = next state
		; CHG:	al, ah (ah only if _XLATBSEQ == 6)
.set_char:

.xlatbseq:
%if 0 == _XLATBSEQ	; 10
	push bx
	mov al, byte [bx + state.st]
	mov bx, next_states
	cs xlatb
		; Problem: It is reported that prior to the 386
		;  a segment override on an xlatb instruction
		;  does not have any effect. So this choice is
		;  possibly wrong on those machines.
	pop bx
%elif 1 == _XLATBSEQ	; 13
	push bx
	mov al, byte [bx + state.st]
	mov bx, next_states
	push ds
	 push cs
	 pop ds
	xlatb
	pop ds
	pop bx
%elif 2 == _XLATBSEQ	; 16
	push bx
	mov al, byte [bx + state.st]
	mov bx, next_states
	add bl, al
	adc bh, 0
	mov al, byte [cs:bx]
	pop bx
%elif 3 == _XLATBSEQ	; 14
	push bx
	mov al, byte [bx + state.st]
	xor bx, bx
	mov bl, al
	mov al, byte [cs:next_states + bx]
	pop bx
%elif 4 == _XLATBSEQ	; 12
	push bx
	mov bl, byte [bx + state.st]
	mov bh, 0
	mov al, byte [cs:next_states + bx]
	pop bx
%elif 5 == _XLATBSEQ	; 10
	push bx
	mov bl, byte [bx + state.st]
	; mov bh, 0
		; ! because the pointer stored in ?localvariables
		;    is normalised bh is already zero here.
	mov al, byte [cs:next_states + bx]
	pop bx
%elif 6 == _XLATBSEQ	; 12
	xor ax, ax
	mov al, byte [bx + state.st]
	xchg ax, bx
	mov bl, byte [cs:next_states + bx]
	xchg ax, bx
%elif 7 == _XLATBSEQ	; 16, but minus 13 for table
	mov al, byte [bx + state.st]
	sub al, 3		; below 4 ?
	jbe .zero		; yes -->
	cmp al, 10 - 3		; 10 or 11 initially ?
	jb .have		; no -->
	sub al, 3		; convert
.have:
	db __TEST_IMM16		; (skip mov)
.zero:
	mov al, 0
%else
 %error Invalid xlatb sequence specified
%endif
%if _WARNXLATBSEQ
%assign SIZE $ - .xlatbseq
%warning xlatb sequence takes SIZE bytes plus XLATBTABSIZE table
%endif
.end:
	mov byte [bx + state.st], al
	retn


		; INP:	ds:bx -> localvariables
		;	byte [bx + state.st]
		;	al = value to use if is_char() == true
		;	ah = value to use else
		; OUT:	byte [bx + state.st] = al = value to use
		; CHG:	al
.select:
	call .is_char
	jc .end
	mov al, ah
	jmp .end


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
.probability:	resw 1		; initialise to bit_model_total / 2
				; at most bit_model_total (800h)
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
.member_pos:		resd 1
.code:			resd 1
.range:			resd 1
	endstruc

		; INP:	ds:bx -> range_decoder structure
		;	ss:bp -> depack stack frame
		; OUT:	! If an error occurs, jumps to depack.error
		; CHG:	es, di, ax, cx
Range_decoder.init:
	push ds
	pop es
	mov ax, 6
	mov di, bx		; -> .member_pos
	stosw			; low word of .member_pos
	xor ax, ax
	stosw			; high word of .member_pos
	stosw
	stosw			; .code
	dec ax
	stosw
	stosw			; .range
	mov cx, 5
.loop:
	call getbyteshiftcode
	loop .loop
	retn


		; INP:	ds:bx -> range_decoder structure
		;	ss:bp -> depack stack frame
		; OUT:	! If an error occurs, jumps to depack.error
		; CHG:	-
normaliserange:
	cmp byte [bx + range_decoder.range + 3], 0
	jnz @F			; (retn)
	push ax
	mov ax, word [bx + range_decoder.range + 1]
	mov word [bx + range_decoder.range + 2], ax
	mov ah, byte [bx + range_decoder.range]
	mov al, 0
	mov word [bx + range_decoder.range], ax
	pop ax
		; fall through


		; INP:	ds:bx -> range_decoder structure
		;	ss:bp -> depack stack frame
		; OUT:	! If an error occurs, jumps to depack.error
		; CHG:	-
getbyteshiftcode:
	push ax
	mov ax, word [bx + range_decoder.code + 1]
	mov word [bx + range_decoder.code + 2], ax
	mov ah, byte [bx + range_decoder.code]
	call Range_decoder.get_byte
	mov word [bx + range_decoder.code], ax
	pop ax
@@:
	retn


		; INP:	ds:bx -> range_decoder structure
		;	cx = num_bits
		;	ss:bp -> depack stack frame
		; OUT:	! If an error occurs, jumps to depack.error
		;	If success,
		;	 dx:ax = symbol
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
	loop .loop
.end:
	retn


		; INP:	ds:bx -> range_decoder structure
		;	es:di -> bit_model structure
		;	ss:bp -> depack stack frame
		; OUT:	al = read bit
		;	NC if zero read
		;	CY if one read
		;	! If an error occurs, jumps to depack.error
		; CHG:	cx, dx, ax
Range_decoder.decode_bit:
	mov dx, word [bx + range_decoder.range + 2]
	mov ax, word [bx + range_decoder.range]
	mov cx, bit_model_total_bits
@@:
	shr dx, 1
	rcr ax, 1
	loop @B

	mov cx, dx
	mul word [es:di + bit_model.probability]
				; dx:ax = low word + first high word
	 push dx
	 push ax		; on stack = low word + first high word
	xchg ax, cx
	mul word [es:di + bit_model.probability]
				; ax = second high word (dx overflow)
	xchg ax, cx		; cx
	 pop ax
	 pop dx
	add dx, cx		; = full uint32_t result
	mov cx, bit_model_move_bits

	cmp word [bx + range_decoder.code + 2], dx
	jne @F
	cmp word [bx + range_decoder.code], ax
@@:
	jnb .not_code_below_bound

.code_below_bound:
	mov word [bx + range_decoder.range], ax
	mov word [bx + range_decoder.range + 2], dx
	mov ax, bit_model_total
	sub ax, word [es:di + bit_model.probability]
	jc .error
	shr ax, cl
	add word [es:di + bit_model.probability], ax
	mov al, 0
	jmp .after_if

.not_code_below_bound:
	sub word [bx + range_decoder.range], ax
	sbb word [bx + range_decoder.range + 2], dx
	sub word [bx + range_decoder.code], ax
	sbb word [bx + range_decoder.code + 2], dx

	mov ax, word [es:di + bit_model.probability]
	shr ax, cl
	sub word [es:di + bit_model.probability], ax
	jc .error
	mov al, 1

.after_if:
	call normaliserange
	cmp al, 1		; CY if 0, NC if 1
	cmc			; NC if 0, CY if 1
	retn

.error:
	jmp depack.error


		; INP:	ds:bx -> range_decoder structure
		;	es:di -> bit_model structure array
		;	cx = num_bits, <= 15
		;	ss:bp -> depack stack frame
		; OUT:	! If an error occurs, jumps to depack.error
		;	If success,
		;	 dx:ax = ax = symbol
		; CHG:	cx, si
Range_decoder.decode_tree:
	mov si, 1		; symbol = 1
	cmp cx, 15
	ja .error
	push cx
	jcxz .end
.loop:
	push di
		; Here si (symbol) is at most 1 << 14.
%if bit_model_size != 2
 %error Assuming word size for bit_model_size
%endif
	shl si, 1		; Note that this shift is both used instead of
				;  multiplying symbol (si) by bit_model_size
				;  and to actually shift symbol (si) left!
	add di, si		; index into bit_model array
	jc .error_pop_2
	push cx
	call Range_decoder.decode_bit
	pop cx
	adc si, 0		; add in the decoded bit
	pop di
	loop .loop
.end:
	pop cx
	mov ax, 1
	shl ax, cl		; = 1 << num_bits
	sub si, ax		; symbol - ( 1 << num_bits )
	xchg ax, si
	xor dx, dx		; return symbol
	retn

.error_pop_2:
.error:
	jmp depack.error


		; INP:	ds:bx -> range_decoder structure
		;	es:di -> bit_model structure array
		;	cx = num_bits, <= 15
		;	ss:bp -> depack stack frame
		; OUT:	! If an error occurs, jumps to depack.error
		;	If success,
		;	 dx:ax = ax = reversed_symbol
		; CHG:	cx, si
Range_decoder.decode_tree_reversed:
	push cx
	call Range_decoder.decode_tree
	pop cx
	xchg dx, ax		; dx = symbol
	xor ax, ax		; = reversed_symbol
	jcxz .end
.loop:
	shr dx, 1
	rcl ax, 1
	loop .loop
.end:
	xor dx, dx
	retn


		; INP:	ds:bx -> range_decoder structure
		;	es:di -> bit_model structure array
		;	al = match_byte
		;	ss:bp -> depack stack frame
		; OUT:	! If an error occurs, jumps to depack.error
		;	If success,
		;	 al = return value (symbol & 0FFh)
		; CHG:	cx, dx, ax
Range_decoder.decode_matched:
	mov dh, al		; = match_byte

	mov ax, 1		; initialise symbol = 1

	mov cx, 8
.loop:
	push dx			; preserve dh = match_byte
	push cx			; preserve loop counter
	dec cx
	shr dh, cl		; match_byte >> i
	and dx, 100h		; dh &= 1 = match_bit, dl = 0
	push dx
	inc dh			; = (match_bit << 8) + 100h
	add dx, ax		; = symbol + (match_bit << 8) + 100h
		; As symbol is below 256, this is at most 255 + 100h + 100h,
		;  which is 2FFh. As such, the bm_literal array's
		;  entries are arrays of 300h bit_model each.
	push di
	push ax
%if bit_model_size != 2
 %error Assuming word size for bit_model_size
%endif
	add dx, dx
		; As dx was < 300h before this addition, it cannot carry.
	add di, dx
		; We assume that this does not carry.
	call Range_decoder.decode_bit
	xchg ax, cx		; cl = result (1 or 0)
	pop ax			; = symbol
	pop di
	pop dx			; = match_bit << 8
	rcl ax, 1		; shift symbol, OR in the bit
		; As the loop counter is initialised to 8,
		;  the symbol variable stays below 256.
	cmp cl, dh		; if( match_bit != bit ) ...-
	pop cx			; = loop counter
	pop dx			; = dh = match_byte
	jne .inner_next		; -... do the following -->
.next:
	loop .loop
.end:
	xor ah, ah		; return ax = symbol & 0FFh
	retn

.error_pop_2:
.error:
	jmp depack.error


.inner_loop:
	push ax
%if bit_model_size != 2
 %error Assuming word size for bit_model_size
%endif
	add ax, ax
	push di
	add di, ax
	jc .error_pop_2
	call Range_decoder.decode_bit
	pop di
	pop ax
	rcl ax, 1
	jc .error

.inner_next:
	cmp ax, 100h
	jb .inner_loop
	jmp .end


		; INP:	ds:bx -> range_decoder structure
		;	es:di -> len_model structure
		;	ax = pos_state
		;	ss:bp -> depack stack frame
		; OUT:	! If an error occurs, jumps to depack.error
		;	If success,
		;	 dx:ax = return
		; CHG:	cx, si
Range_decoder.decode_len:
	mov si, ax		; = pos_state
	 push di		; = len_model_struc (on stack)

	lea di, [di + len_model.choice1]
	call Range_decoder.decode_bit
	 pop di			; reset to ?len_model_struc
	 push di
	jc .not_decode_bit_choice1_equals_zero

	lea di, [di + len_model.bm_low]
	mov ax, len_low_symbols * bit_model_size
	mul si
	test dx, dx
	jnz .error
	add di, ax
	jc .error
	mov cx, len_low_bits
	call Range_decoder.decode_tree
	jmp .ret

.not_decode_bit_choice1_equals_zero:
	lea di, [di + len_model.choice2]
	call Range_decoder.decode_bit
	 pop di			; reset to ?len_model_struc
	 push di
	jc .not_decode_bit_choice2_equals_zero

	lea di, [di + len_model.bm_mid]
	mov ax, len_mid_symbols * bit_model_size
	mul si
	test dx, dx
	jnz .error
	add di, ax
	jc .error
	mov cx, len_mid_bits
	call Range_decoder.decode_tree
	add ax, len_low_symbols & 0FFFFh
	adc dx, len_low_symbols >> 16
	jmp .ret

.not_decode_bit_choice2_equals_zero:
	lea di, [di + len_model.bm_high]
	mov cx, len_high_bits
	call Range_decoder.decode_tree
	add ax, (len_low_symbols + len_mid_symbols) & 0FFFFh
	adc dx, (len_low_symbols + len_mid_symbols) >> 16
.ret:
	 pop di
	retn

.error:
	jmp depack.error


	struc lz_decoder
.range_decoder:		resb range_decoder_size
			alignb 8
.dictionary_size:	resd 1
.pos:			resd 1
	endstruc


		; INP:	ds:bx -> lz_decoder structure, localvariables structure
		;	dx:ax = distance
		; OUT:	al = ax = byte from buffer
		; CHG:	dx, cx, di, si, es
LZ_decoder.peek:
	cmp word [bx + lz_decoder.pos + 2], dx
	jne @F
	cmp word [bx + lz_decoder.pos], ax
@@:
	jna .not_pos_above_distance

	call calculate_peek_pointer_disi

	mov es, di			; es:si -> peek address
	xor ax, ax
	es lodsb
	retn

.not_pos_above_distance:
	xor ax, ax
	retn


		; INP:	dx:ax = peek distance
		;	ds:bx -> local variables
		; OUT:	di:si -> peek address
		; CHG:	cx, dx, ax
calculate_peek_pointer_disi:
	push bx
	 push word [bx + destinationbuffer_constant + 2]
	 push word [bx + destinationbuffer_constant]

	neg dx
	neg ax
	sbb dx, byte 0			; neg dx:ax = - distance
	sub ax, 1
	sbb dx, 0			; - 1
	add ax, word [bx + lz_decoder.pos]
	adc dx, word [bx + lz_decoder.pos + 2]
					; + pos
	xchg cx, ax
	xchg bx, dx

	call normalise_pointer_with_displacement_bxcx
	 pop si
	 pop di				; di:si -> source
	pop bx
	retn


		; INP:	ss:bp -> depack stack frame
		; OUT:	! If an error occurs, jumps to depack.error
		;	If success,
		;	 al = byte
		; CHG:	-
LZ_decoder.get_byte: equ Range_decoder.get_byte


	struc localvariables
lz_decoder_struc:
		resb lz_decoder_size
		alignb 4
zeros_start:
rep0:		resd 1
rep1:		resd 1
rep2:		resd 1
rep3:		resd 1
state.st:	resw 1		; initialise to zero
		alignb 4
zeros_end:
destinationbuffer_constant:	resd 1		; stays constant
		alignb 16
bit_models_start:
bm_match:	resb bit_model_size * amount_states * pos_states
bm_rep:		resb bit_model_size * amount_states
bm_rep0:	resb bit_model_size * amount_states
bm_rep1:	resb bit_model_size * amount_states
bm_rep2:	resb bit_model_size * amount_states
bm_literal:	resb bit_model_size * (1 << literal_context_bits) * 300h
bm_len:		resb bit_model_size * amount_states * pos_states
bm_dis_slot:	resb bit_model_size * len_states * (1 << dis_slot_bits)
bm_dis:		resb bit_model_size * (modeled_distances - end_dis_model + 1)
bm_align:	resb bit_model_size * dis_align_size
match_len_model:resb len_model_size
rep_len_model:	resb len_model_size
bit_models_end:
		alignb 16
	endstruc
%if lz_decoder_struc != 0
 %error Expecting lz_decoder structure at start of localvariables structure
%endif
%assign STRUCSIZE localvariables_size
%warning localvariables has STRUCSIZE bytes


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
		;	if _PAYLOAD_KERNEL_MAX_PARAS:
		;	 ax = maximum amount in paragraphs of destination needed
		;	 (-1 if full source should be decompressed)
		;	else:
		;	 ax = -1
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
%if _IMAGE_EXE || _COUNTER || _DEBUG0
	lenter early
 %if _IMAGE_EXE
	lvar word,	exemode	; must be bp - 2!
	 push bx
  %if ?exemode != -2
   %error exemode variable must be directly below bp
  %endif
 %endif
 %if _COUNTER || _DEBUG0
	xor bx, bx
 %endif
%endif
%if _COUNTER
	lvar word,	counter
	 push bx		; initialise counter to zero
%endif
d0	lvar word,	errordata
d0	 push bx
	lvar dword,	distance
	lvar dword,	len
	lvar dword,	dis_slot
	lvar word,	len_state
	lvar word,	pos_state
	lenter

	call normalise_both_pointers

		; ! di < 16, so dih == 0
	lvar dword,	src
	 push ds
	 push si
	lvar dword,	final_dst
	 push es
	 push di
	lequ ?final_dst,	localvariables
		; ! offset of ?localvariables is always < 16
		;  required for State.set_char with _XLATBSEQ == 5
	lvar dword,	length_of_source
	 push dx
	 push cx

%if _PAYLOAD_KERNEL_MAX_PARAS
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
	jc .error_CY_a1		; should not carry
@@:
	lvar word,	dst_max_segment
	 push ax
%endif

	 push ds
	 push si
	call pointer_to_linear

	xchg bx, dx
	xchg cx, ax		; bx:cx = source linear, clobber dx:ax

	 push es
	 push di
	call pointer_to_linear

%if _ALLOW_OVERLAPPING
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
	jb .error		; make variables buffer available
	jne @F
	test cx, cx
	jz .error
@@:

	lvar dword,	length_of_destination
	 push bx		; push into [bp + ?length_of_destination + 2]
	 push cx		; push into [bp + ?length_of_destination]

	push es
	push di
%if localvariables_size >> 16
	mov bx, localvariables_size >> 16
%else
	xor bx, bx
%endif
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

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
		; Note:	We initially check here that the write pointer is
		;	 low enough, ie below-or-equal the read pointer.
		;	Unlike the other decompressors, this check is done
		;	 after any copied match or literal too, because
		;	 literals can presumably be encoded with less than
		;	 one byte of source data to the range decoder.
d0	mov byte [bp + ?errordata], 1Bh
.error_CY_a1:
	jc short .error_CY_a
%else
 .error_CY_a1 equ .error_CY_a
%endif


member_min_size equ lzip_header_size + lzip_trailer_size

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
	ja short .error_NZ_a		; (NZ if jumping)
	jmp .end

.got_member:
	lds si, [bp + ?src]		; ds:si -> lzip_header.magic, .version
	push cs
	pop es
	mov di, lzip_header_bytes
	mov cx, lzip_header_bytes.length
	repe cmpsb
.error_NZ_a:
	jne .error
%if _COUNTER && !_PROGRESS
	mov al, '#'
	call disp_al
%endif
	xor ax, ax
	lodsb				; ax = lzip_header.coded_dict_size

	 push ds
	 push si
	call normalise_pointer
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]
	sub word [bp + ?length_of_source], 6
	sbb word [bp + ?length_of_source + 2], 0
.error_CY_a:
	jc short .error_CY_b

	push ax
	and al, 1Fh
	xchg cx, ax			; cx = coded dict size & 1Fh, clobber ax
	mov ax, 1
	xor dx, dx
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

	push dx
	push ax

	mov ax, di			; ax = low word of input
	mul cx
	xchg ax, bx			; ax = high word of input
	mov di, dx			; di:bx = low word + first high word
	mul cx				; = high word
	add di, ax			; add into sum
.error_CY_b:
	jc short .error_CY_c
	test dx, dx			; overflows ?
	jnz .error
					; bx:di = dict_size / 16 * fraction
	pop ax
	pop dx
	sub ax, bx
	sbb dx, di
	jc short .error_CY_c

	cmp dx, min_dictionary_size >> 16
	jne @F
	cmp ax, min_dictionary_size & 0FFFFh
@@:
.error_CY_c:
	jb short .error_CY_d

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


		; decode_member start (inlined)
		; INP:	?localvariables = ds:bx -> localvariables structure,
		;	 destinationbuffer_constant pre-initialised
		;	dx:ax = dictionary size
		;	Following variables of depack frame initialised:
		;	 dword [ss:bp + ?src] -> source buffer
		;	 dword [ss:bp + ?length_of_source] = remaining length
		;	 dword [ss:bp + ?dst] -> destination buffer
		;	 dword [ss:bp + ?length_of_destination] = remaining
		; OUT:	NC if success
		;	CY if error
		; CHG:	all
; LZ_decoder.decode_member:

	 push dx
	 push ax			; preserve dictionary size
	push ds
	pop es
	mov di, bx
	mov cx, fromdwords(dwords(lz_decoder_size)) / 2
	xor ax, ax
	rep stosw			; initialise lz_decoder structure

	call Range_decoder.init		; initialise embedded range_decoder

	 pop word [bx + lz_decoder.dictionary_size]
	 pop word [bx + lz_decoder.dictionary_size + 2]
					; set dictionary size

	lea di, [bx + bit_models_start]
	mov cx, (bit_models_end - bit_models_start) / bit_model_size
	mov ax, bit_model_total / 2	; initial value for bit_model
%if bit_model_size != 2
 %error Assuming word size for bit_model_size
%endif
	rep stosw			; initialise this bit_model
					; loop for all bit_model and len_model

	lea di, [bx + zeros_start]
	xor ax, ax
	mov cl, (zeros_end - zeros_start) / 2
	rep stosw

.loop:
%if _COUNTER
	inc byte [bp + ?counter]
	test byte [bp + ?counter], _COUNTER - 1
	jnz @F
	mov al, '.'
	call disp_al_counter
@@:
%endif
	mov bx, word [bp + ?localvariables]
	mov ax, word [bx + lz_decoder.pos]
	and ax, pos_state_mask
	xchg cx, ax			; cx = pos_state, ax clobbered
	mov word [bp + ?pos_state], cx

	push ds
	pop es
	lea di, [bx + bm_match]		; es:di -> bm_match 2D array
	mov ax, bit_model_size * pos_states
	mul word [bx + state.st]	; dx:ax = first index is state
		; bit_model_size = 2
		; pos_states = 4
		; state.st < 12
		; multiplication 2 * 4 * 11 = 88
%if bit_model_size != 2
 %error Assuming word size for bit_model_size
%endif
	add cx, cx			; = second index (from pos_state)
		; pos_state < 4
		; cx < 8
		; ax <= 88
	add ax, cx			; = second index is pos_state
	add di, ax			; es:di -> bm_match[state()][pos_state]
.error_CY_d:
	jc short .error_CY_1
	call Range_decoder.decode_bit
	jc .1st_bit_not_zero

.1st_bit_zero:			; literal byte
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
	stc
	jnz short .error_CY_1
	add di, ax			; es:di -> bm_literal[literal_state]
.error_CY_1:
	jc short .error_CY_2

	call State.is_char
	jnc .not_is_char
.is_char:
	mov cx, 8
	call Range_decoder.decode_tree
	jmp @F

.not_is_char:
	mov ax, word [bx + rep0]
	mov dx, word [bx + rep0 + 2]
	push es
	push di
	call LZ_decoder.peek
	pop di
	pop es
	call Range_decoder.decode_matched
@@:
	call LZ_decoder.put_byte
	call State.set_char
	jmp .loop


.1st_bit_not_zero:		; match or repeated match
	push ds
	pop es
	lea di, [bx + bm_rep]		; es:di -> bm_rep array
%if bit_model_size != 2
 %error Assuming word size for bit_model_size
%endif
	mov ax, word [bx + state.st]
	add ax, ax			; ax = index is state
	; jc short .error_CY_2	; (state.st is always < 12)
	add di, ax			; es:di -> bm_rep[state()]
.error_CY_2:
	jc short .error_CY_3
	call Range_decoder.decode_bit
	jnc .2nd_bit_zero

.2nd_bit_not_zero:
	push ds
	pop es
	lea di, [bx + bm_rep0]		; es:di -> bm_rep0 array
%if bit_model_size != 2
 %error Assuming word size for bit_model_size
%endif
	mov ax, word [bx + state.st]
	add ax, ax			; ax = index is state
	; jc short .error_CY_3	; (state.st is always < 12)
	add di, ax			; es:di -> bm_rep0[state()]
	jc short .error_CY_3
	call Range_decoder.decode_bit
	jc .3rd_bit_not_zero

.3rd_bit_zero:
	push ds
	pop es
	lea di, [bx + bm_len]		; es:di -> bm_len 2D array
	mov ax, bit_model_size * pos_states
				; (2 * 4 = 8)
	mul word [bx + state.st]; (< 12)
					; dx:ax = first index is state
	; test dx, dx
	; stc
	; jnz short .error_CY_3	; (dx:ax is always < 12 * 8)
%if bit_model_size != 2
 %error Assuming word size for bit_model_size
%endif
%rep bit_model_size
	add ax, word [bp + ?pos_state]
	; jc short .error_CY_3	; (pos_state is always < 4
				;  and state_st is always < 12
				;  and ax is < 12 * 8 prior to adding)
%endrep
	add di, ax			; es:di -> bm_len[state()]
.error_CY_3:
	jc short .error_CY_4
	call Range_decoder.decode_bit
	jc .4th_bit_not_zero

.4th_bit_zero:
; State.set_short_rep
	mov ax, 9 | (11 << 8)
	call State.select

	mov ax, word [bx + rep0]
	mov dx, word [bx + rep0 + 2]
	call LZ_decoder.peek
	call LZ_decoder.put_byte
	jmp .loop

.3rd_bit_not_zero:
	push ds
	pop es
	lea di, [bx + bm_rep1]		; es:di -> bm_rep1 array
%if bit_model_size != 2
 %error Assuming word size for bit_model_size
%endif
	mov ax, word [bx + state.st]
	add ax, ax			; ax = index is state
	; jc short .error_CY_4	; (state.st is always < 12)
	add di, ax			; es:di -> bm_rep1[state()]
.error_CY_4:
	jc short .error_CY_4a
	call Range_decoder.decode_bit
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
%if bit_model_size != 2
 %error Assuming word size for bit_model_size
%endif
	mov ax, word [bx + state.st]
	add ax, ax			; ax = index is state
	; jc short .error_CY_5	; (state.st is always < 12)
	add di, ax			; es:di -> bm_rep2[state()]
.error_CY_4a:
	jc short .error_CY_5
	call Range_decoder.decode_bit
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
	push word [bx + rep0 + 2]
	push word [bx + rep0]
	pop word [bx + rep1]
	pop word [bx + rep1 + 2]	; rep1 = rep0
	push word [bp + ?distance + 2]
	push word [bp + ?distance]
	pop word [bx + rep0]
	pop word [bx + rep0 + 2]	; rep0 = distance

.4th_bit_not_zero:
; State.set_rep
	mov ax, 8 | (11 << 8)
	call State.select

	mov ax, word [bp + ?pos_state]	; ax = pos_state variable
	push ds
	pop es
	lea di, [bx + rep_len_model]	; -> len_model to use
	call Range_decoder.decode_len	; dx:ax = length
	add ax, min_match_len
	adc dx, 0
.error_CY_5:
	jc short .error_CY_6
	mov word [bp + ?len], ax
	mov word [bp + ?len + 2], dx
	jmp .handle_match

.2nd_bit_zero:			; match
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

	mov ax, word [bp + ?pos_state]	; ax = pos_state variable
	push ds
	pop es
	lea di, [bx + match_len_model]	; -> len_model to use
	call Range_decoder.decode_len	; dx:ax = length

	mov word [bp + ?len_state], ax
	test dx, dx
	jnz @F
	cmp ax, len_states - 1
	jb @FF
@@:
	mov word [bp + ?len_state], len_states - 1
@@:

	add ax, min_match_len
	adc dx, 0
.error_CY_6:
	jc short .error_CY_7

	mov word [bp + ?len], ax
	mov word [bp + ?len + 2], dx

	push ds
	pop es
	lea di, [bx + bm_dis_slot]	; -> 2D array bm_dis_slot

	mov ax, bit_model_size * (1 << dis_slot_bits)
	mul word [bp + ?len_state]	; first index is len_state
		; bit_model_size = 2
		; 1 << dis_slot_bits = 1 << 6 = 64
		; ?len_state < 4
		; multiplication 2 * 64 * 3 = 384
					; dx:ax = first index into array
	add di, ax			; -> 1D array at bm_dis_slot[len_state]
	mov cx, dis_slot_bits
	call Range_decoder.decode_tree
	mov word [bx + rep0], ax
	mov word [bx + rep0 + 2], dx

	test dx, dx			; (same flags as cmp dx, 0)
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
.error_CY_7:
.error_CY_8:
	jc short .error_CY_9
	stc
	jnz short .error_CY_9
	xchg cx, ax			; cx = direct_bits, clobber ax
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
.error_CY_9:
	jc short .error_CY_10

%if bit_model_size != 2
 %error Assuming word size for bit_model_size
%endif
	add ax, ax
	adc dx, dx			; dx:ax *= 2
	jc short .error_CY_10
	stc
	jnz short .error_CY_10		; if dx != 0 -->
	push ds
	pop es
	lea di, [bx + bm_dis]		; es:di -> bm_dis array
	add di, ax			; index into the array
	jc short .error_CY_10
	call Range_decoder.decode_tree_reversed
	add word [bx + rep0], ax
	adc word [bx + rep0 + 2], dx
	jc short .error_CY_10
	jmp .after_dis_slot_below

.not_dis_slot_below_end_dis_model:
	sub cx, dis_align_bits
	call Range_decoder.decode
	mov cx, dis_align_bits
@@:
	shl ax, 1
	rcl dx, 1
.error_CY_10:
	jc short .error_CY_11
	loop @B
	add word [bx + rep0], ax
	adc word [bx + rep0 + 2], dx

	mov cx, dis_align_bits
	push ds
	pop es
	lea di, [bx + bm_align]
	call Range_decoder.decode_tree_reversed
	add word [bx + rep0], ax
	adc word [bx + rep0 + 2], dx
.error_CY_11:
	jc .error_CY_12

	cmp word [bx + rep0 + 2], -1	; rep0 = 0FFFF_FFFFh ?
	jne @F
	cmp word [bx + rep0], -1
@@:
	je .end_member			; yes, end (marker found) -->

.after_dis_slot_below:

.not_rep0_ae_start_dis_model:

; State.set_match
	mov ax, 7 | (10 << 8)
	call State.select

	mov dx, word [bx + rep0 + 2]
	mov ax, word [bx + rep0]

	cmp dx, word [bx + lz_decoder.dictionary_size + 2]
	jne @F
	cmp ax, word [bx + lz_decoder.dictionary_size]
@@:
	jae short .error_AE_1

		; check for (rep0 >= pos && !pos_wrapped)
		;  (pos_wrapped is always false for us)
	cmp dx, word [bx + lz_decoder.pos + 2]
	jne @F
	cmp ax, word [bx + lz_decoder.pos]
@@:
.error_AE_1:
	jae short .error_1

.handle_match:
	mov dx, word [bx + rep0 + 2]
	mov ax, word [bx + rep0]

	call calculate_peek_pointer_disi

	mov ax, word [bp + ?len]
	mov dx, word [bp + ?len + 2]	; dx:ax = length


		; INP:	dx:ax = length of match
		;	di:si -> source (normalised)
		;	ds:bx -> local variables structure
		;	ss:bp -> depack stack frame,
		;		with ?length_of_destination, ?dst
		; OUT:	NC if success,
		;	 ?length_of_destination and ?dst updated
		;	CY if error
		;	 (destination buffer too small or overlap error)
		;	! may jump to depack.end if ?dst_max_segment reached
		; CHG:	ax, cx, dx, di, si, es
; handle_match:
	add word [bx + lz_decoder.pos], ax
	adc word [bx + lz_decoder.pos + 2], dx
	jc short .error_CY_12		; (CY) -->

	sub word [bp + ?length_of_destination], ax
	sbb word [bp + ?length_of_destination + 2], dx
					; enough space left ?
	jb short .error_CY_12		; no --> (below == CY)

	push ds

	mov ds, di			; ds:si -> source
	les di, [bp + ?dst]		; es:di -> destination
.hm_loop:
	mov cx, 64 * 1024 - 16		; block size
		; If both pointers are normalised, moving 0FFF0h bytes is
		;  valid and results in a maximum offset of 0FFFFh in either.

	test dx, dx			; >= 1_0000h ?
	jnz @F				; yes, full block -->
	test ax, ax			; == 0 ?
	jz .hm_end			; yes, done -->
	cmp ax, cx			; can move in one (last) block ?
	jbe .hm_last			; yes -->
@@:
					; no, move one block and continue
	sub ax, cx
	sbb dx, 0			; left over remaining
	jmp .hm_copy

.hm_last:
	xchg cx, ax			; cx = remaining length
	xor ax, ax			; no more remaining

.hm_copy:
	rep movsb			; move one block (full or partial)

	call normalise_both_pointers
	jmp .hm_loop

.hm_end:
	mov word [bp + ?dst], di
	mov word [bp + ?dst + 2], es
%if _PAYLOAD_KERNEL_MAX_PARAS
	mov ax, es
	cmp ax, word [bp + ?dst_max_segment]
	jae depack.end
		; note that we have the depack stack frame pointed to by
		;  ss:bp here, which is needed for running depack.end
%endif
	pop ds
%if _ALLOW_OVERLAPPING
	push bx
	call check_pointers_not_overlapping
	pop bx				; returns CF
.error_CY_12:
	jc short .error_1
%endif
	jmp .loop

%if ! _ALLOW_OVERLAPPING
.error_CY_12:
%endif
.error_1:
	jmp .error


.end_member:			; End Of Stream marker
	cmp word [bp + ?len + 2], min_match_len >> 16
	jne @F
	cmp word [bp + ?len], min_match_len & 0FFFFh
@@:
	jne short .error_1

		; decode_member succeeded

	lds bx, [bp + ?final_dst]	; -> localvariables

	sub word [bp + ?length_of_source], lzip_trailer_size
	sbb word [bp + ?length_of_source + 2], 0
	jc .error

	les si, [bp + ?src]	; es:si -> lzip_trailer.uncompressed_checksum
	add si, 4			; skip CRC

				; es:si -> lzip_trailer.uncompressed_size
	es lodsw			; does the destination length match ?
	cmp ax, word [bx + lz_decoder.pos]
	jne .error
	es lodsw
	cmp ax, word [bx + lz_decoder.pos + 2]
	jne .error			; if no -->
	es lodsw
	test ax, ax
	jnz .error
	es lodsw
	test ax, ax
	jnz .error

	add word [bx + lz_decoder.range_decoder + range_decoder.member_pos], lzip_trailer_size
	adc word [bx + lz_decoder.range_decoder + range_decoder.member_pos + 2], 0
	jc .error

				; es:si -> lzip_trailer.member_size
	es lodsw			; does the source length match ?
	cmp ax, word [bx + lz_decoder.range_decoder + range_decoder.member_pos]
	jne .error
	es lodsw
	cmp ax, word [bx + lz_decoder.range_decoder + range_decoder.member_pos + 2]
	jne .error
	es lodsw
	test ax, ax
	jnz .error
	es lodsw
	test ax, ax
	jnz .error

				; es:si -> behind lzip_trailer
	 push es
	 push si
	call normalise_pointer
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]

	jmp .loop_member

.end:

.final:
%if _COUNTER && !_PROGRESS
	mov al, '%'
	call disp_al
%endif
	les di, [bp + ?final_dst]
				; -> destination
	lds si, [bp + ?original_dst]
				; -> source
	 push ds
	 push si
	call pointer_to_linear	; dx:ax = linear ?original_dst
	xchg cx, ax
	xchg bx, dx		; bx:cx = linear ?original_dst, clobber dx:ax
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
	call disp_al_for_progress
	mov al, 10
	call disp_al_for_progress
	sahf
%endif
d0	mov bx, word [bp + ?errordata]
	lleave code
	lret


		; INP:	ds:bx -> range_decoder structure
		;	ss:bp -> depack stack frame
		; OUT:	! If an error occurs, jumps to depack.error
		;	If success,
		;	 al = byte read
		; CHG:	-
Range_decoder.get_byte:
	add word [bx + range_decoder.member_pos], 1
	adc word [bx + range_decoder.member_pos + 2], 0
	jc short .error

		; INP:	ds:bx -> range_decoder structure
		;	ss:bp -> depack stack frame
		; OUT:	! If an error occurs, jumps to depack.error
		;	If success,
		;	 al = value read
		; CHG:	-
; get_byte:
	push ds
	push si

	sub word [bp + ?length_of_source], 1
	sbb word [bp + ?length_of_source + 2], 0
	jc short .error

	lds si, [bp + ?src]
	lodsb
	 push ds
	 push si
	call normalise_pointer
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]
	pop si
	pop ds
	retn

.error: equ depack.error


		; INP:	ds:bx -> lz_decoder structure
		;	al = byte to write to buffer
		;	ss:bp -> depack stack frame
		; OUT:	! If an error occurs, jumps to depack.error
		; CHG:	cx, dx, ax, di, es
LZ_decoder.put_byte:
	les di, [bp + ?dst]

	add word [bx + lz_decoder.pos], 1
	adc word [bx + lz_decoder.pos + 2], 0
	jc short .error

	sub word [bp + ?length_of_destination], 1
	sbb word [bp + ?length_of_destination + 2], 0
	jb short .error

	stosb
	 push es
	 push di
	call normalise_pointer
	 pop word [bp + ?dst]
	 pop word [bp + ?dst + 2]

%if _ALLOW_OVERLAPPING
	push bx
	call check_pointers_not_overlapping
	pop bx			; returns CF
	jc short .error
%endif
	retn

.error: equ depack.error


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
