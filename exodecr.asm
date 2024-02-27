
%if 0

8086 Assembly lDOS iniload payload exomizer raw depacker
 by E. C. Masloch, 2020

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

%endif

	numdef P, 7, 7
%if _P > 63
 %error Too large P value, not supported
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
	xor bx, bx
 %if _DEBUG0
	lvar word,	errordata
	 push bx
 %endif
	lvar word, bit_buffer_and_counter
	lequ ?bit_buffer_and_counter, bit_buffer
	lequ ?bit_buffer_and_counter + 1, counter
	 push bx		; initialise counter (high byte) to zero
				; if _P & 8: initialise bit_buffer to zero
%if _P & 32
	lvar dword, offset
	 push bx
	 push bx
	lvar word, reuse_offset_state_and_RCL_carry_in
	lequ ?reuse_offset_state_and_RCL_carry_in, reuse_offset_state
	inc bx			; = 1
	 push bx
%endif

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
	jc .error_CY_8		; should not carry
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
d0	mov byte [bp + ?errordata], 1Bh
	jc .error_CY_8
%endif

	lequ fromwords(words(16 * exo_table_entry_size)), 16tablesize
	lvar ?16tablesize, lengths
%if _P & 16
	lvar ?16tablesize, offsets4
%endif
	lvar ?16tablesize, offsets3
	lvar ?16tablesize, offsets2
	lequ fromwords(words(4 * exo_table_entry_size)), 4tablesize
	lvar ?4tablesize, offsets1
	lreserve

%ifn _P & 8
	call read_byte_to_bit_buffer
d0	mov byte [bp + ?errordata], 30h
	jc .error_CY_8
%endif

	mov di, ?lengths
	call generate_table_16
d0	mov byte [bp + ?errordata], 41h
.error_CY_8:
	jc .error_CY_7
%if _P & 16
	mov di, ?offsets4
	call generate_table_16
d0	mov byte [bp + ?errordata], 49h
	jc .error_CY_7
%endif
	mov di, ?offsets3
	call generate_table_16
d0	mov byte [bp + ?errordata], 42h
	jc .error_CY_7
	mov di, ?offsets2
	call generate_table_16
d0	mov byte [bp + ?errordata], 43h
	jc .error_CY_7
	mov di, ?offsets1
	mov cl, 4
	call generate_table_cx		; cx = 0 if NC
d0	mov byte [bp + ?errordata], 44h
	jc .error_CY_7

%ifn _P & 4
	jmp .STATE_NEXT_BYTE
%endif

		; cx = 0
.STATE_IMPLICIT_FIRST_LITERAL_BYTE:
		; ! cx = 0
		; All paths to this label must have cx = 0.
.literal:
	inc cx				; cx = 1
.STATE_NEXT_LITERAL_BYTE_increment_counter:
	lds si, [bp + ?src]
	sub word [bp + ?src_remaining], cx
	sbb word [bp + ?src_remaining + 2], 0
d0	mov byte [bp + ?errordata], 45h
.error_CY_7:
	jc .error_CY_6
	call copy_data
d0	mov byte [bp + ?errordata], 46h
	jc .error_CY_6
	mov word [bp + ?src], si
	mov word [bp + ?src + 2], ds
%if _P & 32
	stc
.STATE_NEXT_BYTE_rcl:
	rcl byte [bp + ?reuse_offset_state], 1
%endif

	; jmp .STATE_NEXT_BYTE

.STATE_NEXT_BYTE:
%if _COUNTER
	inc byte [bp + ?counter]
	test byte [bp + ?counter], _COUNTER - 1
	jnz @F
	mov al, '.'
	call disp_al_counter
@@:
%endif
	call read_bits_1		; cx = 0 if NC
d0	mov byte [bp + ?errordata], 32h
.error_CY_6:
	jc .error_CY_5
	test ax, ax
	jnz .literal			; (cx = 0 still)

		; cx = ax = 0
.not_literal:

	; call get_gamma_code
		; INP:	-
		; OUT:	CY if error
		;	NC if success,
		;	 bx:dx = gamma
		;	 ax = cx = 0
		; CHG:	ds, si
		; STT:	bp -> depack stack frame
		;	UP
.get_gamma_code:
	xor dx, dx
	xor bx, bx		; bx:dx = gamma = 0
.ggc_loop:
		; cx = 0. ax = 0 initially, else = 1
	add dx, ax
	adc bx, cx		; ++gamma (except initially)
	call read_bits_1	; read_bits(1)
d0	mov byte [bp + ?errordata], 33h
.error_CY_5:
	jc .error_CY_4
	xor al, 1		; returned == 0 ?
	jnz .ggc_loop		; yes, loop --> (ax = 1 if looping)
				; no, end of loop

	test bx, bx		; (NC)
d0	mov byte [bp + ?errordata], 34h
	jnz .error_NC_1		; (! NC)
	cmp dx, 17
	jne .not_literal_data_block
