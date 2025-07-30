
%if 0

8086 Assembly lDOS iniload payload LZEXE depacker
 by E. C. Masloch, 2020--2025

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


	numdef TESTFILE,	0
	numdef 4,		0
	numdef LONGLITERAL,	0
%assign NEED_NORMALISE_POINTER_WITH_DISPLACEMENT 0
%assign NEED_NORMALISE_BOTH_POINTERS 0
%assign CHECK_POINTERS_VARIABLE_SRC 0
%assign CHECK_POINTERS_VARIABLE_DST 0


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
		db "Match -"
.verbose.2.index:
		db "----h length "
.verbose.2.length:
		db "----h masque="
.verbose.2.masque:
		db "----h left="
.verbose.2.left:
		db "--h.",13,10
@@:
.except.2:	db @F - ($ + 1)
		db "dest="
.except.2.desthigh:
		db "----_"
.except.2.destlow:
		db "----h src="
.except.2.srchigh:
		db "----_"
.except.2.srclow:
		db "----h "
		db "Literal length "
.except.2.lengthhigh:
		db "----_"
.except.2.lengthlow:
		db "----h masque="
.except.2.masque:
		db "----h left="
.except.2.left:
		db "--h.",13,10
@@:
.extra.2:	db @F - ($ + 1)
		db "dest="
.extra.2.desthigh:
		db "----_"
.extra.2.destlow:
		db "----h src="
.extra.2.srchigh:
		db "----_"
.extra.2.srclow:
		db "----h "
		db "Literal reads "
.extra.2.value:
		db "--h '"
.extra.2.text:
		db "-' masque="
.extra.2.masque:
		db "----h left="
.extra.2.left:
		db "--h.",13,10
@@:
.extra.3:	db @F - ($ + 1)
		db " command "
		db "dest="
.extra.3.desthigh:
		db "----_"
.extra.3.destlow:
		db "----h src="
.extra.3.srchigh:
		db "----_"
.extra.3.srclow:
		db "----h masque="
.extra.3.masque:
		db "----h left="
.extra.3.left:
		db "--h.",13,10
@@:
.extra.4.eos:	counted "EOS"
.extra.4.segchange:
		counted "Seg Change"
.extra.4.longliteral:
		counted "Long Literal"

	align 2, db 0
literalamount:	dd 0
%endif


	numdef COUNTER,		0, 64
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
		; Note:	The input pointers need to be normalised.
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

%if _TESTFILE
	lvar dword,	original_src
	 push ds
	 push si
	lvar dword,	original_dst
	 push es
	 push di
%endif
	lvar dword,	src_remaining
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

	lvar word,	tagword
	 push ax
	mov ax, 1
	lvar word,	tagbitscycle
	 push ax		; = 1

	call get_bit

	jmp .loop

.literal:
%if _LONGLITERAL
	inc cx
.loop_literal:
%endif

%if _TESTFILE
	add word [ss:literalamount], 1
	adc word [ss:literalamount + 2], 0
%endif
	sub word [bp + ?src_remaining], 1
	call sbb_src_remaining_check
	sub word [bp + ?dst_remaining], 1
	sbb word [bp + ?dst_remaining + 2], 0
d0	mov byte [bp + ?errordata], 70h
	jc .error

%if _TESTFILE
	rol byte [ss:extraverbose], 1
	jnc @F
	push es
	push ds
	push ax
	push bx
	push cx
	push dx
	push di

	mov al, [si]
	 push ds
	 push si
	 push es
	 push di
	push ss
	pop es
	mov di, msg.extra.2.value
	call store_hex_byte

	mov di, msg.extra.2.text
	inc ax
	cmp al, 32
	jg .gottext
	mov al, '.' + 1
