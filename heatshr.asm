
%if 0

8086 Assembly lDOS iniload payload heatshrink depacker
 by C. Masloch, 2020

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
	lvar word,	unused_and_counter
	lequ ?unused_and_counter + 1, counter
%if _COUNTER
	 push bx		; initialise counter (high byte) to zero
%endif
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
	lvar dword,	src_remaining
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
d0	mov byte [bp + ?errordata], 7Fh
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

@@:
	call read_byte
d0	mov byte [bp + ?errordata], 70h
	jc .error

	mov ah, 0
	test ax, ax
d0	mov byte [bp + ?errordata], 71h
	jz .error
	cmp al, 15
	ja .error

	lvar word,	window_size_bits
	 push ax

	call read_byte
d0	mov byte [bp + ?errordata], 72h
	jc .error

	mov ah, 0
	test ax, ax
d0	mov byte [bp + ?errordata], 73h
	jz .error
	cmp ax, word [bp + ?window_size_bits]
	jae .error

	lvar word,	lookahead_size_bits
	 push ax

	xor cx, cx
	lvar word,	low_bit_index_and_high_current_byte
	 push cx

.loop:
%if _COUNTER
	inc byte [bp + ?counter]
	test byte [bp + ?counter], _COUNTER - 1
	jnz @F
	mov al, '.'
	call disp_al
@@:
%endif
	mov cx, 1
	call get_bits
	jnc .notend

d0	mov byte [bp + ?errordata], 7Dh
.end_check:
	xor cx, cx
	cmp word [bp + ?src_remaining + 2], cx
	jne .error
	cmp word [bp + ?src_remaining], cx
	jne .error

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

.notend:
	test al, al
	jz .notliteral

	mov cl, 8
	call get_bits
d0	mov byte [bp + ?errordata], 74h
	jc .end_check
	call write_byte
d0	mov byte [bp + ?errordata], 75h
	jc .error
	jmp .loop

.notliteral:
	mov cl, byte [bp + ?window_size_bits]
	call get_bits_size_cl
d0	mov byte [bp + ?errordata], 76h
	jc .end_check
		; dx = output index
	xchg bx, dx
	mov cl, byte [bp + ?lookahead_size_bits]
	call get_bits_size_cl
d0	mov byte [bp + ?errordata], 77h
	jc .end_check
		; bx = output index less 1
		; dx = output count less 1
	inc bx				; = output index
d0	mov byte [bp + ?errordata], 78h
	jz .error

	mov ax, dx
	xor dx, dx			; dx:ax = length of match less one
	add ax, 1
	adc dx, 0			; = length of match

	mov cx, bx
	neg cx				; -1 .. -65535
	mov bx, -1			; sign-extend (always negative sense)

	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
	call normalise_pointer_with_displacement_bxcx
	 pop si
	 pop ds				; ds:si -> source of matching
d0	mov byte [bp + ?errordata], 80h
	jnc .copy_zeros

	push ax
	mov ax, ds			; is source of matching within ?dst ?
	cmp word [bp + ?original_dst + 2], ax
	pop ax
d0	mov byte [bp + ?errordata], 79h
	ja .copy_zeros
	jb @F
	cmp word [bp + ?original_dst], si
d0	mov byte [bp + ?errordata], 7Ah
	ja .copy_zeros			; no, ?original_dst is above it -->
@@:

.copy_data:
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


		; INP:	bx:cx = negative displacement from ?dst
		;	dx:ax = length of match
		;	?dst
		;	?original_dst
.copy_zeros:
	push dx
	push ax				; stacked = length of match

	neg bx
	neg cx
	sbb bx, byte 0			; neg bx:cx

	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
	call pointer_to_linear
	mov si, dx
	mov di, ax

	 push word [bp + ?original_dst + 2]
	 push word [bp + ?original_dst]
	call pointer_to_linear
	sub di, ax
	sbb si, dx			; si:di = ?dst - ?original_dst
					;  = maximum displacement

	sub cx, di
	sbb bx, si			; = over-long displacement - max
					;  = how many zeros to insert
	mov ax, cx
	mov dx, bx			; dx:ax = how many zeros
	pop di
	pop si				; length of match
