
%if 0

8086 Assembly lDOS iniload payload exomizer raw depacker
 by C. Masloch, 2020

Copyright (c) 2005-2017 Magnus Lind.

This software is provided 'as-is', without any express or implied warranty.
In no event will the authors be held liable for any damages arising from
the use of this software.

Permission is granted to anyone to use this software for any purpose,
including commercial applications, and to alter it and redistribute it
freely, subject to the following restrictions:

  1. The origin of this software must not be misrepresented * you must not
  claim that you wrote the original software. If you use this software in a
  product, an acknowledgment in the product documentation would be
  appreciated but is not required.

  2. Altered source versions must be plainly marked as such, and must not
  be misrepresented as being the original software.

  3. This notice may not be removed or altered from any distribution.

  4. The names of this software and/or it's copyright holders may not be
  used to endorse or promote products derived from this software without
  specific prior written permission.

%endif


	struc exo_table_entry
eteBits:	resb 1
eteBase:	resw 1
	endstruc

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
	lenter
 %if _IMAGE_EXE
	lvar word,	exemode	; must be bp - 2!
	 push bx
  %if ?exemode != -2
   %error exemode variable must be directly below bp
  %endif
 %endif
	xor bx, bx
 %if _DEBUG0
	lvar word,	errordata
	 push bx
 %endif
	lvar word, bit_buffer_and_counter
	lequ ?bit_buffer_and_counter, bit_buffer
	lequ ?bit_buffer_and_counter + 1, counter
	 push bx		; initialise counter (high byte) to zero

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
d0	mov byte [bp + ?errordata], 40h
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
d0	mov byte [bp + ?errordata], 1Bh
	jc .error
%endif

	lequ fromwords(words(16 * exo_table_entry_size)), 16tablesize
	lvar ?16tablesize, lengths
	lvar ?16tablesize, offsets3
	lvar ?16tablesize, offsets2
	lequ fromwords(words(4 * exo_table_entry_size)), 4tablesize
	lvar ?4tablesize, offsets1
	lreserve

	call read_byte_to_bit_buffer
d0	mov byte [bp + ?errordata], 30h
	jc .error

	mov di, ?lengths
	call generate_table_16
d0	mov byte [bp + ?errordata], 41h
	jc .error
	mov di, ?offsets3
	call generate_table_16
d0	mov byte [bp + ?errordata], 42h
	jc .error
	mov di, ?offsets2
	call generate_table_16
d0	mov byte [bp + ?errordata], 43h
	jc .error
	mov di, ?offsets1
	mov cl, 4
	call generate_table_cx		; cx = 0 if NC
d0	mov byte [bp + ?errordata], 44h
	jc .error

		; cx = 0
.STATE_IMPLICIT_FIRST_LITERAL_BYTE:
		; ! cx = 0
		; All paths to this label must have cx = 0.
.literal:
	inc cx				; cx = 1
.STATE_NEXT_LITERAL_BYTE_increment_counter:
d0	inc byte [bp + ?errordata + 1]
.STATE_NEXT_LITERAL_BYTE:
	call read_write_byte
d0	mov byte [bp + ?errordata], 37h
	jc .error
	loop .STATE_NEXT_LITERAL_BYTE
		; cx = 0
	; jmp .STATE_NEXT_BYTE

.STATE_NEXT_BYTE:
%if _COUNTER
	inc byte [bp + ?counter]
	test byte [bp + ?counter], _COUNTER - 1
	jnz @F
	mov al, '.'
	call disp_al
@@:
%endif
	call read_bits_1		; cx = 0 if NC
d0	mov byte [bp + ?errordata], 32h
	jc .error
	test ax, ax
	jnz .literal			; (cx = 0 still)

.not_literal:
	call get_gamma_code
d0	mov byte [bp + ?errordata], 33h
	jc .error
	test bx, bx
d0	mov byte [bp + ?errordata], 34h
	jnz .error
	cmp dx, 17
	jne .not_literal_data_block
.literal_data_block:
	call read_byte
d0	mov byte [bp + ?errordata], 35h
	jc .error
	mov ah, al
	call read_byte
d0	mov byte [bp + ?errordata], 36h
	jc .error
	xchg ax, cx
	jmp .STATE_NEXT_LITERAL_BYTE_increment_counter

.not_literal_data_block:
	cmp dx, 16
	je .end_check
