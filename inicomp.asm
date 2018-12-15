
%if 0

lDOS iniload packed payload
 by C. Masloch, 2018

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.


Contains BriefLZ depacker, which is under separate usage conditions.

%endif

%include "lmacros2.mac"

	struc LOADSTACKVARS, -10h
lsvFirstCluster:	resd 1
lsvFATSector:		resd 1
lsvFATSeg:		resw 1
lsvLoadSeg:		resw 1
lsvDataStart:		resd 1
	endstruc

	struc LOADDATA, LOADSTACKVARS - 10h
ldMemoryTop:	resw 1
ldLoadTop:	resw 1
ldSectorSeg:	resw 1
ldFATType:	resb 1
ldHasLBA:	resb 1
ldClusterSize:	resw 1
ldParaPerSector:resw 1
ldLoadingSeg:	resw 1
ldLoadUntilSeg:	resw 1
	endstruc


%ifndef _MAP
%elifempty _MAP
%else	; defined non-empty, str or non-str
	[map all _MAP]
%endif

	defaulting

	numdef DEBUG0		; use errordata to generate an error code
	numdef DEBUG1		; dump_stack_frame after an error occurred
	numdef DEBUG2		; dump_stack_frame before blz_depack_safe call
	numdef DEBUG3		; dump_stack_frame at start of blz_depack_safe

	numdef OPTIMISE_MOVP_DN_ONLY,	1	; init0_movp always moves DN
	numdef ALLOW_OVERLAPPING,	1	; allow overlapping src and dst

	numdef EXEC_OFFSET,	0
	numdef EXEC_SEGMENT,	0
	numdef IMAGE_EXE,	0
	numdef IMAGE_EXE_CS,	-16	; relative-segment for CS
	numdef IMAGE_EXE_IP,	256 +64	; value for IP
		; The next two are only used if _IMAGE_EXE_AUTO_STACK is 0.
	numdef IMAGE_EXE_SS,	-16	; relative-segment for SS
	numdef IMAGE_EXE_SP,	0FFFEh	; value for SP (0 underflows)
	numdef IMAGE_EXE_AUTO_STACK,	0, 2048	; use stack behind image
		; _IMAGE_EXE_AUTO_STACK here differs from iniload's def of
		;  the same name. This one is only used as a flag; if non-zero,
		;  keep the stack given to us by iniload; if zero, set up the
		;  stack specified by _IMAGE_EXE_SS and _IMAGE_EXE_SP.

	numdef BRIEFLZ,		0
	numdef LZ4,		0
%if (!!_BRIEFLZ + !!_LZ4) != 1
 %error Exactly one compression method must be selected.
%endif
%if _BRIEFLZ
	strdef PAYLOAD_FILE,	"lDOSLOAD.BLZ"
%elif _LZ4
	strdef PAYLOAD_FILE,	"lDOSLOAD.LZ4"
	numdef COUNTER,		0, 32
 %if (_COUNTER - 1) & _COUNTER
  %error COUNTER must be a power of two
 %endif
%endif


	cpu 8086
	section INIT0 start=0 vstart=0
init0_start:

%if _IMAGE_EXE
	nop
	align 32, nop
init0_kernel_entry:
		; cs:ip = load seg : 32 here
%if ($ - $$) != 32
 %error Wrong kernel mode entrypoint
%endif
	mov bx, 0		; kernel mode
	push ax
	mov ax, cs
	add ax, (init0_end - init0_start) >> 4
	mov dx, word [ bp + ldLoadTop ]	; => after end of available space
	mov si, 60h		; => destination
	jmp init0_common

	align 64, nop
init0_exe_entry:
		; NOTE:	This part is called with ip = 256 + 64, cs = PSP.
%if ($ - $$) != 64
 %error Wrong EXE mode entrypoint
%endif
	mov bx, 1		; EXE mode
	push ax
	mov dx, ss		; => after end of available space
	mov ax, cs
	add ax, (256 + (init0_end - init0_start)) >> 4	; => source
	mov si, cs
	add si, 256 >> 4	; => destination

