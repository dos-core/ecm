
%if 0

8086 Assembly lDOS iniload payload LZO depacker
 by C. Masloch, 2020

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%include "lmacros3.mac"

	numdef LZO_SUPPORT_RLE,	0	; DO NOT ENABLE
					; Our implementation doesn't match
					;  the Linux kernel's one. lzop does
					;  not use the LZO-RLE extension.


lzop_signature:
.:
	db 89h, "LZO", 0, 13, 10, 26, 10
.size: equ $ - .


	struc lzop_header		; all multi-byte fields are big endian
lzophSignature:		resb lzop_signature.size
lzophVersion:		resw 1			; 0940h+
lzophLibVersion:	resw 1
lzophVersionNeeded:	resw 1			; 0900h..1040h
		; prior field not present for version 0900h..093Fh
lzophMethod:		resb 1			; > 0
		; prior field values:	1 M_LZO1X_1
		;			2 M_LZO1X_15
		;			3 M_LZO1X_999 (observed)
lzophLevel:		resb 1			; 9 observed
		; prior field not present for version 0900h..093Fh
lzophFlags:		resd 1			; 03000001h observed
		; prior field values:
F_H_EXTRA_FIELD	equ 40h
F_H_FILTER	equ 800h
F_ADLER32_D	equ 1
F_ADLER32_C	equ 2
F_CRC32_D	equ 100h
F_CRC32_C	equ 200h
F_MASK		equ 3FFFh
F_OS_MASK	equ 0_FF00_0000h
F_CS_MASK	equ 00F0_0000h
F_reserved_bits	equ 000F_C000h
		; (dword filter here if flags & F_H_FILTER set)
lzophMode:		resd 1
lzophMtimeLow:		resd 1
lzophMtimeHigh:		resd 1
		; prior field not present for version 0900h..093Fh
lzophFilenameLength:	resb 1
lzophFilename:					; not zero terminated!
		; (dword checksum here)
		; extra field here if flags & F_H_EXTRA_FIELD set:
		;  dword amount, then amount bytes, then dword checksum
	endstruc

	struc lzop_frame		; all fields are big endian
lzopfUncompressedSize:		resd 1		; 0 = end
lzopfCompressedSize:		resd 1
		; if compressed size == decompressed size then uncompressed
		; if compressed size > decompressed size, invalid
		; for F_ADLER32_D one dword checksum
		; for F_CRC32_D one dword checksum
		; for F_ADLER32_C one dword checksum, unless uncompressed
		; for F_CRC32_C one dword checksum, unless uncompressed
		; actual stream follows
	endstruc

; The stream format was implemented going by the description
;  in https://www.kernel.org/doc/Documentation/lzo.txt
; The header and frame format was gleaned from lzop.


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
	lvar word,	version_and_counter
	lequ ?version_and_counter, version
	lequ ?version_and_counter + 1, counter
%if _COUNTER || 1
	 push bx		; initialise both to zero
%endif
	lvar word,	state
	lvar dword,	length_of_uncompressed
	lvar dword,	length_of_compressed
	lvar dword,	after_end_length_of_source
	lvar dword,	after_end_length_of_destination
	lvar dword,	flags
	lvar dword,	original_dst
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

.loop_header:
	push word [bp + ?dst + 2]
	push word [bp + ?dst]
	pop word [bp + ?original_dst]
	pop word [bp + ?original_dst + 2]

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
	cmp word [bp + ?length_of_source + 2], 0
	jne @F
	cmp word [bp + ?length_of_source], lzop_header_size
@@:
	jb .error

	lds si, [bp + ?src]
	push cs
	pop es
	mov di, lzop_signature
	mov cx, lzop_signature.size

	sub word [bp + ?length_of_source], cx
	sbb word [bp + ?length_of_source + 2], 0
	jb .error

	repe cmpsb
	jne .error

	 push ds
	 push si
	call normalise_pointer
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]

	mov cl, 2
	call read_be_data_src		; get version
