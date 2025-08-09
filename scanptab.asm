
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
	numdef BOOTCMD_FAIL_ERROR, 1
	numdef SPT_ELD, 0
%if _SPT_ELD
 %define sptrel reloc
 %define sptinternal internaldatarelocation
 %define sptexternal linkdatarelocation
	numdef MODE, 1
%else
 %define sptrel
 %define sptinternal comment
 %define sptexternal comment
	numdef MODE, 0
%endif
	gendef BASE, ss:bx
%ifidn _BASE, ss:bx
%elifidn _BASE, bp
%else
 %error Invalid base
%endif

%if _MODE
mode_all_ext5			equ 00b
mode_ignore_ext5		equ 01b
mode_first_ext5			equ 10b
mode_first_type_ext5		equ 11b

mode_all_ext15			equ 00b << 2
mode_ignore_ext15		equ 01b << 2
mode_first_ext15		equ 10b << 2
mode_first_type_ext15		equ 11b << 2

mode_all_ext85			equ 00b << 4
mode_ignore_ext85		equ 01b << 4
mode_first_ext85		equ 10b << 4
mode_first_type_ext85		equ 11b << 4

mode_ignore_subsequent_nested	equ            1_00_00_00b
mode_ignore_subsequent_logical	equ           10_00_00_00b
mode_ignore_subsequent_primary	equ          100_00_00_00b
mode_traditional_order_logical	equ         1000_00_00_00b
mode_active_priority		equ       1_0000_00_00_00b
mode_subsequent_primary_after	equ      10_0000_00_00_00b
mode_disable_fat32		equ 00_1000_0000_00_00_00b
mode_disable_lba		equ 01_0000_0000_00_00_00b
mode_dlasort_zero		equ 10_0000_0000_00_00_00b
%endif


		; INP:	byte [%load_unit] = unit to scan
		;	cx = function to call for each partition
		; OUT:	function called for each partition
		; CHG:	di, si, ax, bx, (cx), dx, es
		; STT:	ds => data segment (used for %load_* variables, unless bp-based)
		;
		; Note:	Calls %read_partition_table (in this module),
		;	 which calls %read_ae_512_bytes, which calls
		;	 read_sector. The read_sector base must be
		;	 zero and the geometry must be initialised.

		; Function in cx is called with:
		; INP:	es:si -> partition table entry,
		;	 si = %partition_table .. %partition_table+48,
		;	 es = ss (if not _PARTITION_TABLE_IN_CS)
		;	 es = cs (if _PARTITION_TABLE_IN_CS)
		;	byte [%load_current_partition] = partition number,
		;	 0 for diskette (unpartitioned),
		;	 1 to 4 for primary partitions,
		;	 5+ for logical partitions
		;	_BASE + di -> above part table metadata,
		;	 dword [_BASE + di - 4] = root (outermost extended position)
		;	 dword [_BASE + di - 8] = base (current table position)
		;	 dword [es:si + piStart] = local partition start
		;	 base + local start = absolute partition start
		;	_BASE -> bp value (dummy if _BASE is not bp),
		;		near return address of scan_partitions
		; CHG:	ax, (cx), dx, bx (unless part of _BASE)
		; STT:	ds => data segment (used for load_* variables, unless bp-based)
		; Note:	preserves (cx), si, di, ds, es, (bp), _BASE
		;
		; Note:	If the function returns to scan_partitions,
		;	 cx must be left as the function to call for
		;	 subsequent partitions afterwards.
		; Note:	May load sp from _BASE then pop bp then return
		;	 near if the scan should stop after the call.
%[_SCANPTAB_PREFIX]scan_partitions:
sptrel	and word [ %[_SCANPTAB_PREFIX]load_partition_cycle], 0
sptinternal -3
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

sptrel	cmp byte [ %[_SCANPTAB_PREFIX]load_unit], 80h
sptinternal -3
	jae @F

	push di
	push cx
%if _PARTITION_TABLE_IN_CS
	 push cs
%else
	 push ss
%endif
	 pop es
