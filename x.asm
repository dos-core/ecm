
%if 0

MIT License

Copyright (c) 2020 David Barina

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

%endif

	struc CONTEXT_TABLE
ctFreq:		resw 256
ctFreq_size:	equ 2
ctSorted:	resb 256
ctOrder:	resb 256
	endstruc

CONTEXTSIZE equ CONTEXT_TABLE_size * 256
RESET_INTERVAL equ 256
%assign ADDITIONAL_MEMORY CONTEXTSIZE + 16384
	; 16384 is the layer threshold memory


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
	lvar dword,	bit_buffer
	lvar word,	bit_counter
	lvar word,	layers
	lvar word,	opt_k
	lvar word,	sum_delta
	lvar word,	global_N
	lvar dword,	context
	lenter

	call normalise_both_pointers

	lvar dword,	src
	 push ds
	 push si
	lvar dword,	src_remaining
	 push dx
	 push cx

	mov bx, dx		; bx:cx = length of source
	 push ds
	 push si
	lvar dword,	src_top
	call normalise_pointer_with_displacement_bxcx
	and byte [bp + ?src_top], 0F0h
				; round down to paragraph boundary

	lvar dword,	table
	lequ ?table,	final_dst
	 push es
	 push di

	mov cx, CONTEXTSIZE & 0FFFFh
	mov bx, CONTEXTSIZE >> 16
	 push es
	 push di
	call normalise_pointer_with_displacement_bxcx
	 pop di
	 pop es

	lvar dword,	original_dst
	 push es
	 push di
	lvar dword,	dst
	 push es
	 push di

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
		; (Only if ?layers is equal to 1 this should be checked.)
d0	mov byte [bp + ?errordata], 80h
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

%if _ALLOW_OVERLAPPING && 0
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
d0	mov byte [bp + ?errordata], 81h
	jb .error		; source linear is below destination linear -->

	lvar dword,	dst_remaining
	 push bx		; push into [bp + ?dst_remaining + 2]
	 push cx		; push into [bp + ?dst_remaining]

	; add cx, CONTEXTSIZE & 0FFFFh
	; adc bx, CONTEXTSIZE >> 16

	; lvar dword,	final_dst_remaining
	;  push bx
	;  push cx

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
		; Note:	We initially check here that the write pointer is
		;	 low enough, ie below-or-equal the read pointer.
		;	 Doing this check here (as well as after any
		;	 copied match) allows us to drop the check done
		;	 after moving literal bytes.
d0	mov byte [bp + ?errordata], 82h
	jc .error
%endif

	xor ax, ax
	mov bx, .lodsb
	call x_func_bx_with_src
d0	mov byte [bp + ?errordata], 83h
	jc .error
	mov word [bp + ?layers], ax
	test al, al
	jnz .not_zero_layers
.zero_layers:
	lds si, [bp + ?src]
	mov bx, [bp + ?src_remaining + 2]
	mov ax, [bp + ?src_remaining]

		; ds:si -> data
		; bx:ax = length of data
.final:
	les di, [bp + ?final_dst]

	; sub word [bp + ?final_dst_remaining], ax
	; sbb word [bp + ?final_dst_remaining + 2], bx
	; jc .error

	mov cx, 4
	add ax, 15
	adc bx, 0
@@:
	shr bx, 1
	rcr ax, 1
	loop @B
	mov cx, ax
	test bx, bx
d0	mov byte [bp + ?errordata], 84h
	jnz .error

	call x_mov_p

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


.not_zero_layers:
.layer_loop:
		; original_dst -> start of destination, same as dst
		; dst -> destination
		; src -> source
		; src_remaining = length of source
		; dst_remaining = length of destination
		; layers = how often to iterate
		; final_dst = final destination (in front of dst)

		; Initialise context tables
	lds si, [bp + ?table]
	xor ax, ax
	mov word [bp + ?opt_k], 3
	mov word [bp + ?sum_delta], ax
	mov word [bp + ?global_N], ax
	mov word [bp + ?bit_counter], 32

	mov cx, 256
.init_loop_outer:
	xor ax, ax
.init_loop_inner:
	mov bx, ax

	mov byte [si + ctSorted + bx], al
	mov byte [si + ctOrder + bx], al

	add bx, bx
	and word [si + ctFreq + bx], 0
%if ctFreq_size != 2
 %error Assuming ctFreq size is 2