d0	mov byte [bp + ?errordata], 1
	jc .error

	cmp ax, 0940h			; we only support 0940h+
		; (some header fields are omitted for 0900h..093Fh)
	jb .error

	call read_be_data_src		; skip lib version
	jc .error

	call read_be_data_src		; get version needed
	jc .error
	cmp ax, 0900h
	jb .error
	cmp ax, 1040h
	ja .error

	mov cl, 1
	call read_be_data_src		; method
	jc .error
	test al, al
	jz .error
	cmp al, 3			; 1, 2, 3 valid
	ja .error

	call read_be_data_src		; skip level
	jc .error

	mov cl, 4
	call read_be_data_src		; flags
	jc .error
	test dl, F_reserved_bits >> 16	; reserved ?
	jnz .error
	test ax, (F_reserved_bits & 0FFFFh) | F_H_FILTER | F_H_EXTRA_FIELD
					; extra field, filter, or reserved ?
	jnz .error

	mov word [bp + ?flags], ax
	mov word [bp + ?flags + 2], dx

	mov cl, 4 * 3
	call read_be_data_src		; skip mode, mtimelow, mtimehigh
	jc .error

	mov cl, 1
	call read_be_data_src		; load filename length
	jc .error
	mov cl, al
	call read_be_data_src		; skip filename
	jc .error

	mov cl, 4
	call read_be_data_src		; skip header checksum
	jc .error

.loop_frame:
	mov cx, 4
	call read_be_data_src		; uncompressed size
	mov word [bp + ?length_of_uncompressed], ax
	mov word [bp + ?length_of_uncompressed + 2], dx

	mov bx, ax
	or bx, dx
	jz .loop_header

	call read_be_data_src		; compressed size
	mov word [bp + ?length_of_compressed], ax
	mov word [bp + ?length_of_compressed + 2], dx

	cmp dx, word [bp + ?length_of_uncompressed + 2]
	jne @F
	cmp ax, word [bp + ?length_of_uncompressed]
@@:
	ja .error
	jb .compressed

		; equal: is uncompressed block
.uncompressed:
	xor cx, cx
	testopt [bp + ?flags], F_ADLER32_D
	jz @F
	mov cl, 4
@@:
	testopt [bp + ?flags], F_CRC32_D
	jz @F
	add cl, 4
@@:

	call read_be_data_src		; skip checksums
	jc .error

	call check_limits
	jc .error

	call copy_literal_or_uncompressed
	jc .error

	jmp .loop_frame


.compressed:
	xor cx, cx
	testopt [bp + ?flags], F_ADLER32_D
	jz @F
	mov cl, 4
@@:
	testopt [bp + ?flags], F_CRC32_D
	jz @F
	add cl, 4
@@:
	testopt [bp + ?flags], F_ADLER32_C
	jz @F
	add cl, 4
@@:
	testopt [bp + ?flags], F_CRC32_C
	jz @F
	add cl, 4
@@:

	call read_be_data_src		; skip checksums

	call check_limits
	jc .error

	push dx
	push ax				; ?length_of_compressed

	neg dx
	neg ax
	sbb dx, byte 0			; neg dx:ax

	add ax, word [bp + ?length_of_source]
	adc dx, word [bp + ?length_of_source + 2]
	jnc .error

	mov word [bp + ?after_end_length_of_source], ax
	mov word [bp + ?after_end_length_of_source + 2], dx
					; remember how much to do after

	pop word [bp + ?length_of_source]
	pop word [bp + ?length_of_source + 2]
					; set length to frame length

	mov dx, word [bp + ?length_of_uncompressed + 2]
	mov ax, word [bp + ?length_of_uncompressed]

	push dx
	push ax				; uncompressed size

	neg dx
	neg ax
	sbb dx, byte 0			; neg dx:ax

	add ax, word [bp + ?length_of_destination]
	adc dx, word [bp + ?length_of_destination + 2]
	jnc .error

	mov word [bp + ?after_end_length_of_destination], ax
	mov word [bp + ?after_end_length_of_destination + 2], dx
					; remember how much to do after

	pop word [bp + ?length_of_destination]
	pop word [bp + ?length_of_destination + 2]
					; set length to frame length

	xor ax, ax
	mov word [bp + ?state], ax
%if _LZO_SUPPORT_RLE
	mov byte [bp + ?version], al
%endif

.first:
	mov cx, 1
	call read_le_data_src
	mov ah, 0
	cmp al, 16
	je .error
	cmp al, 17
	jb .normal
%if _LZO_SUPPORT_RLE
	je .version
%else
	je .error
%endif

%if 0