init0_common:
		; NOTE:	This part must be position-independent, as it is
		;	 called either with ip = init0_common (kernel mode)
		;	 or ip = init0_common + 256 (EXE mode).
	cld
	mov cx, ( (payload_end - payload) \
		+ (init1_end - init1_start) \
		) >> 4
	sub dx, cx
	push si
	call init0_movp
	pop si
%else
	cld
	mov ax, cs
	add ax, (init0_end - init0_start) >> 4
	mov cx, ( (payload_end - payload) \
		+ (init1_end - init1_start) \
		) >> 4
	mov dx, word [ bp + ldLoadTop ]
	sub dx, cx
	call init0_movp
%endif

	mov ax, dx
	add ax, ( \
		+ (payload_end - payload) \
		) >> 4
	xor cx, cx
	push ax
	push cx
	retf			; jump to relocated INIT1:init1_start


		; Move paragraphs
		;
		; INP:	ax => source
		;	dx => destination
		;	cx = number of paragraphs
		; CHG:	cx, ds, si, es, di
		; OUT:	NC, ax and dx unchanged
		; Note:	Doesn't work correctly on HMA; doesn't always wrap to LMA either.
		;	Do not provide a wrapped/HMA source or destination!
init0_movp:
	cmp ax, dx		; source below destination ?
	jb .down		; yes, move from top down -->
	je .return		; same, no need to move --> (NC)

%if _OPTIMISE_MOVP_DN_ONLY
@@:
	int3
	jmp @B
%else
	push ax
	push dx
.uploop:
	mov ds, ax
	mov es, dx
	xor di, di
	xor si, si		; -> start of segment
	sub cx, 1000h		; 64 KiB left ?
	jbe .uplast		; no -->
	push cx
	mov cx, 10000h /2
	rep movsw		; move 64 KiB
	pop cx
	add ax, 1000h
	add dx, 1000h		; -> next segment
	jmp short .uploop	; proceed for more -->
.uplast:
	add cx, 1000h		; restore counter
	shl cx, 1
	shl cx, 1
	shl cx, 1		; *8, paragraphs to words (NC)
	rep movsw		; move last part
	pop dx
	pop ax
	jmp short .return
%endif

.down:
	std
.dnloop:
	sub cx, 1000h		; 64 KiB left ?
	jbe .dnlast		; no -->
	push ax
	push dx
	add ax, cx
	add dx, cx
	mov ds, ax		; -> 64 KiB not yet moved
	mov es, dx
	pop dx
	pop ax
	mov di, -2
	mov si, di		; moved from last word down
	push cx
	mov cx, 10000h /2
	rep movsw		; move 64 KiB
	pop cx
	jmp short .dnloop	; proceed for more -->
.dnlast:
	add cx, 1000h		; restore counter
	shl cx, 1
	shl cx, 1
	shl cx, 1		; *8, paragraphs to words
	mov di, cx
	dec di
	shl di, 1		; words to offset, -> last word (NC)
	mov si, di
	mov ds, ax
	mov es, dx		; first segment correct
	rep movsw		; move first part
	cld
.return:
	retn


	align 16
init0_end:


	section PAYLOAD align=16 follows=INIT0
payload:
	incbin _PAYLOAD_FILE
.end:
	align 16, db 38

	numdef INCLUDE_UNCOMPRESSED
	strdef UNCOMPRESSED_FILE, "lDOSLOAD.BIN"
%if _INCLUDE_UNCOMPRESSED
payload_uncompressed:
	incbin _UNCOMPRESSED_FILE
	db 38
	align 16, db 38
%endif

payload_end:


	section INIT1 align=16 follows=PAYLOAD vstart=0
init1_start:
		; INP:	ax = cs = INIT1
		;	dx = cs - (payload_end - payload) >> 4 => source data
		;	if not _IMAGE_EXE, or if kernel mode:
		;	 ss:bp -> LOADDATA and LOADSTACKVARS
		;	 ss:sp -> valid stack above [bp + ldLoadTop]
		;	 60h => destination
		;	if _IMAGE_EXE, either mode:
		;	 word [ss:sp] = value for ax
		;	 bx = 1 if EXE mode, 0 if kernel mode
		;	 si => destination (60h for kernel mode,
		;				after PSP for EXE mode)
		;	 if EXE mode:
		;	  ss:sp -> valid stack above INIT1
		;	  bp = unset
		; CHG:	ax, bx, cx, dx, es, ds, si, di
