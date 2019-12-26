
%if 0

scanptab - Scan partition table
 2019 by C. Masloch

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif

	; _SCANPTAB_PREFIX = prefix for our variables and functions
	; _SCANPTAB_DEBUG4_PREFIX = prefix for d4 function calls
	numdef PARTITION_TABLE_IN_CS, 1
	gendef BASE, ss:bx
%ifidn _BASE, ss:bx
%elifidn _BASE, bp
%else
 %error Invalid base
%endif


%[_SCANPTAB_PREFIX]scan_partitions:
	and word [ %[_SCANPTAB_PREFIX]load_partition_cycle], 0
d4	call %[_SCANPTAB_DEBUG4_PREFIX]d4message
d4	asciz "In scan_partitions",13,10

	push bp
%ifidn _BASE, ss:bx
	mov bx, sp
%elifidn _BASE, bp
	mov bp, sp
%endif
	xor di, di
	push di		; [_BASE+di-2]
	push di		; [_BASE+di-4]
	push di		; [_BASE+di-6]
	push di		; [_BASE+di-8]

	cmp byte [ %[_SCANPTAB_PREFIX]load_unit], 80h
	jae @F

	push di
	push cx
	 push cs
	 pop es
	mov di, %[_SCANPTAB_PREFIX]partition_table
	xor ax, ax
	mov cx, (4 * 16) >> 1
	rep stosw			; initialise fake partition table
	pop cx
	pop di
	mov si, %[_SCANPTAB_PREFIX]partition_table
					; -> fake PARTINFO
	mov byte [es:si + piBoot], 80h	; fake primary active
	mov byte [es:si + piType], 0FFh	; fake a type
	mov byte [ %[_SCANPTAB_PREFIX]load_current_partition], 0	; special: 0 = diskette
					; piLength is 0, too
	call cx

	jmp %[_SCANPTAB_PREFIX]scan_logical.end


@@:
	xor ax, ax
	xor dx, dx
d4	call %[_SCANPTAB_DEBUG4_PREFIX]d4message
d4	asciz "In scan_partitions (before first call to read_partition_table)",13,10
	call %[_SCANPTAB_PREFIX]read_partition_table
d4	call %[_SCANPTAB_DEBUG4_PREFIX]d4message
d4	asciz "In scan_partitions (after first call to read_partition_table)",13,10
	mov si, %[_SCANPTAB_PREFIX]partition_table
	mov byte [ %[_SCANPTAB_PREFIX]load_current_partition], dl	; = 0
.loop_primary_parts:
	inc byte [ %[_SCANPTAB_PREFIX]load_current_partition]
	cmp byte [es:si + piType], 0
	je .loop_primary_skip
	call cx			; es:si -> partition table entry
				; byte [load_current_partition] = which
.loop_primary_skip:
	add si, 16
	cmp si, %[_SCANPTAB_PREFIX]partition_table.end
	jb .loop_primary_parts

%[_SCANPTAB_PREFIX]scan_logical:
.:
d4	call %[_SCANPTAB_DEBUG4_PREFIX]d4message
d4	asciz "In scan_logical.",13,10
	mov si, %[_SCANPTAB_PREFIX]partition_table
.loop:
	inc word [ %[_SCANPTAB_PREFIX]load_partition_cycle]
	jz .got_partition_cycle

	mov al, [es:si + piType]

%ifidn _BASE, bp
	xor bx, bx
%endif
	test al, al
	jz .next
	cmp al, 0Fh		; extended partition (LBA aware) ?
	je .push		; yes -->
	and al, ~80h		; extended partition Linux (85h) ?
	cmp al, 05h		;  or extended partition DOS (05h) ?
	je .push		; yes -->

%ifidn _BASE, bp
	cmp word [_BASE+di-2], bx
	jne .logical
	cmp word [_BASE+di-4], bx
%else
	cmp word [_BASE+di-2], 0
	jne .logical
	cmp word [_BASE+di-4], 0
%endif
	je .next
.logical:
	inc byte [ %[_SCANPTAB_PREFIX]load_current_partition]
	jz .error_too_many_partitions
	call cx
		; CHG: ax, (cx), dx, bx if _BASE = bp
		; preserve: (cx), si, di, ds, es, bx if _BASE = ss:bx
