
%if 0

8086 Assembly lDOS iniload payload LZ4 depacker
 by C. Masloch, 2018

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


snappy_chunk_id			equ 0FFh
snappy_chunk_padding		equ 0FEh
snappy_chunk_skippable_mask	equ  80h
snappy_chunk_uncompressed	equ  01h
snappy_chunk_compressed		equ  00h

		; INP:	ds:si -> source
		;	dx:cx = length of source
		;	es:di -> destination (below source)
		;	if _IMAGE_EXE:
		;	 bx = EXE mode flag (bit 0)
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
	lvar word,	token_and_counter
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
	lvar dword,	original_dst
	 push es
	 push di
	lvar dword,	dst
	 push es
	 push di
	lvar dword,	length_of_source
	 push dx
	 push cx


	 push ds
	 push si
	call pointer_to_linear

	mov bx, dx
	mov cx, ax		; bx:cx = source linear

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

	lvar dword,	length_of_destination
	 push bx		; push into [bp + ?length_of_destination + 2]
	 push cx		; push into [bp + ?length_of_destination]

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
		; Note:	We initially check here that the write pointer is
		;	 low enough, ie below-or-equal the read pointer.
		;	 Doing this check here (as well as after any
		;	 copied match) allows us to drop the check done
		;	 after moving literal bytes.
d0	mov byte [bp + ?errordata], 1Bh
	jc .error
%endif

.loop_frame:
	xor cx, cx
	cmp word [bp + ?length_of_source + 2], cx
	jne @F
	cmp word [bp + ?length_of_source], cx
	jne @F

.end:
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


@@:
	mov cl, 1
	call read_le_data_src
d0	mov byte [bp + ?errordata], 1
	jc .error

	test al, snappy_chunk_skippable_mask
					; skippable frame ?
	jnz .not_skippable		; no -->

	mov cl, 3
	call read_le_data_src		; read length of skippable frame
d0	mov byte [bp + ?errordata], 2
	jc .error

	xor dh, dh			; dx:ax = length of skippable frame

	 push ds
	 push si
	mov cx, ax
	mov bx, dx			; displacement = skippable frame length
	call normalise_pointer_with_displacement_bxcx
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]	; ?src += length

	sub word [bp + ?length_of_source], ax
	sbb word [bp + ?length_of_source + 2], dx
					; ?length_of_source -= length
d0	mov byte [bp + ?errordata], 5
	jc .error
	jmp .loop_frame


.not_skippable:


	mov cl, 2
	call read_le_data_src		; read FLG (low byte), BD (high byte)
d0	mov byte [bp + ?errordata], 6
.error_CY_1:
	jc .error

	mov word [bp + ?frame_descriptor_flg_and_bd], ax
	mov bx, ax
	and bl, lz4_flg_version_mask
	cmp bl, lz4_flg_version		; version correct ?
d0	mov byte [bp + ?errordata], 7
.error_NZ_1:
	jne .error			; no -->

	test ax, (lz4_bd_reserved_mask << 8) \
		 | lz4_flg_reserved | lz4_flg_dict_id	; unsupported bits set?
d0	mov byte [bp + ?errordata], 8
	jnz .error_NZ_1			; yes -->

		; not checked: lz4_flg_b_indep (linked is always supported),
		;  lz4_flg_b_checksum, lz4_flg_c_checksum (both checked later)

	test al, lz4_flg_c_size		; content size field present ?
	jz @F				; no -->
	mov cl, 8
	call read_le_data_src		; (skip content size field)
d0	mov byte [bp + ?errordata], 9
	jc .error_CY_1
@@:
	mov cl, 1
	call read_le_data_src		; (skip header checksum field)
d0	mov byte [bp + ?errordata], 0Ah
	jc .error_CY_1

.loop_block:
%if _COUNTER
	mov al, '#'
	call disp_al
%endif
	mov cx, 4
	call read_le_data_src		; read block size field
					; leaves ds:si -> source
d0	mov byte [bp + ?errordata], 0Bh
	jc .error_CY_1

	test dx, dx			; nonzero ?
	jnz @FF
	test ax, ax
	jnz @FF				; yes -->

	test byte [bp + ?frame_descriptor_flg_and_bd], lz4_flg_c_checksum
	jz @F
		; cx = 4 already
	call read_le_data_src		; (skip c checksum field)