sptrel	mov di, %[_SCANPTAB_PREFIX]partition_table
sptinternal
	xor ax, ax
	mov cx, (4 * 16) >> 1
	rep stosw			; initialise fake partition table
	pop cx
	pop di
sptrel	mov si, %[_SCANPTAB_PREFIX]partition_table
sptinternal
					; -> fake PARTINFO
	mov byte [es:si + piBoot], 80h	; fake primary active
	mov byte [es:si + piType], 0FFh	; fake a type
sptrel	mov byte [ %[_SCANPTAB_PREFIX]load_current_partition], 0	; special: 0 = diskette
sptinternal -3				; piLength is 0, too
	call cx

	jmp %[_SCANPTAB_PREFIX]scan_logical.end


@@:
	xor ax, ax
	xor dx, dx
d4	call %[_SCANPTAB_DEBUG4_PREFIX]d4message
d4	asciz "In scan_partitions (before first call to read_partition_table)",13,10
	call %[_SCANPTAB_PREFIX]read_partition_table.first
d4	call %[_SCANPTAB_DEBUG4_PREFIX]d4message
d4	asciz "In scan_partitions (after first call to read_partition_table)",13,10
sptrel	mov si, %[_SCANPTAB_PREFIX]partition_table
sptinternal
sptrel	mov byte [ %[_SCANPTAB_PREFIX]load_current_partition], dl	; = 0
sptinternal
%if _SPT_ELD
sptrel	mov word [ %[_SCANPTAB_PREFIX]load_current_extended_and_is], dx	; = 0
sptinternal
%endif

.loop_primary_parts:
sptrel	inc byte [ %[_SCANPTAB_PREFIX]load_current_partition]
sptinternal
	cmp byte [es:si + piType], 0
	je .loop_primary_skip

%if _MODE
sptrel	testopt [ %[_SCANPTAB_PREFIX]load_scan_flags ], 32
sptinternal -3			; had a primary partition yet ?
	jz .callprimary		; no, accept it -->
sptrel	testopt [ %[_SCANPTAB_PREFIX]load_mode ], mode_ignore_subsequent_primary
sptinternal -3			; ignore subsequent primary ?
	jnz .ignoreprimary	; yes, ignore it -->
.callprimary:
%endif
	call cx			; es:si -> partition table entry
				; byte [load_current_partition] = which
.ignoreprimary:
.loop_primary_skip:
	add si, 16
sptrel	cmp si, strict word %[_SCANPTAB_PREFIX]partition_table.end
sptinternal
	jb .loop_primary_parts

%[_SCANPTAB_PREFIX]scan_logical:
.:
d4	call %[_SCANPTAB_DEBUG4_PREFIX]d4message
d4	asciz "In scan_logical.",13,10

%if _MODE
sptrel	testopt [ %[_SCANPTAB_PREFIX]load_mode ], mode_traditional_order_logical
sptinternal -3
	jz .nottraditional

sptrel	mov si, %[_SCANPTAB_PREFIX]partition_table
sptinternal
.loop_traditional:
sptrel	inc word [ %[_SCANPTAB_PREFIX]load_partition_cycle]
sptinternal
	jz .got_partition_cycle

	mov al, [es:si + piType]

%ifidn _BASE, bp
	xor bx, bx
%endif
	test al, al
	jz .next_traditional
	cmp al, 0Fh		; extended partition (LBA aware) ?
	je .next_traditional	; yes -->
	and al, ~80h		; extended partition Linux (85h) ?
	cmp al, 05h		;  or extended partition DOS (05h) ?
	je .next_traditional	; yes -->

%ifidn _BASE, bp
	cmp word [_BASE+di-2], bx
	jne .logical_traditional
	cmp word [_BASE+di-4], bx
%else
	cmp word [_BASE+di-2], 0
	jne .logical_traditional
	cmp word [_BASE+di-4], 0
%endif
	je .next_traditional
.logical_traditional:

%if _MODE
sptrel	testopt [ %[_SCANPTAB_PREFIX]load_scan_flags ], 32
sptinternal -3			; had a logical partition yet ?
	jz .calllogicaltrad	; no, accept it -->