.gottext:
	dec ax
	stosb

	mov ax, word [bp + ?tagword]
	mov di, msg.extra.2.masque
	call store_hex_word

	mov al, byte [bp + ?tagbitsleft]
	mov di, msg.extra.2.left
	call store_hex_byte

	 push word [bp + ?original_dst + 2]
	 push word [bp + ?original_dst]
	call pointer_to_linear

	xchg cx, ax
	xchg bx, dx

	 ; es:di on stack
	call pointer_to_linear

	sub ax, cx
	sbb dx, bx

	mov di, msg.extra.2.destlow
	call store_hex_word
	xchg ax, dx
	mov di, msg.extra.2.desthigh
	call store_hex_word

	 push word [bp + ?original_src + 2]
	 push word [bp + ?original_src]
	call pointer_to_linear

	xchg cx, ax
	xchg bx, dx

	 ; ds:si on stack
	call pointer_to_linear

	sub ax, cx
	sbb dx, bx

	mov di, msg.extra.2.srclow
	call store_hex_word
	xchg ax, dx
	mov di, msg.extra.2.srchigh
	call store_hex_word

	push ss
	pop ds
	mov dx, msg.extra.2
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

	movsb
	test si, si			; overflowed ?
d0	mov byte [bp + ?errordata], 88h
	jz .error
	test di, di			; overflowed ?
d0	mov byte [bp + ?errordata], 89h
	jz .error

%if _LONGLITERAL
 %if _TESTFILE
	loop .loop_literal_j
	jmp .loop
.loop_literal_j:
	jmp .loop_literal
 %else
	loop .loop_literal
 %endif
%endif

.loop:
	xor cx, cx			; ! ch = 0, cx = 0
	call get_bit
	jc .literal

%if _TESTFILE
	rol byte [ss:exceptional], 1
	jnc @F
	cmp word [ss:literalamount + 2], 0
	jne .high
	cmp word [ss:literalamount], 26
.high:
	jb @F
	push es
	push ds
	push ax
	push bx
	push cx
	push dx
	push di

	 push ds
	 push si
	 push es
	 push di
	push ss
	pop es
	mov ax, word [ss:literalamount]
	mov di, msg.except.2.lengthlow
	call store_hex_word
	mov ax, word [ss:literalamount + 2]
	mov di, msg.except.2.lengthhigh
	call store_hex_word

	mov ax, word [bp + ?tagword]
	mov di, msg.except.2.masque
	call store_hex_word

	mov al, byte [bp + ?tagbitsleft]
	mov di, msg.except.2.left
	call store_hex_byte

	 push word [bp + ?original_dst + 2]
	 push word [bp + ?original_dst]
	call pointer_to_linear

	xchg cx, ax
	xchg bx, dx

	 ; es:di on stack
	call pointer_to_linear

	sub ax, cx
	sbb dx, bx

	mov di, msg.except.2.destlow
	call store_hex_word
	xchg ax, dx
	mov di, msg.except.2.desthigh
	call store_hex_word

	 push word [bp + ?original_src + 2]
	 push word [bp + ?original_src]
	call pointer_to_linear

	xchg cx, ax
	xchg bx, dx

	 ; ds:si on stack
	call pointer_to_linear

	sub ax, cx
	sbb dx, bx

	mov di, msg.except.2.srclow
	call store_hex_word
	xchg ax, dx
	mov di, msg.except.2.srchigh
	call store_hex_word

	push ss
	pop ds
	mov dx, msg.except.2
	call disp_msg_counted

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	pop ds
	pop es
@@:
	and word [ss:literalamount + 2], 0
	and word [ss:literalamount], 0
%endif


.notliteral:
%if _COUNTER
	inc byte [bp + ?counter]
	test byte [bp + ?counter], _COUNTER - 1
	jnz @F
	mov al, '.'
	call disp_al_counter
@@:
%endif

	call get_bit
	jc .combined

.shortmatch:
		; cx = 0
	call get_bit
	rcl cx, 1
	call get_bit
	rcl cx, 1			; cx = 0..3

	call load_byte			; load displacement

	mov ah, -1			; sign extend for negative number
	xchg bx, ax			; bx = displacement (-1 to -256)