%endif
	inc ax
	test ah, ah		; ax == 256 ?
	jz .init_loop_inner	; not yet -->
	add si, CONTEXT_TABLE_size
d0	mov byte [bp + ?errordata], 85h
	jc .error
	 push ds
	 push si
	call normalise_pointer
	 pop si
	 pop ds			; normalise, as the whole table is > 64 KiB
	loop .init_loop_outer	; loop for 256 CONTEXT_TABLE tables

	mov ax, ds
	cmp ax, word [bp + ?dst + 2]
d0	mov byte [bp + ?errordata], 86h
	jne .error
	cmp si, word [bp + ?dst]
d0	mov byte [bp + ?errordata], 87h
	jne .error

	push word [bp + ?table + 2]
	push word [bp + ?table]
	pop word [bp + ?context]
	pop word [bp + ?context + 2]

.decompress_loop:
d0	inc byte [bp + ?errordata + 1]
	mov ax, word [bp + ?opt_k]
	call bio_read_gr	; dx:ax = d
	jc .error

	test dx, dx
d0	mov byte [bp + ?errordata], 88h
	jnz .error
	cmp ax, 256		; d == 256 ?
	je .decompress_end	;	break;
d0	mov byte [bp + ?errordata], 89h
	ja .error		; error if > 256 -->

	lds si, [bp + ?context]
	mov bx, ax		; bx = d
	mov al, byte [si + ctSorted + bx]
				; c = context->sorted[d]
	les di, [bp + ?dst]
	sub word [bp + ?dst_remaining], 1
	sbb word [bp + ?dst_remaining + 2], 0
d0	mov byte [bp + ?errordata], 8Ah
	jc .error

	stosb			; *optrc = c
	 push es
	 push di
	call normalise_pointer
	 pop word [bp + ?dst]
	 pop word [bp + ?dst + 2]

	push ax			; push c
	push bx			; push d
				; ax = c
	call increment_frequency; increment_frequency(context, c)

	pop ax			; ax = d
	jc @F
	call update_model	; update_model(d)
@@:
	pop ax			; ax = c
	jc .error
	mov bx, CONTEXT_TABLE_size
	mul bx			; index into array of CONTEXT_TABLE
	mov bx, dx
	mov cx, ax
	 push word [bp + ?table + 2]
	 push word [bp + ?table]
	call normalise_pointer_with_displacement_bxcx
	 pop word [bp + ?context]
	 pop word [bp + ?context + 2]
	jmp .decompress_loop

.decompress_end:
	lds si, [bp + ?original_dst]
	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
	call pointer_to_linear

	mov bx, dx
	mov cx, ax		; bx:cx = dst linear

	 push ds
	 push si
	call pointer_to_linear
	sub cx, ax
	sbb bx, dx		; bx:cx = length of dst
	mov ax, cx		; bx:ax = length of dst

	dec word [bp + ?layers]
	jz .final		; if it was the last layer -->

	mov word [bp + ?src_remaining + 2], bx
	mov word [bp + ?src_remaining], cx
				; set up new source

	add cx, 15
	adc bx, 0
	and cl, 0F0h		; round up to paragraph
	push bx
	push cx

	 push word [bp + ?src_top + 2]
	 push word [bp + ?src_top]
        neg bx
        neg cx
        sbb bx, byte 0          	; neg bx:cx
	call normalise_pointer_with_displacement_bxcx
	 pop di
	 pop es
	mov word [bp + ?src + 2], es
	mov word [bp + ?src], di

	pop ax
	pop bx
	mov cx, 4
@@:
	shr bx, 1
	rcr ax, 1
	loop @B			; convert to paragraphs
	mov cx, ax
	test bx, bx
d0	mov byte [bp + ?errordata], 8Bh
	jnz .error

	call x_mov_p		; move prior layer's data to source

	push word [bp + ?original_dst + 2]
	push word [bp + ?original_dst]
	pop word [bp + ?dst]
	pop word [bp + ?dst + 2]; reset dst

	 push word [bp + ?src + 2]
	 push word [bp + ?src]
	call pointer_to_linear

	mov bx, dx
	mov cx, ax		; bx:cx = source linear

	 push word [bp + ?dst + 2]
	 push word [bp + ?dst]
	call pointer_to_linear

%if _ALLOW_OVERLAPPING && 0
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
d0	mov byte [bp + ?errordata], 8Ch
	jb .error		; source linear is below destination linear -->

	mov [bp + ?dst_remaining + 2], bx
	mov [bp + ?dst_remaining], cx