sptrel	testopt [ %[_SCANPTAB_PREFIX]load_mode ], mode_ignore_subsequent_logical
sptinternal -3			; ignore subsequent logical ?
	jnz .ignorelogicaltrad	; yes, ignore it -->
.calllogicaltrad:
%endif

sptrel	inc byte [ %[_SCANPTAB_PREFIX]load_current_partition]
sptinternal
	jz .error_too_many_partitions
	call cx			; (sets load_scan_flags & 32 if recognised)
		; CHG: ax, (cx), dx, bx if _BASE = bp
		; preserve: (cx), si, di, ds, es, bx if _BASE = ss:bx
.ignorelogicaltrad:
.next_traditional:
	add si, 16		; -> next partition table entry
sptrel	cmp si, strict word %[_SCANPTAB_PREFIX]partition_table.end
sptinternal			; was last?
	jb .loop_traditional	; no, loop -->

sptrel	setopt [ %[_SCANPTAB_PREFIX]load_scan_flags ], 32
sptinternal -3			; mark as had logical

.nottraditional:
%endif

sptrel	mov si, %[_SCANPTAB_PREFIX]partition_table
sptinternal
.loop:
sptrel	inc word [ %[_SCANPTAB_PREFIX]load_partition_cycle]
sptinternal
	jz .got_partition_cycle

	mov al, [es:si + piType]

%ifidn _BASE, bp
	xor bx, bx
%endif
	test al, al
	jz .next
%if _MODE
%ifidn _BASE, bp
	cmp word [_BASE+di-2], bx
	jne .allextended
	cmp word [_BASE+di-4], bx
%else
	cmp word [_BASE+di-2], 0
	jne .allextended
	cmp word [_BASE+di-4], 0
%endif
	jne .allextended

sptrel	mov ah, [ %[_SCANPTAB_PREFIX]load_mode ]
sptinternal
	cmp al, 5
	je .check
	shr ah, 1
	shr ah, 1
	cmp al, 15
	je .check
	shr ah, 1
	shr ah, 1
	cmp al, 85h
	jne .notextended
.check:
sptrel	clropt [ %[_SCANPTAB_PREFIX]load_scan_flags ], 16
sptinternal -3			; new outermost extended

	test ah, 11b
	jz .push		; if it is 00b = all, always accept -->
	test ah, 10b		; if prior is NZ but this is zero
	jz .ignoreextended	;  then we have 01b, always ignore -->
	test ah, 01b		; if prior is NZ and this is NZ,
	; jnz .firsttype	;  then we have 11b, accept first of type
	mov ah, 1		; flag 1 for 10b
	jz @F			; if ZR, we have 10b, accept first of all types with 10b
.firsttype:
	mov ah, 2		; flag 2 for 11b type 5
	cmp al, 15
	jb @F
	mov ah, 4		; flag 4 for 11b type 15
	je @F
	mov ah, 8		; flag 8 for 11b type 85h
@@:
sptrel	test byte [ %[_SCANPTAB_PREFIX]load_scan_flags ], ah
sptinternal			; seen one of those before ?
	jnz .ignoreextended	; yes, ignore -->
sptrel	or byte [ %[_SCANPTAB_PREFIX]load_scan_flags ], ah
sptinternal			; no, note seen it now
	jmp .push		; and process extended partition -->
%endif

.allextended:
%if _MODE
sptrel	testopt [ %[_SCANPTAB_PREFIX]load_mode ], mode_ignore_subsequent_nested
sptinternal -3
	jz @F
sptrel	testopt [ %[_SCANPTAB_PREFIX]load_scan_flags ], 16
sptinternal -3
	jnz .ignoreextended
@@:
%endif
	cmp al, 0Fh		; extended partition (LBA aware) ?
	je .push		; yes -->
	and al, ~80h		; extended partition Linux (85h) ?
	cmp al, 05h		;  or extended partition DOS (05h) ?
	je .push		; yes -->
.notextended:

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

%if _MODE
sptrel	testopt [ %[_SCANPTAB_PREFIX]load_scan_flags ], 32
sptinternal -3			; had a logical partition yet ?
	jz .calllogical		; no, accept it -->