.match_cx_plus_2:
	inc cx
.match_cx_plus_1:
	inc cx

		; INP:	es:di -> destination
		;	bx = match displacement (-1 to -8192)
		;	cx = match count (2 to 256)
.match:
	sub word [bp + ?dst_remaining], cx
	sbb word [bp + ?dst_remaining + 2], 0
d0	mov byte [bp + ?errordata], 85h
	jc .error

	mov ax, di
	add ax, bx			; ax -> match offset
d0	mov byte [bp + ?errordata], 83h
	jnc .error			; ax must be below di !
	push di

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

	 push ds
	 push si
	 push es
	 push di
	push ss
	pop es
	mov ax, cx
	mov di, msg.verbose.2.length
	call store_hex_word
	mov ax, bx
	neg ax
	mov di, msg.verbose.2.index
	call store_hex_word

	mov ax, word [bp + ?tagword]
	mov di, msg.verbose.2.masque
	call store_hex_word

	mov al, byte [bp + ?tagbitsleft]
	mov di, msg.verbose.2.left
	call store_hex_byte

	 push word [bp + ?original_dst + 2]
	 push word [bp + ?original_dst]
	call pointer_to_linear

	xchg cx, ax
	xchg bx, dx

	 ; es:di on stack
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

	 ; ds:si on stack
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

@@:
	mov al, byte [es:di + bx]	; load from window
	stosb				; store, increment di
	loop @B				; loop until -- cx == 0
	pop ax				; = prior di
	cmp di, ax
d0	mov byte [bp + ?errordata], 82h
	jbe .error			; di must be above ax !

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
					; CHG: ax, bx, cx, dx
d0	mov byte [bp + ?errordata], 7Ch
	jc .error
%endif

.loop_j1:
	jmp .loop

.combined:
	call load_word			; load combined word

	mov bx, ax
	stc				; CY
	rcr bh, 1			; rotate in a 1
	sar bh, 1
	sar bh, 1			; fill top three bits with 1s
%if _4
	sar bh, 1			; fill top *four* bits with 1s
	and ah, 15
%else
	and ah, 7
%endif
	mov cl, ah			; ch already = 0
	jnz .match_cx_plus_2		; length = cx + 2, bx = displacement

.escape:
	call load_byte			; ah = 0
	cmp al, 1
	jb .end_check
	xchg cx, ax			; cx = length
	ja .match_cx_plus_1		; length = cx + 1, bx = displacement

%if _LONGLITERAL
	xchg cx, bx			; cx = displacement, top 4 or 3 bits sets
 %if _4
	and ch, ~ 1111_0000b		; isolate 12-bit displacement
 %else
	and ch, ~ 1110_0000b		; isolate 13-bit displacement
 %endif
 	jcxz .normalise			; displacement 0 means segment change -->
 	cmp cx, 26			; long literals command needs >= 26 bytes
 	jb .error			; (reserved for future expansion)
%if _TESTFILE
	push dx
	mov dx, msg.extra.4.longliteral
	call disp_command
	pop dx
%endif
 	jmp .loop_literal		; process the literals -->
%endif
.normalise:
%if _TESTFILE
	push dx
	mov dx, msg.extra.4.segchange
	call disp_command
	pop dx
%endif

	call normalise_dssi_pointer
	mov ax, di
	mov cl, 4
	sub ax, 8192			; large enough offset ?
d0	mov byte [bp + ?errordata], 87h
	jb .error			; no -->
	and di, 15
	add di, 8192			; 8192 .. 8207
	shr ax, cl			; how many paragraphs to advance
	mov cx, es
	add cx, ax			; => new window
	mov es, cx
	jmp .loop_j1

.end_check:
%if _TESTFILE
	push dx
	mov dx, msg.extra.4.eos
	call disp_command
	pop dx
%endif

d0	mov byte [bp + ?errordata], 7Dh
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
	call disp_al_for_progress
	mov al, 10
	call disp_al_for_progress
	sahf
