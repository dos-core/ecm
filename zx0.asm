
%if 0

8086 Assembly lDOS iniload payload ZX0 depacker
 by E. C. Masloch, 2018--2026

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


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
%if _IMAGE_EXE || _DEBUG0 || _COUNTER || 1
	lenter early
 %if _IMAGE_EXE
	lvar word,	exemode	; must be bp - 2!
	 push bx
  %if ?exemode != -2
   %error exemode variable must be directly below bp
  %endif
 %endif
 %if _DEBUG0 || _COUNTER || 1
	xor bx, bx
 %endif
 %if _DEBUG0
	lvar word,	errordata
	 push bx
 %endif
%endif
%if _COUNTER
	lvar word,	counter
	 push bx		; initialise counter (high byte) to zero
%endif
	lvar word,	value_and_mask
	lequ ?value_and_mask, value
	lequ ?value_and_mask + 1, mask
	 push bx		; mask = 0
	lvar word, backtrack_and_lastbyte
	lequ ?backtrack_and_lastbyte, backtrack
	lequ ?backtrack_and_lastbyte + 1, lastbyte
	 push bx		; backtrack = 0
	lvar dword,	last_offset
	dec bx			; = all-1s
	 push bx
	 push bx
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

.copyliterals:
	call readinterlacedeliasgamma_normal
					; dx:ax = length of literals (may be 0)

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
	lds si, [bp + ?src]

	sub word [bp + ?length_of_source], ax
	sbb word [bp + ?length_of_source + 2], dx
					; enough data exists ?
	jb .error			; no --> (CY)

	call copy_data			; CY/NC depending on status
	jc .error

	mov word [bp + ?src], si
	mov word [bp + ?src + 2], ds

	call readbit_count
	jc .copyfromnewoffset

.copyfromlastoffset:
	call readinterlacedeliasgamma_normal
					; dx:ax = length of match

	mov bx, word [bp + ?last_offset + 2]
	mov cx, word [bp + ?last_offset]

	call .match

	call readbit_count
	jnc .copyliterals

.copyfromnewoffset:
	call readinterlacedeliasgamma_inverted
	test dx, dx
	jnz @F
	cmp ax, 256
	je .end_check
@@:
	xchg bx, ax
	shr dh, 1			; into CF
	jnz .error
	mov dh, dl
	mov dl, bh
	mov bh, bl
	mov bl, 0
	rcr dx, 1
	rcr bx, 1			; shift right 25-bit number in CF:dx:bh
	call readbyte			; al = next byte
	shr al, 1			; get upper 7 bits into al
	mov ah, 0
	sub bx, ax
	sbb dx, 0			; dx:bx = offset

	push dx
	push bx
	not byte [bp + ?backtrack]	; set to FFh
	pop cx
	pop bx

	neg bx
	neg cx
	sbb bx, byte 0			; neg bx:cx

	mov word [bp + ?last_offset + 2], bx
	mov word [bp + ?last_offset], cx

	push bx
	call readinterlacedeliasgamma_normal
					; dx:ax = length of match - 1
	inc ax
	jnz @F
	inc dx				; dx:ax = length of match
@@:
	pop bx

	call .match

	call readbit_count
	jnc .copyliterals
	jmp .copyfromnewoffset


.end_check:
	xor cx, cx
	cmp word [bp + ?length_of_source + 2], cx
	jne .error
	cmp word [bp + ?length_of_source], cx
	jne .error

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


.match:
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

	call copy_data			; give ?dst -> dest, ds:si -> source
		; returns: ?dst incremented, ds:si -> after match source
d0	mov byte [bp + ?errordata], 1Ah
	jc .error

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
d0	mov byte [bp + ?errordata], 1Ch
	jc .error
%endif
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
copy_data:
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


readbyte:
	lds si, [bp + ?src]
	sub word [bp + ?length_of_source], 1
	sbb word [bp + ?length_of_source + 2], 0
	jb depack.error
	lodsb
	call normalise_dssi_pointer
	mov word [bp + ?src], si
	mov word [bp + ?src + 2], ds
	mov byte [bp + ?lastbyte], al
	retn


readbit_count:
%if _COUNTER
	inc byte [bp + ?counter]
	test byte [bp + ?counter], _COUNTER - 1
	jnz @F
	mov al, '.'
	call disp_al_counter
@@:
%endif

readbit:
	rol byte [bp + ?backtrack], 1
	jc .backtrack
	shr byte [bp + ?mask], 1
	jnz .got
	call readbyte
	mov ah, 128
	mov word [bp + ?value_and_mask], ax
.got:
	mov al, byte [bp + ?mask]
	and al, byte [bp + ?value]
@@:					; !!al
	cmp al, 1			; CY iff 0
	cmc				; NC iff 0
	retn

.backtrack:
	mov al, byte [bp + ?lastbyte]
	and al, 1
	not byte [bp + ?backtrack]
	jmp @B


readinterlacedeliasgamma_normal:
	xor dx, dx
	mov bx, 1
.loop:
	call readbit
	jc .end
	call readbit
	rcl bx, 1
	rcl dx, 1
	jc depack.error
	jmp .loop
.end:
readinterlacedeliasgamma_inverted.end: equ $
	xchg ax, bx
	retn


readinterlacedeliasgamma_inverted:
	xor dx, dx
	mov bx, 1
.loop:
	call readbit
	jc .end
	call readbit
	cmc				; !bit
	rcl bx, 1
	rcl dx, 1
	jc depack.error
	jmp .loop
