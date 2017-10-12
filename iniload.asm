
%if 0

Loader for finishing file system booting
 by C. Masloch, 2017

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%include "lmacros2.mac"

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


%ifndef _MAP
%elifstr _MAP
%elifempty _MAP
%else	; defined non-empty non-str
	[map all _MAP]
%endif

	defaulting

	numdef QUERY_GEOMETRY,	1	; query geometry via 13.08 (for CHS access)
	numdef RPL,		1	; support RPL and do not overwrite it
	numdef CHS,		1	; support CHS (if it fits)
	numdef LBA,		1	; support LBA (if available)

	numdef LBA_SKIP_CHECK,	0	; don't use proper LBA extensions check
	numdef LBA_RETRY,	1	; retry LBA reads
	numdef CHS_RETRY,	1	; retry CHS reads

	strdef PAYLOAD_FILE,	"lDOS.BIN"
	numdef EXEC_OFFSET,	0
	numdef EXEC_SEGMENT,	0


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
		resb 1
ldClusterSize:	resw 1
ldParaPerSector:resw 1
ldLoadingSeg:	resw 1
ldLoadUntilSeg:	resw 1
	endstruc


	cpu 8086
	org 0
start:
	db "MZ"		; exeSignature
		; dec bp, pop dx
	jmp strict short ms6_entry	; exeExtraBytes
			; db 0EBh, 16h	; dw 16EBh
	dw -1		; exePages
	dw 0		; exeRelocItems
	dw -1		; exeHeaderSize
	dw -1		; exeMinAlloc
	dw -1		; exeMaxAlloc
	dw -16, 0	; exeInitSS, exeInitSP
	dw 0		; exeChecksum
	dw 100h, -16	; exeInitCSIP
	dw 0		; exeRelocTable

