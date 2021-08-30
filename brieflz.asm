
%if 0

 BriefLZ - small fast Lempel-Ziv

 8086 Assembly lDOS iniload payload BriefLZ depacker

 Based on: BriefLZ C safe depacker

 Copyright (c) 2002-2016 Joergen Ibsen

 This software is provided 'as-is', without any express or implied
 warranty. In no event will the authors be held liable for any damages
 arising from the use of this software.

 Permission is granted to anyone to use this software for any purpose,
 including commercial applications, and to alter it and redistribute it
 freely, subject to the following restrictions:

   1. The origin of this software must not be misrepresented; you must
      not claim that you wrote the original software. If you use this
      software in a product, an acknowledgment in the product
      documentation would be appreciated but is not required.

   2. Altered source versions must be plainly marked as such, and must
      not be misrepresented as being the original software.

   3. This notice may not be removed or altered from any source
      distribution.

%endif


	; Local labels of non-local label "msg".
%if  _DEBUG1 || _DEBUG2 || _DEBUG3
.dstavaileq:	asciz "iniblz: dst_avail="
.dstsizeeq:	asciz "h dst_size="
.srcavaileq:	asciz "h src_avail="
.depackedsizeeq:asciz "h",13,10,"iniblz: depacked_size="
.len_of_dst_eq:	asciz "h length_of_destination="
.leneq:		asciz "h",13,10,"iniblz: len="
.offeq:		asciz "h off="
.tageq:		asciz "h",13,10,"iniblz: tag="
.bits_left_eq:	asciz "h bits_left="
.src_eq:	asciz "h src="
.dst_eq:	asciz "h",13,10,"iniblz: dst="
.len_of_src_eq:	asciz "h length_of_source="
.end:		asciz "h",13,10
%endif


	struc BRIEFLZHEADER
blzhSignature:		resd 1	; 626C7A1Ah, big-endian ("blz\x1A")
blzhVersion:		resd 1	; 1, big-endian
blzhCompressedSize:	resd 1	; compressed data size (without header)
blzhCompressedCRC:	resd 1
blzhDecompressedSize:	resd 1	; decompressed size
blzhDecompressedCRC:	resd 1
	endstruc


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
		;	 (if _DEBUG1) dump_stack_frame called at end
		; CHG:	ax, (bx), cx, dx, es, ds, si, di
		; STT:	UP
		;
		; Note:	The destination reaches up to below the source.
		; Note:	The input pointers need not be normalised yet.
		;	 Normalised means that the offset part is below 16.
depack:
	lframe near
%if _IMAGE_EXE || _DEBUG0
	lenter early
 %if _IMAGE_EXE
	lvar word,	exemode		; must be bp - 2!
	 push bx
  %if ?exemode != -2
   %error exemode variable must be directly below bp
  %endif
 %endif
d0	xor bx, bx
d0	lvar word,	errordata
d0	 push bx
%endif
	lvar dword,	dst_avail
	lvar dword,	dst_size
	lvar dword,	src_avail
	lvar dword,	depacked_size
	lvar dword,	len
	lvar dword,	off
	lvar word,	tag
	lvar word,	bits_left
	lenter

	call normalise_both_pointers

	lvar dword,	src
	 push ds
	 push si
	lvar dword,	dst
	 push es
	 push di
	lvar dword,	original_dst
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


.loop:
	cmp word [bp + ?length_of_source + 2], 0
	ja @F
	cmp word [bp + ?length_of_source], BRIEFLZHEADER_size
	jae @F

d0	mov byte [bp + ?errordata + 1], 1
	cmp word [bp + ?length_of_source], 15
	ja .error
	jmp .end

@@:

	call read_be32_src		; signature

d0	mov byte [bp + ?errordata + 1], 2
	cmp ax, 7A1Ah
	jne .error
	cmp dx, 626Ch
	jne .error

	call read_be32_src		; version

d0	mov byte [bp + ?errordata + 1], 3
	cmp ax, 1
	jne .error
	test dx, dx
	jnz .error

	call read_be32_src		; compressed size

	mov word [bp + ?src_avail], ax
	mov word [bp + ?src_avail + 2], dx

	mov bx, dx
	mov cx, ax			; bx:cx = compressed size, used later