d0	mov byte [bp + ?errordata], 38h
	ja .error

.sequence:
	mov di, dx
	add dx, dx
	add di, dx		; * 3 = * exo_table_entry_size

	mov bx, word [bp + ?lengths + di + eteBase]
	; xor cx, cx		; cx = 0 already after get_gamma_code NC
	mov cl, byte [bp + ?lengths + di + eteBits]
	call read_bits		; cx = 0 if NC
d0	mov byte [bp + ?errordata], 39h
	jc .error
	add bx, ax		; bx = length
	test bx, bx
	jz .switch_default
	cmp bx, 2
	je .switch_case2
	ja .switch_default
.switch_case1:
	mov cl, 2		; cx = 2
	mov dx, ?offsets1
d0	mov byte [bp + ?errordata], 3Ah
	jmp .switch_common

.switch_case2:
	mov cl, 4		; cx = 4
	mov dx, ?offsets2
d0	mov byte [bp + ?errordata], 3Bh
	jmp .switch_common

.switch_default:
	mov cl, 4		; cx = 4
	mov dx, ?offsets3
d0	mov byte [bp + ?errordata], 3Ch
	; jmp .switch_common

.switch_common:
	call read_bits
	jc .error
				; ax = next index, dx -> next table
	mov di, ax
	add ax, ax
	add di, ax		; di = offset into table
	add di, dx		; -> table entry
	; xor cx, cx		; cx already = 0 after read_bits NC
	mov cl, byte [bp + di + eteBits]
	call read_bits		; leaves cx = 0 if NC
d0	mov byte [bp + ?errordata], 3Dh
	jc .error
	xchg cx, bx		; cx = length that we remembered in bx
				; bx = 0
	xchg dx, ax		; bx:dx = read bits
	add dx, word [bp + di + eteBase]
	adc bx, 0		; bx:dx = offset
d0	inc byte [bp + ?errordata + 1]
        ; jmp .STATE_NEXT_SEQUENCE_BYTE

.STATE_NEXT_SEQUENCE_BYTE:
	call read_byte_from_window
d0	mov byte [bp + ?errordata], 3Eh
	jc .error
	call write_byte
d0	mov byte [bp + ?errordata], 3Fh
	jc .error
	loop .STATE_NEXT_SEQUENCE_BYTE

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
d0	mov byte [bp + ?errordata], 1Ch
	jc .error
%endif
	jmp .STATE_NEXT_BYTE

.end_check:
d0	mov byte [bp + ?errordata], 40h
	cmp word [bp + ?src_remaining + 2], 0
	jne .error
	cmp word [bp + ?src_remaining], 15
	ja .error
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


		; INP:	?src
		;	?src_remaining
		; OUT:	CY if error (source exhausted)
		;	NC if success,
		;	 al = byte read from source
		;	 ?src
		;	 ?src_remaining
		; CHG:	-
		; STT:	bp -> depack stack frame
read_byte:
	push ds
	push si
	lds si, [bp + ?src]
	lodsb
	 push ds
	 push si
	call normalise_pointer
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]
	pop si
	pop ds
	sub word [bp + ?src_remaining], 1
	sbb word [bp + ?src_remaining + 2], 0
	retn


		; as for read_byte
		; OUT:	CY if error
		;	NC if succesa,
		;	 ?bit_buffer
		; CHG:	al
read_byte_to_bit_buffer:
	call read_byte
	mov byte [bp + ?bit_buffer], al
	retn


		; INP:	CF = carry in
		;	?bit_buffer
		; OUT:	CF = carry out
		;	ZF = whether ?bit_buffer is now zero
		;	?bit_buffer
		; CHG:	-
		; STT:	bp -> depack stack frame
bitbuffer_rotate:
	rcl byte [bp + ?bit_buffer], 1
	dec byte [bp + ?bit_buffer]
	inc byte [bp + ?bit_buffer]	; this is to set ZF and preserve CF
	retn


read_bits_1:
	mov cx, 1

		; INP:	cl = cx = number of bits to read (0..15)
		; OUT:	CY if error (cx too high or source exhausted)
		;	NC if success,
		;	 ax = read data
		;	 cx = 0
		; CHG:	-
		; STT:	bp -> depack stack frame