d0	mov byte [bp + ?errordata], 0Ch
.error_CY_2:
	jc .error_CY_1
@@:
	jmp .loop_frame			; next frame, if any -->


@@:
	 push ds
	 push si			; -> source
	mov bx, dx
	and bh, ~80h			; clear "uncompressed" flag
	mov cx, ax			; bx:cx = block size
	call normalise_pointer_with_displacement_bxcx
					; -> source after block
	 pop word [bp + ?src_behind_block]
	 pop word [bp + ?src_behind_block + 2]
	test dh, 80h			; is it uncompressed ?
	jz .compressed			; no -->

.uncompressed:
	xchg bx, dx			; get size without "uncompressed" flag
	call lz4_copy_literal_or_uncompressed
d0	mov byte [bp + ?errordata], 0Dh
	jc .error_CY_2

.end_block:
	 push word [bp + ?src_behind_block + 2]
	 push word [bp + ?src_behind_block]
	call pointer_to_linear
	mov cx, ax
	mov bx, dx			; bx:cx = linear ?src_behind_block

	 push word [bp + ?src + 2]
	 push word [bp + ?src]
	call pointer_to_linear		; dx:ax = linear ?src

	sub cx, ax
	sbb bx, dx			; ?src_behind_block - ?src
					;  = amount to skip
d0	mov byte [bp + ?errordata], 0Fh
	jc .error_CY_2

	sub word [bp + ?length_of_source], cx
	sbb word [bp + ?length_of_source + 2], bx
d0	mov byte [bp + ?errordata], 10h
.error_CY_3:
	jc .error_CY_2			; not enough data to skip -->

	push word [bp + ?src_behind_block + 2]
	push word [bp + ?src_behind_block]
	pop word [bp + ?src]
	pop word [bp + ?src + 2]	; set ?src -> behind block

	test byte [bp + ?frame_descriptor_flg_and_bd], lz4_flg_b_checksum
	jz @F				; no block checksum -->
	mov cx, 4
	call read_le_data_src		; (skip block checksum field)
d0	mov byte [bp + ?errordata], 0Eh
	jc .error_CY_3
@@:

	jmp .loop_block


.compressed:
.loop_sequence:

%if _COUNTER
	inc byte [bp + ?token_and_counter + 1]
	test byte [bp + ?token_and_counter + 1], _COUNTER - 1
	jnz @F
	mov al, '.'
	call disp_al
@@:
%endif

	mov bx, .lodsb
	call lz4_func_bx_with_src	; load token
d0	mov byte [bp + ?errordata], 11h
	jc .error_CY_3
	mov byte [bp + ?token_and_counter], al

	mov cl, 4
	shr al, cl
	call lz4_get_length		; dx:cx = length of literals
d0	mov byte [bp + ?errordata], 12h
	jc .error_CY_3

	mov ax, cx			; dx:ax = length of literals (may be 0)
	call lz4_copy_literal_or_uncompressed
					; copy over the literals
d0	mov byte [bp + ?errordata], 13h
	jc .error_CY_3

	call lz4_check_behind_block_higher_than_src
					; do we have more data in this block ?
	jc .end_sequence		; no -->

	mov bx, .lodsw
	call lz4_func_bx_with_src	; load match offset
d0	mov byte [bp + ?errordata], 14h
.error_CY_4:
	jc .error_CY_3

	test ax, ax			; offset is 0 ?
d0	mov byte [bp + ?errordata], 15h
	stc
	jz .error_CY_4			; yes, error -->

	mov cx, ax
	neg cx				; -1 .. -65535
	mov bx, -1			; sign-extend (always negative sense)

	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
	call normalise_pointer_with_displacement_bxcx
	 pop si
	 pop ds				; ds:si -> source of matching

	mov ax, ds			; is source of matching within ?dst ?
	cmp word [bp + ?original_dst + 2], ax
d0	mov byte [bp + ?errordata], 16h
.error_A_1:
	ja .error
	jb @F
	cmp word [bp + ?original_dst], si
d0	mov byte [bp + ?errordata], 17h
	ja .error_A_1			; no, ?original_dst is above it -->