d0	mov byte [bp + ?errordata + 1], 8
	add ax, BRIEFLZHEADER_size
	adc dx, 0
	jc .error

d0	mov byte [bp + ?errordata + 1], 4
	cmp dx, word [bp + ?length_of_source + 2]
	ja .error
	jb @F
	cmp ax, word [bp + ?length_of_source]
	ja .error
@@:
	sub word [bp + ?length_of_source], ax
	sbb word [bp + ?length_of_source + 2], dx

	call read_be32_src		; compressed crc

	call read_be32_src		; decompressed size

d0	mov byte [bp + ?errordata + 1], 5
	cmp dx, word [bp + ?length_of_destination + 2]
	ja .error
	jb @F
	cmp ax, word [bp + ?length_of_destination]
	ja .error
@@:
	sub word [bp + ?length_of_destination], ax
	sbb word [bp + ?length_of_destination + 2], dx

	mov word [bp + ?depacked_size], ax
	mov word [bp + ?depacked_size + 2], dx

	call read_be32_src		; decompressed crc
					; leaves ds:si = ?src
	 push ds
	 push si
	call normalise_pointer_with_displacement_bxcx
					; bx:cx = compressed size used here
	jc .error_pop_2
%if _DEBUG2
	call dump_stack_frame
%endif
	call blz_depack_safe
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]
d0	mov byte [bp + ?errordata + 1], 6
	jc .error

d0	mov byte [bp + ?errordata + 1], 7
	cmp word [bp + ?depacked_size], ax
	jne .error
	cmp word [bp + ?depacked_size + 2], dx
	jne .error

	jmp .loop

%if _DEBUG1
.end:
	clc
	jmp .ret

.error_pop_2:				; (restores sp from bp anyway)
.error:
	call dump_stack_frame
	stc
.ret:
%else
.end:
	db __TEST_IMM8			; (NC)
.error_pop_2:				; (restores sp from bp anyway)
.error:
	stc
%endif

d0	mov bx, word [bp + ?errordata]

	lleave code
	lret


%if _DEBUG1 || _DEBUG2 || _DEBUG3

%define ERROR_DISPLAY empty,empty,empty,empty

	%macro add_error_display_dword 2-3.nolist _
%xdefine ERROR_DISPLAY ERROR_DISPLAY,%1,%2 + 2,%2,%3
	%endmacro

	%macro add_error_display_word 2.nolist
%xdefine ERROR_DISPLAY ERROR_DISPLAY,%1,%2,,-
	%endmacro

add_error_display_dword dstavaileq,	bp + ?dst_avail
add_error_display_dword dstsizeeq,	bp + ?dst_size
add_error_display_dword srcavaileq,	bp + ?src_avail
add_error_display_dword depackedsizeeq,	bp + ?depacked_size
add_error_display_dword len_of_dst_eq,	bp + ?length_of_destination
add_error_display_dword leneq,		bp + ?len
add_error_display_dword offeq,		bp + ?off
add_error_display_word tageq,		bp + ?tag
add_error_display_word bits_left_eq,	bp + ?bits_left
add_error_display_dword src_eq,		bp + ?src, :
add_error_display_dword dst_eq,		bp + ?dst, :
add_error_display_dword len_of_src_eq,	bp + ?length_of_source

	%macro error_display_code 4-*.nolist
%if %0 < 4
 %error Expected at least 4 arguments
%endif
%if %0 % 4
 %error Expected amount of arguments that is a multiple of 4
%endif
%rep (%0 / 4) - 1
%rotate 4
	mov si, msg.%1
	call disp_error
	mov ax, word [%2]
	call disp_ax_hex
 %ifnempty %3
  %ifidni %4, :
	mov al, ':'
	call disp_al
  %elifidni %4, _
	mov al, '_'
	call disp_al
  %endif
	mov ax, word [%3]
	call disp_ax_hex
 %endif
%endrep
	%endmacro

dump_stack_frame:
	push ax
	push ds
	push si

	push cs
	pop ds

	numdef TESTERRORDISPLAYMACRO
%if _TESTERRORDISPLAYMACRO == 0
error_display_code ERROR_DISPLAY
%else
	%macro testmacro 4-*
	numdef TESTROTATE, 4