%if _IMAGE_EXE
	lframe
	lenter
	lvar word,	exemode		; must be bp - 2!
	 push bx
 %if ?exemode != -2
  %error exemode variable must be directly below bp
 %endif
	push si
%endif

	cld

%if _IMAGE_EXE
	mov es, si		; es => destination
%else
	mov ax, 60h
	mov es, ax		; es => destination
%endif
	xor di, di		; -> destination

	mov ds, dx
	xor si, si		; -> source

	mov cx, (payload.end - payload) & 0FFFFh
%if (payload.end - payload) >> 16
	mov dx, (payload.end - payload) >> 16	; = length of source
%else
	xor dx, dx
%endif
		; INP:	ds:si -> source
		;	dx:cx = length of source
		;	es:di -> destination (below source)
		;	bx = EXE mode flag
		; Note:	The destination reaches up to below the source.
	call depack
	jc error

%if _IMAGE_EXE
	pop si			; si
	pop bx			; ?exemode
	pop bp			; bp
	pop ax			; ax

	lleave ctx

	test bx, 1
	jz .jmp_kernel_mode

%if ! _IMAGE_EXE_AUTO_STACK
	mov cx, cs
	lea dx, [si + _IMAGE_EXE_SS]
	push dx			; stack = relocated ss value
	add dx, (_IMAGE_EXE_SP + 2 + 15) >> 4
	cmp cx, dx		; INIT1 code is above intended stack ?
	jae @F			; yes -->

	lframe
	lenter
	lvar	word, exemode
	 push bx
 %if ?exemode != -2
  %error exemode variable must be directly below bp
 %endif
	mov bx, -1		; unimplemented, return error
	jmp error
	lleave ctx
@@:
	cli
	pop ss			; = relocated ss value
	mov sp, (_IMAGE_EXE_SP + 2) & 0FFFFh	; change stack
	sti
%endif

	xor cx, cx
	push cx			; put zero on top of stack

	mov cx, _IMAGE_EXE_IP
%if _IMAGE_EXE_CS == -16
	add si, -16
	mov ds, si
	mov es, si
%else
	lea dx, [si - 10h]	; => PSP
	mov ds, dx
	mov es, dx		; ds = es => PSP
	add si, _IMAGE_EXE_CS	; = relocated cs value
%endif
	push si
	push cx
	retf			; jump to EXE mode of image

.jmp_kernel_mode:
%endif
	jmp 60h + _EXEC_SEGMENT:_EXEC_OFFSET


error:
	push cs
	pop ds
%if _DEBUG0
	mov si, msg.error_begin
	call disp_error
	mov ax, bx
	call disp_ax_hex
	mov si, msg.error_end
%else
	mov si, msg.error
%endif
	call disp_error

%if _IMAGE_EXE
	test byte [bp - 2], 1
	jz .exit_kernel_mode

	mov ax, 4C7Fh
	int 21h

.exit_kernel_mode:
%endif
	xor ax, ax
	int 16h
	int 19h

disp_error:
.:
	lodsb
	test al, al
	jz .ret
	call disp_al
	jmp short .

%if _DEBUG0 || _DEBUG1 || _DEBUG2 || _DEBUG3
disp_ax_hex:			; ax
		xchg al,ah
		call disp_al_hex		; display former ah
		xchg al,ah			;  and fall trough for al
disp_al_hex:			; al
		push cx
		mov cl,4
		ror al,cl
		call disp_al_lownibble_hex	; display former high-nibble
		rol al,cl
		pop cx
						;  and fall trough for low-nibble
disp_al_lownibble_hex:
		push ax			 ; save ax for call return
		and al,00001111b		; high nibble must be zero
		add al,'0'			; if number is 0-9, now it's the correct character
		cmp al,'9'
		jna .decimalnum		 ; if we get decimal number with this, ok -->
		add al,7			;  otherwise, add 7 and we are inside our alphabet
 .decimalnum:
		call disp_al
		pop ax
		retn
%endif

disp_al:
	push ax
	push bx
	push bp
%if _IMAGE_EXE
	push dx

	test byte [bp - 2], 1
	jz .display_kernel_mode

	mov dl, al
	mov ah, 02h
	int 21h
	jmp .common