ms6_entry:
		; This is the MS-DOS 6 / IBMDOS compatible entry point.
		;  Note that this supports FAT32 for PC-DOS 7.10!
		; cs:ip = 70h:0
		; bx:ax = first data sector of first cluster,
		;	including hidden sectors
		; 0:7C00h-> boot sector with BPB,
		;	    load unit field set, hidden sectors set
		; (actually boot unit in dl; because the "MZ" signature
		;  destroys dl we assume it's in the BPB too)
		; ds:si = old int 1Eh address
		; 0:500h-> directory entry for BIO file
	cli
	cld
	push dx
	inc bp		; undo signature instructions

	xor cx, cx
	mov es, cx
	mov ss, cx
	mov sp, 7C00h + LOADSTACKVARS
	mov bp, 7C00h

	mov word [es:1Eh * 4], si
	mov word [es:1Eh * 4 + 2], ds

	mov dx, word [es:500h + 26]
	mov cx, word [es:500h + 20]
	mov word [bp + lsvFirstCluster + 0], dx
	mov word [bp + lsvFirstCluster + 2], cx

	sub bx, word [bp + bsBPB + bpbHiddenSectors + 0]
	sbb ax, word [bp + bsBPB + bpbHiddenSectors + 2]
	mov word [bp + lsvDataStart + 0], bx
	mov word [bp + lsvDataStart + 2], ax
	jmp ms7_entry.ms6_common


error:
	push cs
	pop ds
	mov si, msg.error
	call disp_error
	pop si
	call disp_error
	xor ax, ax
	int 16h
	int 19h

disp_error:
.:
	lodsb
	test al, al
	jz .ret
	mov ah, 0Eh
	mov bx, 7
	push bp
	int 10h
	pop bp
	jmp short .
.ret:
	retn

msg:
.error:	db "Load error: ", 0


%if _QUERY_GEOMETRY	; +30 bytes
query_geometry:
	mov dl, [bp + bsBPB + ebpbNew + bpbnBootUnit]
;	test dl, dl		; floppy?
;	jns @F			; don't attempt query, might fail -->
	; Note that while the original PC BIOS doesn't support this function
	;  (for its diskettes), it does properly return the error code 01h.
	; https://sites.google.com/site/pcdosretro/ibmpcbios (IBM PC version 1)
	mov ah, 08h
	xor cx, cx		; initialise cl to 0
	stc			; initialise to CY
	int 13h			; query drive geometry
	jc @F			; apparently failed -->
	and cx, 3Fh		; get sectors
	jz @F			; invalid (S is 1-based), don't use -->
	mov [bp + bsBPB + bpbCHSSectors], cx
	mov cl, dh		; cx = maximum head number
	inc cx			; cx = number of heads (H is 0-based)
	mov [bp + bsBPB + bpbCHSHeads], cx
@@:
	retn
%endif

		; Read a sector using Int13.02 or Int13.42
		;
		; INP:	dx:ax = sector number within partition
		;	bx:0-> buffer
		;	(_LBA) ds = ss
		; OUT:	If unable to read,
		;	 ! jumps to error instead of returning
		;	If sector has been read,
		;	 dx:ax = next sector number (has been incremented)
		;	 bx:0-> next buffer (bx = es+word[para_per_sector])
		;	 es = input bx
		; CHG:	-
		;
		; Note:	If error 09h (data boundary error) is returned,
		;	 the read is done into the ldSectorSeg buffer,
		;	 then copied into the user buffer.
read_sector:
	push dx
	push cx
	push ax
	push si

	push bx

; DX:AX==LBA sector number
; add partition start (= number of hidden sectors)
		add ax,[bp + bsBPB + bpbHiddenSectors + 0]
		adc dx,[bp + bsBPB + bpbHiddenSectors + 2]

%if _LBA		; +70 bytes (with CHS, +63 bytes without CHS)
	xor cx, cx
	push cx
	push cx
	push dx
	push ax		; qword sector number
	push bx
	push cx		; bx:0 -> buffer
	inc cx
	push cx		; word number of sectors to read
	mov cl, 10h
	push cx		; word size of disk address packet
	mov si, sp	; ds:si -> disk address packet (on stack)

 %if _LBA_SKIP_CHECK		; -14 bytes
	mov dl, [bp + bsBPB + ebpbNew + bpbnBootUnit]
 %else
	mov ah, 41h
	mov dl, [bp + bsBPB + ebpbNew + bpbnBootUnit]
	mov bx, 55AAh
	stc
	int 13h		; 13.41.bx=55AA extensions installation check
	jc .no_lba
	cmp bx, 0AA55h
	jne .no_lba
	test cl, 1	; support bitmap bit 0
	jz .no_lba
 %endif

%if _LBA_RETRY
	mov ah, 42h
	int 13h		; 13.42 extensions read
	jnc .lba_done

	xor ax, ax
	int 13h
	jc .lba_error
%endif

	mov ah, 42h
	int 13h

	jnc .lba_done
%if _LBA_SKIP_CHECK
	cmp ah, 1	; invalid function?
	je .no_lba	; try CHS instead -->
%endif
	cmp ah, 9	; data boundary error?
	jne .lba_error

	; push word [si + 4 + 0]
	push word [si + 4 + 2]	; user buffer
	 push word [bp + ldSectorSeg]
	 pop word [si + 4 + 2]
	; and word [si + 4 + 0], byte 0

%if _LBA_RETRY
	mov ah, 42h
	int 13h
	jnc .lba_sectorseg_done

	xor ax, ax
	int 13h
	jc .lba_error
%endif
	mov ah, 42h
	int 13h
	jc .lba_error
.lba_sectorseg_done:

	xor si, si
	mov ds, word [bp + ldSectorSeg]
	pop es
	; pop cx
	 push di
	; mov di, cx
	xor di, di
	mov cx, word [bp + bsBPB + bpbBytesPerSector]
	rep movsb
	 pop di

	push ss
	pop ds
.lba_done:
	add sp, 10h
	pop bx
	jmp short .chs_done

.lba_error: equ .err

 %if !_CHS
.no_lba: equ .err
 %else
.no_lba:
	add sp, 8
	pop ax
	pop dx
	pop cx
	pop cx
 %endif
%endif	

%if _CHS		; +70 bytes
; DX:AX=LBA sector number
; divide by number of sectors per track to get sector number
; Use 32:16 DIV instead of 64:32 DIV for 8088 compatability
; Use two-step 32:16 divide to avoid overflow
			mov cx,ax
			mov ax,dx
			xor dx,dx
			div word [bp + bsBPB + bpbCHSSectors]
			xchg cx,ax
			div word [bp + bsBPB + bpbCHSSectors]
			xchg cx,dx

; DX:AX=quotient, CX=remainder=sector (S) - 1
; divide quotient by number of heads
			mov bx, ax
			xchg ax, dx
			xor dx, dx
			div word [bp + bsBPB + bpbCHSHeads]
			xchg bx, ax
			div word [bp + bsBPB + bpbCHSHeads]

; bx:ax=quotient=cylinder (C), dx=remainder=head (H)
; move variables into registers for INT 13h AH=02h
			mov dh, dl	; dh = head
			inc cx		; cl5:0 = sector
			xchg ch, al	; ch = cylinder 7:0, al = 0
			shr ax, 1
			shr ax, 1	; al7:6 = cylinder 9:8
	; bx has bits set iff it's > 0, indicating a cylinder >= 65536.
			 or bl, bh	; collect set bits from bh
			or cl, al	; cl7:6 = cylinder 9:8
	; ah has bits set iff it was >= 4, indicating a cylinder >= 1024.
			 or bl, ah	; collect set bits from ah
			mov dl, [bp + bsBPB + ebpbNew + bpbnBootUnit]
					; dl = drive
			 jnz .err	; error if cylinder >= 1024 -->
					; ! bx = 0 (for 13.02 call)

; we call INT 13h AH=02h once for each sector. Multi-sector reads
; may fail if we cross a track or 64K boundary
			pop es
%if _CHS_RETRY
			mov ax, 0201h
			int 13h		; read one sector
			jnc .done
; reset drive
			xor ax, ax
			int 13h
			jc .err
%endif
; try read again
			mov ax, 0201h
			int 13h
	jnc .done
	cmp ah, 9	; data boundary error?
	jne .err

	push es		; user buffer
	 mov es, word [bp + ldSectorSeg]

%if _CHS_RETRY
	mov ax, 0201h
	int 13h
	jnc .chs_sectorseg_done

	xor ax, ax
	int 13h
	jc .err
%endif
	mov ax, 0201h
	int 13h
	jc .err
.chs_sectorseg_done:

	xor si, si
	mov ds, word [bp + ldSectorSeg]
	pop es
	 push di
	xor di, di
	mov cx, word [bp + bsBPB + bpbBytesPerSector]
	rep movsb
	 pop di

	push ss
	pop ds
.done:
; increment segment
	mov bx, es
%endif

.chs_done:
	mov es, bx
	add bx, word [bp + ldParaPerSector]

	pop si
	pop ax
	pop cx
	pop dx
; increment LBA sector number
	inc ax
	jne @F
	inc dx
@@:
	retn

.err:
error_diskaccess:
	call error
	db "Disk read error.", 0

error_shortfile:
	call error
	db "File is too short.", 0

error_badchain:
	call error
	db "Bad cluster chain.", 0

error_outofmemory:
	call error
	db "Out of memory.", 0


%assign num 512-($-$$)
%warning iniload: num bytes in front of ms7_entry
	_fill 512,38,start
ms7_entry:
		; This is the MS-DOS 7 compatible entry point.
		;  Supports FAT32 too.
		; cs:ip = 70h:200h
		; (si:)di = first cluster of load file
		; dwo [ss:bp - 4] = first data sector (with hidden sectors)
		; dwo [ss:sp] = 0:78h (IVT entry of int 1Eh)
		; dwo [ss:sp + 4] = old int 1Eh address
		; ss:bp -> boot sector with (E)BPB,
		;	    load unit field set, hidden sectors set
	inc dx
	dec dx		; "BJ" FAT32 support signature
	cli
	cld

	pop di
	pop es
	pop word [es:di]
	pop word [es:di + 2]

	mov ax, sp
	lea bx, [bp + LOADSTACKVARS]
	cmp ax, bx
	jbe @F
	mov sp, bx
@@:
	mov word [bp + lsvFirstCluster + 0], di
	mov word [bp + lsvFirstCluster + 2], si

	mov ax, word [bp + bsBPB + bpbHiddenSectors + 0]
	mov dx, word [bp + bsBPB + bpbHiddenSectors + 2]
	sub word [bp + lsvDataStart + 0], ax
	sbb word [bp + lsvDataStart + 2], dx

.ms6_common:
	mov ax, -1
	mov word [bp + lsvFATSector + 0], ax
	mov word [bp + lsvFATSector + 2], ax
	inc ax
	mov word [bp + lsvFATSeg], ax
	mov ax, cs
	add ax, (3 * 512) >> 4
	mov word [bp + lsvLoadSeg], ax

	jmp ldos_entry.ms7_common


		; INP:	dx:ax = cluster - 2 (0-based cluster)
		; OUT:	cx:bx = input dx:ax
		;	dx:ax = first sector of that cluster
		; CHG:	-
clust_to_first_sector:
	push dx
	push ax
	 push dx
	mul word [bp + ldClusterSize]
	xchg bx, ax
	xchg cx, dx
	 pop ax
	mul word [bp + ldClusterSize]
	test dx, dx
	jnz error_badchain
	xchg dx, ax
	add dx, cx
	xchg ax, bx

	add ax, [bp + lsvDataStart]
	adc dx, [bp + lsvDataStart + 2]
	jc error_badchain
				; dx:ax = first sector in cluster
	pop bx
	pop cx			; cx:bx = cluster
	retn


		; INP:	cx:bx = cluster (0-based)
		;	si:di = loaded FAT sector, -1 if none
		; OUT:	CY if no next cluster
		;	NC if next cluster found,
		;	 dx:ax = next cluster value (0-based)
		;	si:di = loaded FAT sector
		; CHG:	cx, bx
clust_next:
	mov ax, bx
	mov dx, cx
	add ax, 2
	adc dx, 0

	push es
	cmp byte [bp + ldFATType], 16
	je .fat16
	ja .fat32

.fat12:
; FAT12 entries are 12 bits, bytes are 8 bits. Ratio is 3 / 2,
;  so multiply cluster number by 3 first, then divide by 2.
					; ax = cluster number (up to 12 bits set)
		mov dx, ax
		shl ax, 1		; = 2n (up to 13 bits set)
		add ax, dx		; = 2n+n = 3n (up to 14 bits set)
		shr ax, 1		; ax = byte offset into FAT (0..6129)
					; CF = whether to use high 12 bits
		sbb cx, cx		; = -1 iff CY, else 0

; Use the calculated byte offset as an offset into the FAT
;  buffer, which holds all of the FAT's relevant data.
		mov es, [bp + lsvFATSeg]
		mov bx, ax		; -> 16-bit word in FAT to load

; get 16 bits from FAT
		mov ax, [es:bx]

		and cl, 4	; = 4 iff CY after shift, else 0
		shr ax, cl	; shift down iff odd entry, else unchanged
		and ax, 0FFFh	; insure it's only 12 bits
		xor dx, dx
	jmp short .gotvalue

.fat32:
		; * 4 = byte offset into FAT (0--4000_0000h)
	add ax, ax
	adc dx, dx
.fat16:
		; * 2 = byte offset into FAT (0--2_0000h)
	add ax, ax
	adc dx, dx

	 push ax
	xchg ax, dx
	xor dx, dx		; dx:ax = high word
	div word [bp + bsBPB + bpbBytesPerSector]
	mov bx, ax
	 pop ax			; dx = remainder, ax = low word
	div word [bp + bsBPB + bpbBytesPerSector]
	xchg dx, bx		; dx:ax = result, bx = remainder
				; dx:ax = sector offset into FAT (0--200_0000h)
				; bx = byte offset into FAT sector (0--8190)
	cmp dx, si
	jne @F		; read sector
	cmp ax, di
	je @FF		; sector is already buffered
@@:
	mov si, dx
	mov di, ax
	mov word [bp + lsvFATSector + 2], dx
	mov word [bp + lsvFATSector + 0], ax

	push bx
	add ax, [bp + bsBPB + bpbReservedSectors]
	adc dx, 0
	mov bx, [bp + lsvFATSeg]
	call read_sector
	pop bx
@@:
	mov es, [bp + lsvFATSeg]
	xor dx, dx
	mov ax, [es:bx]

	cmp byte [bp + ldFATType], 16
	je @F
	mov dx, [es:bx + 2]
@@:
.gotvalue:
	pop es

		; INP:	dx:ax = cluster value, 2-based
		; OUT:	dx:ax -= 2 (makes it 0-based)
		;	CY iff invalid cluster
check_clust:
	and dx, 0FFFh
	sub ax, 2
	sbb dx, 0

	cmp byte [bp + ldFATType], 16
	ja .fat32
	je .fat16

.fat12:
	cmp ax, 0FF7h - 2
	jmp short .common

.fat16:
	cmp ax, 0FFF7h - 2
	jmp short .common

.fat32:
	cmp dx, 0FFFh
	jb @F		; CY here means valid ...-
	cmp ax, 0FFF7h - 2
@@:			;  -... or if NC first, CY here also
.common:
	cmc		; NC if valid
	retn


finish_relocation:
	mov si, relocator	; ds:si -> relocator
	mov cx, 8
	rep movsw	; move 16 bytes
	mov es, ax
	xor di, di	; -> where to relocate to
	xor si, si	; ds:si = cs:0

	mov cx, word [bp + lsvLoadSeg]
	sub cx, bx	; length of currently loaded fragment
	mov bx, 1000h
	mov ax, cx
	cmp ax, bx	; > 64 KiB ?
	jbe @F
	mov cx, bx	; first relocate the first 64 KiB
@@:
	sub ax, cx	; how much to relocate later
	shl cx, 1
	shl cx, 1
	shl cx, 1	; how much to relocate first,
			;  << 3 == convert paragraphs to words
	retf		; jump to relocator


		; ds => first chunk of to be relocated data
		; es => first chunk of relocation destination
		; cx = number of words in first chunk
relocator:
	rep movsw
	retf		; jump to relocated relocate_to

		; ds => first chunk of to be relocated data
		; es => first chunk of relocated data
		; bx = 1000h (64 KiB >> 4)
		; ax = number of paragraphs after first chunk (in next chunk)
relocate_to:
@@:
	mov dx, es
	add dx, bx
	mov es, dx	; next segment

	mov dx, ds
	add dx, bx
	mov ds, dx	; next segment

	sub ax, bx	; = how much to relocate after this round
	mov cx, 1000h << 3	; in case another full 64 KiB to relocate
	jae @F		; another full 64 KiB to relocate -->
	add ax, bx	; restore
	shl ax, 1
	shl ax, 1
	shl ax, 1	; convert paragraphs to words
	mov cx, ax	; that many words
	xor ax, ax	; no more to relocate after this round

@@:
	xor si, si
	xor di, di
	rep movsw	; relocate next chunk
	test ax, ax	; another round needed?
	jnz @BB		; yes -->
	
	pop ax
	sub word [bp + lsvLoadSeg], ax

		; cs = low enough to complete load
		; lsvLoadSeg => after last loaded fragment
		; ldLoadTop => after last available memory
		; ldParaPerSector = initialised
		; word [ss:sp] = payload.end in paras rounded up to sector size
finish_load:
	mov ax, cs
	mov word [bp + ldLoadingSeg], ax

	pop ax
	mov bx, cs
	add ax, bx
	mov word [bp + ldLoadUntilSeg], ax
		; ldLoadUntilSeg => after last to-be-loaded paragraph

	cmp ax, word [bp + ldLoadTop]
	ja error_outofmemory
		; shouldn't happen, but to be sure ...-

	mov ax, [bp + lsvFirstCluster]
	mov dx, [bp + lsvFirstCluster + 2]
	mov di, [bp + lsvFATSector]
	mov si, [bp + lsvFATSector + 2]
	call check_clust
	jc error_badchain

skip_next_clust:
	call clust_to_first_sector
	push cx
	push bx
	mov cx, [bp + ldClusterSize]
skip_next_sect:
	push cx

	mov bx, [bp + ldLoadingSeg]
	cmp bx, [bp + ldLoadUntilSeg]
	jae loaded_all.3stack

	mov cx, bx
	add cx, [bp + ldParaPerSector]
	cmp cx, [bp + lsvLoadSeg]
	ja skipped_all
	add ax, 1		; emulate read_sector:
	adc dx, 0		; dx:ax += 1
	mov bx, cx		; bx += paras per sector
	mov [bp + ldLoadingSeg], bx

	pop cx
	loop skip_next_sect
	pop bx
	pop cx
	call clust_next
	jnc skip_next_clust
end_of_chain:
	inc ax
	inc ax
	test ax, 8	; set in 0FFF_FFF8h--0FFF_FFFFh,
			;  clear in 0, 1, and 0FFF_FFF7h
	jz error_badchain
	mov bx, [bp + ldLoadingSeg]
	cmp bx, [bp + ldLoadUntilSeg]
	jae loaded_all
	jmp error_shortfile


load_next_clust:
	call clust_to_first_sector
	push cx
	push bx
	mov cx, [bp + ldClusterSize]
load_next_sect:
	push cx

	mov bx, [bp + ldLoadingSeg]
	cmp bx, [bp + ldLoadUntilSeg]
	jae loaded_all.3stack
skipped_all:
	call read_sector
	mov [bp + ldLoadingSeg], bx
	pop cx
	loop load_next_sect
	pop bx
	pop cx
	call clust_next
	jnc load_next_clust
	jmp short end_of_chain

loaded_all.3stack:
	pop ax
	pop ax
	pop ax
loaded_all:
	mov ax, cs
	add ax, ((payload -$$+0) >> 4) + _EXEC_SEGMENT
	push ax
%if _EXEC_OFFSET
	mov ax, _EXEC_OFFSET
%else
	xor ax, ax
%endif
	push ax
		; cs:ip = xxxxh:_EXEC_OFFSET
		; entire payload loaded (payload -- payload.end)
		; LOADSTACKVARS and LOADDATA and EBPB and ebpbNew BPBN set
	retf


%assign num 1024-($-$$)
%warning iniload: num bytes in front of ldos_entry
	_fill 1024,38,start
ldos_entry:
		; cs:ip = 70h:400h
		; dwo [ss:bp - 4] = first data sector (without hidden sectors)
		; wo [ss:bp - 6] = load_seg, => after last loaded data
		; wo [ss:bp - 8] = fat_seg, 0 if invalid
		;  fat_sector is not used for FAT12 !
		; wo [ss:bp - 12] = fat_sector, -1 if none (FAT16)
		; dwo [ss:bp - 12] = fat_sector, -1 if none (FAT32)
		; wo [ss:bp - 16] = first_cluster (FAT16, FAT12)
		; dwo [ss:bp - 16] = first_cluster (FAT32)

.ms7_common:
	mov bx, word [bp + lsvLoadSeg]
	mov ax, cs
	sub bx, ax
	mov cx, (payload.end -$$+0) >> 4
	cmp bx, cx
	jbe @F
	add cx, ax
	mov word [bp + lsvLoadSeg], cx
@@:
	mov cx, word [bp + lsvLoadSeg]
	sub cx, ax
	cmp cx, (end -$$+0) >> 4
	jae @F
	call error
	db "Initial loader not fully loaded.", 0

@@:


; Get conventional memory size and store it
		int 12h
		mov cl, 6
		shl ax, cl
%if _RPL
	xor si, si
	xchg dx, ax
	mov ds, si
	lds si, [4 * 2Fh]
	add si, 3
	lodsb
	cmp al, 'R'
	jne .no_rpl
	lodsb
	cmp al, 'P'
	jne .no_rpl
	lodsb
	cmp al, 'L'
	jne .no_rpl
	mov ax, 4A06h
	int 2Fh
.no_rpl:
	xchg ax, dx
%endif
	push ax
	sub ax, 32 >> 4	; make space for two MCBs: top MCB, RPL MCB
	mov cx, ax
	sub ax, (8192) >> 4
	dec cx		; => last paragraph of higher buffer
	mov dx, ax	; => first paragraph of higher buffer
	mov bx, cx
	and dx, 0F000h	; 64 KiB chunk of first paragraph of higher buffer
	and bx, 0F000h	; 64 KiB chunk of last paragraph of higher buffer
	cmp bx, dx	; in same chunk?
	je .gotsectorseg	; yes, use higher buffer as sector buffer ->
	mov bx, ax	; use higher buffer as FAT buffer
	sub ax, (8192 + 32) >> 4
			; leave space for higher buffer MCB + header
	mov cx, ax	; use lower buffer as sector buffer
	jmp short .gotsegs

.gotsectorseg:
			; ax = use higher buffer as sector buffer
	mov bx, ax
	sub bx, (8192 + 32) >> 4	; use lower buffer as FAT buffer
			; leave space for higher buffer MCB + header
	mov cx, bx
		; ax = sector seg
		; bx = FAT seg
		; cx = the lower of the two
.gotsegs:
	sub cx, (+512 -LOADDATA + bsBPB + EBPB_size + BPBN_size + 32 + 15) >> 4
			; 32 = leave space for lower buffer MCB + header
		; cx = stack seg

	dec cx		; leave space for stack + BPB buffer MCB
	cmp cx, word [bp + lsvLoadSeg]
	jnb @F
.error_outofmemory:
	jmp error_outofmemory
@@:

	push ax
	mov dx, ss
	mov ax, bp
	add ax, bsBPB + EBPB_size + BPBN_size + 15
	shr ax, 1
	shr ax, 1
	shr ax, 1
	shr ax, 1
	add dx, ax
	cmp dx, cx
	ja .error_outofmemory
		; note that the next conditional doesn't jump for lsvFATSeg = 0
	mov dx, word [bp + lsvFATSeg]
	add dx, (8192) >> 4
	cmp dx, cx
	ja .error_outofmemory
	pop ax

	pop dx		; top of memory (=> start of RPL, EBDA, video memory)
	inc cx		; => stack + BPB buffer
	push ss
	pop ds
	lea si, [bp + LOADSTACKVARS]	; ds:si -> lsv + BPB
	mov es, cx
	mov di, 512 - LOADDATA + LOADSTACKVARS	; es:di -> where to place lsv
	push cx		; top of memory below buffers
	mov cx, (- LOADSTACKVARS + bsBPB + EBPB_size + BPBN_size + 1) >> 1
	rep movsw
	pop cx
	mov ss, cx
	mov sp, 512	; -> above end of stack space
	mov bp, 512 - LOADDATA	; -> BPB, above end of lsv
	dec cx		; => space for stack + BPB buffer MCB

		; ax => sector buffer
		; bx => FAT buffer
		; cx => above end of memory available for load
		; dx => above end of memory used by us
	mov word [bp + ldMemoryTop], dx
	mov word [bp + ldLoadTop], cx
	mov word [bp + ldSectorSeg], ax

	mov ax, word [bp + lsvFATSeg]
	mov ds, ax
	xor si, si	; ds:si -> FAT buffer
	mov es, bx
	xor di, di	; es:di -> where to move
	mov cx, 8192 >> 1
	rep movsw
	mov word [bp + lsvFATSeg], bx

	push ax		; to check for word [lsvFATSeg] == zero later on

	push ss
	pop es
	push ss
	pop ds

; adjusted sectors per cluster (store in a word,
;  and decode EDR-DOS's special value 0 meaning 256)
	xor ax, ax
	mov al, [bp + bsBPB + bpbSectorsPerCluster]
	dec al
	inc ax
	mov [bp + ldClusterSize], ax

; 16-byte paragraphs per sector
	mov ax, [bp + bsBPB + bpbBytesPerSector]
	mov cl, 4
	shr ax, cl
	mov [bp + ldParaPerSector], ax

; total sectors
	xor dx, dx
	mov ax, [bp + bsBPB + bpbTotalSectors]
	test ax, ax
	jnz @F
	mov dx, [bp + bsBPB + bpbTotalSectorsLarge + 2]
	mov ax, [bp + bsBPB + bpbTotalSectorsLarge]
	jmp short @FF
@@:
	mov [bp + bsBPB + bpbTotalSectorsLarge + 2], dx
	mov [bp + bsBPB + bpbTotalSectorsLarge], ax
@@:
	; dx:ax = total sectors

	mov bx, [bp + bsBPB + bpbSectorsPerFAT]
	test bx, bx
	jnz .fat_not_32
	mov byte [bp + ldFATType], 32
	jmp .got_fat_type

.fat_not_32:
	lea si, [bp + bsBPB + bpbNew]
	lea di, [bp + bsBPB + ebpbNew]
	mov cx, (BPBN_size + 1) >> 1
	rep movsw

	mov word [bp + lsvFirstCluster + 2], cx
	mov word [bp + lsvFATSector + 2], cx

	mov word [bp + bsBPB + ebpbSectorsPerFATLarge], bx
	mov word [bp + bsBPB + ebpbSectorsPerFATLarge + 2], cx
	mov word [bp + bsBPB + ebpbFSFlags], cx
	mov word [bp + bsBPB + ebpbRootCluster], cx
	mov word [bp + bsBPB + ebpbRootCluster + 2], cx
	; FSVersion, FSINFOSector, BackupSector, Reserved: uninitialised

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
	call error
	db "Bad amount of clusters.", 0

@@:
	cmp ax, 0FFF7h - 2
	ja .badclusters
	mov byte [bp + ldFATType], 16
	cmp ax, 0FF7h - 2
	ja .got_fat_type

	mov byte [bp + ldFATType], 12
%if _QUERY_GEOMETRY
	call query_geometry
		; do it here because loading the FAT uses the geometry.
		; however, the ebpbNew BPBN needs to be initialised.
%endif
	pop ax
	test ax, ax
	jnz .got_fat12

; lsvFATSeg was zero! This means the FAT isn't loaded yet.

; Load the entire FAT into memory. This is easily feasible for FAT12,
;  as the FAT can only contain less than 4096 entries.
; (The exact condition should be "at most 4087 entries", or with a
;  specific FF7h semantic, "at most 4088 entries"; the more reliable
;  and portable alternative would be "at most 4080 entries".)
; Thus, no more than 6 KiB need to be read, even though the FAT size
;  as indicated by word[sectors_per_fat] could be much higher. The
;  first loop condition below is to correctly handle the latter case.
; (Sector size is assumed to be a power of two between 32 and 8192
;  bytes, inclusive. An 8 KiB buffer is necessary if the sector size
;  is 4 or 8 KiB, because reading the FAT can or will write to 8 KiB
;  of memory instead of only the relevant 6 KiB. This is always true
;  if the sector size is 8 KiB, and with 4 KiB sector size it is true
;  iff word[sectors_per_fat] is higher than one.)
		mov di, 6 << 10		; maximum size of FAT12 to load
		mov cx, [bp + bsBPB + bpbSectorsPerFAT]
					; maximum size of this FS's FAT
		xor dx, dx
		mov ax, [bp + bsBPB + bpbReservedSectors]; = first FAT sector
		mov bx, [bp + lsvFATSeg]
@@:
		call read_sector	; read next FAT sector
		sub di, [bp + bsBPB + bpbBytesPerSector]
					; di = bytes still left to read
		jbe @F			; if none -->
					; (jbe means jump if CF || ZF)
		loop @B			; if any FAT sector still remains -->
@@:					; one of the limits reached; FAT read

.got_fat12:
	jmp short @F
.got_fat_type:
%if _QUERY_GEOMETRY
	call query_geometry
%endif
	pop ax
@@:

	mov ax, (payload.end -$$+0) >> 4
	mov bx, [bp + ldParaPerSector]
	dec bx		; para per sector - 1
	add ax, bx	; round up
	not bx		; ~ (para per sector - 1)
	and ax, bx	; rounded up,
		; ((payload.end -$$+0) >> 4 + pps - 1) & ~ (pps - 1)
	push ax
		; on stack: payload.end in paragraphs rounded up to sector size
	mov bx, cs
	add ax, bx	; = cs + rounded up length
	sub ax, word [bp + ldLoadTop]	; = paras to move down
	jbe finish_load

	push ax
	add ax, bx	; ax = cs - paras to move down
	mov di, relocate_to
	push ax
	push di		; dword on stack: relocate_to
	dec ax		; one less to allow relocator
	cmp ax, 60h
	jb error_outofmemory
	mov es, ax
	xor di, di	; es:di -> where to put relocator
	push es
	push di		; dword on stack: relocator destination
	mov ds, bx	; ds => unrelocated cs
	inc ax		; ax => where to relocate to

	jmp finish_relocation


%assign num 1024+512-($-$$)
%warning iniload: num bytes in front of end
	_fill 1024+512,38,start
	align 16, db 38
end:

	align 16
payload:
	incbin _PAYLOAD_FILE
	align 16, db 38
.end:
