
%if 0

instsect.asm - install boot sectors. 2018 by C. Masloch

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%include "lmacros3.mac"

numdef DEBUG0
numdef DEBUG1
numdef DEBUG2
numdef DEBUG3
numdef DEBUG4
numdef DEBUG5
%idefine d5 _d 5,
numdef VDD,		1	; try to load DEBXXVDD.DLL to use it for L and W sector commands
numdef DISPLAY_ALL_NAMES,	0


	struc BS
bsJump:	resb 3
bsOEM:	resb 8
bsBPB:
	endstruc

	struc EBPB		;        BPB sec
bpbBytesPerSector:	resw 1	; offset 00h 0Bh
bpbSectorsPerCluster:	resb 1	; offset 02h 0Dh
bpbReservedSectors:	resw 1	; offset 03h 0Eh
bpbNumFATs:		resb 1	; offset 05h 10h
bpbNumRootDirEnts:	resw 1	; offset 06h 11h -- 0 for FAT32
bpbTotalSectors:	resw 1	; offset 08h 13h
bpbMediaID:		resb 1	; offset 0Ah 15h
bpbSectorsPerFAT:	resw 1	; offset 0Bh 16h -- 0 for FAT32
bpbCHSSectors:		resw 1	; offset 0Dh 18h
bpbCHSHeads:		resw 1	; offset 0Fh 1Ah
bpbHiddenSectors:	resd 1	; offset 11h 1Ch
bpbTotalSectorsLarge:	resd 1	; offset 15h 20h
bpbNew:				; offset 19h 24h

ebpbSectorsPerFATLarge:	resd 1	; offset 19h 24h
ebpbFSFlags:		resw 1	; offset 1Dh 28h
ebpbFSVersion:		resw 1	; offset 1Fh 2Ah
ebpbRootCluster:	resd 1	; offset 21h 2Ch
ebpbFSINFOSector:	resw 1	; offset 25h 30h
ebpbBackupSector:	resw 1	; offset 27h 32h
ebpbReserved:		resb 12	; offset 29h 34h
ebpbNew:			; offset 35h 40h
	endstruc

	struc BPBN		; ofs B16 S16 B32 S32
bpbnBootUnit:		resb 1	; 00h 19h 24h 35h 40h
			resb 1	; 01h 1Ah 25h 36h 41h
bpbnExtBPBSignature:	resb 1	; 02h 1Bh 26h 37h 42h -- 29h for valid BPBN
bpbnSerialNumber:	resd 1	; 03h 1Ch 27h 38h 43h
bpbnVolumeLabel:	resb 11	; 07h 20h 2Bh 3Ch 47h
bpbnFilesystemID:	resb 8	; 12h 2Bh 36h 47h 52h
	endstruc		; 1Ah 33h 3Eh 4Fh 5Ah

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

	struc LOADDATA2, LOADDATA - 10h
ldRootSector:		resd 1
ldEntriesPerSector:	resw 1
ldLastAvailableSector:	resw 1
ldParasLeft:		resw 1
ldParasDone:		resw 1
ldBytesPerSector:	resw 1
	endstruc

	struc DIRENTRY
deName:		resb 8
deExt:		resb 3
deAttrib:	resb 1
		resb 8
deClusterHigh:	resw 1
deTime:		resw 1
deDate:		resw 1
deClusterLow:	resw 1
deSize:		resd 1
	endstruc

ATTR_READONLY	equ 1
ATTR_HIDDEN	equ 2
ATTR_SYSTEM	equ 4
ATTR_VOLLABEL	equ 8
ATTR_DIRECTORY	equ 10h
ATTR_ARCHIVE	equ 20h

	struc LBAPACKET
lpSize:		resw 1
lpCount:	resw 1
lpBuffer:	resd 1
lpSector:	resq 1
	endstruc

	struc PARTINFO
piBoot:		resb 1
piStartCHS:	resb 3
piType:		resb 1
piEndCHS:	resb 3
piStart:	resd 1
piLength:	resd 1
	endstruc

ptEmpty:		equ 0
ptFAT12:		equ 1
ptFAT16_16BIT_CHS:	equ 4
ptExtendedCHS:		equ 5
ptFAT16_CHS:		equ 6
ptFAT32_CHS:		equ 0Bh
ptFAT32:		equ 0Ch
ptFAT16:		equ 0Eh
ptExtended:		equ 0Fh
ptLinux:		equ 83h
ptExtendedLinux:	equ 85h

	struc FSINFO	; FAT32 FSINFO sector layout
.signature1:	resd 1		; 41615252h ("RRaA") for valid FSINFO
.reserved1:			; former unused, initialized to zero by FORMAT
.fsiboot:	resb 480	; now used for FSIBOOT
.signature2:	resd 1		; 61417272h ("rrAa") for valid FSINFO
.numberfree:	resd 1		; FSINFO: number of free clusters or -1
.nextfree:	resd 1		; FSINFO: first free cluster or -1
.reserved2:	resd 3		; unused, initialized to zero by FORMAT
.signature3:	resd 1		; AA550000h for valid FSINFO or FSIBOOT
	endstruc

	struc FSIBOOTG	; FSIBOOT general layout
.signature:	resq 1		; 8 byte that identify the FSIBOOT type
.fsicode:	resb 472	; 472 byte FSIBOOT type specific data or code
	endstruc

%if _VDD
; standard BOPs for communication with DEBXXVDD on NT platforms
%macro RegisterModule 0.nolist
	db 0C4h, 0C4h, 58h, 0
	nop
%endmacro
%macro UnRegisterModule 0.nolist
	db 0C4h, 0C4h, 58h, 1
	nop
%endmacro
%macro DispatchCall 0.nolist
	db 0C4h, 0C4h, 58h, 2
	nop
%endmacro
%endif


%ifndef _MAP
%elifempty _MAP
%else	; defined non-empty, str or non-str
	[map all _MAP]
%endif

	cpu 8086
	org 256
	section PROGRAM align=16
	section BUFFERS follows=PROGRAM align=16

	numdef FAT12,		1
	numdef FAT16,		1
	numdef FAT32,		1
	strdef PAYLOAD_FAT12,	"boot12.bin"
	strdef PAYLOAD_FAT16,	"boot16.bin"
	strdef PAYLOAD_FAT32,	"boot32.bin"

	align 16
%if _FAT12
fat12_payload:		incbin _PAYLOAD_FAT12
.end:
%if (fat12_payload.end - fat12_payload) != 512
 %error "FAT12 payload isn't 512 bytes sized."
%endif
%endif
%if _FAT16
fat16_payload:		incbin _PAYLOAD_FAT16
.end:
%if (fat16_payload.end - fat16_payload) != 512
 %error "FAT16 payload isn't 512 bytes sized."
%endif
%endif
%if _FAT32
fat32_payload:		incbin _PAYLOAD_FAT32
.end:
%assign fat32_payload.size (fat32_payload.end - fat32_payload)
%assign _FAT32_TWO_SECTORS 0
%if fat32_payload.size == 512
%elif fat32_payload.size == 1024
 %assign _FAT32_TWO_SECTORS 1
%else
 %error "FAT32 payload isn't 512 or 1024 bytes sized."
%endif
%else
 %assign _FAT32_TWO_SECTORS 0
%endif


	section PROGRAM
start:
			; This is a simple MS-DOS 1.x detection (8 Byte).
	mov ah, 4Dh		; the only function I found that doesn't need much setup or cleanup
	stc			; but that uses MS-DOS 2.x error reporting. clears CF (Int21.30 does not)
	int 21h
	jnc .dosgood		; it is MS-DOS 2.x+ or compatible -->
	retn			; it isn't so simply terminate

.dosgood:
	cld
	cmp sp, stack_end
	jae .stackgood
	mov dx, msg.out_of_memory
	call disp_msg_asciz
	mov ax, 4CFFh
	int 21h

.stackgood:
	mov dx, i23
	mov ax, 2523h
	int 21h			; set Int23 so that we restore on Ctrl-C as well
	mov dx, i24
	mov ax, 2524h
	int 21h			; set Int24 so all hard errors are changed to the soft error

	mov byte [drivenumber], -1

	mov si, 81h
.loop:
	lodsb
.loop_got_byte:
	cmp al, 9
	je .loop
	cmp al, 32
	je .loop
	jb cmd_line_end

	cmp al, '-'
	je .switch
	cmp al, '/'
	je .switch

	cmp byte [si], ':'
	jne .error
	call uppercase
	sub al, 'A'
	cmp al, 32
	jae .error
	cmp byte [drivenumber], -1
	jne .error_multiple_drives
	mov byte [drivenumber], al
	inc si
	jmp .loop

.switch:
	lodsb
	call uppercase
	cmp al, 'F'
	je .switch_f
	cmp al, 'U'
	je .switch_u
	cmp al, 'I'
	je .switch_i
	cmp al, 'B'
	je .switch_b

	cmp al, 'H'
	je .switch_h
	cmp al, '?'
	je .switch_h

.switch_not_supported:
	mov dx, msg.switch_not_supported
disp_error: equ $
	call disp_msg_asciz
	jmp exit_error


.switch_h:
	mov dx, msg.help
	call disp_msg_asciz
	jmp exit_normal


.switch_f:

NUM_REPLACEMENTS equ 4

@@:
	lodsb
	cmp al, 32
	je @B
	cmp al, 9
	je @B
	 cmp al, '='
	 je @FF
	 cmp al, ':'
	 je @FF
	cmp al, '1'
	jb .error
	cmp al, '1' - 1 + NUM_REPLACEMENTS	; '4'
	ja .error
	cmp byte [si], '='
	je @F
	cmp byte [si], ':'
	jne .error
@@:
	inc si			; -> behind the colon
	sub al, '1'		; 0 to 3 inclusive
	mov ah, 12
	mul ah			; 0, 12, 24, 36
	db __TEST_IMM16		; (skip xor)
@@:
	 xor ax, ax		; if empty number field (al was colon)
	add ax, msg.name_replacements	; -> name replacement buffer
	xchg ax, di		; -> buffer

	lodsb
	dec si
	cmp al, 32
	je @F
	cmp al, 9
	je @F
	call iseol?
	je @F

	push di
	call boot_parse_fn	; parse
	pop di
	jc .error		; error out -->
	cmp al, '/'
	je .error
	cmp al, '\'
	je .error		; invalid -->
	dec si
	push si
	mov si, load_kernel_name
	mov cx, 12 >> 1
	rep movsw		; write to buffer
	pop si
	jmp .loop