.display_kernel_mode:
%endif
	mov ah, 0Eh
	mov bx, 7
	int 10h
%if _IMAGE_EXE
.common:
	pop dx
%endif
	pop bp
	pop bx
	pop ax
disp_error.ret:
	retn


msg:
%if _DEBUG0
.error_begin:	db "Load error: Decompression failure, code ",0
.error_end:	db "h.",13,10,0
%else
.error:		db "Load error: Decompression failure.",13,10,0
%endif
%if _BRIEFLZ
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
%if _IMAGE_EXE
	lenter early
	lvar word,	exemode		; must be bp - 2!
	 push bx
 %if ?exemode != -2
  %error exemode variable must be directly below bp
 %endif
%endif
	lvar dword,	dst_avail
	lvar dword,	dst_size
	lvar dword,	src_avail
	lvar dword,	depacked_size
	lvar dword,	len
	lvar dword,	off
	lvar word,	tag
	lvar word,	bits_left
%if _DEBUG0
	lvar word,	errordata
%endif
	lenter

	call normalise_both_pointers

	lvar dword,	src
	 push ds
	 push si
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


.loop:
	cmp word [bp + ?length_of_source + 2], 0
	ja @F
	cmp word [bp + ?length_of_source], BRIEFLZHEADER_size
	jae @F

%if _DEBUG0
	mov byte [bp + ?errordata + 1], 1
%endif
	cmp word [bp + ?length_of_source], 15
	ja .error
	jmp .end

@@:

	call read_be32_src		; signature

%if _DEBUG0
	mov byte [bp + ?errordata + 1], 2
%endif
	cmp ax, 7A1Ah
	jne .error
	cmp dx, 626Ch
	jne .error

	call read_be32_src		; version

%if _DEBUG0
	mov byte [bp + ?errordata + 1], 3
%endif
	cmp ax, 1
	jne .error
	test dx, dx
	jnz .error

	call read_be32_src		; compressed size

	mov word [bp + ?src_avail], ax
	mov word [bp + ?src_avail + 2], dx

	mov bx, dx
	mov cx, ax			; bx:cx = compressed size, used later

%if _DEBUG0
	mov byte [bp + ?errordata + 1], 8
%endif
	add ax, BRIEFLZHEADER_size
	adc dx, 0
	jc .error

%if _DEBUG0
	mov byte [bp + ?errordata + 1], 4
%endif
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

%if _DEBUG0
	mov byte [bp + ?errordata + 1], 5
%endif
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
%if _DEBUG2
	call dump_stack_frame
%endif
	call blz_depack_safe
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]
%if _DEBUG0
	mov byte [bp + ?errordata + 1], 6
%endif
	jc .error

%if _DEBUG0
	mov byte [bp + ?errordata + 1], 7
%endif
	cmp word [bp + ?depacked_size], ax
	jne .error
	cmp word [bp + ?depacked_size + 2], dx
	jne .error

	jmp .loop

%if _DEBUG1
.end:
	clc
	jmp .ret

.error:
	call dump_stack_frame
	stc
.ret:
%else
.end:
	db __TEST_IMM8			; (NC)
.error:
	stc
%endif

%if _DEBUG0
	mov bx, word [bp + ?errordata]
%endif

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

%if _DEBUG0
	mov byte [bp + ?errordata], 1
%endif
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
%if _DEBUG0
	mov byte [bp + ?errordata], 2
%endif
	jc .ret				; (CY)
	test dh, 80h
	stc
%if _DEBUG0
	mov byte [bp + ?errordata], 3
%endif
	jnz .ret			; (CY)

	shl bx, 1
	rcl dx, 1

	or bx, ax

	call blz_getbit_safe
%if _DEBUG0
	mov byte [bp + ?errordata], 4
%endif
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
%if _DEBUG0
	mov byte [bp + ?errordata], 13h
%endif
	jc .ret_CY
%endif

%if _DEBUG3
	call dump_stack_frame
%endif

		; Note:	Before the first iteration of .loop, move a literal.
.literal:
%if _DEBUG0
	mov byte [bp + ?errordata], 0Eh
%endif
	xor cx, cx
	cmp word [bp + ?dst_avail + 2], cx
	jne @F
	cmp word [bp + ?dst_avail], cx
	je .ret_CY