.next:
	add si, 16		; -> next partition table entry
	cmp si, %[_SCANPTAB_PREFIX]partition_table.end
				; was last?
	jb .loop		; no, loop -->
	test di, di		; still some on stack?
	jnz .pop		; yes, pop
.end:
%ifidn _BASE, bp
	mov sp, bp		; restore sp
	pop bp
%else
	mov sp, bx		; restore sp
	pop ax			; (discard dummy bp value)
%endif
	retn			; and bye

.push:
d4	call %[_SCANPTAB_DEBUG4_PREFIX]d4message
d4	asciz "In scan_logical.push",13,10

	push si
.push_check_empty_next:
	add si, 16		; -> next
	cmp si, %[_SCANPTAB_PREFIX]partition_table.end
				; at end?
	jae .replace		; yes, no other partitions found, replace -->
	cmp byte [es:si + piType], 0	; is this a partition?
	je .push_check_empty_next	; no, check next -->
				; found a partition after this, do push
				; (possibly logical or another extended)
.push_check_is_not_empty:
d4	call %[_SCANPTAB_DEBUG4_PREFIX]d4message
d4	asciz "In scan_logical.push_check_is_not_empty",13,10
	pop si			; restore -> partition table entry
	push si			; stored at word [_BASE+di-10]
	sub di, 10
	push word [_BASE+di+10-2]
	push word [_BASE+di+10-4]	; copy root

	mov ax, word [es:si + piStart]
	mov dx, word [es:si + piStart + 2]	; get extended partition offset
	add ax, word [_BASE+di-4]
	adc dx, word [_BASE+di-2]	; add in root to get absolute sector number

	push dx
	push ax			; new base

.replace_common:
	cmp word [_BASE+di-2], 0	; have a (nonzero) root?
	jne .have_root
	cmp word [_BASE+di-4], 0
	jne .have_root		; yes -->

	mov word [_BASE+di-2], dx
	mov word [_BASE+di-4], ax	; set root
.have_root:

	call %[_SCANPTAB_PREFIX]read_partition_table
	jmp .

.pop:
d4	call %[_SCANPTAB_DEBUG4_PREFIX]d4message
d4	asciz "In scan_logical.pop",13,10

	add di, 10
	add sp, 8
	pop si

	mov ax, word [_BASE+di-8]
	mov dx, word [_BASE+di-6]
	call %[_SCANPTAB_PREFIX]read_partition_table
	jmp .next

.replace:
d4	call %[_SCANPTAB_DEBUG4_PREFIX]d4message
d4	asciz "In scan_logical.replace",13,10

	pop si				; (discard)
	mov ax, word [es:si + piStart]
	mov dx, word [es:si + piStart + 2]	; get extended partition offset
	add ax, word [_BASE+di - 4]
	adc dx, word [_BASE+di - 2]	; add in root
	mov word [_BASE+di - 8], ax
	mov word [_BASE+di - 6], dx	; set base

	jmp .replace_common

.got_partition_cycle:
	mov dx, msg.boot_partition_cycle_error
	jmp bootcmd.fail

.error_too_many_partitions:
	mov dx, msg.boot_too_many_partitions_error
	jmp bootcmd.fail



		; if _PARTITION_TABLE_IN_CS:
		; INP:  dx:ax = partition table sector to read
		; CHG:	ax, dx
		; OUT:  es = cs
		;       64 bytes [es:partition_table] = partition table
		;       does not return if error

		; else:
		; INP:  dx:ax = partition table sector to read
		; CHG:	ax, dx
		; OUT:  es = ss
		;       64 bytes [es:partition_table] = partition table
		;       does not return if error
%[_SCANPTAB_PREFIX]read_partition_table:
	push bx
%ifidn _BASE, bp
	mov bx, word [auxbuff_segorsel]	; bx => auxbuff
%else
	mov bx, word [bp + ldSectorSeg]
%endif
	call %[_SCANPTAB_PREFIX]read_ae_512_bytes
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
%if _PARTITION_TABLE_IN_CS
	push cs
%else
	push ss
%endif
	pop es
	mov di, %[_SCANPTAB_PREFIX]partition_table
					; es:di -> cs:%[_SCANPTAB_PREFIX]partition_table
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