sptrel	test word [ %[_SCANPTAB_PREFIX]load_mode ], strict word \
		mode_ignore_subsequent_logical | mode_traditional_order_logical
sptinternal -4			; ignore subsequent logical or post-trad run ?
	jnz .ignorelogical	; yes, ignore it -->
.calllogical:
%endif

sptrel	inc byte [ %[_SCANPTAB_PREFIX]load_current_partition]
sptinternal
	jz .error_too_many_partitions
	call cx			; (sets load_scan_flags & 32 if recognised)
		; CHG: ax, (cx), dx, bx if _BASE = bp
		; preserve: (cx), si, di, ds, es, bx if _BASE = ss:bx
.ignorelogical:
.ignoreextended:
.next:
	add si, 16		; -> next partition table entry
sptrel	cmp si, strict word %[_SCANPTAB_PREFIX]partition_table.end
sptinternal			; was last?
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

%if _SPT_ELD
sptrel	rol byte [ %[_SCANPTAB_PREFIX]extended], 1
sptinternal
	jnc @F
sptrel	not byte [ %[_SCANPTAB_PREFIX]load_is_extended]
sptinternal

	push si
	sub di, 10			; address temporary root and base
	push word [_BASE+di+10-2]
	push word [_BASE+di+10-4]	; copy root as root
	push word [_BASE+di+10-2]
	push word [_BASE+di+10-4]	; copy root as base
		; Extended partitions always have LBA start values
		;  relative to the outermost extended partition.
		;  Therefore the "root" must be used as base for
		;  this call to always get the expected address
		;  from dword [bp - di - 8] + dword [es:si + 8].

	call cx

	add sp, 8			; discard temporary root and base
	add di, 10			; point back to prior root and base
	pop si				; undo last part of the stack frame

sptrel	not byte [ %[_SCANPTAB_PREFIX]load_is_extended]
sptinternal
sptrel	inc byte [ %[_SCANPTAB_PREFIX]load_current_extended]
sptinternal
%ifidn _BASE, bp
	xor bx, bx
%endif
@@:
%endif

	push si
.push_check_empty_next:
	add si, 16		; -> next
sptrel	cmp si, strict word %[_SCANPTAB_PREFIX]partition_table.end
sptinternal			; at end?
	jae .replace		; yes, no other partitions found, replace -->
	cmp byte [es:si + piType], 0	; is this a partition?
	je .push_check_empty_next	; no, check next -->
				; found a partition after this, do push
				; (possibly logical or another extended)
.push_check_is_not_empty:
d4	call %[_SCANPTAB_DEBUG4_PREFIX]d4message
d4	asciz "In scan_logical.push_check_is_not_empty",13,10

%if _MODE
	xor ax, ax		; sentinel 0 = accept more logicals

sptrel	testopt [ %[_SCANPTAB_PREFIX]load_mode ], mode_traditional_order_logical
sptinternal -3
	jnz .traditionalsentinel
sptrel	testopt [ %[_SCANPTAB_PREFIX]load_scan_flags ], 32
sptinternal -3			; had a logical partition in this table ?
	jz @F			; no, no need to reset -->
sptrel	testopt [ %[_SCANPTAB_PREFIX]load_mode ], mode_ignore_subsequent_logical
sptinternal -3			; ignore subsequent logical ?
	jz @F			; no -->
.traditionalsentinel:
	mov al, 64		; sentinel 64 = no more logicals
@@:
sptrel	clropt [ %[_SCANPTAB_PREFIX]load_scan_flags ], 32
sptinternal -3			; accept a logical partition in next table
%endif

	pop si			; restore -> partition table entry
%if _MODE
	push word [es:si + piStart]
	mov dx, word [es:si + piStart + 2]	; get extended partition offset
	add si, ax		; now -> behind partition_table if sentinel set
	pop ax
%endif
	push si			; stored at word [_BASE+di-10]
	sub di, 10
	push word [_BASE+di+10-2]
	push word [_BASE+di+10-4]	; copy root
%ifn _MODE
	mov ax, word [es:si + piStart]
	mov dx, word [es:si + piStart + 2]	; get extended partition offset