@@:

%if _DEBUG0
	mov byte [bp + ?errordata], 0Fh
%endif
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
	mov ax, word [bp + ?dst_size]
	mov dx, word [bp + ?dst_size + 2]

	cmp dx, word [bp + ?depacked_size + 2]
	ja .end
	jb @F
	cmp ax, word [bp + ?depacked_size]
	jae .end
@@:

	call blz_getbit_safe
%if _DEBUG0
	mov byte [bp + ?errordata], 7
%endif
	jc .ret_CY

	test ax, ax
	jz .literal

	call blz_getgamma_safe
%if _DEBUG0
	mov byte [bp + ?errordata], 8
%endif
	jc .ret_CY
	mov cx, ax
	mov bx, dx			; bx:cx = len

	call blz_getgamma_safe
%if _DEBUG0
	mov byte [bp + ?errordata], 9
%endif
	jc .ret_CY			; dx:ax = off

	add cx, 2
	adc bx, 0			; len += 2

	sub ax, 2
	sbb dx, 0			; off -= 2

%if _DEBUG0
	mov byte [bp + ?errordata], 0Ah
%endif
	cmp dx, 00FFh
	ja .ret_CY
	jb @F
	cmp ax, 0FFFFh			; off >= 00FF_FFFFh ?
	jae .ret_CY			; return error if so
@@:

%if _DEBUG0
	mov byte [bp + ?errordata], 0Bh
%endif
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

%if _DEBUG0
	mov byte [bp + ?errordata], 0Ch
%endif
	cmp word [bp + ?off + 2], dx
	ja .ret_CY
	jb @F
	cmp word [bp + ?off], ax	; off > depacked_size - dst_avail ?
	ja .ret_CY			; return error if so
@@:

	mov ax, word [bp + ?len]
	mov dx, word [bp + ?len + 2]

%if _DEBUG0
	mov byte [bp + ?errordata], 0Dh
%endif
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
%if _DEBUG0
	mov byte [bp + ?errordata], 10h
%endif
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
%endif


%if _LZ4

%if 0

8086 Assembly lDOS iniload payload LZ4 depacker
 by C. Masloch, 2018

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


lz4_flg_version_mask:	equ 1100_0000b
lz4_flg_version:	equ 0100_0000b
lz4_flg_b_indep:	equ 0010_0000b
lz4_flg_b_checksum:	equ 0001_0000b
lz4_flg_c_size:		equ 0000_1000b
lz4_flg_c_checksum:	equ 0000_0100b
lz4_flg_reserved:	equ 0000_0010b
lz4_flg_dict_id:	equ 0000_0001b

lz4_bd_reserved_mask:	equ 1000_1111b
		; BD block max size is not used by us


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
%if _DEBUG0
	mov byte [bp + ?errordata], 1Bh
%endif
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
%if _DEBUG0
	mov bx, word [bp + ?errordata]
%endif
	lleave code
	lret


@@:
	mov cl, 4
	call read_le_data_src
%if _DEBUG0
	mov byte [bp + ?errordata], 1
%endif
	jc .error

	cmp dx, 184Dh			; signature match ?
%if _DEBUG0
	mov byte [bp + ?errordata], 2
%endif
	jne .error			; no -->
	cmp ax, 2204h			; usual frame ?
	je @F				; yes -->

	and al,  ~0Fh
	cmp ax, 2A50h			; skippable frame ?
%if _DEBUG0
	mov byte [bp + ?errordata], 3
%endif
	jne .error			; no -->

		; cx = 4 still here
	call read_le_data_src		; read length of skippable frame
%if _DEBUG0
	mov byte [bp + ?errordata], 4
%endif
	jc .error

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
%if _DEBUG0
	mov byte [bp + ?errordata], 5
%endif
	jc .error
	jmp .loop_frame


@@:
	mov cl, 2
	call read_le_data_src		; read FLG (low byte), BD (high byte)
%if _DEBUG0
	mov byte [bp + ?errordata], 6
%endif
.error_CY_1:
	jc .error

	mov word [bp + ?frame_descriptor_flg_and_bd], ax
	mov bx, ax
	and bl, lz4_flg_version_mask
	cmp bl, lz4_flg_version		; version correct ?
