
%if 0

8086 Assembly lDOS iniload payload Snappy depacker
 by E. C. Masloch, 2018

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

snappy_tag_mask			equ 0000_0011b
snappy_tag_literal		equ 0
snappy_tag_copy_1byteoffset	equ 1
snappy_tag_copy_2byteoffset	equ 2
snappy_tag_copy_4byteoffset	equ 3


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
	lvar word,	chunk_type_and_counter
%if _COUNTER
	 push bx		; initialise counter (high byte) to zero
%endif
	lvar word,	highbits_and_tag
	lvar dword,	src_behind_block
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
	jc .error		; should not carry
@@:
	lvar word,	dst_max_segment
	 push ax
%endif

	 push ds
	 push si
	call pointer_to_linear

	mov bx, dx
	xchg cx, ax		; bx:cx = source linear

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
%if _COUNTER && !_PROGRESS
	mov al, '#'
	call disp_al
%endif
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
	call disp_al_for_progress
	mov al, 10
	call disp_al_for_progress
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

	mov byte [bp + ?chunk_type_and_counter], al

	test al, snappy_chunk_skippable_mask
					; skippable frame ?
	jz .not_skippable		; no -->

	mov cl, 3
	call read_le_data_src		; read length of skippable frame
d0	mov byte [bp + ?errordata], 2
	jc .error
					; dx:ax = length of skippable frame

	 push ds
	 push si
	mov cx, ax
	mov bx, dx			; displacement = skippable frame length
	call normalise_pointer_with_displacement_bxcx
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]	; ?src += length
d0	mov byte [bp + ?errordata], 1Dh
	jc .error

	sub word [bp + ?length_of_source], ax
	sbb word [bp + ?length_of_source + 2], dx
					; ?length_of_source -= length
d0	mov byte [bp + ?errordata], 5
	jc .error
	jmp .loop_frame


.not_skippable:
	cmp al, snappy_chunk_uncompressed
	je @F
	cmp al, snappy_chunk_compressed
d0	mov byte [bp + ?errordata], 6
	jne .error

@@:
	mov cl, 3
	call read_le_data_src		; read length of chunk
d0	mov byte [bp + ?errordata], 7
.error_CY_1:
	jc .error
					; dx:ax = length of chunk
					;	  (including checksum)

	test dx, dx			; at least 4 bytes in this chunk ?
	jnz @F
	cmp ax, 4
d0	mov byte [bp + ?errordata], 8
	jb .error_CY_1			; no, error -->
@@:

	 push ds
	 push si			; -> source
	mov bx, dx
	mov cx, ax			; bx:cx = chunk size
	call normalise_pointer_with_displacement_bxcx
					; -> source after chunk
	 pop word [bp + ?src_behind_block]
	 pop word [bp + ?src_behind_block + 2]
d0	mov byte [bp + ?errordata], 1Eh
	jc .error_CY_1

	push dx
	push ax
	mov cx, 4
	call read_le_data_src		; (skip checksum field)
	pop ax
	pop dx
d0	mov byte [bp + ?errordata], 0Ah
	jc .error_CY_1

	cmp byte [bp + ?chunk_type_and_counter], snappy_chunk_compressed
	 				; is it compressed ?
	je .compressed			; yes -->

.uncompressed:
		; dx:ax = length of chunk
	sub ax, 4
	sbb dx, 0
d0	mov byte [bp + ?errordata], 0Bh
.error_CY_2:
	jc .error_CY_1
	call snappy_copy_literal_or_uncompressed
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

	jmp .loop_frame


.compressed:
@@:
	mov bx, .lodsb
	call snappy_func_bx_with_src	; load next varint byte of preamble
	test al, 80h			; more bytes following ?
	jnz @B

.loop_sequence:

%if _COUNTER
	inc byte [bp + ?chunk_type_and_counter + 1]
	test byte [bp + ?chunk_type_and_counter + 1], _COUNTER - 1
	jnz @F
	mov al, '.'
	call disp_al_counter
@@:
%endif

	mov bx, .lodsb
	call snappy_func_bx_with_src	; load tag byte
d0	mov byte [bp + ?errordata], 11h
	jc .error_CY_3
	mov ah, al
	and ah, snappy_tag_mask
	mov word [bp + ?highbits_and_tag], ax

	shr al, 1
	shr al, 1

	cmp ah, snappy_tag_literal
	jne .copy

.literal:
	xor dx, dx
	xor ah, ah
	inc ax				; dx:ax = literal length if <= 60
					; ax = 61, 62, 63, 64 for 1--4 bytes
	cmp al, 60
	jbe .literal_got_length

	mov cx, ax
	sub cx, 60			; 61 -> 1, 62 -> 2, 63 -> 3, 64 -> 4

	call read_le_data_src
	add ax, 1
	adc dx, 0			; dx:ax = literal length
d0	mov byte [bp + ?errordata], 14h
	jc .error_CY_3

.literal_got_length:
	call snappy_copy_literal_or_uncompressed
	jmp .next_sequence


.copy:
	cmp ah, snappy_tag_copy_1byteoffset
	je .copy_1byteoffset
	cmp ah, snappy_tag_copy_2byteoffset
	je .copy_2byteoffset
	cmp ah, snappy_tag_copy_4byteoffset
	je .copy_4byteoffset
d0	mov byte [bp + ?errordata], 12h
.error_1:
	stc
	jmp .error_CY_3