@@:

	mov al, byte [bp + ?token_and_counter]
	and al, 0Fh			; get match length from token
	call lz4_get_length		; dx:cx = length of match - 4
d0	mov byte [bp + ?errordata], 18h
	jc .error_CY_4
	mov ax, cx			; dx:ax = length of match - 4
	add ax, 4
	adc dx, 0			; dx:ax = length of match
d0	mov byte [bp + ?errordata], 19h
	jc .error_CY_4
	call lz4_copy_data		; give ?dst -> dest, ds:si -> source
		; returns: ?dst incremented, ds:si -> after match source
d0	mov byte [bp + ?errordata], 1Ah
	jc .error_CY_4

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
d0	mov byte [bp + ?errordata], 1Ch
	jc .error_CY_4
%endif

.next_sequence:
	call lz4_check_behind_block_higher_than_src
	jnc .loop_sequence		; process next sequence -->

.end_sequence:
	jmp .end_block


		; INP:	ds:si -> source data
		;	?length_of_source
		; OUT:	CY if error (source buffer too small)
		;	NC if success,
		;	 al = value read
		;	 ds:si incremented (NOT normalised)
		;	 ?length_of_source decremented
.lodsb:
	sub word [bp + ?length_of_source], 1
	sbb word [bp + ?length_of_source + 2], 0
	jb .retn
	lodsb
.retn:
	retn


		; INP:	ds:si -> source data
		;	?length_of_source
		; OUT:	CY if error (source buffer too small)
		;	NC if success,
		;	 ax = value read
		;	 ds:si incremented (NOT normalised)
		;	 ?length_of_source decremented
.lodsw:
	sub word [bp + ?length_of_source], 2
	sbb word [bp + ?length_of_source + 2], 0
	jb .retn
	lodsw
	retn


		; INP:	?src_behind_block -> block end (normalised)
		;	?src -> current address in source buffer
		; OUT:	CY if ?src is >= (above-or-equal) ?src_behind_block
		;	NC else (?src is below ?src_behind_block, more data)
		; CHG:	ax, dx
		;
		; Note:	Although ?src should always equal ?src_behind_block
		;	 if CY here, we actually check for above-or-equal.
lz4_check_behind_block_higher_than_src:
	mov dx, word [bp + ?src_behind_block + 2]
	mov ax, word [bp + ?src_behind_block]
					; dx:ax -> behind block

	cmp word [bp + ?src + 2], dx	; compare segment
	ja .error			; ?src > dx:ax -->
	jb .success			; ?src < dx:ax -->
	cmp word [bp + ?src], ax	; segment is same, compare offset
	jae .error			; ?src >= dx:ax -->

.success:
	db __TEST_IMM8			; (NC)
.error:
	stc
	retn


		; INP:	?dst -> destination (normalised)
		;	?src -> source (normalised)
		;	dx:ax = how long the literal data is (0 is valid)
		; OUT:	?dst incremented (normalised)
		;	?src incremented (normalised)
		;	?length_of_destination shortened
		;	?length_of_source shortened
		;	CY if error (either buffer too small)
		;	NC if success
		; CHG:	cx, dx, ax, es, di, ds, si
lz4_copy_literal_or_uncompressed:
	lds si, [bp + ?src]

	sub word [bp + ?length_of_source], ax
	sbb word [bp + ?length_of_source + 2], dx
					; enough data exists ?
	jb .return			; no --> (CY)

	call lz4_copy_data		; CY/NC depending on status

	mov word [bp + ?src], si
	mov word [bp + ?src + 2], ds
					; (CF preserved)
.return:
	retn


		; INP:	?dst -> destination (normalised)
		;	ds:si -> source (normalised)
		;	dx:ax = how long the data is (0 is valid)
		; OUT:	?dst incremented (normalised)
		;	ds:si incremented (normalised)
		;	?length_of_destination shortened
		;	CY if error (buffer too small)
		;	NC if success
		; CHG:	cx, dx, ax, es, di, ds, si
lz4_copy_data:
d0	inc byte [bp + ?errordata + 1]
	sub word [bp + ?length_of_destination], ax
	sbb word [bp + ?length_of_destination + 2], dx
					; enough space left ?
	jb .error			; no -->

	les di, [bp + ?dst]