d0	mov byte [bp + ?errordata], 81h
	jb .error

	sub di, ax
	sbb si, dx			; = how many - how many zeros
					;  = how much to copy from ?original_dst
d0	mov byte [bp + ?errordata], 82h
	jc .error

	push si
	push di				; stack it again
	call store_zeros		; store zeros
	pop ax
	pop dx				; dx:ax = how much to copy
d0	mov byte [bp + ?errordata], 83h
	jc .error

	lds si, [bp + ?original_dst]	; -> ?original_dst
	jmp .copy_data			; back to common handling -->


		; INP:	cx = how many bits to read (1..15)
		; OUT:	NC if successful,
		;	 dx = number
		;	 cx = 0
		;	CY if error
		; CHG:	ax, ds, si
get_bits_size_cl:
	mov ax, 8
	xor dx, dx
	mov ch, 0
	cmp cx, ax
	jbe @F
	sub cx, ax
	call get_bits
	jc .ret
	mov dh, al
	mov cl, 8
@@:
	call get_bits
	mov dl, al
.ret:
	retn


		; INP:	?dst -> destination (normalised)
		;	ds:si -> source (normalised)
		;	dx:ax = how long the data is (0 is valid)
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
store_zeros:
	mov bx, copy_data.stosb_zeros
	jmp @F

copy_data:
	mov bx, .movsb
@@:
d0	inc byte [bp + ?errordata + 1]
	sub word [bp + ?dst_remaining], ax
	sbb word [bp + ?dst_remaining + 2], dx
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
	call bx				; move one block (full or partial)

	call normalise_both_pointers
	jmp .loop

.end:
	mov word [bp + ?dst], di
	mov word [bp + ?dst + 2], es
	mov ax, es
	cmp ax, word [bp + ?dst_max_segment]
	jae depack.end

	db __TEST_IMM8			; (NC)
.error:
	stc
	retn

.movsb:
	rep movsb
	retn

.stosb_zeros:
	push ax
	xor ax, ax
	rep stosb
	pop ax
	retn


write_byte:
	les di, [bp + ?dst]
	sub word [bp + ?dst_remaining], 1
	sbb word [bp + ?dst_remaining + 2], 0
	jc .ret
	stosb
	 push es
	 push di
	call normalise_pointer
	 pop di
	 pop es
	mov word [bp + ?dst], di
	mov word [bp + ?dst + 2], es
	clc
.ret:
	retn


		; INP:	cx = 0..15
		; OUT:	NC if successful,
		;	 ax = value read
		;	 cx = 0
		;	CY if error
		; CHG:	ds, si
get_bits:
	push bx
	mov bx, word [bp + ?low_bit_index_and_high_current_byte]
	cmp cx, 15
	ja .error
	test cx, cx
	jz .error
	xor ax, ax
.loop:
	test bl, bl
	jnz .havebit
	push ax
	call read_byte
	mov bh, al
	mov bl, 80h
	pop ax
	jc .error
.havebit:
	shl ax, 1
	test bh, bl
	jz @F
	inc ax
@@:
	shr bl, 1
	loop .loop
.end:
	db __TEST_IMM8
.error:
	stc
	mov word [bp + ?low_bit_index_and_high_current_byte], bx
	pop bx
	retn


		; INP:	?src -> source data (normalised)
		;	?src_remaining
		; OUT:	NC if success,
		;	 al = value read
		;	 ds:si = ?src = incremented source (normalised)
		;	 ?src_remaining decremented
		;	CY if error (source buffer too small)
		; CHG:	ds, si
		;
		; Note:	Always reads four bytes at INP:ds:si -> data.
read_byte:
	sub word [bp + ?src_remaining], 1
	sbb word [bp + ?src_remaining + 2], 0
	jb .empty

	lds si, [bp + ?src]

	lodsb

	 push ds
	 push si
	call normalise_pointer
	 pop si
	 pop ds
	mov word [bp + ?src], si
	mov word [bp + ?src + 2], ds
	clc
	retn

.empty:
	and word [bp + ?src_remaining], 0
	and word [bp + ?src_remaining + 2], 0
	stc
	retn