.copy_1byteoffset:
	and al, 7
	add al, 4
	xor ah, ah

	push ax

	xor dx, dx			; dx = 0
	xor ax, ax
	mov al, byte [bp + ?highbits_and_tag]
	shl ax, 1
	shl ax, 1
	shl ax, 1			; ah = upper three bits of al

	mov bx, .lodsb			; al = to be loaded
	jmp .copy_dxax_offset_stack_length


.copy_2byteoffset:
	xor dx, dx			; dx = 0
	mov bx, .lodsw			; ax = to be loaded
	jmp .copy_2_4_common


.copy_4byteoffset:
	mov bx, .lodsd_dxax		; dx:ax = to be loaded
.copy_2_4_common:
	inc ax
	xor ah, ah

	push ax
		; fall through


.copy_dxax_offset_stack_length:
	call snappy_func_bx_with_src	; load offset value, dx:ax = offset

	mov cx, ax
	mov bx, dx			; bx:cx = offset
	pop ax
	mov dx, 0			; dx:ax = length (preserve CF!)
d0	mov byte [bp + ?errordata], 13h
.error_CY_4:
	jc .error_1

	test bx, bx			; offset is zero ?
	jnz @F
	test cx, cx
d0	mov byte [bp + ?errordata], 15h
	jz .error_1			; yes, error -->
@@:

        neg bx
        neg cx
        sbb bx, byte 0          	; neg bx:cx

	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
	call normalise_pointer_with_displacement_bxcx
	 pop si
	 pop ds				; ds:si -> source of matching
d0	mov byte [bp + ?errordata], 1Fh
	jnc .error

	push ax
	mov ax, ds			; is source of matching within ?dst ?
	cmp word [bp + ?original_dst + 2], ax
	pop ax
d0	mov byte [bp + ?errordata], 16h
.error_A_1:
	ja .error
	jb @F
	cmp word [bp + ?original_dst], si
d0	mov byte [bp + ?errordata], 17h
	ja .error_A_1			; no, ?original_dst is above it -->
@@:

	call snappy_copy_data		; give ?dst -> dest, ds:si -> source
		; returns: ?dst incremented, ds:si -> after match source
d0	mov byte [bp + ?errordata], 1Ah
	jc .error_CY_4

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
d0	mov byte [bp + ?errordata], 1Ch
	jc .error_CY_4
%endif

.next_sequence:
	; call snappy_check_behind_block_higher_than_src
		; INP:	?src_behind_block -> block end (normalised)
		;	?src -> current address in source buffer
		; OUT:	CY if ?src is >= (above-or-equal) ?src_behind_block
		;	NC else (?src is below ?src_behind_block, more data)
		; CHG:	ax, dx
		;
		; Note:	Although ?src should always equal ?src_behind_block
		;	 if CY here, we actually check for above-or-equal.
; snappy_check_behind_block_higher_than_src:
	mov dx, word [bp + ?src_behind_block + 2]
	mov ax, word [bp + ?src_behind_block]
					; dx:ax -> behind block

	cmp word [bp + ?src + 2], dx	; compare segment
	ja .snappy_check_error		; ?src > dx:ax -->
	jb .snappy_check_success	; ?src < dx:ax -->
	cmp word [bp + ?src], ax	; segment is same, compare offset
	jae .snappy_check_error		; ?src >= dx:ax -->
.snappy_check_success:
	jmp .loop_sequence		; process next sequence -->
.snappy_check_error:

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


		; INP:	ds:si -> source data
		;	?length_of_source
		; OUT:	CY if error (source buffer too small)
		;	NC if success,
		;	 dx:ax = value read
		;	 ds:si incremented (NOT normalised)
		;	 ?length_of_source decremented
.lodsd_dxax:
	sub word [bp + ?length_of_source], 4
	sbb word [bp + ?length_of_source + 2], 0
	jb .retn
	lodsw
	xchg dx, ax
	lodsw
	xchg dx, ax
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
snappy_copy_literal_or_uncompressed:
	lds si, [bp + ?src]

	sub word [bp + ?length_of_source], ax
	sbb word [bp + ?length_of_source + 2], dx
					; enough data exists ?
	jb .return			; no --> (CY)

	call snappy_copy_data		; CY/NC depending on status

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
		;	Instead of returning, this may jump to depack.end
		;	 if the destination segment grows up to the value
		;	 stored in the ?dst_max_segment variable. It is
		;	 assumed that this will use the stack frame to leave
		;	 the function, therefore discarding any of the stack
		;	 contents between the frame and the stack top.
		; CHG:	cx, dx, ax, es, di, ds, si
snappy_copy_data:
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
%if _PAYLOAD_KERNEL_MAX_PARAS
	mov ax, es
	cmp ax, word [bp + ?dst_max_segment]
	jae depack.end
%endif

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
snappy_func_bx_with_src:
	lds si, [bp + ?src]
	call bx
	pushf
	call normalise_dssi_pointer
	mov word [bp + ?src], si
	mov word [bp + ?src + 2], ds
	popf
	retn


		; INP:	?src -> source data (normalised)
		;	cx = size to read, 1 to 4 or higher (at most 0FFF0h)
		;	?length_of_source
		; OUT:	dx:ax = value read as little-endian
		;	 (either a dword, 3byte, word, or byte)
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

	cmp cx, 4
	jae @F
	xor dh, dh
	cmp cx, 3
	je @F
	xor dl, dl
	cmp cx, 2
	je @F
	xor ah, ah
	cmp cx, 1
	jb .error
@@:

	sub si, 4
	add si, cx

	call normalise_dssi_pointer
	mov word [bp + ?src], si
	mov word [bp + ?src + 2], ds

	db __TEST_IMM8		; (NC)
.error:
	stc
	retn