@@:
	mov byte [di], 0	; delete replacement name
	jmp .loop


.switch_u:
@@:
	lodsb
	cmp al, 32
	je @B
	cmp al, 9
	je @B

	mov dx, msg.auto
	dec si
	call isstring?
	mov ax, 0FF00h
	je @F
	lodsb
	call get_hexadecimal_literal
	test bx, bx
	jnz .error
	cmp dx, 256
	jae .error
	mov ax, dx
	dec si
@@:
	mov word [load_unit], ax
	jmp .loop


.switch_i:
	lodsb
	call uppercase
	cmp al, 'O'
	jne @F
	setopt [cmd_line_flags], clfLeaveInfo
.loop_1:
	jmp .loop

@@:
	cmp al, 'R'
	jne @F
	clropt [cmd_line_flags], clfLeaveInfo
	jmp .loop_1

@@:
	cmp al, 'S'
	jne @F
	clropt [cmd_line_flags], clfWriteInfoMask
	setopt [cmd_line_flags], clfWriteInfoToSector
	jmp .loop_1

@@:
	cmp al, 'N'
	jne @F
	clropt [cmd_line_flags], clfWriteInfoMask
	setopt [cmd_line_flags], clfDontWriteInfo
	jmp .loop_1

@@:
	cmp al, ':'
	je @F
	cmp al, '='
	je @F
	cmp al, 'B'
	je .switch_i_b
	jmp .switch_not_supported

@@:
	clropt [cmd_line_flags], clfWriteInfoMask
	setopt [cmd_line_flags], clfWriteInfoToFile
@@:
	lodsb
	cmp al, 32
	je @B
	cmp al, 9
	je @B

	dec si
	mov word [cmd_line_info_file.name], si
	call process_switch_filename
	jmp .loop_got_byte

.switch_i_b:
	clropt [cmd_line_flags], clfWriteInfoMask
	setopt [cmd_line_flags], clfWriteInfoToSectorFile
	jmp .loop_1


.switch_b:
	lodsb
	call uppercase
	cmp al, 'O'
	jne @F
	setopt [cmd_line_flags], clfLeaveSector
	jmp .loop_1

@@:
	cmp al, 'R'
	jne @F
	clropt [cmd_line_flags], clfLeaveSector
	jmp .loop_1

@@:
	cmp al, 'S'
	jne @F
	clropt [cmd_line_flags], clfWriteSectorMask
	setopt [cmd_line_flags], clfWriteSectorToSector
	jmp .loop_1

@@:
	cmp al, 'N'
	jne @F
	clropt [cmd_line_flags], clfWriteSectorMask
	setopt [cmd_line_flags], clfDontWriteSector
	jmp .loop_1

@@:
	cmp al, ':'
	je @F
	cmp al, '='
	je @F
	jmp .switch_not_supported

@@:
	clropt [cmd_line_flags], clfWriteSectorMask
	setopt [cmd_line_flags], clfWriteSectorToFile
@@:
	lodsb
	cmp al, 32
	je @B
	cmp al, 9
	je @B

	dec si
	mov word [cmd_line_sector_file.name], si
	call process_switch_filename
	jmp .loop_got_byte


.error_multiple_drives:
	mov dx, msg.error_multiple_drives
	jmp disp_error

.error:
	mov dx, msg.invalid_argument
	jmp disp_error


process_switch_filename:
	mov bx, si		; -> start of name
	mov di, si		; -> start of name
	lodsb			; load character
	call iseol?
	jne @F
	mov dx, msg.switch_requires_filename
.disp_error_1:
	jmp disp_error

@@:
.unquoted_loop:
	cmp al, 32		; blank or EOL outside quoted part ?
	je .blank
	cmp al, 9
	je .blank
	call iseol?
	je .blank		; yes -->
	cmp al, '"'		; starting quote mark ?
	je .quoted		; yes -->
	stosb			; store character
.unquote:
	lodsb			; load character
	jmp .unquoted_loop	; continue in not-quoted loop -->