%if _DEBUG0
	mov byte [bp + ?errordata], 7
%endif
.error_NZ_1:
	jne .error			; no -->

	test ax, (lz4_bd_reserved_mask << 8) \
		 | lz4_flg_reserved | lz4_flg_dict_id	; unsupported bits set?
%if _DEBUG0
	mov byte [bp + ?errordata], 8
%endif
	jnz .error_NZ_1			; yes -->

		; not checked: lz4_flg_b_indep (linked is always supported),
		;  lz4_flg_b_checksum, lz4_flg_c_checksum (both checked later)

	test al, lz4_flg_c_size		; content size field present ?
	jz @F				; no -->
	mov cl, 8
	call read_le_data_src		; (skip content size field)
%if _DEBUG0
	mov byte [bp + ?errordata], 9
%endif
	jc .error_CY_1
@@:
	mov cl, 1
	call read_le_data_src		; (skip header checksum field)
%if _DEBUG0
	mov byte [bp + ?errordata], 0Ah
%endif
	jc .error_CY_1

.loop_block:
%if _COUNTER
	mov al, '#'
	call disp_al
%endif
	mov cx, 4
	call read_le_data_src		; read block size field
					; leaves ds:si -> source
%if _DEBUG0
	mov byte [bp + ?errordata], 0Bh
%endif
	jc .error_CY_1

	test dx, dx			; nonzero ?
	jnz @FF
	test ax, ax
	jnz @FF				; yes -->

	test byte [bp + ?frame_descriptor_flg_and_bd], lz4_flg_c_checksum
	jz @F
		; cx = 4 already
	call read_le_data_src		; (skip c checksum field)
%if _DEBUG0
	mov byte [bp + ?errordata], 0Ch
%endif
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
%if _DEBUG0
	mov byte [bp + ?errordata], 0Dh
%endif
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
%if _DEBUG0
	mov byte [bp + ?errordata], 0Fh
%endif
	jc .error_CY_2

	sub word [bp + ?length_of_source], cx
	sbb word [bp + ?length_of_source + 2], bx
%if _DEBUG0
	mov byte [bp + ?errordata], 10h
%endif
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
%if _DEBUG0
	mov byte [bp + ?errordata], 0Eh
%endif
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
%if _DEBUG0
	mov byte [bp + ?errordata], 11h
%endif
	jc .error_CY_3
	mov byte [bp + ?token_and_counter], al

	mov cl, 4
	shr al, cl
	call lz4_get_length		; dx:cx = length of literals
%if _DEBUG0
	mov byte [bp + ?errordata], 12h
%endif
	jc .error_CY_3

	mov ax, cx			; dx:ax = length of literals (may be 0)
	call lz4_copy_literal_or_uncompressed
					; copy over the literals
%if _DEBUG0
	mov byte [bp + ?errordata], 13h
%endif
	jc .error_CY_3

	call lz4_check_behind_block_higher_than_src
					; do we have more data in this block ?
	jc .end_sequence		; no -->

	mov bx, .lodsw
	call lz4_func_bx_with_src	; load match offset
%if _DEBUG0
	mov byte [bp + ?errordata], 14h
%endif
.error_CY_4:
	jc .error_CY_3

	test ax, ax			; offset is 0 ?
%if _DEBUG0
	mov byte [bp + ?errordata], 15h
%endif
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
%if _DEBUG0
	mov byte [bp + ?errordata], 16h
%endif
.error_A_1:
	ja .error
	jb @F
	cmp word [bp + ?original_dst], si
%if _DEBUG0
	mov byte [bp + ?errordata], 17h
%endif
	ja .error_A_1			; no, ?original_dst is above it -->
@@:

	mov al, byte [bp + ?token_and_counter]
	and al, 0Fh			; get match length from token
	call lz4_get_length		; dx:cx = length of match - 4
%if _DEBUG0
	mov byte [bp + ?errordata], 18h
%endif
	jc .error_CY_4
	mov ax, cx			; dx:ax = length of match - 4
	add ax, 4
	adc dx, 0			; dx:ax = length of match
%if _DEBUG0
	mov byte [bp + ?errordata], 19h