.loop:
	mov cx, 64 * 1024 - 16		; block size
		; If both pointers are normalised, moving 0FFF0h bytes is
		;  valid and results in a maximum offset of 0FFFFh in either.

	test dx, dx			; >= 1_0000h ?
	jnz @F				; yes, full block -->
	test ax, ax			; == 0 ?
	jz .end				; yes, done -->
	cmp ax, cx			; can move in one (last) block ?
	jbe .last			; yes -->
@@:
					; no, move one block and continue
	sub ax, cx
	sbb dx, 0			; left over remaining
	jmp .copy

.last:
	xchg cx, ax			; cx = remaining length
	xor ax, ax			; no more remaining

.copy:
	rep movsb			; move one block (full or partial)

	call normalise_both_pointers
	jmp .loop

.end:
	mov word [bp + ?dst], di
	mov word [bp + ?dst + 2], es

	db __TEST_IMM8			; (NC)
.error:
	stc
	retn


		; INP:	?src -> source data
		;	bx = function to call
		; OUT:	ds:si = ?src -> behind data (normalised)
		;	CY if error (buffer too small)
		;	NC if success
		;	(CF is passed from what the function at bx returns)
		;
		; Protocol of function in bx called by this:
		; INP:	ds:si -> source data
		;	?length_of_source
		;	(may take more inputs depending on function)
		; OUT:	ds:si incremented (NOT normalised)
		;	?length_of_source decremented
		;	CY if error (buffer too small or other error)
		;	NC if success
		;	(may give more outputs depending on function)
lz4_func_bx_with_src:
	lds si, [bp + ?src]
	call bx
	pushf
	 push ds
	 push si
	call normalise_pointer
	 pop si
	 pop ds
	mov word [bp + ?src], si
	mov word [bp + ?src + 2], ds
	popf
	retn


		; INP:	?src -> source data
		;	?length_of_source
		;	al = first field data (0 to 15)
		; OUT:	dx:cx = length value
		;	?src incremented
		;	?length_of_source decremented
		;	CY if error (too high or out of source data)
		;	NC if success
		; CHG:	ax, bx
lz4_get_length:
	push ds
	push si

	xor cx, cx
	xor dx, dx			; dx:cx = length field
	mov ah, 15			; first byte maximum value
.loop:
	add cl, al
	adc ch, 0
	adc dx, 0			; add in this byte
	jc .error			; if too high -->
	cmp al, ah			; is this the maximum value ?
	jne .end			; no -->
	mov bx, depack.lodsb
	call lz4_func_bx_with_src	; load next byte
	jc .error
	mov ah, 255			; next maximum value is 255
	jmp .loop			; -->

.end:
	db __TEST_IMM8			; (NC)
.error:
	stc

	pop si
	pop ds
	retn


		; INP:	?src -> source data (normalised)
		;	cx = size to read, 1 to 4 or higher (at most 0FFF0h)
		;	?length_of_source
		; OUT:	If cx >= 4,
		;	 dx:ax = value read as little-endian
		;	If cx == 3,
		;	 dl:ax = value read
		;	If cx == 2,
		;	 ax = value read
		;	If cx == 1,
		;	 al = value read
		;	If cx == 0,
		;	 invalid, CY
		;	ds:si = ?src = incremented source (normalised)
		;	?length_of_source decremented
		;	CY if error (source buffer too small, or cx zero)
		;	NC if success
		; CHG:	ds, si, dx, ax
		;
		; Note:	Always reads four bytes at INP:ds:si -> data.
read_le_data_src:
	jcxz .error

	sub word [bp + ?length_of_source], cx
	sbb word [bp + ?length_of_source + 2], 0
	jb .error

	lds si, [bp + ?src]

	lodsw
	xchg ax, dx		; dx = low word (first)
	lodsw			; ax = high word (second)
	xchg ax, dx		; fix order, dx:ax = dword

	sub si, 4
	add si, cx

	 push ds
	 push si
	call normalise_pointer
	 pop si
	 pop ds
	mov word [bp + ?src], si
	mov word [bp + ?src + 2], ds

	db __TEST_IMM8		; (NC)
.error:
	stc
	retn