%endif
d0	mov bx, word [bp + ?errordata]
%if _TESTFILE
 %assign _TESTFILE_SUPPORTED 1
%endif
	lleave code
	lret


		; INP:	ds:si -> source
		;	?src_remaining
		;	word [?tagword] = tag word
		;	word [?tagbitscycle] = circular tag bits indicator
		;	 (there's always a single bit set in this word.
		;	 if this word is equal to 1 on INP then the tag
		;	 word must be reloaded, and the last bit shifted
		;	 out of the INP prior tag word.)
		; OUT:	NC if read a zero,
		;	CY if read a one,
		;	 ds:si = incremented source (not normalised)
		;	 ?src_remaining decremented
		;	 word [?tagword] updated
		;	 word [?tagbitscycle] updated
		;	branches to depack.error on error
		; CHG:	si, ax
get_bit:
	ror word [bp + ?tagbitscycle], 1
	jnc .left
		; after this branch not taken, the cycle word
		;  wraps around to be equal to 8000h. this
		;  will wrap around again after 15 more ror.
	call load_word
	shr word [bp + ?tagword], 1
	mov word [bp + ?tagword], ax
	retn

.left:
	shr word [bp + ?tagword], 1
	retn

		; lodsw with ?src_remaining check
load_word:
	cmp si, -2			; would overflow ?
d0	mov byte [bp + ?errordata], 86h
	jae depack.error
		; The above check needs to be done before the lodsw
		;  so that lodsw never runs with si = 0FFFFh which
		;  would fault on some machines.
	sub word [bp + ?src_remaining], 2
	lodsw

sbb_src_remaining_check:
	sbb word [bp + ?src_remaining + 2], 0
d0	mov byte [bp + ?errordata], 84h
	jc depack.error
	retn

		; lodsb with ?src_remaining check
load_byte:
	lodsb
	test si, si			; overflowed ?
d0	mov byte [bp + ?errordata], 81h
	jz depack.error
	sub word [bp + ?src_remaining], 1
	jmp sbb_src_remaining_check


%if _TESTFILE
disp_command:
	rol byte [ss:commandsextraverbose], 1
	jc .do
	rol byte [ss:extraverbose], 1
	jc .do
	cmp dx, msg.extra.4.longliteral
	je @F
	rol byte [ss:commandsverbose], 1
	jnc @F
.do:
	push es
	push ds
	push ax
	push bx
	push cx
	push dx
	push di

	 push ds
	 push si
	 push es
	 push di
	push ss
	pop ds
	call disp_msg_counted

	push ss
	pop es
	mov ax, word [bp + ?tagword]
	mov di, msg.extra.3.masque
	call store_hex_word

	mov al, byte [bp + ?tagbitsleft]
	mov di, msg.extra.3.left
	call store_hex_byte

	 push word [bp + ?original_dst + 2]
	 push word [bp + ?original_dst]
	call pointer_to_linear

	xchg cx, ax
	xchg bx, dx

	 ; es:di on stack
	call pointer_to_linear

	sub ax, cx
	sbb dx, bx

	mov di, msg.extra.3.destlow
	call store_hex_word
	xchg ax, dx
	mov di, msg.extra.3.desthigh
	call store_hex_word

	 push word [bp + ?original_src + 2]
	 push word [bp + ?original_src]
	call pointer_to_linear

	xchg cx, ax
	xchg bx, dx

	 ; ds:si on stack
	call pointer_to_linear

	sub ax, cx
	sbb dx, bx

	mov di, msg.extra.3.srclow
	call store_hex_word
	xchg ax, dx
	mov di, msg.extra.3.srchigh
	call store_hex_word

	push ss
	pop ds
	mov dx, msg.extra.3
	call disp_msg_counted

	pop di
	pop dx
	pop cx
	pop bx
	pop ax
	pop ds
	pop es
@@:
	retn
%endif
