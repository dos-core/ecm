
%if 0

8086 Assembly lDOS iniload payload mvcomp depacker
 by E. C. Masloch, 2024

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


	numdef TESTFILE,	0

%if _TESTFILE
.verbose.2:	db @F - ($ + 1)
		db "dest="
.verbose.2.desthigh:
		db "----_"
.verbose.2.destlow:
		db "----h src="
.verbose.2.srchigh:
		db "----_"
.verbose.2.srclow:
		db "----h "
		db "Match at minus "
.verbose.2.index:
		db "----h length "
.verbose.2.length:
		db "----h.",13,10
@@:
%endif

	numdef COUNTER,		0, 128
%if (_COUNTER - 1) & _COUNTER
 %error COUNTER must be a power of two
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
	lenter
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
%if _COUNTER
	lvar word,	unused_and_counter
	lequ ?unused_and_counter + 1, counter
	 push bx		; initialise counter (high byte) to zero
%endif

	call normalise_both_pointers

%if _TESTFILE
	lvar dword,	original_src
	 push ds
	 push si
	lvar dword,	original_dst
	 push es
	 push di
%endif
	lvar dword,	src
	 push ds
	 push si
	lvar dword,	dst
	 push es
	 push di
	lvar dword,	src_remaining
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
d0	mov byte [bp + ?errordata], 7Fh
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
	add cx, word [bp + ?src_remaining]
	adc bx, word [bp + ?src_remaining + 2]
		; In case of allowing overlapping source and destination,
		;  the ?dst_remaining variable is set to
		;  ?src + ?src_remaining - ?dst, allowing to write to
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

	lvar dword,	dst_remaining
	 push bx		; push into [bp + ?dst_remaining + 2]
	 push cx		; push into [bp + ?dst_remaining]

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
		; Note:	We initially check here that the write pointer is
		;	 low enough, ie below-or-equal the read pointer.
		;	 Doing this check here (as well as after any
		;	 copied match) allows us to drop the check done
		;	 after moving literal bytes.
d0	mov byte [bp + ?errordata], 7Eh
	jc .error
%endif

.loop:
%if _COUNTER
	inc byte [bp + ?counter]
	test byte [bp + ?counter], _COUNTER - 1
	jnz @F
	mov al, '.'
	call disp_al_counter
@@:
%endif
	sub word [bp + ?src_remaining], 2
	sbb word [bp + ?src_remaining + 2], 0
	jb .end

	lds si, [bp + ?src]
	lodsw
	call normalise_dssi_pointer
	mov word [bp + ?src], si
	mov word [bp + ?src + 2], ds

	test ax, 0F000h
	jnz .match

	push ax
	 push ss
	 pop ds
	mov si, sp
	mov ax, 1
	call copy_data
	pop ax
d0	mov byte [bp + ?errordata], 75h
	jc .error

	xchg al, ah
	mov ah, 0			; ax = number of words
	add ax, ax			; ax = number of bytes
	lds si, [bp + ?src]
	sub word [bp + ?src_remaining], ax
	sbb word [bp + ?src_remaining + 2], 0
					; enough space left ?
d0	mov byte [bp + ?errordata], 26h
	jb .error			; no -->
	call copy_data
	mov word [bp + ?src], si
	mov word [bp + ?src + 2], ds
	jmp .loop

.match:
	mov cl, 4
	push ax
	rol ax, cl			; get LLLL into low nybble
	and ax, 15			; mask off OOOO OOOO OOOO
	pop cx
	and cx, 0FFFh			; get OOOO OOOO OOOO
	inc ax				; LLLL + 1
					; ax = length
	inc cx				; OOOO OOOO OOOO +1
	neg cx				; -2 .. -4096
	mov bx, -1			; sign-extend (always negative sense)

%if _TESTFILE
	rol byte [ss:verbose], 1
	jnc @F
	push es
	push ds
	push ax
	push bx
	push cx
	push dx
	push di

	push ss
	pop es
	mov di, msg.verbose.2.length
	call store_hex_word
	mov ax, cx
	neg ax
	mov di, msg.verbose.2.index
	call store_hex_word

	 push word [bp + ?original_dst + 2]
	 push word [bp + ?original_dst]
	call pointer_to_linear

	xchg cx, ax
	xchg bx, dx

	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
	call pointer_to_linear

	sub ax, cx
	sbb dx, bx

	mov di, msg.verbose.2.destlow
	call store_hex_word
	xchg ax, dx
	mov di, msg.verbose.2.desthigh
	call store_hex_word

	 push word [bp + ?original_src + 2]
	 push word [bp + ?original_src]
	call pointer_to_linear

	xchg cx, ax
	xchg bx, dx

	 push word [bp + ?src + 2]
	 push word [bp + ?src]
	call pointer_to_linear

	sub ax, cx
	sbb dx, bx

	mov di, msg.verbose.2.srclow
	call store_hex_word
	xchg ax, dx
	mov di, msg.verbose.2.srchigh
	call store_hex_word

	push ss
	pop ds
	mov dx, msg.verbose.2
	call disp_msg_counted

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	pop ds
	pop es
@@:
%endif

	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
	call normalise_pointer_with_displacement_bxcx
	 pop si
	 pop ds				; ds:si -> source of matching

	call copy_data			; give ?dst -> dest, ds:si -> source
		; returns: ?dst incremented, ds:si -> after match source
d0	mov byte [bp + ?errordata], 7Bh
	jc .error

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
d0	mov byte [bp + ?errordata], 7Ch
	jc .error
%endif

	jmp .loop


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
%if _TESTFILE
	les di, [bp + ?dst]
 %assign _TESTFILE_SUPPORTED 1
%endif
	lleave code
	lret


		; INP:	?dst -> destination (normalised)
		;	ds:si -> source (normalised)
		;	ax = how long the data is (0 is valid), < 256
		; OUT:	?dst incremented (normalised)
		;	ds:si incremented (normalised)
		;	?dst_remaining shortened
		;	CY if error (buffer too small)
		;	NC if success
		;	Instead of returning, this may jump to depack.end
		;	 if the destination segment grows up to the value
		;	 stored in the ?dst_max_segment variable. It is
		;	 assumed that this will use the stack frame to leave
		;	 the function, therefore discarding any of the stack
		;	 contents between the frame and the stack top.
		; CHG:	cx, bx, dx, ax, es, di, ds, si
copy_data:
d0	inc byte [bp + ?errordata + 1]
	sub word [bp + ?dst_remaining], ax
	sbb word [bp + ?dst_remaining + 2], 0
					; enough space left ?
	jb .error			; no -->

	xchg cx, ax
	les di, [bp + ?dst]
		; If both pointers are normalised, moving 0FFF0h bytes is
		;  valid and results in a maximum offset of 0FFFFh in either.
	rep movsb

	call normalise_both_pointers

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