%endif
	add ax, word [_BASE+di-4]
	adc dx, word [_BASE+di-2]	; add in root to get absolute sector number

	push dx
	push ax			; new base

.replace_common:
%ifidn _BASE, bp
	cmp word [_BASE+di-2], bx	; have a (nonzero) root?
	jne .have_root
	cmp word [_BASE+di-4], bx
%else
	cmp word [_BASE+di-2], 0	; have a (nonzero) root?
	jne .have_root
	cmp word [_BASE+di-4], 0
%endif
	jne .have_root		; yes -->

	mov word [_BASE+di-2], dx
	mov word [_BASE+di-4], ax	; set root
.have_root:

	call %[_SCANPTAB_PREFIX]read_partition_table.first
	jmp .

.pop:
d4	call %[_SCANPTAB_DEBUG4_PREFIX]d4message
d4	asciz "In scan_logical.pop",13,10

%if _MODE
sptrel	setopt [ %[_SCANPTAB_PREFIX]load_scan_flags ], 16
sptinternal -3			; remember we found a nested extended partition
				;  so we can ignore others in the same outermost
%endif

	add di, 10
	add sp, 8
	pop si

%if _MODE
sptrel	clropt [ %[_SCANPTAB_PREFIX]load_scan_flags ], 32
sptinternal -3			; accept a logical partition in this table
sptrel	cmp si, 64 + %[_SCANPTAB_PREFIX]partition_table
sptinternal			; sentinel set ?
	jb @F			; no -->
sptrel	setopt [ %[_SCANPTAB_PREFIX]load_scan_flags ], 32
sptinternal -3			; do not accept a logical partition in this table
	sub si, 64		; undo sentinel addition
@@:
%endif
	mov ax, word [_BASE+di-8]
	mov dx, word [_BASE+di-6]
	call %[_SCANPTAB_PREFIX]read_partition_table.reload
	jmp .next

.replace:
d4	call %[_SCANPTAB_DEBUG4_PREFIX]d4message
d4	asciz "In scan_logical.replace",13,10
sptrel	clropt [ %[_SCANPTAB_PREFIX]load_scan_flags ], 32
sptinternal -3			; accept a logical partition in next table

	pop si				; (discard)
.replace_no_pop:
	mov ax, word [es:si + piStart]
	mov dx, word [es:si + piStart + 2]	; get extended partition offset
	add ax, word [_BASE+di - 4]
	adc dx, word [_BASE+di - 2]	; add in root
	mov word [_BASE+di - 8], ax
	mov word [_BASE+di - 6], dx	; set base

	jmp .replace_common


%if _BOOTCMD_FAIL_ERROR
.got_partition_cycle:
sptrel	mov dx, msg.boot_partition_cycle_error
sptinternal
	jmp bootcmd.fail

.error_too_many_partitions:
sptrel	mov dx, msg.boot_too_many_partitions_error
sptinternal
	jmp bootcmd.fail
%endif


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
%if _SPT_ELD
.first:
	db __TEST_IMM8			; NC, skip stc
.reload:
	stc
%else
.first:
.reload:
%endif

	push bx
%if _SPT_ELD
sptrel	mov bx, word [buffersegment]
sptinternal
%elifidn _BASE, bp
	mov bx, word [auxbuff_segorsel]	; bx => auxbuff
%else
	mov bx, word [bp + ldSectorSeg]
%endif
	call %[_SCANPTAB_PREFIX]read_ae_512_bytes
	pop bx
	cmp word [es:510], 0AA55h
	jne .signature_fail
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
sptrel	mov di, %[_SCANPTAB_PREFIX]partition_table
sptinternal				; es:di -> cs:%[_SCANPTAB_PREFIX]partition_table
	mov cx, 4*16 / 2
	rep movsw
	 pop cx
	 pop si
	 pop di
	 pop ds
	retn


%if _BOOTCMD_FAIL_ERROR
.signature_fail:
sptrel	mov dx, msg.bootfail_sig_parttable
sptinternal
	jmp bootcmd.fail
%endif
