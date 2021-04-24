
; 8086 Assembly lDOS iniload payload LZSA2 depacker
;  by C. Masloch, 2021
;
;  based on:
;  decompress_small.S - space-efficient decompressor implementation for 8088
;
;  Copyright (C) 2019 Emmanuel Marty
;
;  This software is provided 'as-is', without any express or implied
;  warranty.  In no event will the authors be held liable for any damages
;  arising from the use of this software.
;
;  Permission is granted to anyone to use this software for any purpose,
;  including commercial applications, and to alter it and redistribute it
;  freely, subject to the following restrictions:
;
;  1. The origin of this software must not be misrepresented; you must not
;     claim that you wrote the original software. If you use this software
;     in a product, an acknowledgment in the product documentation would be
;     appreciated but is not required.
;  2. Altered source versions must be plainly marked as such, and must not be
;     misrepresented as being the original software.
;  3. This notice may not be removed or altered from any source distribution.


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
	lvar word,	counter
%if _COUNTER
	 push bx		; initialise counter (high byte) to zero
%endif
	lvar dword,	src_behind_block
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

%if 0
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

%if 0 && _ALLOW_OVERLAPPING
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

%if 0 && _ALLOW_OVERLAPPING
	call check_pointers_not_overlapping
		; Note:	We initially check here that the write pointer is
		;	 low enough, ie below-or-equal the read pointer.
		;	 Doing this check here (as well as after any
		;	 copied match) allows us to drop the check done
		;	 after moving literal bytes.
d0	mov byte [bp + ?errordata], 1Bh
	jc .error
%endif

	lodsw
	cmp ax, 7Bh | (9Eh << 8)	; signature
	jne .error
	lodsb
	cmp al, 1 << 5			; traits byte, check for lzsa2
	jne .error

.loop:
	call normalise_both_pointers

	xor dx, dx
	lodsw				; bits 0 to 15 of length
	mov bx, di
	add bx, ax			; fits in destination segment ?
	jc .error			;  (assuming bit 16 = 0)
	mov bx, si
	add bx, ax			; fits in source segment ?
	jc .error
	xchg ax, dx
	lodsb
	test al, 0111_1111b		; reserved bits + bit 16 of length
	jnz .error			; error if nonzero -->
	test al, al			; uncompressed ?
	xchg ax, dx
	jns .compressed			; no -->
.uncompressed:
	xchg ax, cx
	rep movsb			; copy this
	jmp .loop

.compressed:
	test ax, ax
	jz .end
	push ax
	push bp
	call lzsa2_decompress
	pop bp
	pop cx
	cmp cx, ax
	jne .error
	jmp .loop

.end:
	 push ds
	 push si
	call pointer_to_linear
	sub ax, word [bp + ?length_of_source]
	sbb dx, word [bp + ?length_of_source + 2]
	jc .error

	mov bx, dx
	mov cx, ax		; bx:cx = source linear

	 push word [bp + ?src + 2]
	 push word [bp + ?src]
	call pointer_to_linear

	cmp bx, dx
	jne .error
	cmp cx, ax
	jne .error

.ret:
	db __TEST_IMM8		; (skip stc, NC)
.error:
	stc

	lleave code
	lret


;  ---------------------------------------------------------------------------
;  Decompress raw LZSA2 block
;  inputs:
;  * ds:si: raw LZSA2 block
;  * es:di: output buffer
;  output:
;  * ax:    decompressed size
;  ---------------------------------------------------------------------------

lzsa2_decompress:
   push di                 ; remember decompression offset
   cld                     ; make string operations (lods, movs, stos..) move forward

   xor cx,cx
   mov bx,0100H
   xor bp,bp

.decode_token:
   mov ax,cx               ; clear ah - cx is zero from above or from after rep movsb in .copy_match
   lodsb                   ; read token byte: XYZ|LL|MMMM
   mov dx,ax               ; keep token in dl
   
   and al,018H             ; isolate literals length in token (LL)
   mov cl,3
   shr al,cl               ; shift literals length into place

   cmp al,03H              ; LITERALS_RUN_LEN_V2?
   jne .got_literals       ; no, we have the full literals count from the token, go copy

   call .get_nibble        ; get extra literals length nibble
   add al,cl               ; add len from token to nibble 
   cmp al,012H             ; LITERALS_RUN_LEN_V2 + 15 ?
   jne .got_literals       ; if not, we have the full literals count, go copy

   lodsb                   ; grab extra length byte
   add al,012H             ; overflow?
   jnc .got_literals       ; if not, we have the full literals count, go copy

   lodsw                   ; grab 16-bit extra length