%if _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
		; Note:	We initially check here that the write pointer is
		;	 low enough, ie below-or-equal the read pointer.
		;	 Doing this check here (as well as after any
		;	 copied match) allows us to drop the check done
		;	 after moving literal bytes.
d0	mov byte [bp + ?errordata], 8Dh
	jc .error
%endif

	jmp .layer_loop


		; INP:	ds:si -> source data
		;	?src_remaining
		; OUT:	CY if error (source buffer too small)
		;	NC if success,
		;	 al = value read
		;	 ds:si incremented (NOT normalised)
		;	 ?src_remaining decremented
.lodsb:
	sub word [bp + ?src_remaining], 1
	sbb word [bp + ?src_remaining + 2], 0
	jb .retn
	lodsb
.retn:
	retn


		; INP:	ds:si -> source data
		;	?src_remaining
		; OUT:	CY if error (source buffer too small)
		;	NC if success,
		;	 ax = value read
		;	 ds:si incremented (NOT normalised)
		;	 ?src_remaining decremented
.lodsw:
	sub word [bp + ?src_remaining], 2
	sbb word [bp + ?src_remaining + 2], 0
	jb .retn
	lodsw
	retn


		; INP:	ds:si -> source data
		;	?src_remaining
		; OUT:	CY if error (source buffer too small)
		;	NC if success,
		;	 dx:ax = value read
		;	 ds:si incremented (NOT normalised)
		;	 ?src_remaining decremented
.lodsd_dxax:
	sub word [bp + ?src_remaining], 4
	sbb word [bp + ?src_remaining + 2], 0
	jb .retn
	lodsw
	xchg dx, ax
	lodsw
	xchg dx, ax
	retn


		; INP:	ax = c
		;	ds:si = ?context -> context table
		; CHG:	ax, bx, cx, dx, di
increment_frequency:
	mov bx, ax
	xor cx, cx
	mov cl, byte [si + ctOrder + bx]
				; ic = context->order[c]
%if ctFreq_size != 2
 %error Unexpected ctFreq size
%endif
	add bx, bx
	inc word [si + ctFreq + bx]
	mov dx, word [si + ctFreq + bx]
				; freq_c
	mov bx, cx
	add bx, ctSorted - 1	; pd = context->sorted + ic - 1

.loop:
	cmp bx, ctSorted
	jb .end

	push bx
	mov bl, byte [si + bx]
	mov bh, 0
%if ctFreq_size != 2
 %error Unexpected ctFreq size
%endif
	add bx, bx
	cmp dx, word [si + ctFreq + bx]
	pop bx
	jbe .end

	dec bx
	jmp .loop

.end:
	xor dx, dx
	mov dl, [si + bx + 1]

	cmp ax, dx
	je .ret				; (NC if jumping)

		; ax = c
		; dx = d
	mov bx, ax
	xor cx, cx
	mov cl, byte [si + ctOrder + bx]
		; cx = ic
	mov bx, dx
	mov di, word [si + ctOrder + bx]
	and di, 0FFh
		; di = id

	mov bx, cx
	cmp al, byte [si + ctSorted + bx]
d0	mov byte [bp + ?errordata], 8Eh
	jne .error			; context->sorted[ic] == c ?
	mov bx, di
	cmp dl, byte [si + ctSorted + bx]
d0	mov byte [bp + ?errordata], 8Fh
	jne .error			; context->sorted[id] == d ?

		; bx = id
	mov byte [si + ctSorted + bx], al
					; sorted[id] = c
	mov bx, cx
		; bx = ic
	mov byte [si + ctSorted + bx], dl
					; sorted[ic] = d

	mov bx, dx
		; bx = d
	mov byte [si + ctOrder + bx], cl
					; order[d] = ic
	mov bx, ax
		; bx = c
	xchg ax, di			; ax = id
	mov byte [si + ctOrder + bx], al
					; order[c] = id

	db __TEST_IMM8			; (NC)
.error:
	stc
.ret:
	retn


		; INP:	ax = delta
		; CHG:	bx, cx
update_model:
	cmp word [bp + ?global_N], RESET_INTERVAL
	jb .notreset
d0	mov byte [bp + ?errordata], 90h
	ja .error

	mov bx, word [bp + ?global_N]
	; mov cx, 1
	; jmp .add
	xor cx, cx
.loop:
	inc cx