.blank:
	; mov byte [si - 1], 0	; terminate (shouldn't be needed)
	mov byte [di], 0	; terminate
	cmp bx, di		; empty ?
	je .empty		; yes -->
	retn			; done

.quoted_loop:
	call iseol?		; EOL inside quoted part ?
	je .quoted_eol		; if yes, error -->
	cmp al, '"'		; ending quote mark ?
	je .unquote		; yes -->
	stosb			; store character
.quoted:
	lodsb			; load character
	jmp .quoted_loop	; continue in quoted loop -->

.empty:
	mov dx, msg.switch_filename_empty
	jmp .disp_error_1

.quoted_eol:
	mov dx, msg.switch_filename_missing_unquote
	jmp .disp_error_1


cmd_line_end:
	cmp byte [drivenumber], -1
	jne @F
	mov dx, msg.no_drive_specified
	jmp disp_error

@@:
	testopt [cmd_line_flags], clfWriteInfoToSectorFile
	jz @F
	testopt [cmd_line_flags], clfWriteSectorToFile
	jnz @F

	mov dx, msg.no_sector_file_specified
	jmp disp_error

@@:

detect_fat_type:
	mov bx, second_sector_buffer
	mov bp, bx
	push bx

	call initialise
	jc exit_error

	pop bx
	xor ax, ax
	xor dx, dx
	mov cl, [drivenumber]
	call read_ae_512_bytes		; load partition boot sector
	jc exit_error

	mov dx, msg.bootfail_sig
	cmp word [bp + 510], 0AA55h
	jne .disp_error_1

	mov bx, [bp + ldBytesPerSector]
	cmp bx, [bp + bsBPB + bpbBytesPerSector]
	mov dx, msg.bootfail_secsizediffer
	jne .disp_error_1

	cmp bx, 512
	jbe @FF
	cmp bx, 1024
	jae @F
	mov dx, msg.bootfail_secsizeinvalid
.disp_error_1:
	jmp disp_error
@@:
	mov di, bx
	cmp word [bp + di - 2], 0AA55h
	mov dx, msg.bootfail_sig2
	jne .disp_error_1
@@:

	mov si, second_sector_buffer
	mov di, third_sector_buffer_512_bytes
	mov cx, 512 >> 1
	rep movsw

	xor ax, ax
	cmp word [bp + bsBPB + bpbSectorsPerFAT], ax
	je @F					; is FAT32 -->
	mov si, second_sector_buffer + bsBPB + bpbNew
	mov di, second_sector_buffer + bsBPB + ebpbNew
	mov cx, BPBN_size
	rep movsb				; clone the FAT16 / FAT12 BPBN
						; to where the FAT32 BPBN lives
@@:

; (boot.asm code starts here)

	xor ax, ax
; calculate some values that we need:
; adjusted sectors per cluster (store in a word,
;  and decode EDR-DOS's special value 0 meaning 256)
	mov al, [bp + bsBPB + bpbSectorsPerCluster]
	dec al
	inc ax
	mov [bp + ldClusterSize], ax

	mov ax, [bp + ldEntriesPerSector]

; number of sectors used for root directory (store in CX)
	xor dx, dx
	mov bx, ax
	dec ax				; rounding up
	add ax, [bp + bsBPB + bpbNumRootDirEnts]	; (0 iff FAT32)
	adc dx, dx			; account for overflow (dx was zero)
	div bx				; get number of root sectors
	xchg ax, cx			; cx = number of root secs


; (iniload.asm code starts here)

	push cx				; number of root secs
	xor ax, ax
; first sector of root directory
	mov al, [bp + bsBPB + bpbNumFATs]	; ! ah = 0, hence ax = number of FATs
	mov cx, word [bp + bsBPB + bpbSectorsPerFAT]
	xor di, di			; di:cx = sectors per FAT
					;  iff FAT12, FAT16
	test cx, cx			; is FAT32 ?
	jnz @F				; no -->
	mov cx, word [bp + bsBPB + ebpbSectorsPerFATLarge]
	mov di, word [bp + bsBPB + ebpbSectorsPerFATLarge + 2]	; for FAT32
@@:
	push ax
	mul cx
		; ax = low word SpF*nF
		; dx = high word
	xchg bx, ax
	xchg cx, dx
		; cx:bx = first mul
	pop ax
	mul di
		; ax = high word adjust
		; dx = third word
	test dx, dx
	jz @F
error_badchain: equ $
	mov dx, msg.boot_badchain
	jmp disp_error

@@:
	xchg dx, ax
		; dx = high word adjust
	add dx, cx
		; dx:bx = result
	jc error_badchain
	xchg ax, bx
		; dx:ax = result
	jc error_badchain

	add ax, [bp + bsBPB + bpbReservedSectors]
	adc dx, byte 0
	jc error_badchain

	pop cx				; number of root sectors
	xor di, di

; first sector of disk data area:
	add cx, ax
	adc di, dx
	jc error_badchain
	mov [bp + lsvDataStart], cx
	mov [bp + lsvDataStart + 2], di

	mov [bp + ldRootSector], ax
	mov [bp + ldRootSector + 2], dx

; total sectors
	xor dx, dx
	mov ax, [bp + bsBPB + bpbTotalSectors]
	test ax, ax
	jnz @F
	mov dx, [bp + bsBPB + bpbTotalSectorsLarge + 2]
	mov ax, [bp + bsBPB + bpbTotalSectorsLarge]

		; fall through and let it overwrite the field with the
		; already current contents. saves a jump.
@@:
	mov [bp + bsBPB + bpbTotalSectorsLarge + 2], dx
	mov [bp + bsBPB + bpbTotalSectorsLarge], ax

	; dx:ax = total sectors

	mov bx, [bp + bsBPB + bpbSectorsPerFAT]
	mov byte [bp + ldFATType], 32
	test bx, bx
	jz .gotfattype

	xor cx, cx

	mov word [bp + bsBPB + ebpbSectorsPerFATLarge], bx
	mov word [bp + bsBPB + ebpbSectorsPerFATLarge + 2], cx
	mov word [bp + bsBPB + ebpbFSFlags], cx
	; FSVersion, RootCluster, FSINFOSector, BackupSector, Reserved:
	;  uninitialised here (initialised by loaded_all later)

	; dx:ax = total amount of sectors
	sub ax, word [bp + lsvDataStart]
	sbb dx, word [bp + lsvDataStart + 2]

	; dx:ax = total amount of data sectors
	mov bx, ax
	xchg ax, dx
	xor dx, dx
	div word [bp + ldClusterSize]
	xchg bx, ax
	div word [bp + ldClusterSize]
	; bx:ax = quotient, dx = remainder
	; bx:ax = number of clusters
	test bx, bx
	jz @F
.badclusters:
	mov dx, msg.boot_badclusters
	jmp disp_error

@@:
	cmp ax, 0FFF7h - 2
	ja .badclusters
	mov byte [bp + ldFATType], 16
	cmp ax, 0FF7h - 2
	ja .gotfattype

	mov byte [bp + ldFATType], 12
.gotfattype:

	mov dx, msg.is_fat16
%if _FAT16
	mov si, fat16_payload
%else
	mov si, 0			; (preserve flags)
%endif
	cmp byte [bp + ldFATType], 16
	je @F
	mov dx, msg.is_fat12
%if _FAT12
	mov si, fat12_payload
%else
	mov si, 0			; (preserve flags)
%endif
	jb @F
	mov dx, msg.is_fat32
%if _FAT32
	mov si, fat32_payload
%else
	mov si, 0			; (preserve flags)
%endif
@@:
	call disp_msg_asciz

%if !_FAT32 || !_FAT16 || !_FAT12
	test si, si
	jnz @F

	testopt [cmd_line_flags], clfLeaveSector
	jnz @F

	mov dx, msg.not_supported_fat_type
	jmp disp_error

@@:
%endif

	mov byte [bp + ldHasLBA], 0	; 2 clear: not FSINFO
%if _FAT32_TWO_SECTORS
	cmp si, fat32_payload
	jne .not_fat32
	cmp word [bp + ldBytesPerSector], 1024
	jae .fat32_larger_sector
		; Because we checked that the sector size is a power of two,
		;  we can assume here that sectors are 512 bytes or less.

	cmp word [si + 512 + FSINFO.signature1], "RR"
	jne .not_fsinfo
	cmp word [si + 512 + FSINFO.signature1 + 2], "aA"
	jne .not_fsinfo

	mov ax, word [bp + bsBPB + ebpbFSINFOSector]
	xor dx, dx

	or byte [bp + ldHasLBA], 2	; 2 set: FSINFO

	test ax, ax
	jz .invalid_fsinfo
	cmp ax, word [bp + bsBPB + bpbReservedSectors]
	jae .invalid_fsinfo

	mov bx, second_sector_buffer + 512
	mov cl, [drivenumber]
	call read_ae_512_bytes		; load FSINFO sector
	jc exit_error

	jmp .fat32_fsinfo_setup_done

.invalid_fsinfo:
	mov dx, msg.no_fsinfo
	jmp disp_error

.not_fsinfo:
	mov dx, .msg_not_yet_non_fsinfo
	jmp disp_error
.msg_not_yet_non_fsinfo:
	asciz "FAT32 with two sectors and not FSINFO not yet supported.",13,10

.not_fat32:
.fat32_larger_sector:
.fat32_fsinfo_setup_done:
%endif
	testopt [cmd_line_flags], clfLeaveSector
	jz @F

		; Copy over original 512-byte sector buffer content.
	mov cx, 512
	mov di, sector_buffer
	mov si, third_sector_buffer_512_bytes
	mov cx, 512 >> 1
	rep movsw
		; Copy over big sector excess from buffer.
	mov si, second_sector_buffer + 512
	mov cx, [bp + ldBytesPerSector]
	sub cx, 512
	jbe .got_sector_buffer
	shr cx, 1
	rep movsw
	jmp .got_sector_buffer


		; Copy over two sectors into the sector_buffer,
		;  for the case of FAT32 with _FAT32_TWO_SECTORS
		;  and a sector size >= 1 KiB.
@@:
	mov cx, 1024 >> 1
	mov di, sector_buffer
	rep movsw
	mov si, second_sector_buffer + bsBPB
	mov di, sector_buffer + bsBPB
	cmp byte [bp + ldFATType], 16
	jbe @F					; if FAT12/FAT16 -->
	mov cx, ebpbNew
	rep movsb				; move EBPB (minus BPBN)
	jmp @FF					; si -> BPBN
@@:
	mov cx, bpbNew				; move BPB
	rep movsb
	add si, ebpbNew - bpbNew		; si -> BPBN
@@:
	mov cx, BPBN_size
	rep movsb


.got_sector_buffer:
%if _FAT32_TWO_SECTORS
	test byte [bp + ldHasLBA], 2
	jz .no_fsinfo

	testopt [cmd_line_flags], clfLeaveInfo
	jz @F

		; Copy over original FSINFO sector content.
	mov si, second_sector_buffer + 512
	mov di, sector_buffer + 512
	mov cx, 512 >> 1
	rep movsw
	jmp .no_fsinfo

@@:
		; Copy over actual FSINFO structure from original.
		;  (Leaves FSIBOOT as written from our image.)
	mov si, second_sector_buffer + 512 + FSINFO.signature2
	mov di, sector_buffer + 512 + FSINFO.signature2
	mov cx, (FSINFO_size - FSINFO.signature2) >> 1
	rep movsw				; copy over FSINFO
.no_fsinfo:
%endif

	mov si, second_sector_buffer + 510
	mov di, sector_buffer + 510
	movsw
	mov cx, word [bp + ldBytesPerSector]
%if _FAT32_TWO_SECTORS
	 cmp byte [bp + ldFATType], 16
	 jbe @F
	add si, 512				; -> second_sector_buffer +1024
	add di, 512				; -> behind buffer for FSIBOOT
	sub cx, 512
	jbe @FF
@@:
%endif
	sub cx, 512
	jbe @F
	rep movsb
@@:

listnames:
	mov bx, msg.names
	mov si, sector_buffer + bsBPB + bpbNew + BPBN_size
	mov cx, 512 - (bsBPB + bpbNew + BPBN_size) - 2
						; -2 = AA55h sig
	cmp byte [bp + ldFATType], 16
	jbe @F
	mov si, sector_buffer + bsBPB + ebpbNew + BPBN_size
	mov cx, 512 - (bsBPB + ebpbNew + BPBN_size) - 2
@@:

%if _DISPLAY_ALL_NAMES
.nextname:
	call findname
	 lahf
	mov dx, [bx]
	call disp_msg_asciz
	mov dx, msg.name_before
	call disp_msg_asciz
	 sahf
	 jc @F		; skip quote if no name -->
	 mov dx, msg.name_quote
	 call disp_msg_asciz
@@:
	mov dx, msg.foundname
	call disp_msg_asciz
	 sahf
	 jc @F		; skip quote if no name -->
	 mov dx, msg.name_quote
	 call disp_msg_asciz
@@:
	mov dx, msg.name_after
	call disp_msg_asciz
	 sahf
	 mov ax, 0
	 jc @F		; set to zero if no name -->
	 lea ax, [si - 11]	; -> name in buffer
@@:
	 mov word [bx + 2], ax	; -> name in buffer, or 0
	add bx, 4
	cmp word [bx], 0
	jne .nextname
%else
		; First name: Special, if none found display a message.
	call findname
	jnc @F
	mov dx, msg.name_none
	call disp_msg_asciz
	jmp @FF

.nextname:
	call findname
	jc @FF
@@:
	mov dx, [bx]
	call disp_msg_asciz
	mov dx, msg.name_before
	call disp_msg_asciz
	 mov dx, msg.name_quote
	 call disp_msg_asciz
	mov dx, msg.foundname
	call disp_msg_asciz
	 mov dx, msg.name_quote
	 call disp_msg_asciz
	mov dx, msg.name_after
	call disp_msg_asciz
	 lea ax, [si - 11]	; -> name in buffer
	 mov word [bx + 2], ax	; -> name in buffer, or 0
	add bx, 4
	cmp word [bx], 0
	jne .nextname
@@:
%endif

	mov si, msg.name_replacements
	mov bx, msg.names
	mov cx, NUM_REPLACEMENTS
.loop:
	cmp byte [si], 0
	je .next
	mov di, word [bx + 2]
	test di, di
	jnz .replace
	mov dx, msg.no_name_found_before
	call disp_msg_asciz
	mov dx, [bx]
	call disp_msg_asciz
	mov dx, msg.no_name_found_after
	call disp_msg_asciz
	jmp exit_error

.replace:
	mov dx, msg.replacing_before
	call disp_msg_asciz
	mov dx, [bx]
	call disp_msg_asciz
	mov dx, msg.replacing_between
	call disp_msg_asciz
	push cx
	push si
	 push si
	 push di
	call convert_name_to_asciz
	 pop di
	 pop si
	mov dx, msg.foundname
	call disp_msg_asciz
	mov dx, msg.replacing_after
	call disp_msg_asciz
	mov cx, 11
	rep movsb
	pop si
	pop cx

.next:
	add bx, 4
	add si, 12
	cmp word [bx], 0
	loopnz .loop

set_unit:
	mov bx, [load_unit]
	mov dx, msg.using_auto_unit
	cmp bh, 0FFh
	je .auto

	mov si, sector_buffer
	lodsb
	cmp al, 0E9h
	je .nearjmp
	cmp al, 0EBh
	je .shortjmp

.notfound:
	mov dx, msg.unit_not_found
	jmp disp_error

.nearjmp:
	lodsw
	db __TEST_IMM16		; (skip lodsb, cbw)
.shortjmp:
	lodsb
	cbw
	add si, ax

	mov dx, 16
	mov di, unit_search_strings.mov
	mov cx, unit_search_strings.mov_length
@@:
	push si
	push di
	push cx
	repe cmpsb
	pop cx
	pop di
	pop si
	je .found_mov
	inc si
	dec dx
	jnz @B

	jmp .notfound

.found_mov:
	add si, cx

	mov dx, 48
	mov di, unit_search_strings.1612_set_bpbn
	mov cx, unit_search_strings.1612_set_bpbn_length
	cmp byte [bp + ldFATType], 16
	jbe @F
	mov di, unit_search_strings.32_set_bpbn
	mov cx, unit_search_strings.32_set_bpbn_length
@@:
	push si
	push di
	push cx
	repe cmpsb
	pop cx
	pop di
	pop si
	je .found_set
	inc si
	dec dx
	jnz @B

	jmp .notfound

.found_set:
	cmp byte [bp + ldFATType], 16
	jbe .1612
.32:
	mov byte [sector_buffer + bsBPB + ebpbNew + bpbnBootUnit], bl
	mov di, unit_search_strings.32_set_dl
	mov cx, unit_search_strings.32_set_dl_length
	jmp @F

.1612:
	mov byte [sector_buffer + bsBPB + bpbNew + bpbnBootUnit], bl
	mov di, unit_search_strings.1612_set_dl
	mov cx, unit_search_strings.1612_set_dl_length
@@:

	xchg si, di
	rep movsb		; write .32_set_dl or .1612_set_dl to there

	mov dx, msg.using_fix_unit
	call disp_msg_asciz

	mov al, bl
	call disp_al_hex

	mov dx, msg.using_fix_unit_after
.auto:
	call disp_msg_asciz

write:

%if _FAT32_TWO_SECTORS
		; If the sector size is <= 512 bytes and there is a second
		;  FAT32 sector which is an FSINFO sector, write it here.
	test byte [bp + ldHasLBA], 2
	jz .no_fsinfo
	mov dx, msg.info_writing_not
	testopt [cmd_line_flags], clfDontWriteInfo
	jnz .no_fsinfo_message
	testopt [cmd_line_flags], clfWriteInfoToSectorFile
	jz .not_info_to_sector_file

	mov dx, msg.info_writing_sector_file
	call disp_msg_asciz
	mov di, cmd_line_sector_file
	call open_file
	jc exit_error

	mov ax, 4200h
	xor cx, cx
	mov dx, 512		; seek offset 512
	int 21h

	jmp @F


.not_info_to_sector_file:
	testopt [cmd_line_flags], clfWriteInfoToFile
	jz .not_info_to_file

	mov dx, msg.info_writing_file
	call disp_msg_asciz
	mov di, cmd_line_info_file
	call open_file
	jc exit_error

@@:
	mov dx, sector_buffer + 512
	call write_file_ae_512_bytes
	jc exit_error
	jmp .no_fsinfo


.not_info_to_file:
	mov dx, msg.info_writing_sector
	call disp_msg_asciz
	mov bx, sector_buffer + 512
	mov ax, word [bp + bsBPB + ebpbFSINFOSector]
	xor dx, dx
	mov cl, [drivenumber]
	call write_ae_512_bytes
	jc exit_error
	jmp .no_fsinfo


.no_fsinfo_message:
	call disp_msg_asciz

.no_fsinfo:
%endif

	mov dx, msg.sector_writing_not
	testopt [cmd_line_flags], clfDontWriteSector
	jnz exit_normal_message
	testopt [cmd_line_flags], clfWriteSectorToFile
	jz .not_sector_to_file

	mov dx, msg.sector_writing_file
	call disp_msg_asciz
	mov di, cmd_line_sector_file
	call open_file
	jc exit_error_restore_fsinfo

	mov ax, 4200h		; seek from start of file
	xor cx, cx
	xor dx, dx		; seek offset 0
	int 21h			; seek to start of file

	mov dx, sector_buffer	; -> buffer
	call write_file_ae_512_bytes
	jc exit_error_restore_fsinfo
	jmp exit_normal


.not_sector_to_file:
	mov dx, msg.sector_writing_sector
	call disp_msg_asciz
	mov bx, sector_buffer
	xor ax, ax
	xor dx, dx
	mov cl, [drivenumber]
		; If sector size is >= 1 KiB, this writes both sectors for
		;  the FAT32 two-sector case.
	call write_ae_512_bytes
	jnc exit_normal

exit_error_restore_fsinfo:
%if _FAT32_TWO_SECTORS
		; If the boot sector failed to write after FSINFO was
		;  already written, try to restore FSINFO.
	test byte [bp + ldHasLBA], 2
	jz @F
		; If haven't written, do not restore.
	testopt [cmd_line_flags], clfDontWriteInfo
	jnz @F
		; If have written to a file, do not restore.
	testopt [cmd_line_flags], clfWriteInfoToFile | clfWriteInfoToSectorFile
	jnz @F

	mov dx, msg.info_restoring_sector
	call disp_msg_asciz

	mov bx, second_sector_buffer + 512
	mov ax, word [bp + bsBPB + ebpbFSINFOSector]
	xor dx, dx
	mov cl, [drivenumber]
	call write_ae_512_bytes
	jnc @F

	mov dx, msg.critical_fail_fsinfo_changed
	call disp_msg_asciz
@@:
%endif

exit_error:
	call restorestate
	mov ax, 4C01h
	int 21h


exit_normal_message:
	call disp_msg_asciz

exit_normal:
	call restorestate
	mov ax, 4C00h
	int 21h


		; INP:	ds:di -> cmd_line_file structure
		;		(word pointer to name, word handle)
		; OUT:	File opened,
		;	 bx = file handle
		;	Jumps to disp_dos_error then disp_error if error
		; CHG:	ax, bx, cx, dx, si
		; Note:	We never close our files, instead relying on the
		;	 process termination to close them.
open_file:
		; Is it already open ?
	mov bx, word [di + cmd_line_file_handle_ofs]
	cmp bx, -1
	je @F
	clc
	retn

@@:

	call .setup_opencreate			; ds:si -> pathname
	mov ax, 716Ch				; LFN open-create
	push di
	xor di, di				; alias hint
	stc
	int 21h
	pop di
	jnc .got		; LFN call succeeded -->

		; Early case for no-LFN-interface available.
	; cmp ax, 1
	; je .try_sfn
	cmp ax, 7100h
	je .try_sfn

		; Only now, we check whether the used drive supports LFNs.
		; If it does, then we treat the error received as an
		; actual error and cancel here. If not, the SFN function
		; is called next as a fallback.
		;
		; We cannot rely on specific error returns like the
		; expected 7100h CY (or 7100h CF-unchanged) or the similar
		; 0001h CY (Invalid function) because no one agrees on what
		; error code to use.
		;
		; dosemu returns 0003h (Path not found) on FATFS and
		; redirected-non-dosemu drives. But may be changed so as to
		; return 0059h (Function not supported on network).
		; MSWindows 98SE returns 0002h (File not found) on
		; DOS-redirected drives.
		; DOSLFN with Fallback mode enabled supports the call (albeit
		; limited to SFNs).
		;
		; To suss out what the error means, check LFN availability.
		;
		; Refer to https://github.com/stsp/dosemu2/issues/770
	push ds
	push es
	push di
	push ax
	lframe
	lvar 34, fstype_buffer
	lvar 4, pathname_buffer
	lenter

	push ss
	pop ds
	mov dx, sp		; ds:dx -> ?pathname_buffer
	push ss
	pop es
	mov di, sp		; es:di -> ?pathname_buffer

	lodsw			; load first two bytes of pathname
	cmp ah, ':'		; starts with drive specifier ?
	je @F			; yes -->

	mov ah, 19h
	int 21h			; get current default drive
	add al, 'A'		; A: = 0, convert to drive letter
	mov ah, ':'		; drive specifier
@@:
	stosw
	mov ax, '\'		; backslash and zero terminator
	stosw			; es:di -> ?fstype_buffer

	xor ax, ax
	mov cx, 34 >> 1
	push di
	rep stosw		; initialise ?fstype_buffer to all zeros
	pop di			; -> ?fstype_buffer

	mov cx, 32		; size of ?fstype_buffer
	xor bx, bx		; harden, initialise this
	mov ax, 71A0h		; get volume information
	stc
	int 21h

	jc @F			; if call not supported -->
				; bx = FS flags
	test bh, 0100_0000b	; LFN interface available ?
	stc			; if no
	jz @F			; no -->

	clc			; is available
@@:

	lleave
	pop ax			; (restore error code)
	pop di
	pop es
	pop ds
	jnc .error		; if LFN interface is available, actual error
				; if LFN interface is not available, try SFN

.try_sfn:
	call .setup_opencreate
	mov ax, 6C00h				; Open-create
	stc
	int 21h
	jnc .got

	cmp ax, 1
	je .try_old_create
	cmp ax, 6C00h
	jne .error

.try_old_create:
	mov ah, 3Ch				; Create (Create/Truncate)
	mov dx, si				; -> filename
						; cx = create attribute
	stc
	int 21h
	jc .error

.got:
	mov bx, ax
	mov word [di + cmd_line_file_handle_ofs], bx
	clc
	retn

.error:
	mov dx, msg.error_file_open
	call disp_dos_error
	stc
	retn

.setup_opencreate:
	mov si, word [di + cmd_line_file_name_ofs]	; -> filename
	mov bx, 0110_0000_0010_0001b		; Auto-commit, no int 24h
						; DENY WRITE, Write-only
	xor cx, cx				; create attribute
	mov dx, 0000_0000_0001_0010b		; create / open-truncate
	retn


disp_dos_error:
	call disp_msg_asciz
	mov dx, msg.dos_error_msg_1
	call disp_msg_asciz
	call disp_ax_hex
	mov dx, msg.dos_error_msg_2
	call disp_msg_asciz
	mov dx, msg.dos_error_unknown
	cmp ax, dos_error_table.after_last
	jae @F
	mov bx, ax
	shl bx, 1
	mov dx, word [dos_error_table + bx]
@@:
	call disp_msg_asciz
	mov dx, msg.dos_error_msg_3
	jmp disp_msg_asciz


		; INP:	ds:dx -> buffer
		;	bx = handle
write_file_ae_512_bytes:
	mov cx, word [bp + ldBytesPerSector]
	cmp cx, 512		; more than 512 bytes ?
	ja @F			; yes -->
	mov cx, 512		; fix sector size
@@:
	mov ah, 40h
	int 21h			; write file
	jnc @F			; (NC) -->
	mov dx, msg.error_file_write
	call disp_dos_error
	stc
@@:
	retn


unit_search_strings:
.mov:	mov bp, 7C00h
.mov_length: equ $ - .mov
.1612_set_bpbn:		mov byte [bp + bsBPB + bpbNew + bpbnBootUnit], dl
.1612_set_bpbn_length:	equ $ - .1612_set_bpbn
.1612_set_dl:		mov dl, byte [bp + bsBPB + bpbNew + bpbnBootUnit]
.1612_set_dl_length:	equ $ - .1612_set_dl
%if .1612_set_bpbn_length != .1612_set_dl_length
 %error Unit fixing replacement string not same length!
%endif

.32_set_bpbn:		mov byte [bp + bsBPB + ebpbNew + bpbnBootUnit], dl
.32_set_bpbn_length:	equ $ - .32_set_bpbn
.32_set_dl:		mov dl, byte [bp + bsBPB + ebpbNew + bpbnBootUnit]
.32_set_dl_length:	equ $ - .32_set_dl
%if .32_set_bpbn_length != .32_set_dl_length
 %error Unit fixing replacement string not same length!
%endif


		; INP:	ds:si -> first byte to check for name
		;	cx = number of bytes left
		; OUT:	(8+1+3+1)bytes[msg.foundname] = found name,
		;	 converted to 8.3 ASCIZ format,
		;	 "(None)" if none
		;	CY if no filename found,
		;	 si = INP:si + INP:cx
		;	 cx = 0
		;	NC if filename found,
		;	 si -> byte behind the name, thus (si-11)-> name
		;	 cx = number of bytes left
		; CHG:	di, ax
		; STT:	ds = es
findname:
.:
	cmp cx, 11		; enough for another name ?
	jb .none		; no -->
				; (cx == 0 jumps here too)
.check:
	push cx
	push si
	mov cx, 11
	lodsb
	mov ah, al		; check for same char in all 11 places
	cmp al, 32		; first character must not be blank
	je .check_fail		; if it is -->
;	cmp al, 5		; first character may be 05h to indicate 0E5h
;	je .check_pass
	db __TEST_IMM8		; (skip lodsb)
.check_loop_same:
	lodsb
	cmp ah, al
	jne .check_loop_differs
	call .check_character
	jc .check_fail
	loop .check_loop_same
		; if we arrive here, all characters (while valid) are the
		;  same character repeated 11 times. we disallow this in case
		;  that the padding character is an allowed one (eg '&' 26h).
.check_fail:
	pop si
	pop cx
	dec cx			; lessen the counter
	inc si			; -> next position to check
	jmp .

.check_character:
	cmp al, 32
	jb .check_character_fail
	cmp al, 127
;	je .check_character_fail
	jae .check_character_fail
		; note: with all characters >= 128 allowed,
		;  we get false positives in our sectors.
	cmp al, '.'
	je .check_character_fail
	cmp al, '/'
	je .check_character_fail
	cmp al, '\'
	je .check_character_fail
	cmp al, 'a'
	jb .check_character_pass
	cmp al, 'z'
	ja .check_character_pass
.check_character_fail:
	stc
	retn

.check_character_pass:
	clc
	retn

.check_loop:
	lodsb
.check_loop_differs:
	call .check_character
	jc .check_fail
.check_pass:
	loop .check_loop

	pop ax			; (discard si)
	sub si, 11		; -> at name

	call convert_name_to_asciz
				; si -> behind name
	pop cx
	sub cx, 11		; lessen the counter
	clc
	retn

.none:
	 add si, cx
	mov di, msg.foundname
	 push si
	mov si, msg.foundname_none
	mov cx, (msg.foundname_none_size + 1) >> 1
	rep movsw
	 pop si
	 xor cx, cx
	stc
	retn


		; INP:	si -> 11-byte blank-padded name
		;	msg.foundname -> (8+1+3+1)-byte buffer
		; OUT:	si -> behind 11-byte blank-padded name
		;	msg.foundname filled
		; CHG:	cx, di, ax
convert_name_to_asciz:
	mov di, msg.foundname
	mov cx, 8
	rep movsb		; copy over base name, si -> extension
	cmp byte [di - 8], 05h	; is it 05h ?
	jne @F			; no -->
	mov byte [di - 8], 0E5h	; yes, convert to 0E5h
@@:

	db __TEST_IMM8		; (skip dec)
@@:
	dec di			; decrement -> at previous trailing blank
	cmp byte [di - 1], 32	; trailing blank ?
	je @B			; yes -->

	mov al, '.'
	stosb			; store dot (if needed)
	mov cl, 3
	rep movsb		; copy over extension, si -> behind name

	db __TEST_IMM8		; (skip dec)
@@:
	dec di			; decrement -> at previous trailing blank
	cmp byte [di - 1], 32	; trailing blank ?
	je @B			; yes -->

	cmp byte [di - 1], '.'	; trailing dot ? (only occurs if all-blank ext)
	jne @F			; no -->
	dec di			; -> at the dot
@@:
	mov al, 0
	stosb			; store filename terminator
	retn


		; INP:	ds:si-> first letter of name
		;	es:load_kernel_name-> 12-byte buffer (for fn + 0)
		; CHG:	ax, cx, di
		; OUT:	NC if valid name,
		;	 al = first character after name (EOL, blank, or slash)
		;	 si -> next character
		;	CY else
		; STT:	es = ds
boot_parse_fn:
	mov al, 32
	mov di, load_kernel_name
	mov cx, 11
	rep stosb		; initialise to empty

	mov di, load_kernel_name
	mov cx, 9
.loop_name:
	lodsb
	call uppercase
	cmp al, '"'
	je .invalid
	call iseol?
	je .loop_name_done
	cmp al, 32
	je .loop_name_done
	cmp al, 9
	je .loop_name_done
	cmp al, '/'
	je .loop_name_done
	cmp al, '\'
	je .loop_name_done
	cmp al, '.'
	je .loop_name_ext
	stosb
	loop .loop_name
.invalid:
	stc
	retn

.loop_name_ext:
	cmp cx, 9
	je .invalid
	mov cx, 4
	mov di, load_kernel_name + 8
.loop_ext:
	lodsb
	call uppercase
	cmp al, '"'
	je .invalid
	call iseol?
	je .loop_ext_done
	cmp al, 32
	je .loop_ext_done
	cmp al, 9
	je .loop_ext_done
	cmp al, '/'
	je .loop_ext_done
	cmp al, '\'
	je .loop_ext_done
	cmp al, '.'
	je .invalid
	stosb
	loop .loop_ext
	jmp .invalid

.loop_ext_done:
	cmp cx, 4
	je .invalid
.loop_name_done:
	cmp cx, 9
	je .invalid
	mov byte [load_kernel_name + 11], 0
	cmp byte [load_kernel_name], 0E5h
	jne @F
	mov byte [load_kernel_name], 05h
@@:
	clc
	retn


iseol?:
	cmp al, 13
	je .ret
;	cmp al, ';'
;	je .ret
	cmp al, 0
.ret:
	retn


		; Check for given string (cap-insensitive)
		;
		; INP:	si-> input string to check (either cap),
		;	 terminated by CR (13), space, tab, comma
		;	dx-> ASCIZ string to check (all-caps)
		; OUT:	Iff string matches,
		;	 si-> at separator that terminates the keyword
		;	else,
		;	 si = input si
		; STT:	ds = es = ss
		; CHG:	dx, ax
isstring?:
	push si
	xchg dx, di
.loop:
	lodsb
	call uppercase
	scasb
	jne .mismatch
	test al, al
	jne .loop
	jmp .matched_zr

.mismatch:
	call iseol?
	je .checkend
	cmp al, 32
	je .checkend
	cmp al, 9
	je .checkend
	cmp al, ','
	je .checkend
	cmp al, '='
	je .checkend
.ret_nz:
		; NZ
	pop si
.ret:
	xchg dx, di
	retn

.checkend:
	cmp byte [es:di - 1], 0
	jne .ret_nz
.matched_zr:	; ZR
	pop ax			; (discard)
	lea si, [si - 1]	; -> separator
	jmp .ret


uppercase:
	cmp al, 'a'
	jb @F
	cmp al, 'z'
	ja @F
	and al, ~20h
@@:
	retn


		; INP:	al = first character
		;	si -> next
		; OUT:	doesn't return if error
		;	bx:dx = number read
		;	al = character after the number
		;	si -> next
		; CHG:	cx, ax, di
get_decimal_literal:
	mov dx, 10		; set base: decimal
%if 1
	mov cx, '9' | (('A'-10-1 + 10) << 8)
%else
	mov cl, dl
	add cl, '0'-1
	cmp cl, '9'
	jbe .lit_basebelow11
	mov cl, '9'
.lit_basebelow11:		; cl = highest decimal digit for base ('1'..'9')
	mov ch, dl
	add ch, 'A'-10-1	; ch = highest letter for base ('A'-x..'Z')
%endif
	jmp @F


get_hexadecimal_literal:
	mov dx, 16		; set base: hexadecimal
%if 1
	mov cx, '9' | (('A'-10-1 + 16) << 8)
%else
	mov cl, dl
	add cl, '0'-1
	cmp cl, '9'
	jbe .lit_basebelow11
	mov cl, '9'
.lit_basebelow11:		; cl = highest decimal digit for base ('1'..'9')
	mov ch, dl
	add ch, 'A'-10-1	; ch = highest letter for base ('A'-x..'Z')
%endif

@@:
	mov ah, 0
	xor bx, bx
	mov di, dx		; di = base

	call getexpression.lit_isdigit?	; first character must be a digit
	jc .err2
	xor dx, dx		; initialize value
.lit_loopdigit:
	cmp al, '_'
	je .lit_skip
	call getexpression.lit_isdigit?	; was last character ?
	jc .lit_end		; yes -->
	call uppercase
	sub al, '0'
	cmp al, 9		; was decimal digit ?
	jbe .lit_decimaldigit	; yes -->
	sub al, 'A'-('9'+1)	; else adjust for hexadecimal digit
.lit_decimaldigit:
	push ax
	mov ax, dx
	push bx
	mul di			; multiply low word with base
	mov bx, dx
	mov dx, ax
	pop ax
	push dx
	mul di			; multiply high word with base
	test dx, dx
	pop dx
	jnz .err2		; overflow -->
	add bx, ax		; add them
	pop ax
	jc .err2		; overflow -->
	add dl, al		; add in the new digit
	adc dh, 0
	adc bx, byte 0
.lit_skip:
	lodsb
	jmp short .lit_loopdigit

.lit_end:
	call isseparator?	; after the number, there must be a separator
	jne .err2		; none here -->
	retn

.err2:
	mov dx, msg.error_invalid_number
	jmp disp_error


getexpression.lit_ishexdigit?:
	mov cx, "9F"
getexpression.lit_isdigit?:
	cmp al, '0'
	jb .no
	cmp al, cl
	jbe .yes
	push ax
	call uppercase
	cmp al, ch
	ja .no_p
	cmp al, 'A'
	jb .no_p
	pop ax
.yes:
	clc
	retn

.no_p:
	pop ax
.no:
	stc
	retn


		; INP:	al = character
		; OUT:	al = capitalised character
		;	ZR, NC if a separator
		;	NZ if no separator
isseparator?:
	call uppercase
	push cx
%if 0	; _EXPRESSIONS
	call isoperator?	; normal operators are separators (also handles equality sign)
	je .yes			; if match --> (ZR, NC)
%endif
	push di
	mov di, separators
	mov cx, word [di]
	scasw
	repne scasb		; ZR, NC on match, NZ else
	pop di
.yes:
	pop cx
	retn

%if 0	; _EXPRESSIONS
separators:	countedw 32,9,13,",L;]:)",0
%else
separators:	countedw 32,9,13,",L;]:",0
%endif


i24:
	mov al, 3			; always return fail, to handle the error as a soft one
	iret

i23:
	mov word [ cs:$ ], (__JMP_REL8|__REL16__(.return)<<8)	; don't reenter
	call restorestate
.return:
	stc				; always abort program (what default DOS handler also does)
	retf

		; Restore modified DOS data
		;
		; CHG:	-
restorestate:
	push ax
%if _VDD
		; Release the registered VDD.
	testopt [internalflags], ntpacket
	jz .novdd
	mov ax, word [hVdd]
	UnRegisterModule
.novdd:
%endif
	pop ax
	retn


		; INP: es:dx = ds:dx -> 0-terminated message
disp_msg_asciz:
	push ax
	push bx
	push cx
	push di
	mov bx, 1
	mov ax, 4000h
	mov di, dx
	mov cx, -1
	repne scasb	; -> after nul
	dec di		; -> at nul
	sub di, dx	; size
	mov cx, di
	int 21h
	pop di
	pop cx
	pop bx
	pop ax
	retn


disp_ax_hex:
		xchg al, ah
		call disp_al_hex
		xchg al, ah
disp_al_hex:
		push cx
		mov cl, 4
		ror al, cl
		call .nibble
		ror al, cl
		pop cx
.nibble:
		push ax
		and al, 0Fh
		add al, '0'
		cmp al, '9'
		jbe .isdigit
		add al, 'A'-('9'+1)
.isdigit:
		push dx
		xchg dl, al
		mov ah, 02h
		int 21h
		pop dx
		pop ax
		retn


	; Following call: Display number in ax decimal
	; all registers preserved except dx
disp_ax_dec:			; ax (no leading zeros)
	; In: number in ax
	; Out: displayed
		push bx
		xor bx, bx
.pushax:
		push ax
.pushend:
		or bl, bl
		jz .nobl
		sub bl, 5
		neg bl
.nobl:
		push cx
		mov cx, 10000
		call .divide_out
		mov cx, 1000
		call .divide_out
		mov cx, 100
		call .divide_out
		mov cl, 10
		call .divide_out
							; (Divisor 1 is useless)
		add al, '0'
		xchg dl, al
		mov ah, 02h
		int 21h
		pop cx
		pop ax
		pop bx					; Caller's register
		retn

.divide_out:
	; In: ax = number
	;     cx = divisor
	; Out: ax = remainder of operation
	;      result displayed
		push dx
		xor dx, dx
		div cx				; 0:ax / cx
		push dx				; remainder
		dec bl
		jnz .nobl2
		or bh, 1
.nobl2:
		or bh, al
		jz .leadingzero
		add al, '0'
		xchg dl, al
		mov ah, 02h
		int 21h				; display result
 .leadingzero:
		pop ax				; remainder
		pop dx
		retn


		; INP:	dx:ax = sector to write
		;	cl = drive to write to (0 = A:)
		;	ds:bx -> buffer
		; STT:	ds = ss
		; OUT:	CY if failure, error message displayed to stdout
		;	NC if success
		;	dx:ax = incremented
		;	ds:bx -> behind buffer
		;	(bx += word[bp + ldBytesPerSector]
write_sector:
	push ax
	push dx
	push bx
	push cx
	push si
.plw1:
	push cx
	add cl, 'A'
	mov byte [driveno], cl
	pop cx
	testopt [internalflags], oldpacket| newpacket| ntpacket
	jnz .plw3		; if using a packet -->
	test dx, dx
	jnz .error_sector_not_found
	xchg ax, dx		; dx = sector to write
	xchg ax, cx		; al = drive number
	mov cx, 1
.oldint:
	int 26h
	inc sp
	inc sp
	jmp .done

		; disk I/O packet for Int25/Int26, Int21.7305, VDD
.plw3:
	push bx
	mov bx, packet
	mov word [bx+0], ax	; LoWord sector number
	mov word [bx+2], dx	; HiWord sector number
	mov word [bx+4], 1	; number of sectors
	mov al, cl
	pop word [bx+6]		; transfer address ofs
	mov word [bx+8], ds	; transfer address seg
	mov cx, -1

	testopt [ss:internalflags], newpacket| ntpacket
	jz .oldint
	mov dl, al		; A: = 0, ...
	mov si, 0001h		; write, assume "unknown data"
%if _VDD
	testopt [internalflags], ntpacket
	jnz .vdd
%endif
	inc dl			; A: = 1, ...
	call lockdrive
	mov ax, 7305h		; ds:(e)bx-> packet
	stc
	int 21h
	pushf
	call unlockdrive
	popf
	jmp short .done
%if _VDD
.vdd:
	mov ax, word [hVdd]
	mov cx, 5
	DispatchCall
	jmp short .done
%endif
.error_sector_not_found:
	mov al, 8		; "sector not found"
.done:
	mov dx, writing
.ww1:
	jnc .ww3		; if no error
	cmp al, 0Ch
	jbe .ww2		; if in range
	mov al, 0Ch
.ww2:
	cbw			; ah = 0
	mov bx, dskerrs		; -> byte table
	xlatb			; get offset from dskerrs
	add ax, bx		; -> message
	xchg ax, dx		; dx-> diskerrs message
	call disp_msg_asciz
	xchg ax, dx		; dx-> writing/reading
	call disp_msg_asciz
	mov dx, drive		; dx-> "ing drive _"
	call disp_msg_asciz
	stc
.ww3:
	pop si
	pop cx
	pop bx
	pop dx
	pop ax
	 pushf
	inc ax
	jnz @F
	inc dx
@@:
	add bx, word [bp + ldBytesPerSector]
	 popf
	retn


		; INP:	dx:ax = sector to read
		;	cl = drive to read from (0 = A:)
		;	ds:bx -> buffer
		; STT:	ds = ss
		; OUT:	CY if failure, error message displayed to stdout
		;	NC if success
		;	dx:ax = incremented
		;	ds:bx -> behind buffer
		;	(bx += word[bp + ldBytesPerSector]
read_sector:
	push ax
	push dx
	push bx
	push cx
	push si
.plw1:
	push cx
	add cl, 'A'
	mov byte [driveno], cl
	pop cx
	testopt [internalflags], oldpacket| newpacket| ntpacket
	jnz .plw3		; if using a packet -->
	test dx, dx
	jnz .error_sector_not_found
	xchg ax, dx		; dx = sector to read
	xchg ax, cx		; al = drive number
	mov cx, 1
.oldint:
	int 25h
	inc sp
	inc sp
	jmp .done

		; disk I/O packet for Int25/Int26, Int21.7305, VDD
.plw3:
	push bx
	mov bx, packet
	mov word [bx+0], ax	; LoWord sector number
	mov word [bx+2], dx	; HiWord sector number
	mov word [bx+4], 1	; number of sectors
	mov al, cl
	pop word [bx+6]		; transfer address ofs
	mov word [bx+8], ds	; transfer address seg
	mov cx, -1

	testopt [ss:internalflags], newpacket| ntpacket
	jz .oldint
	mov dl, al		; A: = 0, ...
	mov si, 0000h		; read, assume "unknown data"
%if _VDD
	testopt [internalflags], ntpacket
	jnz .vdd
%endif
	inc dl			; A: = 1, ...
	call lockdrive
	mov ax, 7305h		; ds:(e)bx-> packet
	stc
	int 21h
	pushf
	call unlockdrive
	popf
	jmp short .done
%if _VDD
.vdd:
	mov ax, word [hVdd]
	mov cx, 5
	DispatchCall
	jmp short .done
%endif
.error_sector_not_found:
	mov al, 8		; "sector not found"
.done:
	mov dx, reading
	jmp write_sector.ww1



		; INP:	dx:ax = first sector
		;	ds:bx -> buffer
		;	cl = drive number
		; OUT:	dx:ax = sector number after last written
		;	ds:bx -> buffer after last read
		; CHG:	-
		; STT:	ds = ss
write_ae_512_bytes:
	push di
	mov di, 512
.loop:
	call write_sector
	jc .error
	sub di, word [bp + ldBytesPerSector]
	ja .loop
	clc
.error:
	pop di
	retn

		; INP:	dx:ax = first sector
		;	ds:bx -> buffer
		;	cl = drive number
		; OUT:	dx:ax = sector number after last read
		;	ds:bx -> buffer after last written
		; CHG:	-
		; STT:	ds = ss
read_ae_512_bytes:
	push di
	mov di, 512
.loop:
	call read_sector
	jc .error
	sub di, word [bp + ldBytesPerSector]
	ja .loop
	clc
.error:
	pop di
	retn


lockdrive:
	push ax
	push bx
	push cx
	push dx
	mov bl, al
	inc bl
	mov bh, 0
	mov cx, 084Ah
	mov dx, 0001h
	mov ax, 440Dh
	int 21h
	pop dx
	pop cx
	pop bx
	pop ax
	retn

unlockdrive:
	push ax
	push bx
	push cx
	push dx
	mov bl, al
	inc bl
	mov bh, 0
	mov cx, 086Ah
	mov dx, 0001h
	mov ax, 440Dh
	int 21h
	pop dx
	pop cx
	pop bx
	pop ax
	retn


	align 4
internalflags:	dd 0
oldpacket	equ	  1	; Int25/Int26 packet method available (L, W)
newpacket	equ	  2	; Int21.7305 packet method available (L, W)
ntpacket	equ	  4	; VDD registered and usable (L, W)
runningnt	equ   20000h	; running in NTVDM
hVdd:		dw 0
load_unit:	dw 0FF00h
drivenumber:	db 0

	align 4
packet:	dd 0		; sector number
	dw 0		; number of sectors to read
	dd 0		; transfer address Segm:OOOO

msg:
.help:	db "INSTSECT: Install boot sectors. 2018 by C. Masloch",13,10
	db 13,10
	db "Usage of the works is permitted provided that this",13,10
	db "instrument is retained with the works, so that any entity",13,10
	db "that uses the works is notified of this instrument.",13,10
	db 13,10
	db "DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.",13,10
	db 13,10
	db "Options:",13,10
	db 9,"a:",9,9,"load or update boot sectors of specified drive",13,10
	db 13,10
	db 9,"/Fx=filename",9,"replace Xth name in the boot sector, X = 1 to ",'0' + NUM_REPLACEMENTS,13,10
	db 9,"/F=filename",9,"alias to /F1=filename",13,10
	db 9,"/U AUTO",9,9,"leave in default auto-boot-unit handling (default)",13,10
	db 9,"/U xx",9,9,"patch boot loader to use XXh as a fixed unit",13,10
	db 13,10
	db 9,"/BS",9,9,"write boot sector to drive's boot sector (default)",13,10
	db 9,"/B=filename",9,"write boot sector to file, not to drive",13,10
	db 9,"/BN",9,9,"do not write boot sector",13,10
	db 9,"/BR",9,9,"replace boot sector loader with built-in one (default)",13,10
	db 9,"/BO",9,9,"keep original boot sector",13,10
	db 13,10
	db "Only applicable for FAT32 with sector size below or equal to 512 bytes:",13,10
	db 9,"/IS",9,9,"write FSIBOOT to drive's FSINFO sector (default)",13,10
	db 9,"/I=filename",9,"write FSIBOOT to file, not to drive",13,10
	db 9,"/IB",9,9,"write FSIBOOT to boot sector file (see /B=filename)",13,10
	db 9,"/IN",9,9,"do not write FSIBOOT",13,10
	db 9,"/IR",9,9,"replace FSINFO with built-in FSIBOOT (default)",13,10
	db 9,"/IO",9,9,"keep original FSINFO",13,10
	asciz

.boot_access_error:	asciz "Access error.", 13,10
.boot_sector_too_large:	asciz "Sector size too small (< 32 bytes).", 13,10
.boot_sector_too_small:	asciz "Sector size too large (> 8192 bytes).", 13,10
.boot_sector_not_power:	asciz "Sector size not a power of two.", 13,10
.out_of_memory:		asciz "Out of memory.",13,10
.switch_not_supported:	asciz "Switch not supported.",13,10
.invalid_argument:	asciz "Invalid argument.",13,10
.no_drive_specified:	asciz "No drive specified.",13,10
.error_multiple_drives:	asciz "Multiple drives specified.",13,10
.no_sector_file_specified:
		asciz "No boot sector file specified for /IB switch.",13,10
.bootfail_sig:	asciz "Boot sector signature missing (is not AA55h).",13,10
.bootfail_sig2:	asciz "Big boot sector signature missing (is not AA55h).",13,10
.bootfail_secsizeinvalid:
		asciz "Sector size is invalid (not a power of two).",13,10
.bootfail_secsizediffer:
		asciz "BPB BpS differs from actual sector size.",13,10
.boot_badclusters:	asciz "Bad amount of clusters.",13,10
.boot_badchain:		asciz "Bad cluster chain.",13,10
.no_fsinfo:	asciz "No FSINFO sector found.",13,10
.critical_fail_fsinfo_changed:
		asciz "Failure to write back original FSINFO!",13,10
.is_fat12:	asciz "Detected FAT12 FS.",13,10
.is_fat16:	asciz "Detected FAT16 FS.",13,10
.is_fat32:	asciz "Detected FAT32 FS.",13,10
%if !_FAT32 || !_FAT16 || !_FAT12
.not_supported_fat_type:
		asciz "This FAT type is not supported in this build.",13,10
%endif

	align 4
load_kernel_name: equ $
	times 12 db 0
		; buffer for base name (8) + ext (3) + NUL (1) = 12
.name_replacements:
	times 12 * NUM_REPLACEMENTS db 0
		; name replacement buffers, 4 times same as load_kernel_name
	align 4
.foundname:
	times 8+1+3+1 db 0
		; buffer for base name (8) + dot (1) + ext (3) + NUL (1)
	align 2
.foundname_none:
	asciz "(None)"
.foundname_none_size: equ $ - .foundname_none
	align 4
.names:
	dw .name_first, 0
	dw .name_second, 0
	dw .name_third, 0
	dw .name_fourth, 0
	dw 0
.name_first:	asciz "1st name"
.name_second:	asciz "2nd name"
.name_third:	asciz "3rd name"
.name_fourth:	asciz "4th name"
.name_before:	asciz ": "
.name_quote:	asciz '"'
.name_after:	asciz 13,10
.name_none:	asciz "No name detected.",13,10

.no_name_found_before:	asciz "No "
.no_name_found_after:	asciz " for replacement found!",13,10

.replacing_before:	asciz "Replacing "
.replacing_between:	asciz " with ",'"'
.replacing_after:	asciz '".',13,10
.auto:			asciz "AUTO"
.error_invalid_number:	asciz "Invalid number.",13,10
.using_fix_unit:	asciz "Using fixed unit of "
.using_fix_unit_after:	asciz "h.",13,10
.unit_not_found:	asciz "Unit fixing code not found in sector.",13,10
.using_auto_unit:	asciz "Using auto unit.",13,10

.switch_requires_filename:
			asciz "Switch requires a filename.",13,10
.switch_filename_missing_unquote:
			asciz "Switch filename missing ending quote.",13,10
.switch_filename_empty:
			asciz "Switch filename is empty.",13,10

.info_writing_not:	asciz "Not writing FSINFO.",13,10
.info_writing_sector_file:
			asciz "Writing FSINFO to boot sector file.",13,10
.info_writing_file:	asciz "Writing FSINFO to file.",13,10
.info_writing_sector:	asciz "Writing FSINFO to sector.",13,10
.sector_writing_not:	asciz "Not writing boot sector.",13,10
.sector_writing_file:	asciz "Writing boot sector to file.",13,10
.sector_writing_sector:	asciz "Writing boot sector to sector.",13,10
.info_restoring_sector:	db "Error while writing boot sector,"
			asciz " restoring FSINFO sector.",13,10


.error_file_open:	asciz "Error opening file for writing, "
.error_file_write:	asciz "Error writing file, "
.dos_error_msg_1:	asciz "DOS error "
.dos_error_msg_2:	asciz "h ("
.dos_error_msg_3:	asciz ").",13,10

.dos_error_0:		asciz "No error"
.dos_error_1:		asciz "Invalid function"
.dos_error_2:		asciz "File not found"
.dos_error_3:		asciz "Path not found"
.dos_error_4:		asciz "No handles available"
.dos_error_5:		asciz "Access denied"
.dos_error_6:		asciz "Invalid handle"
.dos_error_7:		asciz "MCB destroyed"
.dos_error_8:		asciz "Out of memory"
.dos_error_9:		asciz "MCB invalid"
.dos_error_10:		asciz "Environment invalid"
.dos_error_11:		asciz "Format invalid"
.dos_error_12:		asciz "Access code invalid"
.dos_error_13:		asciz "Data invalid"
.dos_error_14:		asciz "Fixup overflow"
.dos_error_15:		asciz "Invalid drive"
.dos_error_16:		asciz "Attempted to remove current directory"
.dos_error_17:		asciz "Not same device"
.dos_error_18:		asciz "No more files"
.dos_error_19:		asciz "Disk write protected"
.dos_error_20:		asciz "Unknown unit"
.dos_error_21:		asciz "Drive not ready"
.dos_error_22:		asciz "Unknown command"
.dos_error_23:		asciz "Data error"
.dos_error_24:		asciz "Bad request structure length"
.dos_error_25:		asciz "Seek error"
.dos_error_26:		asciz "Unknown media type"
.dos_error_27:		asciz "Sector not found"
.dos_error_28:		asciz "Printer out of paper"
.dos_error_29:		asciz "Write fault"
.dos_error_30:		asciz "Read fault"
.dos_error_31:		asciz "General failure"
.dos_error_32:		asciz "Sharing violation"
.dos_error_33:		asciz "Lock violation"
.dos_error_34:		asciz "Disk change invalid"
.dos_error_35:		asciz "FCB unavailable"
.dos_error_36:		asciz "Sharing buffer overflow"
.dos_error_37:		asciz "Code page mismatch"
.dos_error_38:		asciz "Cannot complete file operation"
.dos_error_39:		asciz "Insufficient disk space"
.dos_error_unknown:	asciz "Unknown error"


dos_error_table:
.:
	dw msg.dos_error_0
	dw msg.dos_error_1
	dw msg.dos_error_2
	dw msg.dos_error_3
	dw msg.dos_error_4
	dw msg.dos_error_5
	dw msg.dos_error_6
	dw msg.dos_error_7
	dw msg.dos_error_8
	dw msg.dos_error_9
	dw msg.dos_error_10
	dw msg.dos_error_11
	dw msg.dos_error_12
	dw msg.dos_error_13
	dw msg.dos_error_14
	dw msg.dos_error_15
	dw msg.dos_error_16
	dw msg.dos_error_17
	dw msg.dos_error_18
	dw msg.dos_error_19
	dw msg.dos_error_20
	dw msg.dos_error_21
	dw msg.dos_error_22
	dw msg.dos_error_23
	dw msg.dos_error_24
	dw msg.dos_error_25
	dw msg.dos_error_26
	dw msg.dos_error_27
	dw msg.dos_error_28
	dw msg.dos_error_29
	dw msg.dos_error_30
	dw msg.dos_error_31
	dw msg.dos_error_32
	dw msg.dos_error_33
	dw msg.dos_error_34
	dw msg.dos_error_35
	dw msg.dos_error_36
	dw msg.dos_error_37
	dw msg.dos_error_38
	dw msg.dos_error_39
.after_last:	equ ($ - .) >> 1


dskerrs:	db dskerr0-dskerrs,dskerr1-dskerrs
		db dskerr2-dskerrs,dskerr3-dskerrs
		db dskerr4-dskerrs,dskerr9-dskerrs
		db dskerr6-dskerrs,dskerr7-dskerrs
		db dskerr8-dskerrs,dskerr9-dskerrs
		db dskerra-dskerrs,dskerrb-dskerrs
		db dskerrc-dskerrs
dskerr0:	asciz "Write protect error"
dskerr1:	asciz "Unknown unit error"
dskerr2:	asciz "Drive not ready"
dskerr3:	asciz "Unknown command"
dskerr4:	asciz "Data error (CRC)"
dskerr6:	asciz "Seek error"
dskerr7:	asciz "Unknown media type"
dskerr8:	asciz "Sector not found"
dskerr9:	asciz "Unknown error"
dskerra:	asciz "Write fault"
dskerrb:	asciz "Read fault"
dskerrc:	asciz "General failure"
reading:	asciz " read"
writing:	asciz " writ"
drive:		db "ing drive "
driveno:	asciz "_",13,10


imsg:
%if _VDD
.vdd:		asciz "DEBXXVDD.DLL"
.dispatch:	asciz "Dispatch"
.init:		asciz "Init"
.mouse:		db "MOUSE",32,32,32		; Looks like a device name
.andy:		db "Andy Watson"		; I don't know him and why he's inside the NTVDM mouse driver
	endarea .andy
.ntdos:		db "Windows NT MS-DOS subsystem Mouse Driver"	; Int33.004D mouse driver copyright string (not ASCIZ)
	endarea .ntdos

		; INP:	-
		; OUT:	CY if not NTVDM
		;	NC if NTVDM
		;	ds = es = cs
		; CHG:	ax, bx, cx, dx, di, si, bp, es, ds
isnt:
		mov ax, 5802h			; Get UMB link state
		int 21h
		xor ah, ah
		push ax				; Save UMB link state
		mov ax, 5803h			; Set UMB link state:
		mov bx, 1			;  Add UMBs to memory chain
		int 21h
		mov ah, 52h
		mov bx, -1
		int 21h				; Get list of lists
		inc bx				; 0FFFFh ?
		jz .notnt			; invalid -->
		mov ax, word [es:bx-3]		; First MCB
		push cs
		pop es				; reset es
.loop:
		mov ds, ax			; ds = MCB
		inc ax				; Now segment of memory block itself
		xor dx, dx
		xor bx, bx
		cmp byte [bx], 'Z'		; End of MCB chain?
		jne .notlast
		inc dx
		jmp short .notchain
 .notlast:
		cmp byte [bx], 'M'		; Valid MCB chain?
		jne .error
 .notchain:
		mov cx, [bx+3]			; MCB size in paragraphs
				; ax = current memory block
				; cx = size of current memory block in paragraphs
				; dx = flag whether this is the last MCB
				; ds = current MCB (before memory block)
		cmp word [bx+1], 8		; MCB owner DOS?
		jne .notfound_1
		cmp word [bx+8], "SD"		; MCB name "SD"?
		jne .notfound_1
.loopsub:
		mov ds, ax			; SD sub-segment inside memory block
		inc ax
		dec cx
		mov bp, word [bx+3]		; Paragraphs 'til end of SD sub-segment
				; ax = current SD sub-segment
				; cx = paragraphs from SD sub-segment start (ax) to current memory block end
				; ds = current SD sub-MCB (like MCB, but for SD sub-segment)
				; bp = current SD sub-segment size in paragraphs
		cmp cx, bp
		jb .notfound_1			; Goes beyond memory block, invalid -->
		cmp byte [bx], 'Q'		; NTVDM type 51h sub-segment ?
		jne .notfound_2			; no -->
		mov si, 8			; Offset of device name (if SD device driver sub-segment)
		mov di, imsg.mouse
		push cx
		mov cx, si			; length of name
		repe cmpsb			; blank-padded device name "MOUSE" ?
		pop cx
		jne .notfound_2			;  Device name doesn't match, try next SD sub-segment
		mov ax, ds
		inc ax
		mov ds, ax			; Segment of SD sub-segment
				; ds = current SD sub-segment
		mov ax, bp			; Leave paragraph value in bp
		test ax, 0F000h			; Would *16 cause an overflow?
		jnz .notfound_3			;  Then too large -->
		push cx
		mov cl, 4
		shl ax, cl			; *16
		pop cx
				; ax = current SD sub-segment size in byte
.andy:
		mov di, imsg.andy
		push cx
		mov cx, imsg.andy_size
		call findstring			; String "Andy Watson"?
		pop cx
		jc .notfound_3
.ntdos:
		mov di, imsg.ntdos
		push cx
		mov cx, imsg.ntdos_size
		call findstring			; String "Windows NT MS-DOS subsystem Mouse Driver"?
		pop cx
		jnc .found			; (NC)
.notfound_3:
		mov ax, ds
.notfound_2:
		cmp cx, bp
		je .notfound_1			; End of SD memory block, get next MCB
		add ax, bp			; Address next SD sub-MCB
		sub cx, bp
		jmp short .loopsub		; Try next SD sub-segment
.notfound_1:
		add ax, cx			; Address next MCB
		test dx, dx			; Non-zero if 'Z' MCB
		jz .loop			; If not at end of MCB chain, try next
		; jmp short .notnt		;  Otherwise, not found
 .error:
 .notnt:
		stc
.found:
		push cs
		pop ds				; restore ds

		pop bx				; saved UMB link state
		mov ax, 5803h
		pushf
		int 21h				; Set UMB link state
		popf
		retn

findstring:
		xor si, si
.loop:
		push si
		add si, cx
		jc .notfound_c
		dec si				; The largest offset we need for this compare
		cmp ax, si
 .notfound_c:
		pop si
		jb .return			; Not found if at top of memory block -->
		push di
		push si
		push cx
		repe cmpsb			; String somewhere inside program?
		pop cx
		pop si
		pop di
		je .return			;  Yes, proceed --> (if ZR, NC)
		inc si				; Increase pointer by one
		jmp short .loop			;  Try next address
.return:
		retn
%endif


initialise:
		; Check DOS version
%if _VDD
	push bp
	call isnt		; NTVDM ?
	pop bp
	jc .isnotnt		; no -->
	setopt [internalflags], runningnt
.isnotnt:
%endif

	mov ax, 3000h		; check DOS version
	int 21h
	xchg al, ah
	cmp ax, ver(3,31)	; MS-DOS version > 3.30 ?
	jb .notoldpacket	; no -->
	setopt [internalflags], oldpacket	; assume Int25/Int26 packet method available
.notoldpacket:
	push ax
	xor bx, bx		; preset to invalid value
	mov ax, 3306h
	int 21h
	or al, al		; invalid, DOS 1.x error -->
	jz .213306invalid
	cmp al, -1		; invalid
.213306invalid:
	pop ax
	je .useoldver
	test bx, bx		; 0.0 ?
	jz .useoldver		; assume invalid -->
	xchg ax, bx		; get version to ax
	xchg al, ah		; strange Microsoft version format
.useoldver:
	cmp ax, ver(7,01)	; MS-DOS version > 7.00 ?
	jb .notnewpacket	; no -->
	setopt [internalflags], newpacket| oldpacket	; assume both packet methods available
.notnewpacket:
%if _VDD
	testopt [internalflags], runningnt
	jz .novdd
	mov si, imsg.vdd	; ds:si-> ASCIZ VDD filename
	mov bx, imsg.dispatch	; ds:bx-> ASCIZ dispatching entry
	mov di, imsg.init	; es:di-> ASCIZ init entry
	clc			; !
	RegisterModule		; register VDD
	jc .novdd		; error ? -->
	mov word [hVdd], ax
	setopt [internalflags], ntpacket| oldpacket	; assume old packet method also available
.novdd:
%endif

	xor ax, ax
	mov bx, sector_buffer		; ds:bx -> sector buffer
	mov di, bx			; es:di -> sector buffer
	mov cx, (8192 + 2) >> 1
	rep stosw			; fill buffer, di -> behind (sector_buffer+8192+2)
	xor dx, dx
	mov cl, [drivenumber]
	push bx
	call read_sector
	pop bx
	jc .access_error

	std
	mov word [es:bx - 2], 5E5Eh	; writes to unused word (1)
	scasw				; -> sector_buffer+8192 (at last word to sca)
	mov cx, (8192 + 2) >> 1
	xor ax, ax
	repe scasw
	add di, 4			; di -> first differing byte (from top)
	cld
	 push di

	mov di, bx
	mov cx, (8192 + 2) >> 1
	dec ax				; = FFFFh
	rep stosw

	xor ax, ax
	xor dx, dx
	mov cl, [drivenumber]
	push bx
	call read_sector
	pop bx
	 pop dx
	jc .access_error

	std
	scasw				; di -> sector_buffer+8192 (last word to sca)
	mov ax, -1
	mov cx, (8192 + 2) >> 1
	repe scasw
%if 0
AAAB
   ^
	sca B, match
  ^
	sca B, mismatch
 ^
	stop
%endif
	add di, 4			; di -> first differing byte (from top)
	cld

%if 0	
0000000000000
AAAAAAAA00000
	^
FFFFFFFFFFFFF
AAAAAAAA00FFF
	  ^
%endif
	cmp dx, di			; choose the higher one
	jae @F
	mov dx, di
@@:
	sub dx, bx			; dx = sector size

	cmp dx, 8192 + 2
	jae .sector_too_large
	mov ax, 32
	cmp dx, ax
	jb .sector_too_small
@@:
	cmp dx, ax
	je .got_match
	cmp ax, 8192
	jae .sector_not_power
	shl ax, 1
	jmp @B

.got_match:
	mov word [bp + ldBytesPerSector], ax
	mov cl, 4
	shr ax, cl
	mov word [bp + ldParaPerSector], ax
	shr ax, 1
	mov word [bp + ldEntriesPerSector], ax
	clc
	retn


.access_error:
	mov dx, msg.boot_access_error
	jmp .error_common_j
.sector_too_large:
	mov dx, msg.boot_sector_too_large
	jmp .error_common_j
.sector_too_small:
	mov dx, msg.boot_sector_too_small
	jmp .error_common_j
.sector_not_power:
	mov dx, msg.boot_sector_not_power
.error_common_j:
	call disp_msg_asciz
	stc
	retn

	align 16
	section BUFFERS

cmd_line_flags:		dw clfWriteSectorToSector | clfWriteInfoToSector
clfWriteSectorToFile:		equ   1
clfWriteSectorToSector:		equ   2
clfDontWriteSector:		equ   4
clfWriteSectorMask: \
	equ clfWriteSectorToFile | clfWriteSectorToSector | clfDontWriteSector
clfLeaveSector:			equ   8
clfWriteInfoToFile:		equ  10h
clfWriteInfoToSector:		equ  20h
clfWriteInfoToSectorFile:	equ  40h
clfDontWriteInfo:		equ  80h
clfWriteInfoMask: \
	equ clfWriteInfoToFile | clfWriteInfoToSector \
		| clfWriteInfoToSectorFile | clfDontWriteInfo
clfLeaveInfo:			equ 100h
cmd_line_sector_file:
.name:		dw 0
.handle:	dw -1
cmd_line_info_file:
.name:		dw 0
.handle:	dw -1
cmd_line_file_name_ofs:		equ 0
cmd_line_file_handle_ofs:	equ 2


	dw 0		; insure there's an unused word in front of this (1)
	align 16
sector_buffer:
second_sector_buffer:	equ sector_buffer - LOADDATA2 + 16 + 8192
third_sector_buffer_512_bytes: \
			equ second_sector_buffer + 8192
end:			equ third_sector_buffer_512_bytes + 512
stack_start:		equ end
stack_end:		equ stack_start + 4096