.got_literals:
   xchg cx,ax
   rep movsb               ; copy cx literals from ds:si to es:di

   test dl,0C0h            ; check match offset mode in token (X bit)
   js .rep_match_or_large_offset

   ;;cmp dl,040H             ; check if this is a 5 or 9-bit offset (Y bit)
                           ; discovered via the test with bit 6 set
   xchg cx,ax              ; clear ah - cx is zero from the rep movsb above
   jne .offset_9_bit

                           ; 5 bit offset
   cmp dl,020H             ; test bit 5
   call .get_nibble_x
   jmp short .dec_offset_top

.offset_9_bit:             ; 9 bit offset
   lodsb                   ; get 8 bit offset from stream in A
   dec ah                  ; set offset bits 15-8 to 1
   test dl,020H            ; test bit Z (offset bit 8)
   je .get_match_length
.dec_offset_top:
   dec ah                  ; clear bit 8 if Z bit is clear
                           ; or set offset bits 15-8 to 1
   jmp short .get_match_length

.rep_match_or_large_offset:
   ;;cmp dl,0c0H             ; check if this is a 13-bit offset or a 16-bit offset/rep match (Y bit)
   jpe .rep_match_or_16_bit

                           ; 13 bit offset

   cmp dl,0A0H             ; test bit 5 (knowing that bit 7 is also set)
   xchg ah,al
   call .get_nibble_x
   sub al,2                ; substract 512
   jmp short .get_match_length_1

.rep_match_or_16_bit:
   test dl,020H            ; test bit Z (offset bit 8)
   jne .repeat_match       ; rep-match

                           ; 16 bit offset
   lodsb                   ; Get 2-byte match offset

.get_match_length_1:
   xchg ah,al
   lodsb                   ; load match offset bits 0-7

.get_match_length:
   xchg bp,ax              ; bp: offset
.repeat_match:
   xchg ax,dx              ; ax: original token
   and al,07H              ; isolate match length in token (MMM)
   add al,2                ; add MIN_MATCH_SIZE_V2

   cmp al,09H              ; MIN_MATCH_SIZE_V2 + MATCH_RUN_LEN_V2?
   jne .got_matchlen       ; no, we have the full match length from the token, go copy

   call .get_nibble        ; get extra literals length nibble
   add al,cl               ; add len from token to nibble 
   cmp al,018H             ; MIN_MATCH_SIZE_V2 + MATCH_RUN_LEN_V2 + 15?
   jne .got_matchlen       ; no, we have the full match length from the token, go copy

   lodsb                   ; grab extra length byte
   add al,018H             ; overflow?
   jnc .got_matchlen       ; if not, we have the entire length
   je short .done_decompressing ; detect EOD code

   lodsw                   ; grab 16-bit length

.got_matchlen:
   xchg cx,ax              ; copy match length into cx
   push ds                 ; save ds:si (current pointer to compressed data)
   xchg si,ax          
   push es
   pop ds
   lea si,[bp+di]          ; ds:si now points at back reference in output data
   rep movsb               ; copy match
   xchg si,ax              ; restore ds:si
   pop ds
   jmp .decode_token       ; go decode another token

.done_decompressing:
   pop ax                  ; retrieve the original decompression offset
   xchg di,ax              ; compute decompressed size
   sub ax,di
   ret                     ; done

.get_nibble_x:
   cmc                     ; carry set if bit 4 was set
   rcr al,1
   call .get_nibble        ; get nibble for offset bits 0-3
   or al,cl                ; merge nibble
   rol al,1
   xor al,0E1H             ; set offset bits 7-5 to 1
   ret

.get_nibble:
   neg bh                  ; nibble ready?
   jns .has_nibble
   
   xchg bx,ax
   lodsb                   ; load two nibbles
   xchg bx,ax

.has_nibble:
   mov cl,4                ; swap 4 high and low bits of nibble
   ror bl,cl
   mov cl,0FH
   and cl,bl
   ret
