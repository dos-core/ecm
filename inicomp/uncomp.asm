
%if 0

8086 Assembly lDOS iniload payload uncompressed copy
 by E. C. Masloch, 2026

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%if _SCAN
 %assign SCAN_SUPPORTED 1
%endif

%assign NEED_NORMALISE_POINTER_WITH_DISPLACEMENT 0
%assign CHECK_POINTERS_VARIABLE_SRC 0
%assign CHECK_POINTERS_VARIABLE_DST 0


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
%if _SCAN
	lpar dword, progressticks
	lpar dword, maxbytesahead
	lpar dword, depackedsize
	lpar_return
	xor di, di
	mov es, di		; destination = all-zeroes (special)
%endif
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
%if _SCAN
	lvar dword,	plusdst
	lvar dword,	plussrc
%endif
	lenter

	call normalise_both_pointers

%if _SCAN
	lvar dword,	original_src
	 push ds
	 push si
%endif
	lvar dword,	original_dst
	 push es
	 push di
	lvar dword,	length_of_source
	 push dx
	 push cx

%if 0 && _PAYLOAD_KERNEL_MAX_PARAS
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

%if _SCAN
LENDST equ 960 * 1024
	mov bx, LENDST >> 16
	mov cx, LENDST & 0FFFFh
%else
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
%endif	; _SCAN

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

.uncompressed:
	mov dx, word [bp + ?length_of_source + 2]
	mov ax, word [bp + ?length_of_source]
	call copy_literal_or_uncompressed


.end:
	db __TEST_IMM8			; (NC)
.error:
	stc

%if _SCAN
	pushf
	 push es
	 push di
	call pointer_to_linear

	mov bx, dx
	xchg cx, ax		; bx:cx = end destination linear

	 push word [bp + ?original_dst + 2]
	 push word [bp + ?original_dst]
	call pointer_to_linear	; dx:ax = start destination linear

	sub cx, ax
	sbb bx, dx		; bx:cx = end destination linear
				;  minus start destination linear

	mov word [bp + ?depackedsize], cx
	mov word [bp + ?depackedsize + 2], bx
	popf
%endif
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


		; INP:	es:di -> destination (normalised)
		;	ds:si -> source (normalised)
		;	dx:ax = how long the literal data is (0 is valid)
		; OUT:	es:di incremented (normalised)
		;	ds:si incremented (normalised)
		;	?length_of_destination shortened
		;	?length_of_source shortened
		;	jumps to depack.error if error (either buffer too small)
		;	returns if success
		; CHG:	cx, dx, ax, es, di, ds, si
copy_literal_or_uncompressed:
	sub word [bp + ?length_of_source], ax
	sbb word [bp + ?length_of_source + 2], dx
					; enough data exists ?
	jb depack.error			; no --> (CY)

	sub word [bp + ?length_of_destination], ax
	sbb word [bp + ?length_of_destination + 2], dx
					; enough space left ?
	jb depack.error			; no -->

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
%if _SCAN
	call scan_rep_movsb
%else
	rep movsb			; move one block (full or partial)
%endif

	call normalise_both_pointers
	jmp .loop

.end:
%if _PAYLOAD_KERNEL_MAX_PARAS
	mov ax, es
	cmp ax, word [bp + ?dst_max_segment]
	jae depack.end
%endif
	retn
