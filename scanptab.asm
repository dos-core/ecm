scan_partitions:
	and word [load_partition_cycle], 0
d4	call init1_d4message
d4	asciz "In scan_partitions",13,10

	push bp
	mov bx, sp
	xor di, di
	push di		; [ss:bx+di-2]
	push di		; [ss:bx+di-4]
	push di		; [ss:bx+di-6]
	push di		; [ss:bx+di-8]

	cmp byte [load_unit], 80h
	jae @F

	push di
	push cx
	 push cs
	 pop es
	mov di, parttable
	xor ax, ax
	mov cx, (4 * 16) >> 1
	rep stosw			; initialise fake partition table
	pop cx
	pop di
	mov si, parttable		; -> fake PARTINFO
	mov byte [es:si + piBoot], 80h	; fake primary active
	mov byte [es:si + piType], 0FFh	; fake a type
	mov byte [load_current_partition], 0	; special: 0 = diskette
					; piLength is 0, too
	call cx

	jmp scan_logical.end


@@:
	xor ax, ax
	xor dx, dx
d4	call init1_d4message
d4	asciz "In scan_partitions (before first call to read_partition_table)",13,10
	call read_partition_table
d4	call init1_d4message
d4	asciz "In scan_partitions (after first call to read_partition_table)",13,10
	mov si, parttable
	mov byte [load_current_partition], dl	; = 0
.loop_primary_parts:
	inc byte [load_current_partition]
	cmp byte [es:si + piType], 0
	je .loop_primary_skip
	call cx			; es:si -> partition table entry
				; byte [load_current_partition] = which
.loop_primary_skip:
	add si, 16
	cmp si, parttable.end
	jb .loop_primary_parts

scan_logical:
.:
d4	call init1_d4message
d4	asciz "In scan_logical.",13,10
	mov si, parttable
.loop:
	inc word [load_partition_cycle]
	jz .got_partition_cycle

	mov al, [es:si + piType]

	test al, al
	jz .next
	cmp al, 0Fh		; extended partition (LBA aware) ?
	je .push		; yes -->
	and al, ~80h		; extended partition Linux (85h) ?
	cmp al, 05h		;  or extended partition DOS (05h) ?
	je .push		; yes -->

	cmp word [ss:bx+di-2], 0
	jne .logical
	cmp word [ss:bx+di-4], 0
	je .next
.logical:
	inc byte [load_current_partition]
	jz .error_too_many_partitions
	call cx			; CHG: ax, (cx), dx
				; preserve: (cx), si, di, bx, ds, es
.next:
	add si, 16		; -> next partition table entry
	cmp si, parttable.end	; was last?
	jb .loop		; no, loop -->
	test di, di		; still some on stack?
	jnz .pop		; yes, pop
.end:
	mov sp, bx		; restore sp
	pop ax			; (discard dummy bp value)
	retn			; and bye

.push:
d4	call init1_d4message
d4	asciz "In scan_logical.push",13,10

	push si
.push_check_empty_next:
	add si, 16		; -> next
	cmp si, parttable.end	; at end?
	jae .replace		; yes, no other partitions found, replace -->
	cmp byte [es:si + piType], 0	; is this a partition?
	je .push_check_empty_next	; no, check next -->
				; found a partition after this, do push
				; (possibly logical or another extended)
.push_check_is_not_empty:
d4	call init1_d4message
d4	asciz "In scan_logical.push_check_is_not_empty",13,10
	pop si			; restore -> partition table entry
	push si			; stored at word [ss:bx+di-10]
	sub di, 10
	push word [ss:bx+di+10-2]
	push word [ss:bx+di+10-4]	; copy root

	mov ax, word [es:si + piStart]
	mov dx, word [es:si + piStart + 2]	; get extended partition offset
	add ax, word [ss:bx+di-4]
	adc dx, word [ss:bx+di-2]	; add in root to get absolute sector number

	push dx
	push ax			; new base

.replace_common:
	cmp word [ss:bx+di-2], 0	; have a (nonzero) root?
	jne .have_root
	cmp word [ss:bx+di-4], 0
	jne .have_root		; yes -->

	mov word [ss:bx+di-2], dx
	mov word [ss:bx+di-4], ax	; set root
.have_root:

	call read_partition_table
	jmp .

.pop:
d4	call init1_d4message
d4	asciz "In scan_logical.pop",13,10

	add di, 10
	add sp, 8
	pop si

	mov ax, word [ss:bx+di-8]
	mov dx, word [ss:bx+di-6]
	call read_partition_table
	jmp .next

.replace:
d4	call init1_d4message
d4	asciz "In scan_logical.replace",13,10

	pop si				; (discard)
	mov ax, word [es:si + piStart]
	mov dx, word [es:si + piStart + 2]	; get extended partition offset
	add ax, word [ss:bx+di - 4]
	adc dx, word [ss:bx+di - 2]	; add in root
	mov word [ss:bx+di - 8], ax
	mov word [ss:bx+di - 6], dx	; set base

	jmp .replace_common

.got_partition_cycle:
	mov dx, msg.boot_partition_cycle_error
	jmp bootcmd.fail

.error_too_many_partitions:
	mov dx, msg.boot_too_many_partitions_error
	jmp bootcmd.fail


read_partition_table:
	push bx
	mov bx, word [bp + ldSectorSeg]
	call read_ae_512_bytes
	pop bx
	cmp word [es:510], 0AA55h
	jne @F
	 push ds
	 push di
	 push si
	 push cx
	push es
	pop ds
	mov si, 510 - 4*16		; ds:si -> partition table in sectorseg
	push cs
	pop es
	mov di, parttable		; es:di -> cs:parttable
	mov cx, 4*16 / 2
	rep movsw
	 pop cx
	 pop si
	 pop di
	 pop ds
	retn

@@:
	mov dx, msg.bootfail_sig_parttable
	jmp bootcmd.fail