%rotate _TESTROTATE
; %fatal 1 = %1, 2 = %2, 3 = %3, 4 = %4
	mov si, msg.%1
	call disp_error
	mov ax, word [%2]
	call disp_ax_hex
 %ifnempty %3
  %ifidni %4, :
	mov al, ':'
	call disp_al
  %elifidni %4, _
	mov al, '_'
	call disp_al
  %endif
	mov ax, word [%3]
	call disp_ax_hex
 %endif
	%endmacro

; testmacro end,bp + ?dst_avail + 2,bp + ?dst_avail,_
testmacro ERROR_DISPLAY
%endif

	mov si, msg.end
	call disp_error

	pop si
	pop ds
	pop ax
	retn
%endif


		; INP:	?src -> source data
		; OUT:	dx:ax = 32-bit value read as big-endian dword
		;	?src incremented (normalised)
		; CHG:	ds, si
read_be32_src:
	lds si, [bp + ?src]

		; start of read_be32
		; INP:	ds:si -> data, with big-endian 32 bit word
		; OUT:	dx:ax = CPU equivalent
		;	ds:si incremented
	lodsw
	xchg ax, dx		; dx = high word (first)
	lodsw			; ax = low word (second)
	xchg al, ah
	xchg dl, dh		; fix order
		; end of read_be32

	 push ds
	 push si
	call normalise_pointer
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]
	retn


		; INP:	ss:bp -> stack frame (with blz_state equivalents)
		;	?src -> source data
		;	?src_avail = amount of available bytes
		; OUT:	CY if error
		;	NC if success,
		;	 ax = bit
		;	 ?src incremented (normalised) if had to read new tag
		;	 ?src_avail decremented
		;	 ?bits_left updated
		;	 ?tag updated
		; CHG:	ds, si, es, di
blz_getbit_safe:
	cmp word [bp + ?bits_left], 0
	jne .from_tag

d0	mov byte [bp + ?errordata], 1
	cmp word [bp + ?src_avail + 2], 0
	ja @F
	; jb .ret
	cmp word [bp + ?src_avail], 2
	jb .ret				; (CY)
@@:

	sub word [bp + ?src_avail], 2
	sbb word [bp + ?src_avail + 2], 0

	push bx
	mov bx, .lodsw
	call func_bx_with_normalised_pointers
	pop bx
		; Note:	As the write pointer isn't changed here, it here isn't
		;	 necessary to re-check for overlap-corrupted source.

	mov word [bp + ?bits_left], 16
	mov word [bp + ?tag], ax

.from_tag:
	dec word [bp + ?bits_left]
	xor ax, ax
	shl word [bp + ?tag], 1
	rcl ax, 1			; (NC)
.ret:
	retn


.lodsw:
	lodsw
	retn


		; INP:	ss:bp -> stack frame (with blz_state equivalents)
		;	?src -> source data
		;	?src_avail = amount of available bytes
		; OUT:	CY if error
		;	NC if success,
		;	 dx:ax = gamma
		;	 ?src incremented accordingly (normalised)
		;	 ?src_avail decremented accordingly
		; CHG:	ds, si, es, di
blz_getgamma_safe:
	push bx

	xor dx, dx
	mov bx, 1

.loop:
	call blz_getbit_safe
d0	mov byte [bp + ?errordata], 2
	jc .ret				; (CY)
	test dh, 80h
	stc
d0	mov byte [bp + ?errordata], 3
	jnz .ret			; (CY)

	shl bx, 1
	rcl dx, 1

	or bx, ax

	call blz_getbit_safe
d0	mov byte [bp + ?errordata], 4
	jc .ret				; (CY)

	test ax, ax			; (NC)
	jnz .loop

	mov ax, bx
.ret:
	pop bx
	retn


		; INP:	ss:bp -> stack frame (with blz_state equivalents)
		;	?depacked_size set
		;	?src_avail set
		;	?src set
		;	?dst set
		; OUT:	CY if error
		;	NC if success,
		;	 dx:ax = ?dst_size
		;	Instead of returning, this may jump to depack.end
		;	 if the destination segment grows up to the value
		;	 stored in the ?dst_max_segment variable. It is
		;	 assumed that this will use the stack frame to leave
		;	 the function, therefore discarding any of the stack
		;	 contents between the frame and the stack top.
		; CHG:	ds, si, es, di, bx, (dx), (ax), cx