.literal_data_block:
%if _P & 2
	call read_byte
d0	mov byte [bp + ?errordata], 35h
	jc .error_CY_4
	mov ah, al
	call read_byte
d0	mov byte [bp + ?errordata], 36h
	jc .error_CY_4
%else
	mov cx, 16
	call read_bits
d0	mov byte [bp + ?errordata], 48h
	jc .error_CY_4
%endif
	xchg ax, cx
	jmp .STATE_NEXT_LITERAL_BYTE_increment_counter

.not_literal_data_block:
	cmp dx, 16
	je .end_check
d0	mov byte [bp + ?errordata], 38h
	ja .error_A_1

.sequence:
	mov di, dx
	add dx, dx
	add di, dx		; * 3 = * exo_table_entry_size

	mov bx, word [bp + ?lengths + di + eteBase]
	; xor cx, cx		; cx = 0 already after get_gamma_code NC
	mov cl, byte [bp + ?lengths + di + eteBits]
	call read_bits		; cx = 0 if NC
d0	mov byte [bp + ?errordata], 39h
.error_CY_4:
	jc .error_CY_3
	add bx, ax		; bx = length

%if _P & 32
	mov al, byte [bp + ?reuse_offset_state]
	and al, 3
	cmp al, 1
	jne @F
	call read_bits_1
d0	mov byte [bp + ?errordata], 4Ch
	jc .error_CY_3
	dec ax			; = -1 if was 0, = 0 if was 0
	jnz @F			; jump if now -1, ie was 0
	mov cx, bx
	mov dx, word [bp + ?offset]
	mov bx, word [bp + ?offset + 2]
	jmp .use_prior_offset
@@:
%endif

	test bx, bx
	jz .switch_default
%ifn _P & 16
	cmp bx, 2
	je .switch_case2
	ja .switch_default
%else
	cmp bx, 4
	jae .switch_default
	cmp bl, 2
	je .switch_case2
	; jb .switch_case1
	ja .switch_case3
%endif
.switch_case1:
	mov cl, 2		; cx = 2
	mov dx, ?offsets1
d0	mov byte [bp + ?errordata], 3Ah
	jmp .switch_common

.switch_case2:
	mov dx, ?offsets2
d0	mov byte [bp + ?errordata], 3Bh
	jmp .switch_common_cl_4

%ifn _P & 16
.switch_default:
	mov dx, ?offsets3
d0	mov byte [bp + ?errordata], 3Ch
%else
.switch_case3:
	mov dx, ?offsets3
d0	mov byte [bp + ?errordata], 4Ah
	jmp .switch_common_cl_4

.switch_default:
	mov dx, ?offsets4
d0	mov byte [bp + ?errordata], 4Bh
%endif
	; jmp .switch_common_cl_4

.switch_common_cl_4:
	mov cl, 4		; cx = 4

.switch_common:
	call read_bits
.error_CY_3:
	jc .error_CY_2
				; ax = next index, dx -> next table
	mov di, ax
	add ax, ax
	add di, ax		; di = offset into table
	add di, dx		; -> table entry
	; xor cx, cx		; cx already = 0 after read_bits NC
	mov cl, byte [bp + di + eteBits]
	call read_bits		; leaves cx = 0 if NC
d0	mov byte [bp + ?errordata], 3Dh
.error_CY_2:
	jc .error_CY_1
	xchg cx, bx		; cx = length that we remembered in bx
				; bx = 0
	xchg dx, ax		; bx:dx = read bits

	add dx, word [bp + di + eteBase]
	adc bx, bx		; bx:dx = offset

	; test bx, bx		; offset 0 ?
	jnz @F			; no -->
	test dx, dx		; offset 0 ?
d0	mov byte [bp + ?errordata], 3Eh
.error_ZR_1:
	jz .error		; yes, invalid -->
@@:

%if _P & 32
	mov word [bp + ?offset], dx
	mov word [bp + ?offset + 2], bx

.use_prior_offset:
%endif
	push cx
	mov cx, dx
        neg bx
        neg cx
        sbb bx, byte 0          ; neg bx:cx
	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
	call normalise_pointer_with_displacement_bxcx
	 pop si
	 pop bx			; bx:si = pointer into decompressed data
	pop cx			; restore match length
d0	mov byte [bp + ?errordata], 47h
.error_NC_1:
	jnc .error

	cmp word [bp + ?original_dst + 2], bx
				; is source of matching within ?dst ?
d0	mov byte [bp + ?errordata], 16h
	ja .error_A_1
	jb @F
	cmp word [bp + ?original_dst], si
d0	mov byte [bp + ?errordata], 17h
.error_A_1:
	ja .error		; no, ?original_dst is above it -->
@@:
	mov ds, bx		; -> match source data
	call copy_data
d0	mov byte [bp + ?errordata], 3Fh
.error_CY_1:
	jc .error
				; NC
%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
d0	mov byte [bp + ?errordata], 1Ch
	jc .error
				; NC