.add:
	add bx, bx		; = 64 Ki ?
	jz .end			; yes, next cmp \ ja would jump with
				;  larger registers, so jump here now
%if RESET_INTERVAL & (RESET_INTERVAL - 1)
 %error Unexpected reset interval not a power of two
%endif
%if (RESET_INTERVAL * 255) > 65535
 %error Unexpected reset interval and sum_delta maximum
%endif
	cmp bx, word [bp + ?sum_delta]
	; ja .end
	; jmp .loop
	jbe .loop

.end:
	dec cx
	mov word [bp + ?opt_k], cx
	and word [bp + ?sum_delta], 0
	and word [bp + ?global_N], 0

.notreset:
	add word [bp + ?sum_delta], ax
d0	mov byte [bp + ?errordata], 91h
	jc .error
	inc word [bp + ?global_N]
	db __TEST_IMM8		; (NC)
.error:
	stc
	retn


		; INP:	ax = n (0 .. 32)
		; OUT:	dx:ax = w
		; CHG:	bx, cx, ds, si, di
bio_read_bits:
	cmp word [bp + ?bit_counter], 32
	jne @F
	push ax
	call bio_reload_buffer	; CHG: ax, dx, ds, si
	pop ax
d0	mov byte [bp + ?errordata], 92h
	jc .error
@@:

	mov bx, 32
	sub bx, word [bp + ?bit_counter]

	push ax

	cmp bx, ax
	jb @F
	mov bx, ax		; bx = minsize(32 - bio->c, n)
@@:

	mov cx, bx
	call .get_sidi_1_shl_cx_and_bitbuffer
	mov dx, si
	mov ax, di

	mov cx, bx
	call .shr_bitbuffer_and_add_bitcounter_cx

	pop cx
	sub cx, bx
	jz .end

	cmp word [bp + ?bit_counter], 32
d0	mov byte [bp + ?errordata], 93h
	jne .error
	push dx
	push ax
	call bio_reload_buffer	; CHG: ax, dx, ds, si
	pop ax
	pop dx
d0	mov byte [bp + ?errordata], 94h
	jc .error

	push cx
	call .get_sidi_1_shl_cx_and_bitbuffer
	mov cx, bx
	jcxz @FF
@@:
	shl di, 1
	rcl si, 1
	loop @B
@@:
	or dx, si
	or ax, di

	pop cx
	call .shr_bitbuffer_and_add_bitcounter_cx

.end:
	db __TEST_IMM8		; (NC)
.error:
	stc
	retn


		; INP:	cx = how far to shift
		; OUT:	-
		; CHG:	cx
.shr_bitbuffer_and_add_bitcounter_cx:
	add word [bp + ?bit_counter], cx
	jcxz @FF
@@:
	shr word [bp + ?bit_buffer + 2], 1
	rcr word [bp + ?bit_buffer], 1
	loop @B
@@:
	retn


		; INP:	cx = how far to shift
		; OUT:	si:di = ( (1 << cx) - 1 ) & ?bit_buffer
		; CHG:	cx
.get_sidi_1_shl_cx_and_bitbuffer:
	mov di, 1
	xor si, si		; si:di = 1
	jcxz @FF
@@:
	shl di, 1
	rcl si, 1
	loop @B
@@:
	sub di, 1
	sbb si, 0
	and si, word [bp + ?bit_buffer + 2]
	and di, word [bp + ?bit_buffer]
	retn



		; INP:	-
		; OUT:	CF
		;	?bit_buffer
		;	?bit_counter
		; CHG:	ax, dx, ds, si
bio_reload_buffer:
	push bx
	mov bx, depack.lodsd_dxax
	call x_func_bx_with_src
	mov word [bp + ?bit_buffer], ax
	mov word [bp + ?bit_buffer + 2], dx
	and word [bp + ?bit_counter], 0
	pop bx
	retn


		; INP:	-
		; OUT:	CF
		;	dx:ax = total_zeros
		; CHG:	cx, bx, ds, si, di
bio_read_unary:
	xor bx, bx
	xor di, di		; bx:di = total_zeros = 0

.loop:
	cmp word [bp + ?bit_counter], 32
	jne @F
	call bio_reload_buffer	; CHG: ax, dx, ds, si
d0	mov byte [bp + ?errordata], 95h
	jc .error
@@:
	; count trailing zeros in bit_buffer
	mov dx, word [bp + ?bit_buffer + 2]
	mov ax, word [bp + ?bit_buffer]
	mov cx, ax
	or cx, dx		; zero ?
	mov cx, 32		; if zero, count 32 trailing zeros
	jz .ctz_done		; -->
	xor cx, cx