blz_depack_safe:
	and word [bp + ?dst_size], 0
	and word [bp + ?dst_size + 2], 0
	and word [bp + ?bits_left], 0

	mov ax, word [bp + ?depacked_size]
	mov dx, word [bp + ?depacked_size + 2]

	mov word [bp + ?dst_avail], ax
	mov word [bp + ?dst_avail + 2], dx

	or ax, dx
	jz .ret				; (NC)

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
		; Note:	We initially check here that the write pointer is
		;	 low enough, ie below-or-equal the read pointer.
		;	 Doing this check here (as well as after any
		;	 copied match) allows us to drop the check done
		;	 after moving a literal byte.
d0	mov byte [bp + ?errordata], 13h
	jc .ret_CY
%endif

%if _DEBUG3
	call dump_stack_frame
%endif

		; Note:	Before the first iteration of .loop, move a literal.
.literal:
d0	mov byte [bp + ?errordata], 0Eh
	xor cx, cx
	cmp word [bp + ?dst_avail + 2], cx
	jne @F
	cmp word [bp + ?dst_avail], cx
	je .ret_CY
@@:

d0	mov byte [bp + ?errordata], 0Fh
	cmp word [bp + ?src_avail + 2], cx
	jne @F
	cmp word [bp + ?src_avail], cx
	je .ret_CY
@@:

	sub word [bp + ?dst_avail], 1
	sbb word [bp + ?dst_avail + 2], cx

	sub word [bp + ?src_avail], 1
	sbb word [bp + ?src_avail + 2], cx

	mov bx, .movsb
	call func_bx_with_normalised_pointers
		; Note:	Because we verified that the write pointer was
		;	 below the read pointer prior, a literal byte
		;	 that both reads from the source and writes to
		;	 the destination cannot corrupt the remaining
		;	 needed part of the source data.
	add word [bp + ?dst_size], 1
	adc word [bp + ?dst_size + 2], 0

.loop:
%if _PAYLOAD_KERNEL_MAX_PARAS
		; Do the max segment check here, so it happens either
		;  after the func_bx_* call with movsb (for literals)
		;  or after .end_copy_match (for matches) has been
		;  executed and eventually has returned here to loop.
	mov ax, word [bp + ?dst + 2]	; get new dst segment (may have grown)
	cmp ax, word [bp + ?dst_max_segment]
	jae depack.end
%endif

	mov ax, word [bp + ?dst_size]
	mov dx, word [bp + ?dst_size + 2]

	cmp dx, word [bp + ?depacked_size + 2]
	ja .end
	jb @F
	cmp ax, word [bp + ?depacked_size]
	jae .end
@@:

	call blz_getbit_safe
d0	mov byte [bp + ?errordata], 7
	jc .ret_CY

	test ax, ax
	jz .literal

	call blz_getgamma_safe
d0	mov byte [bp + ?errordata], 8
	jc .ret_CY
	mov cx, ax
	mov bx, dx			; bx:cx = len

	call blz_getgamma_safe
d0	mov byte [bp + ?errordata], 9
	jc .ret_CY			; dx:ax = off

	add cx, 2
	adc bx, 0			; len += 2

	sub ax, 2
	sbb dx, 0			; off -= 2

d0	mov byte [bp + ?errordata], 0Ah
	cmp dx, 00FFh
	ja .ret_CY
	jb @F
	cmp ax, 0FFFFh			; off >= 00FF_FFFFh ?
	jae .ret_CY			; return error if so
@@:

d0	mov byte [bp + ?errordata], 0Bh
	cmp word [bp + ?src_avail + 2], 0
	jne @F
	cmp word [bp + ?src_avail], 0	; src_avail != 0 ?
	je .ret_CY			; return error if == 0
@@:

	sub word [bp + ?src_avail], 1
	sbb word [bp + ?src_avail + 2], 0	; src_avail--

	mov word [bp + ?len], cx
	mov word [bp + ?len + 2], bx

	mov cx, 8