read_bits:
	cmp cx, 16		; CY if valid
	cmc			; NC if valid
	jc .ret			; if error --> (CY)
	mov al, cl
	mov ah, cl
	and ax, (8 << 8) | 7	; al = bit_count, ah = byte_copy
	mov cl, al		; cl = cx = bit_count
	mov al, 0		; al = bits
	jcxz .end
.loop:
	clc
	call bitbuffer_rotate
	jnz .notzero
	push ax
	call read_byte_to_bit_buffer
	pop ax
	jc .ret			; if error --> (CY)
	stc
	call bitbuffer_rotate
.notzero:
	rcl al, 1		; bits <<= 1; bits |= carry;
	loop .loop
.end:
	test ah, ah		; NC
	jz .byte_copy_zero	; (NC)
	mov ah, al		; bits <<= 8;
	call read_byte		; bits |= read_byte()
				; pass CF to caller
.byte_copy_zero:		; ax = bits
.ret:
	retn


generate_table_16:
	mov cx, 16
		; INP:	cx = amount of table entries
		;	bp + di -> start of table
		; OUT:	CY if error
		;	NC if success,
		;	 cx = 0
		; CHG:	ax, bx, di
		; STT:	bp -> depack stack frame
generate_table_cx:
	mov bx, 1
.loop:
	mov word [bp + di + eteBase], bx
	push cx
	mov cx, 3
	call read_bits
	jc .ret
	mov byte [bp + di + eteBits], al
	mov cl, 1
	call read_bits
	jc .ret
	shl al, 1
	shl al, 1
	shl al, 1
	or byte [bp + di + eteBits], al
	mov ax, 1
	mov cl, byte [bp + di + eteBits]
	shl ax, cl
	add bx, ax
	pop cx
	add di, exo_table_entry_size
	loop .loop
	clc
.ret:
	retn


		; INP:	-
		; OUT:	CY if error
		;	NC if success,
		;	 bx:dx = gamma
		;	 ax = cx = 0
		; STT:	bp -> depack stack frame
get_gamma_code:
	xor dx, dx
	xor bx, bx		; bx:dx = gamma = 0
.loop:
	call read_bits_1	; read_bits(1)
	jc .ret
	shr ax, 1		; returned == 0 ?
	jc .end			; no, end of loop -->
	add dx, 1
	adc bx, 0		; ++gamma
	jmp .loop
.end:
	clc			; indicate not error
.ret:
	retn


		; INP:	bx:dx = offset
		; OUT:	CY if error
		;	NC if success,
		;	 al = byte read from decompressed data
		; CHG:	-
		; STT:	bp -> depack stack frame
read_byte_from_window:
	push ds
	push si
	push bx
	push cx
	mov cx, dx
        neg bx
        neg cx
        sbb bx, byte 0          ; neg bx:cx
	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
	call normalise_pointer_with_displacement_bxcx
	 pop cx
	 pop bx

	cmp word [bp + ?original_dst + 2], bx
				; is source of matching within ?dst ?
d0	mov byte [bp + ?errordata], 16h
	ja .error
	jb @F
	cmp word [bp + ?original_dst], cx
d0	mov byte [bp + ?errordata], 17h
	ja .error		; no, ?original_dst is above it -->
@@:

	mov si, cx
	mov ds, bx
	lodsb

	db __TEST_IMM8		; (NC)
.error:
	stc
	pop cx
	pop bx
	pop si
	pop ds
	retn


		; INP:	al = byte to write to decompressed data
		; OUT:	CY if error
		;	NC if success
		;	Instead of returning, this may jump to depack.end
		;	 if the destination segment grows up to the value
		;	 stored in the ?dst_max_segment variable. It is
		;	 assumed that this will use the stack frame to leave
		;	 the function, therefore discarding any of the stack
		;	 contents between the frame and the stack top.
		; CHG:	-
		; STT:	bp -> depack stack frame
write_byte:
	sub word [bp + ?dst_remaining], 1
	sbb word [bp + ?dst_remaining + 2], 0
	jc .ret
	push es
	push di
	les di, [bp + ?dst]
	stosb
	 push es
	 push di
	call normalise_pointer
	 pop word [bp + ?dst]
	 pop di				; ! this is the *segment*
	 mov word [bp + ?dst + 2], di
	cmp di, word [bp + ?dst_max_segment]
	jae depack.end

	pop di
	pop es
	clc
.ret:
	retn


read_write_byte:
	call read_byte
	jc .ret
	call write_byte
.ret:
	retn