.ctz_loop:
	test al, 1		; lowest bit set ?
	jnz .ctz_done		; yes -->
	shr dx, 1
	rcr ax, 1		; shift down
	inc cx			; count trailing zeros
	jmp .ctz_loop
.ctz_done:
	mov ax, 32
	sub ax, word [bp + ?bit_counter]
				; ax = 32 - ?bit_counter
	cmp cx, ax
	jb @F
	mov cx, ax		; cx = minsize(32 - bio->c, ctzu32(bio->b))
@@:
	add word [bp + ?bit_counter], cx
	add di, cx
	adc bx, 0
	jcxz @FF
@@:
	shr word [bp + ?bit_buffer + 2], 1
	rcr word [bp + ?bit_buffer], 1
	loop @B
@@:

	cmp word [bp + ?bit_counter], 32
	je .loop
d0	mov byte [bp + ?errordata], 96h
	ja .error

	inc word [bp + ?bit_counter]
	shr word [bp + ?bit_buffer + 2], 1
	rcr word [bp + ?bit_buffer], 1
	mov dx, bx
	xchg ax, di		; dx:ax = total_zeros
	db __TEST_IMM8		; (NC)
.error:
	stc
	retn


		; INP:	ax = k
		; OUT:	dx:ax = (local) N
		; CHG:	bx, cx, ds, si, di
bio_read_gr:
	push ax
	call bio_read_unary	; dx:ax = Q
	pop cx
d0	mov byte [bp + ?errordata], 97h
	jc .error
	push cx
	jcxz @FF
@@:
	shl ax, 1
	rcl dx, 1
	loop @B
@@:
	mov bx, dx
	xchg cx, ax		; bx:cx = N = Q << k
	pop ax
	cmp ax, 32
d0	mov byte [bp + ?errordata], 98h
	ja .error
	push bx
	push cx
	call bio_read_bits
	pop cx
	pop bx
d0	mov byte [bp + ?errordata], 99h
	jc .error
	or ax, cx
	or dx, bx		; dx:ax = N |= bio_read_bits
				; (NC)
	retn

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
		;	?src_remaining
		;	(may take more inputs depending on function)
		; OUT:	ds:si incremented (NOT normalised)
		;	?src_remaining decremented
		;	CY if error (buffer too small or other error)
		;	NC if success
		;	(may give more outputs depending on function)
x_func_bx_with_src:
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


		; INP:	ds:si = pointer
		;	es:di = pointer
		; OUT:	ds:si anti normalised
		;	es:di anti normalised
anti_normalise_both_pointers:
	 push ds
	 push si
	call anti_normalise_pointer
	 pop si
	 pop ds

	 push es
	 push di
	call anti_normalise_pointer
	 pop di
	 pop es
	retn


		; INP:	word [ss:sp + 2] = segment
		;	word [ss:sp] = offset
		;
		; Note:	Does not work correctly with pointers that point to
		;	 a HMA location. Do not use then!
anti_normalise_pointer:
	lframe near, nested
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
	call anti_normalise_pointer_with_displacement_bxcx
	 pop word [bp + ?offset]
	 pop word [bp + ?segment]

	pop cx
	pop bx
	lleave
	lret


		; INP:	word [ss:sp + 2] = segment
		;	word [ss:sp] = offset
		;	bx:cx = add/sub displacement
		; OUT:	dword [ss:sp] = anti-normalised address
		;
		; An anti-normalised pointer has an offset as high as possible,
		;  which is in the range 0FFF0h to 0FFFFh unless the pointed-to
		;  location is in the first 64 KiB of memory.
anti_normalise_pointer_with_displacement_bxcx:
	lframe near, nested
	lpar word,	segment
	lpar word,	offset
	lpar_return
	lenter
	push ax
	push dx

	 push word [bp + ?segment]
	 push word [bp + ?offset]
	call pointer_to_linear

	add ax, cx
	adc dx, bx			; dx:ax += bx:cx

	cmp dx, 1
	jb @F

	push ax
	or ax, 0FFF0h
	mov word [bp + ?offset], ax
	pop ax

	sub ax, 0FFF0h
	sbb dx, 0

%rep 4
	shr dx, 1
	rcr ax, 1
%endrep
	mov word [bp + ?segment], ax

	jmp .return

		; dx:ax = 0000:offset