%endif
	jc .error_CY_4
	call lz4_copy_data		; give ?dst -> dest, ds:si -> source
		; returns: ?dst incremented, ds:si -> after match source
%if _DEBUG0
	mov byte [bp + ?errordata], 1Ah
%endif
	jc .error_CY_4

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
%if _DEBUG0
	mov byte [bp + ?errordata], 1Ch
%endif
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
%if _DEBUG0
	inc byte [bp + ?errordata + 1]
%endif
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
%endif


%if 0

lDOS iniload payload depacker support functions
 by C. Masloch, 2018

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%if _ALLOW_OVERLAPPING
		; INP:	?src, ?dst
		; OUT:	CY if error
		;	NC if success
		; CHG:	ax, bx, cx, dx
check_pointers_not_overlapping:
	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
	call pointer_to_linear

	xchg cx, ax
	xchg bx, dx			; bx:cx = linear ?dst after write

	 push word [bp + ?src + 2]
	 push word [bp + ?src]
	call pointer_to_linear		; dx:ax = linear ?src before next read

	cmp dx, bx			; ?src >= ?dst ?
	ja @F
	jb .ret				; (CY)
	cmp ax, cx
	; jb .ret			; (CY)
					; (NC) yes, no error
@@:
.ret:
	retn
%endif

	lleave ctx


		; INP:	ds:si = pointer
		;	es:di = pointer
		; OUT:	ds:si normalised
		;	es:di normalised
normalise_both_pointers:
	 push ds
	 push si
	call normalise_pointer
	 pop si
	 pop ds

	 push es
	 push di
	call normalise_pointer
	 pop di
	 pop es
	retn


		; INP:	word [ss:sp + 2] = segment
		;	word [ss:sp] = offset
		;
		; Note:	Does not work correctly with pointers that point to
		;	 a HMA location. Do not use then!
normalise_pointer:
	lframe near
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
	call normalise_pointer_with_displacement_bxcx
	 pop word [bp + ?offset]
	 pop word [bp + ?segment]

	pop cx
	pop bx
	lleave
	lret


		; INP:	word [ss:sp + 2] = segment
		;	word [ss:sp] = offset
		;	bx:cx = add/sub displacement
normalise_pointer_with_displacement_bxcx:
	lframe near
	lpar word,	segment
	lpar word,	offset
	lpar_return
	lenter
	push ax
	push dx

	 push word [bp + ?segment]
	 push word [bp + ?offset]
	call pointer_to_linear

	; push bx
	; 				; sign-extend cx into bx:cx
	; cmp cx, 8000h			; CY if < 8000h (NC if negative)
	; cmc				; NC if positive
	; sbb bx, bx			; 0 if was NC, -1 if was CY

	add ax, cx
	adc dx, bx			; dx:ax += bx:cx
	; pop bx

%if 0
		; Adds in HMA support for this function. Not currently used.
	cmp dx, 10h			; dx:ax >= 10_0000h ?
	jb @F				; no, linear-to-pointer normally -->
%if 0
	ja .error
%endif

	add ax, 10h
%if 0
	jc .error
%endif
	mov word [bp + ?offset], ax
	or word [bp + ?segment], -1
	jmp .return
@@:
%endif

	push ax
	and ax, 15
	mov word [bp + ?offset], ax
	pop ax

%rep 4
	shr dx, 1
	rcr ax, 1
%endrep
	mov word [bp + ?segment], ax

%if 0
	test dx, dx
	jnz .error
%endif

.return:
	pop dx
	pop ax
	lleave
	lret


		; INP:	word [ss:sp + 2] = segment
		;	word [ss:sp] = offset
		; OUT:	dx:ax = linear address
pointer_to_linear:
	lframe near
	lpar word,	segment
	lpar word,	offset
	lenter

	mov ax, word [bp + ?segment]
	xor dx, dx
%rep 4
	shl ax, 1
	rcl dx, 1
%endrep

	add ax, word [bp + ?offset]
	adc dx, 0

	lleave
	lret


	align 16
init1_end:

%assign num (init1_end - init1_start) + (init0_end - init0_start)
%if _BRIEFLZ
%define which iniblz
%elif _LZ4
%define which inilz4
%endif
%warning which: num bytes used for depacker