@@:
	shl ax, 1
	rcl dx, 1			; off <<= 8
	loop @B

	mov word [bp + ?off], ax
	mov word [bp + ?off + 2], dx

	xor ax, ax
	mov bx, .lodsb
	call func_bx_with_normalised_pointers
		; Note:	As the write pointer isn't changed here, it here isn't
		;	 necessary to re-check for overlap-corrupted source.

	inc ax				; *src + 1
	add word [bp + ?off], ax
	adc word [bp + ?off + 2], 0	; + off

	mov ax, word [bp + ?depacked_size]
	mov dx, word [bp + ?depacked_size + 2]

	sub ax, word [bp + ?dst_avail]
	sbb dx, word [bp + ?dst_avail + 2]

d0	mov byte [bp + ?errordata], 0Ch
	cmp word [bp + ?off + 2], dx
	ja .ret_CY
	jb @F
	cmp word [bp + ?off], ax	; off > depacked_size - dst_avail ?
	ja .ret_CY			; return error if so
@@:

	mov ax, word [bp + ?len]
	mov dx, word [bp + ?len + 2]

d0	mov byte [bp + ?errordata], 0Dh
	cmp dx, word [bp + ?dst_avail + 2]
	ja .ret_CY
	jb @F
	cmp ax, word [bp + ?dst_avail]	; len > dst_avail ?
	ja .ret_CY			; return error if so
@@:

	sub word [bp + ?dst_avail], ax
	sbb word [bp + ?dst_avail + 2], dx	; dst_avail -= len


	add word [bp + ?dst_size], ax
	adc word [bp + ?dst_size + 2], dx	; dst_size += len


	lds si, [bp + ?dst]		; pp = dst

	mov bx, word [bp + ?off + 2]
	mov cx, word [bp + ?off]

        neg bx
        neg cx
        sbb bx, byte 0          	; neg bx:cx

	 push ds
	 push si
	call normalise_pointer_with_displacement_bxcx
	 pop si
	 pop ds				; ds:si = pp = dst - off
	jnc .ret_CY

	mov cx, ds			; is source of matching within ?dst ?
	cmp word [bp + ?original_dst + 2], cx
d0	mov byte [bp + ?errordata], 11h
.ret_CY_A_1:
	ja .ret_CY
	jb @F
	cmp word [bp + ?original_dst], si
d0	mov byte [bp + ?errordata], 12h
	ja .ret_CY_A_1			; no, ?original_dst is above it -->
@@:


	les di, [bp + ?dst]		; es:di = dst

.loop_copy_match:
	mov cx, 64 * 1024 - 16		; block size

	test dx, dx			; >= 1_0000h ?
	jnz @F				; yes, full block -->

	test ax, ax			; == 0 ?
	jz .end_copy_match		; yes, done -->

	cmp ax, cx			; can move in one (last) block ?
	jbe .last_copy_match		; yes -->
@@:
					; no, move one block and continue
	sub ax, cx
	sbb dx, 0			; left over remaining

	jmp .copy_match

.last_copy_match:
	xchg cx, ax			; cx = remaining len
	xor ax, ax			; no more remaining

.copy_match:

	rep movsb			; move one block (full or partial)

	call normalise_both_pointers

	jmp .loop_copy_match


.end_copy_match:
	mov word [bp + ?dst], di
	mov word [bp + ?dst + 2], es

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
d0	mov byte [bp + ?errordata], 10h
	jc .ret_CY
%endif
	jmp .loop


.end:
	mov ax, word [bp + ?dst_size]
	mov dx, word [bp + ?dst_size + 2]
	clc
	retn

.ret_CY:
	stc
.ret:
	retn


.lodsb:
	lodsb
	retn

.movsb:
	movsb
	retn


		; INP:	?dst -> destination
		;	?src -> source
		;	bx = function to call with pointers
		; CHG:	ds, si, es, di
		; OUT:	function called,
		;	?dst and ?src advanced (if function changed the regs)
func_bx_with_normalised_pointers:
	les di, [bp + ?dst]
	lds si, [bp + ?src]

	call bx

	 push ds
	 push si
	call normalise_pointer
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]

	 push es
	 push di
	call normalise_pointer
	 pop word [bp + ?dst]
	 pop word [bp + ?dst + 2]

	retn