@@:
	mov word [bp + ?offset], ax
	and word [bp + ?segment], 0

.return:
	pop dx
	pop ax
	lleave
	lret


		; Move paragraphs
		;
		; INP:	ds:si -> source
		;	es:di -> destination
		;	cx = number of paragraphs
		; CHG:	ax, bx, cx, dx
		; OUT:	ds:si -> after source (normalised)
		;	es:di -> after destination (normalised)
		; Note:	Doesn't work correctly on HMA; doesn't always wrap to LMA either.
		;	Do not provide a wrapped/HMA source or destination!
x_mov_p:
	call normalise_both_pointers
	mov ax, ds
	mov dx, es

	test cx, cx
	jz .return

	cmp ax, dx		; source above destination ?
	ja .up			; yes, move up (forwards) -->
	jb .check_down

	cmp si, di
	ja .up
	je .return		; pointers are the same, no need to move -->
.check_down:
	push ax
	add ax, cx		; (expected not to carry)
	cmp ax, dx		; end of source is above destination ?
	pop ax
	ja .down		; yes, move from top down -->
	jb .up
	cmp si, di
	ja .down

	; Here, the end of source is below-or-equal the destination,
	;  so they do not overlap. In this case we prefer moving up.
.up:
.uploop:
	sub cx, 0FFFh		; 64 KiB - 16 B left ?
	jbe .uplast		; no -->
	push cx
	mov cx, 0FFF0h /2
	rep movsw		; move 64 KiB - 16 B
	pop cx
	call normalise_both_pointers
	jmp short .uploop	; proceed for more -->
.uplast:
	add cx, 0FFFh		; restore counter
	shl cx, 1
	shl cx, 1
	shl cx, 1		; *8, paragraphs to words
	rep movsw		; move last part
	jmp short .return

.down:
	std			; _AMD_ERRATUM_109_WORKAROUND as below

	mov ax, cx
	xor bx, bx
	push cx
	mov cx, 4
@@:
	shl ax, 1
	rcl bx, 1
	loop @B
	sub ax, 2
	sbb bx, 0		; -> point at last word
		; (Cannot borrow here because we checked that cx
		;  was nonzero at the intro to this function, so
		;  bx:ax is at least 16 prior to this subtraction.)
	xchg ax, cx		; bx:cx = displacement to point to last word
	 push ds
	 push si
	call anti_normalise_pointer_with_displacement_bxcx
	 pop si
	 pop ds			; -> last word of source
	 push es
	 push di
	call anti_normalise_pointer_with_displacement_bxcx
	 pop di
	 pop es			; -> last word of destination
	pop cx

.dnloop:
	sub cx, 0FFFh		; 64 KiB - 16 B left ?
	jbe .dnlast		; no -->
	push cx
	mov cx, 0FFF0h /2
	rep movsw		; move 64 KiB - 16 B
	pop cx
	call anti_normalise_both_pointers
	jmp short .dnloop	; proceed for more -->
.dnlast:
	add cx, 0FFFh		; restore counter
	shl cx, 1
	shl cx, 1
	shl cx, 1		; *8, paragraphs to words


	numdef AMD_ERRATUM_109_WORKAROUND, 1
%if 0

Jack R. Ellis pointed out this erratum:

Quoting from https://www.amd.com/system/files/TechDocs/25759.pdf page 69:

109   Certain Reverse REP MOVS May Produce Unpredictable Behavior

Description

In certain situations a REP MOVS instruction may lead to
incorrect results. An incorrect address size, data size
or source operand segment may be used or a succeeding
instruction may be skipped. This may occur under the
following conditions:

* EFLAGS.DF=1 (the string is being moved in the reverse direction).

* The number of items being moved (RCX) is between 1 and 20.

* The REP MOVS instruction is preceded by some microcoded instruction
  that has not completely retired by the time the REP MOVS begins
  execution. The set of such instructions includes BOUND, CLI, LDS,
  LES, LFS, LGS, LSS, IDIV, and most microcoded x87 instructions.

Potential Effect on System

Incorrect results may be produced or the system may hang.

Suggested Workaround

Contact your AMD representative for information on a BIOS update.

%endif

%if _AMD_ERRATUM_109_WORKAROUND
	jcxz @FF
	cmp cx, 20
	ja @FF
@@:
	movsw
	loop @B
@@:
%endif
	rep movsw		; move first part
	cld
.return:
	jmp normalise_both_pointers