%endif
%if _P & 32
	; clc			; (already NC)
	jmp .STATE_NEXT_BYTE_rcl
%else
	jmp .STATE_NEXT_BYTE
%endif

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
		; CHG:	ds, si
		; STT:	bp -> depack stack frame
		;	UP
read_byte:
	lds si, [bp + ?src]
	lodsb
	 push ds
	 push si
	call normalise_pointer
	 pop word [bp + ?src]
	 pop word [bp + ?src + 2]
	sub word [bp + ?src_remaining], 1
	sbb word [bp + ?src_remaining + 2], 0
	retn


		; as for read_byte
		; OUT:	CY if error
		;	NC if success,
		;	 ?bit_buffer
		; CHG:	al, ds, si
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
%if _P & 1
	rcl byte [bp + ?bit_buffer], 1
%else
	rcr byte [bp + ?bit_buffer], 1
%endif
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
		; CHG:	ds, si
		; STT:	bp -> depack stack frame
		;	UP
read_bits:
%if _P & 2
	cmp cx, 16		; CY if valid
%else
	cmp cx, 17		; CY if valid
%endif
	cmc			; NC if valid
	jc .ret			; if error --> (CY)
%if _P & 2
	mov al, cl
	mov ah, cl
	and ax, (8 << 8) | 7	; al = bit_count, ah = byte_copy
	mov cl, al		; cl = cx = bit_count
	mov al, 0		; al = bits
%else
	xor ax, ax		; ax = bits
%endif
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
%if _P & 2
	rcl al, 1		; bits <<= 1; bits |= carry;
%else
	rcl ax, 1
%endif
	loop .loop
.end:
%if _P & 2
	test ah, ah		; NC
	jz .byte_copy_zero	; (NC)
	mov ah, al		; bits <<= 8;
	call read_byte		; bits |= read_byte()
				; pass CF to caller
.byte_copy_zero:		; ax = bits
%endif
.ret:
	retn


generate_table_16:
	mov cx, 16
		; INP:	cx = amount of table entries
		;	bp + di -> start of table
		; OUT:	CY if error
		;	NC if success,
		;	 cx = 0
		; CHG:	ax, bx, di, ds, si
		; STT:	bp -> depack stack frame
		;	UP
generate_table_cx:
	mov bx, 1
.loop:
	mov word [bp + di + eteBase], bx
	push cx
%if _P & 2
	mov cx, 3
	call read_bits
	jc .ret_pop
	mov byte [bp + di + eteBits], al
	mov cl, 1
	call read_bits
	jc .ret_pop
	shl al, 1
	shl al, 1
	shl al, 1
	or byte [bp + di + eteBits], al
	mov ax, 1
	mov cl, byte [bp + di + eteBits]
%else
	mov cx, 4
	call read_bits
	jc .ret_pop
	mov byte [bp + di + eteBits], al
	mov cl, al
	mov ax, 1
%endif
	shl ax, cl
	add bx, ax
	pop cx
	add di, exo_table_entry_size
	loop .loop
	db __TEST_IMM8		; (skip pop, NC)
.ret_pop:
	pop cx
	retn


		; INP:	ds:si -> data (normalised and in bounds)
		;	?dst (normalised), ?dst_remaining
		;	cx = number of bytes (entire range valid)
		; OUT:	CY if error (destination exhausted)
		;	NC if success,
		;	 ds:si -> behind copied source (normalised)
		;	 ?dst -> behind copied destination (normalised)
		;	 ?dst_remaining decremented
		;	 ax = cx = 0
		;	Instead of returning, this may jump to depack.end
		;	 if the destination segment grows up to the value
		;	 stored in the ?dst_max_segment variable. It is
		;	 assumed that this will use the stack frame to leave
		;	 the function, therefore discarding any of the stack
		;	 contents between the frame and the stack top.
		; CHG:	es, di
		; STT:	bp -> depack stack frame
		;	UP
copy_data:
d0	inc byte [bp + ?errordata + 1]

	sub word [bp + ?dst_remaining], cx
	sbb word [bp + ?dst_remaining + 2], 0
	jc .ret
	les di, [bp + ?dst]

	xor ax, ax			; initialise second step length
	cmp cx, 0FFF0h			; can copy in one step ?
	jbe @F				; yes -->
	mov al, cl
	and al, 15			; second step length
	mov cl, 0F0h			; maximum first step = 0FFF0h
	rep movsb			; move first step of two steps
	call normalise_both_pointers	; normalise pointers after
	xchg ax, cx			; cx = second step length
@@:
	rep movsb			; move last step
	call normalise_both_pointers	; normalise (again)
	mov word [bp + ?dst], di
	mov word [bp + ?dst + 2], es	; store to ?dst
%if _PAYLOAD_KERNEL_MAX_PARAS
	mov di, es			; ! this is the *segment*
	cmp di, word [bp + ?dst_max_segment]
	jae depack.end
%endif
	clc
.ret:
	retn