The description text specifies the following for this value:

      18..21  : copy 0..3 literals
                state = (byte - 17) = 0..3  [ copy <state> literals ]
                skip byte

      22..255 : copy literal string
                length = (byte - 17) = 4..238
                state = 4 [ don't copy extra literals ]
                skip byte

The "byte - 17" part is correct. Listing "18..21" as copying "0..3 literals"
is incorrect. 17 would encode copying "zero" literals, but does not occur.
18 encodes copying 1 literal, 19 then 2 literals, 20 for 3 literals, 21
for 4 literals. The description should read "18..21" as "copy 1..4 literals".
Likewise, 22 indicates "copying 5 literals", not "4 literals". However, the
state is indeed always set to "byte - 17" (which for 21 results in 4 too).

%endif

	xor dx, dx
	sub al, 17			; dx:ax = length
	cmp al, 4			; below 4 ?
	jae .literals_and_state_4	; no -->
	mov word [bp + ?state], ax	; set state to below 4 value
	jmp .literals


%if _LZO_SUPPORT_RLE
.version:
	call read_le_data_src
	cmp al, 1
	ja .error
	mov byte [bp + ?version], al
%endif


.loop:
	mov cx, 1
	call read_le_data_src
	mov ah, 0
	cmp al, 16
	jae .not_normal

.normal:
	cmp word [bp + ?state], 0
	jne .not_normal_state_0

.long_literal_string:
	mov dx, 15
	mov bx, ax
	call get_length
	mov ax, bx			; dx:ax = length
	jc .error
	add ax, 3
	adc dx, 0
	jc .error

.literals_and_state_4:
	mov word [bp + ?state], 4
	jmp .literals


.not_normal_state_0:
	cmp word [bp + ?state], 4
	jae .normal_state_4

.copy_2_bytes_from_1_KiB:
	mov bl, al
	and bx, 3			; bh = 0
	mov word [bp + ?state], bx
	mov bl, al			; bx = 0 0 0 0 D D S S
	shr bl, 1
	shr bl, 1			; bx = D D

	mov cx, 1
	call read_le_data_src
	mov ah, 0			; ax = H{8}
	shl ax, 1
	shl ax, 1			; ax = H << 2
	add ax, bx			; ax = (H << 2) + D
	jc .error
	inc ax				; ax = (H << 2) + D + 1
	jz .error
	mov bx, 2			; bx = length
	jmp .match_dx_0


.normal_state_4:
.copy_3_bytes_from_2_to_3_KiB:
	mov bl, al
	and bx, 3
	mov word [bp + ?state], bx
	mov bl, al
	shr bl, 1
	shr bl, 1

	mov cx, 1
	call read_le_data_src
	mov ah, 0
	shl ax, 1
	shl ax, 1
	add ax, bx
	jc .error
	add ax, 2049			; ax = distance
	jc .error
	mov bx, 3			; bx = length
	jmp .match_dx_0


.not_normal:
	cmp al, 0001_1111b
	ja .not_0001

.0001:
	push ax
	mov dx, 7
	mov bx, ax
	call get_length
	mov cx, 2			; cx = 2
	jc .error
	add bx, cx
	adc dx, 0			; dx:bx = length = 2 + encoded length
	jc .error

	push dx
	call read_le_data_src		; read D{14} S S
	pop dx
	jc .error
	pop si
	and si, 0000_0000_0000_1000b
	mov cl, 14 - 3
	shl si, cl
	mov cx, ax
	and cx, 3
	mov word [bp + ?state], cx

	shr ax, 1
	shr ax, 1			; ax = D{14}
	add ax, si			; ax = D + (H << 14)
	jc .error
	add ax, 16384
	jc .error
	cmp ax, 16384
	je .end_frame


		; Note: We already parsed the length here. If the length
		;  was initially zero, then this implementation may differ
		;  from the Linux kernel one's described in the text, which
		;  seems to not parse the length the normal way at all if
		;  there appears to be a zero run (H and all D bits = 1).
%if _LZO_SUPPORT_RLE
	cmp byte [bp + ?version], 1
	jb @F
	cmp ax, 0BFFFh
	jne @F
	mov cx, 1
	push dx
	call read_le_data_src
	pop dx
	mov ah, 0
	mov cl, 3
	shl ax, cl
	add ax, bx
	adc dx, 0
	jc .error
	add ax, 4
	adc dx, 0
	jc .error
	jmp .zeros_run

@@:
%endif
	jmp .match


.not_0001:
	cmp al, 0011_1111b
	ja .not_001

.001:
	mov dx, 31
	mov bx, ax
	call get_length
	mov cx, 2
	jc .error
	add bx, cx
	adc dx, 0			; dx:bx = length = 2 + encoded length
	jc .error

	push dx
	call read_le_data_src
	pop dx
	jc .error

	mov cx, ax
	and cx, 3
	mov word [bp + ?state], cx

	shr ax, 1
	shr ax, 1
	inc ax				; distance = D{14} + 1
	jmp .match


.not_001:
	cmp al, 0111_1111b
	ja .not_01

.01:
	mov cx, ax
	and cx, 3
	mov word [bp + ?state], cx

	mov bx, 3
	test al, 0010_0000b
	jz @F
	inc bx				; bx = length
@@:

	and al, 000_111_00b
	shr ax, 1
	shr ax, 1
	push ax
	mov cl, 1
	call read_le_data_src
	pop dx
	jc .error

	mov ah, 0
	mov cl, 3
	shl ax, cl
	add ax, dx
	jc .error
	inc ax				; ax = distance
	jz .error
					; bx = length
	jmp .match_dx_0


.not_01:
.1:
	mov cx, ax
	and cx, 3
	mov word [bp + ?state], cx

	mov bx, ax
	mov cl, 5
	shr bx, cl
	and bl, 3
	add bl, 5			; bx = length

	and al, 000_111_00b
	shr ax, 1
	shr ax, 1
	push ax
	mov cl, 1
	call read_le_data_src
	pop dx
	jc .error

	mov ah, 0
	mov cl, 3
	shl ax, cl
	add ax, dx
	jc .error
	inc ax				; ax = distance
	jz .error
					; bx = length
	jmp .match_dx_0


%if _LZO_SUPPORT_RLE
		; INP:	dx:ax = length
.zeros_run:
	les di, [bp + ?dst]
	sub word [bp + ?length_of_destination], ax
	sbb word [bp + ?length_of_destination + 2], dx
	jc .error

.zr_loop:
	mov cx, 0FFF0h			; how much we can do per step
					;  (?dst is always normalised)
	test dx, dx			; a lot ?
	jnz .zr_do			; yes, skip check -->
	cmp ax, cx			; more than one step ?
	ja .zr_do			; yes, do --> (subtracts cx from ax)
	test ax, ax			; is it zero ?
	jz .zr_end			; yes -->
	mov cx, ax			; set up to get 0 from the subtraction
					;  (meaning this is the last step)
					;  (and set step length to remainder)
.zr_do:
	sub ax, cx
	sbb dx, 0			; determine how much after this step
	jb .error			; (must not carry)
	push ax
	mov al, 0
	rep stosb
	pop ax
	 push es
	 push di
	call normalise_pointer
	 pop di
	 pop es
	jmp .zr_loop

.zr_end:
	mov word [bp + ?dst], di
	mov word [bp + ?dst + 2], es
	jmp .next
%endif


		; INP:	dx:ax = length
.literals:
	call copy_literal_or_uncompressed
	jc .error
	jmp .loop


.match_dx_0:
	xor dx, dx

		; INP:	dx:bx = length
		;	ax = distance
.match:
	push dx
	push bx				; on stack: dword length
	xor dx, dx			; dx:ax = distance

	neg dx
	neg ax
	sbb dx, byte 0			; neg dx:ax

	mov cx, ax
	mov bx, dx			; bx:cx = minus distance

	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
	call normalise_pointer_with_displacement_bxcx
	 pop si
	 pop ds				; -> source
	pop ax
	pop dx				; dx:ax = length
	jnc .error			; must carry !
	mov cx, ds
	cmp cx, word [bp + ?original_dst + 2]
	jne @F
	cmp si, word [bp + ?original_dst]
@@:
	jb .error			; must not be before buffer !

	call copy_data
	jc .error

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
d0	mov byte [bp + ?errordata], 1Ch
	jc .error
%endif
	; jmp .next

.next:
	mov ax, word [bp + ?state]
	xor dx, dx
	jmp .literals


.end_frame:
	xor ax, ax
	cmp word [bp + ?length_of_source + 2], ax
	jne .error
	cmp word [bp + ?length_of_source], ax
	jne .error
	cmp word [bp + ?length_of_destination + 2], ax
	jne .error
	cmp word [bp + ?length_of_destination], ax
	jne .error

	push word [bp + ?after_end_length_of_destination + 2]
	push word [bp + ?after_end_length_of_destination]
	pop word [bp + ?length_of_destination]
	pop word [bp + ?length_of_destination + 2]

	push word [bp + ?after_end_length_of_source + 2]
	push word [bp + ?after_end_length_of_source]
	pop word [bp + ?length_of_source]
	pop word [bp + ?length_of_source + 2]

	jmp .loop_frame


		; INP:	?length_of_compressed|uncompressed|source|destination
		; OUT:	NC if success,
		;	 dx:ax = ?length_of_compressed
		;	CY if error
check_limits:
	mov ax, word [bp + ?length_of_uncompressed]
	mov dx, word [bp + ?length_of_uncompressed + 2]

	cmp dx, word [bp + ?length_of_destination + 2]
	jne @F
	cmp ax, word [bp + ?length_of_destination]
@@:
	ja .error

	mov ax, word [bp + ?length_of_compressed]
	mov dx, word [bp + ?length_of_compressed + 2]

	cmp dx, word [bp + ?length_of_source + 2]
	jne @F
	cmp ax, word [bp + ?length_of_source]
@@:
	ja .error

	db __TEST_IMM8			; (NC, skip stc)
.error:
	stc
	retn


		; INP:	bx = initial length value (needs to be masked)
		;	dx = initial length value mask
		; OUT:	NC if success,
		;	 dx:bx = cumulated length value
		;	 ?src incremented, ?length_of_source decremented
		;	CY if error
		; CHG:	ax, cx, ds, si
get_length:
	xor si, si
	and bx, dx		; (NC)
	jnz .ret

.loop:
	add bx, dx
	adc si, 0
	jc .ret
	mov cx, 1
	push si
	call read_le_data_src
	pop si
	jc .ret
	mov dx, 255
	test al, al
	jz .loop
	mov ah, 0
	add bx, ax
	adc si, 0
	jc .ret
	clc
.ret:
	mov dx, si
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
copy_literal_or_uncompressed:
	lds si, [bp + ?src]

	sub word [bp + ?length_of_source], ax
	sbb word [bp + ?length_of_source + 2], dx
					; enough data exists ?
	jb .return			; no --> (CY)

	call copy_data			; CY/NC depending on status

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

	call normalise_dssi_pointer
	mov word [bp + ?src], si
	mov word [bp + ?src + 2], ds

	db __TEST_IMM8		; (NC)
.error:
	stc
	retn


		; INP:	?src -> source data (normalised)
		;	cx = size to read, 1 to 4 or higher (at most 0FFF0h)
		;	?length_of_source
		; OUT:	If cx >= 4,
		;	 dx:ax = value read as big-endian
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
read_be_data_src:
	jcxz .error

	sub word [bp + ?length_of_source], cx
	sbb word [bp + ?length_of_source + 2], 0
	jb .error

	lds si, [bp + ?src]

	push si
	cmp cx, 3
	jb .1_or_2
	je .3

.4:
	lodsw
	xchg al, ah		; al = second byte,
				;  ah = first byte
	jmp .3_4_common
	; xchg ax, dx		; dx = high word (first)
	; lodsw			; ax = low word (second)
	; xchg al, ah		; al = fourth byte (least significant),
	;			;  ah = third byte
	; jmp .common

.3:
	lodsb
.3_4_common:
	xchg ax, dx		; dl = first byte
.2:
	lodsw
	xchg al, ah		; al = third byte, ah = second byte

	jmp .common

.1_or_2:
	cmp cl, 1
	ja .2
	; jmp .1

; .2:
	; lodsw
	; xchg al, ah		; al = second byte, ah = first byte
	;
	; jmp .common

.1:
	lodsb
.common:

	pop si
	add si, cx

	call normalise_dssi_pointer
	mov word [bp + ?src], si
	mov word [bp + ?src + 2], ds

	db __TEST_IMM8		; (NC)
.error:
	stc
	retn

