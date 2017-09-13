
%if 0

File system boot sector loader code for FAT12

Adapted from 2002-11-26 fatboot.zip/fat12.asm,
 released as public domain by Chris Giese

Public domain by C. Masloch, 2012

%endif


%include "lmacros2.mac"

%ifndef _MAP
%elifstr _MAP
%elifempty _MAP
%else	; defined non-empty non-str
	[map all _MAP]
%endif

	defaulting

	numdef FAT16,		0	; 0 = FAT12, 1 = FAT16
	strdef OEM_NAME,	"    lDOS"
	strdef DEFAULT_LABEL,	"lDOS"

	strdef LOAD_NAME,	"LDOS"
	strdef LOAD_EXT,	"BIN"	; name of file to load
	numdef LOAD_ADR,	00610h	; where to load
	numdef EXEC_SEG_ADJ,	0	; how far cs will be from _LOAD_ADR
	numdef EXEC_OFS,	0	; what value ip will be

	numdef QUERY_GEOMETRY,	1	; query geometry via 13.08 (for CHS access)
	numdef USE_PART_INFO,	1	; use ds:si-> partition info from MBR, if any
	numdef RPL,		1	; support RPL and do not overwrite it
	numdef CHS,		1	; support CHS (if it fits)
	numdef LBA,		1	; support LBA (if available)

	numdef SET_BL_UNIT,	0	; if to pass unit in bl as well
	numdef SET_AXBX_DATA,	0	; if to pass first data sector in ax:bx
	numdef SET_DSSI_DPT,	0	; if to pass DPT address in ds:si
	numdef PUSH_DPT,	0	; if to push DPT address
	numdef MEMORY_CONTINUE,	0	; if to just execute when memory full
	numdef SET_SIDI_CLUSTER,0	; if to pass first load file cluster in si:di
	numdef DIRBUF_500,	0	; if to load root dir sector(s) to 0:500h
	numdef TURN_OFF_FLOPPY,	0	; if to turn off floppy motor after loading
	numdef DATASTART_HIDDEN,0	; if to add hidden sectors to data_start

	numdef FIX_SECTOR_SIZE, 0	; fix sector size (0 = disable, else = sector size)
	numdef FIX_SECTOR_SIZE_SKIP_CHECK,	0	; don't check sector size
	numdef FIX_CLUSTER_SIZE,		0	; fix cluster size
	numdef FIX_CLUSTER_SIZE_SKIP_CHECK,	0	; don't check cluster size
	numdef NO_LIMIT,	0	; allow using more memory than a boot sector
					;  also will not write 0AA55h signature!
	numdef LBA_SKIP_CHECK,	0	; don't use proper LBA extensions check

	numdef COMPAT_FREEDOS,	0	; partial FreeDOS load compatibility
	numdef COMPAT_IBM,	0	; partial IBMDOS load compatibility
	numdef COMPAT_MS7,	0	; partial MS-DOS 7 load compatibility

%if (!!_COMPAT_FREEDOS + !!_COMPAT_IBM + !!_COMPAT_MS7) > 1
 %error At most one set must be selected.
%endif

%if _COMPAT_FREEDOS
	strdef LOAD_NAME,	"KERNEL"
	strdef LOAD_EXT,	"SYS"
	numdef LOAD_ADR,	00600h
	numdef EXEC_SEG_ADJ,	0
	numdef EXEC_OFS,	0
 %assign _SET_BL_UNIT		1
	; The FreeDOS load protocol mandates that the entire file be loaded.
%endif

%if _COMPAT_IBM
	strdef LOAD_NAME,	"IBMBIO"
	strdef LOAD_EXT,	"COM"
	numdef LOAD_ADR,	00700h
	numdef EXEC_SEG_ADJ,	0
	numdef EXEC_OFS,	0
 %assign _MEMORY_CONTINUE	1
	; 3 sectors * 512 BpS should suffice. We load into 700h--7A00h,
	;  ie >= 6000h bytes (24 KiB), <= 7300h bytes (28.75 KiB).
 %assign _DIRBUF_500		1
 	; Note: IBMBIO.COM must be the first file, IBMDOS.COM the second file.
 	;  We do not check this to be the case, but the load protocol may
 	;  prescribe that these two entries are at 0:500h and 0:520h.
 %assign _SET_AXBX_DATA		1
 %assign _DATASTART_HIDDEN	1
 %assign _SET_DSSI_DPT		1
 %assign _PUSH_DPT		1
%endif

%if _COMPAT_MS7
	strdef LOAD_NAME,	"IO"
	strdef LOAD_EXT,	"SYS"
	numdef LOAD_ADR,	00700h
	numdef EXEC_SEG_ADJ,	0
	numdef EXEC_OFS,	200h
 %assign _SET_DSSI_DPT		1
 %assign _PUSH_DPT		1
 %assign _MEMORY_CONTINUE	1
	; 3 sectors * 512 BpS should suffice. We load into 700h--7A00h,
	;  ie >= 6000h bytes (24 KiB), <= 7300h bytes (28.75 KiB).
 %assign _SET_SIDI_CLUSTER	1
 %assign _DATASTART_HIDDEN	1
%endif

%if 0

Notes about partial load compatibilities

* FreeDOS:
 * Does not relocate to 27A00h (1FE0h:7C00h)
* IBMDOS:
 * Does not put directory entry/entries to 00500h
 * Does not search for IBMDOS file (only IBMBIO)
 * Does not actually relocate DPT, just provide its address
* MS-DOS 7:
 * Does not actually relocate DPT, just provide its address

%endif

%if _SET_BL_UNIT && _SET_AXBX_DATA
 %error Cannot select both of these options!
%endif


%assign LOADLIMIT 0A0000h
%assign POSITION   07C00h

%if _FIX_SECTOR_SIZE
 %assign i 5
 %rep 13-5
  %if (1 << i) != (_FIX_SECTOR_SIZE)
   %assign i i+1
  %endif
 %endrep
 %if (1 << i) != (_FIX_SECTOR_SIZE)
  %error Invalid sector size _FIX_SECTOR_SIZE
 %endif
%endif

%if _FIX_CLUSTER_SIZE
 %if _FIX_CLUSTER_SIZE > 256
  %error Invalid cluster size _FIX_CLUSTER_SIZE
 %endif
 %assign i 0
 %rep 8-0
  %if (1 << i) != (_FIX_CLUSTER_SIZE)
   %assign i i+1
  %endif
 %endrep
 %if (1 << i) != (_FIX_CLUSTER_SIZE)
  %warning Non-power-of-two cluster size _FIX_CLUSTER_SIZE
 %endif
%endif


%if (_LOAD_ADR & 0Fh)
 %error Load address must be on a paragraph boundary
%endif

%if _LOAD_ADR > LOADLIMIT
 %error Load address must be in LMA
%elif _LOAD_ADR < 00500h
 %error Load address must not overlap IVT or BDA
%elif _LOAD_ADR > (POSITION-256) && _LOAD_ADR < (POSITION+512)
 %error Load address must not overlap loader
%endif

%if ((_EXEC_SEG_ADJ<<4)+_EXEC_OFS) < 0
 %error Execution address must be in loaded file
%elif ((_EXEC_SEG_ADJ<<4)+_EXEC_OFS+_LOAD_ADR) > LOADLIMIT
 %error Execution address must be in LMA
%endif

%if (_EXEC_OFS & ~0FFFFh)
 %error Execution offset must fit into 16 bits
%endif

%if (_EXEC_SEG_ADJ & ~0FFFFh)
 %error Execution segment adjustment must fit into 16 bits
%endif

%define OEM_NAME_FILL '_'

%if !_CHS && _QUERY_GEOMETRY
 %warning No CHS support but querying geometry anyway
%endif

%if !_CHS && !_LBA
 %error Either CHS or LBA or both must be enabled
%endif


%if 0

There is some logic inside MS-DOS's hard disk partition initialisation
code that sets up several requirements for us to fulfil. Otherwise,
it will not accept the information given in the BPB (using default
information based on the length as specified by MBR/EPBR instead) or
make the whole file system inaccessible except for formatting. Both of
those are undesirable of course. Some/all(?) checks are documented on
pages 601,602 in "DOS Internals", Geoff Chappell 1994, as follows:

* First three bytes contain either "jmp sho xx\ nop" or "jmp ne xx".
* Media descriptor field >= 0F0h.
* Bytes per sector field == 512.
* Sectors per cluster field a power of 2 (1,2,4,8,16,32,64,128).
* OEM name "version" (last three to four characters)
 * must be "20.?", "10.?" (? = wildcard), but no other with "0.?",
 * otherwise, must be "2.0", or
  * 2nd-to-last,3rd-to-last character codes together > "3.", or
   * those == "3.", last character code > "0"

To stay compatible to those, display a warning here if the name
itself would disqualify our boot sector already.

%endif

%push
%strlen %$len _OEM_NAME
%define %$nam _OEM_NAME
%if %$len > 8
 %error Specified OEM name is too long
%else
 %assign %$warn 0
 %rep 8 - %$len
  %strcat %$nam %$nam,OEM_NAME_FILL
 %endrep
 %substr %$prefix %$nam	5	; "wvxyZa.b", get "Z"
 %substr %$major %$nam 6,7	; "wvxyzA.b", get "A."
 %substr %$minor %$nam 8	; "wvxyza.B", get "B"
 %if %$major == "0."
  %ifn %$prefix == "1" || %$prefix == "2"
   %assign %$warn 1
  %endif
 %elifn %$major == "2." && %$minor == "0"
  %if %$major < "3."
   %assign %$warn 1
  %elif %$major == "3." && %$minor < "1"
   %assign %$warn 1
  %endif
 %endif
 %if %$warn
  %warning Specified OEM name fails MS-DOS's validation
 %endif
%endif
%pop

; 512-byte stack.
ADR_STACK	equ	(lowest_variable-start+POSITION)&~1	;~07BF0h
ADR_STACK_LOW	equ	7C00h - 200h		; 07A00h

ADR_FSIBOOT	equ	end -start+7C00h	; 07E00h

ADR_FATBUF	equ	(ADR_FSIBOOT + 512)	; 08000h

%if _DIRBUF_500
 ADR_DIRBUF	equ	500h
 ; start of unused memory:
 ADR_FREE	equ	(ADR_FATBUF + 8192)	; 0A000h
%else
 ; one-sector directory buffer. Assumes sectors are no larger than 8 KiB
 ADR_DIRBUF	equ	(ADR_FATBUF + 8192)	; 0A000h
 ; start of unused memory:
 ADR_FREE	equ	(ADR_DIRBUF + 8192)	; 0C000h
%endif

%if (ADR_FATBUF + 8192) > 1_0000h && ADR_FATBUF < 1_0000h
 %warning Possibly crossing 64 KiB boundary while reading
%endif

%if (ADR_DIRBUF + 8192) > 1_0000h && ADR_DIRBUF < 1_0000h
 %warning Possibly crossing 64 KiB boundary while reading
%endif


%if _LOAD_ADR >= ADR_FREE
	; if reading on a 8 KiB boundary, no crossing can occur.
 %if _LOAD_ADR & (8192 - 1)
  %warning Possibly crossing 64 KiB boundary while reading
 %endif
%else
	; if loading below the boot sector, address 1_0000h is never reached.
%endif

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


; use byte-offset addressing from BP for smaller code
%define	VAR(x)	((x) - start) + bp


	cpu 8086
; bootsector loaded at address 07C00h, addressable using 0000h:7C00h
	org POSITION
start:


; Variables

; (dword) sector where the actual disk data starts
data_start		EQU (start - 4)

; (word) actual sectors per cluster
adj_sectors_per_cluster equ (data_start - 2)

; (word) number of 16-byte paragraphs per sector
para_per_sector		EQU (adj_sectors_per_cluster - 2)

; (word) number of 32-byte FAT directory entries per sector
dir_ents_per_sector	EQU (para_per_sector - 2)

; (word) segment of last available memory for sector
last_available_sector	equ (dir_ents_per_sector - 2)

; (word) current load segment
load_seg		equ (last_available_sector - 2)

; (word) directory entries per sector
entries_per_sector	equ (load_seg - 2)

lowest_variable		equ entries_per_sector

	jmp strict short skip_bpb
	nop


; BIOS Parameter Block (BPB)
;
; Installation will use the BPB already present in your file system.
; These values must be initialised when installing the loader.

oem_id:			; offset 03h (03) - not used by this code
	fill 8,OEM_NAME_FILL,db _OEM_NAME
bytes_per_sector:	; offset 0Bh (11) - refer to _FIX_SECTOR_SIZE !
	dw 0
sectors_per_cluster:	; offset 0Dh (13) - refer to _FIX_CLUSTER_SIZE !
	db 0
fat_start:
num_reserved_sectors:	; offset 0Eh (14)
	dw 0
num_fats:		; offset 10h (16)
	db 0
num_root_dir_ents:	; offset 11h (17)
	dw 0
total_sectors:		; offset 13h (19) - not used by this code
	dw 0
media_id:		; offset 15h (21) - not used by this code
	db 0
sectors_per_fat:	; offset 16h (22)
	dw 0
sectors_per_track:	; offset 18h (24)
	dw 0
heads:			; offset 1Ah (26)
	dw 0
hidden_sectors:		; offset 1Ch (28)
	dd 0
total_sectors_large:	; offset 20h (32) - not used by this code
	dd 0

sectors_per_fat_large:	; offset 24h (36)
	dd 0
fsflags:		; offset 28h (40)
	dw 0
fsversion:		; offset 2Ah (42)
	dw 0
root_cluster:		; offset 2Ch (44)
	dd 0
fsinfo_sector:		; offset 30h (48)
	dw 0
backup_sector:		; offset 32h (50)
	dw 0

	times 12 db 0	; offset 34h (52) reserved

; Extended BPB		; offset 40h (64)

boot_unit:		db 0
			db 0
ext_bpb_signature:	db 29h
serial_number:		dd 0
volume_label:		fill 11,32,db _DEFAULT_LABEL
filesystem_identifier:	fill 8,32,db "FAT32"


; Initialised data

load_name:
	fill 8,32,db _LOAD_NAME
	fill 3,32,db _LOAD_EXT

fsiboot_name:
	db "FSIBOOT",0


; Code

skip_bpb:
	cli
	cld
	 xor ax, ax
	mov bp, start
	 mov ss, ax
	mov sp, ADR_STACK
	mov [VAR(boot_unit)], dl

	; Note:	es is left uninitialised here until the first call to
	;	 read_sector if the below conditional is false.
%if _USE_PART_INFO	; +19 bytes
	 mov es, ax
; Check whether an MBR left us partition information.
; byte[ds:si] bit 7 means active and must be set if valid.
	cmp byte [si], al	; flags for xx-00h (result is xx), SF = bit 7
	jns @F			; xx < 80h, ie info invalid -->
; byte[ds:si+4] is the file system type. Check for valid one.
	cmp byte [si+4], al	; is it zero?
	je @F			; yes, info invalid -->
; Info valid, trust their hidden sectors over hardcoded.
; Assume the movsw instructions won't run with si = FFFFh.
	mov di, hidden_sectors	; -> BPB field
	add si, 8		; -> partition start sector in info
	movsw
	movsw			; overwrite BPB field with value from info
@@:
%endif
	mov ds, ax
	sti


%if _QUERY_GEOMETRY	; +27 bytes
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
	mov [VAR(sectors_per_track)], cx
	mov cl, dh		; cx = maximum head number
	inc cx			; cx = number of heads (H is 0-based)
	mov [VAR(heads)], cx
@@:
%endif


load_fsiboot:
	mov ax, [VAR(fsinfo_sector)]
;	inc ax
;	jz error_fsiboot	; was FFFFh, invalid -->
;	dec ax
		; FFFFh always fails the < num_reserved_sectors check
	test ax, ax
	jz error_fsiboot	; is 0 ? invalid -->
	cmp ax, [VAR(num_reserved_sectors)]
	jae error_fsiboot
	xor dx, dx		; dx:ax = FSINFO sector
	mov cx, 512
	mov bx, ADR_FSIBOOT >> 4
@@:
	call read_sector
	sub cx, [VAR(bytes_per_sector)]
	ja @B			; read 512 bytes -->

	push ds
	pop es
	mov si, signatures
	mov di, ADR_FSIBOOT + FSINFO.signature3
	cmpsw
	jne error_fsiboot
	cmpsw
	jne error_fsiboot
	mov di, ADR_FSIBOOT + FSINFO.reserved1
	mov si, fsiboot_name
	mov cx, 4
	repe cmpsw
	jne error_fsiboot

%if _LOAD_ADR >= ADR_FREE
; Get conventional memory size and store it
		int 12h
		mov cl, 6
		shl ax, cl
 %if _RPL		; +33 bytes
	push si
	xchg dx, ax
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
	push ss
	pop ds
	xchg ax, dx
	pop si
 %endif
%elif _LOAD_ADR < ADR_STACK_LOW
%else
 %error Load address within used memory
%endif
		; With FSIBOOT, para_per_sector isn't initialised yet.
		; So instead we store the address *after* the last buffer here.
%if _LOAD_ADR < ADR_STACK_LOW
		mov word [VAR(last_available_sector)], (ADR_STACK_LOW >> 4)
%else
		mov word [VAR(last_available_sector)], ax
%endif

	mov si, fsinfo_table
	mov di, ADR_FSIBOOT + FSINFO.reserved1 + 8
	mov cx, (fsinfo_table.end - fsinfo_table) >> 1
	rep movsw

	jmp ADR_FSIBOOT + FSINFO.reserved1 + 8 + (fsinfo_table.end - fsinfo_table)

	align 2
fsinfo_table:
.error:		dw error
.success:	dw load_finish
%if _MEMORY_CONTINUE
.memory_full:	dw load_finish_mc
%else
.memory_full:	dw error_filetoobig
%endif
.read_sector:	dw read_sector
.load_name:	dw load_name
.end:


error_fsiboot:
	mov al,'I'

	db __TEST_IMM16	; (skip mov)
error_badchain:
	mov al,'B'

%if !_MEMORY_CONTINUE
	db __TEST_IMM16	; (skip mov)
error_filetoobig:
	mov al,'M'	; Not enough 'M'emory
%endif

error:
	mov bh, [462h]
	mov bl, 7
	mov ah, 0Eh
	int 10h		; display character
	mov al, 07h
	int 10h		; beep!

	xor ax, ax	; await key pressed
	int 16h

	int 19h		; re-start the boot process


%if _MEMORY_CONTINUE
load_finish_mc:
		pop bx
		pop cx
%endif
load_finish:

%if _TURN_OFF_FLOPPY
; turn off floppy motor
		mov dx,3F2h
		mov al,0
		out dx,al
%endif

; Set-up registers for and jump to loaded file
; Already: ss:bp-> boot sector containing BPB
%if _SET_SIDI_CLUSTER && (_PUSH_DPT || _SET_DSSI_DPT)
		pop cx
		pop dx
%endif
%if _DATASTART_HIDDEN
		mov bx, [VAR(hidden_sectors + 0)]
		mov ax, [VAR(hidden_sectors + 2)]
		add word [VAR(data_start + 0)], bx
		adc word [VAR(data_start + 2)], ax
%endif
%if _SET_AXBX_DATA
		mov bx, [VAR(data_start)]
		mov ax, [VAR(data_start+2)]
%endif
%if _PUSH_DPT || _SET_DSSI_DPT
 %ifn _SET_DSSI_DPT		; (implying that only _PUSH_DPT is set)
		mov di, 1Eh*4
		les si, [di]		; -> original (also current) DPT
		push es
		push si			; original (also current) DPT address
		push ss
		push di			; 0000h:0078h (address of 1Eh IVT entry)
 %else
		mov di, 1Eh*4
		lds si, [di]		; -> original (also current) DPT
  %if _PUSH_DPT
		push ds
		push si			; original (also current) DPT address
		push ss
		push di			; 0000h:0078h (address of 1Eh IVT entry)
  %endif
 %endif
%endif
%if _SET_SIDI_CLUSTER
 %if _PUSH_DPT || _SET_DSSI_DPT
		mov di, cx
		mov si, dx
 %else
		pop di
		pop si
 %endif
%endif
		mov dl, [VAR(boot_unit)]	; set dl to unit
%if _SET_BL_UNIT
		mov bl, dl		; set bl to unit, too
%endif
			; dl = BIOS unit
			; ss:bp-> boot sector with BPB
		jmp (_LOAD_ADR>>4)+_EXEC_SEG_ADJ:_EXEC_OFS


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
		;		Note that this is initialised only in FSIBOOT,
		;		 so that it is undefined for the read of the
		;		 FSINFO sector. But this isn't in use then.
		;	 es = input bx
		; CHG:	-
read_sector:
	push dx
	push cx
	push ax

	push bx

; DX:AX==LBA sector number
; add partition start (= number of hidden sectors)
		add ax,[VAR(hidden_sectors + 0)]
		adc dx,[VAR(hidden_sectors + 2)]

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
	mov dl, [VAR(boot_unit)]
 %else
	mov ah, 41h
	mov dl, [VAR(boot_unit)]
	mov bx, 55AAh
	stc
	int 13h		; 13.41.bx=55AA extensions installation check
	jc .no_lba
	cmp bx, 0AA55h
	jne .no_lba
	test cl, 1	; support bitmap bit 0
	jz .no_lba
 %endif

	mov ah, 42h
	int 13h		; 13.42 extensions read
	jnc .lba_done

	xor ax, ax
	int 13h
	jc .lba_error

	mov ah, 42h
	int 13h
 %if _LBA_SKIP_CHECK
	jnc .lba_done
	cmp ah, 1	; invalid function?
	je .no_lba	; try CHS instead -->
	jmp .lba_error
 %else
	jc .lba_error
 %endif

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
			div word [VAR(sectors_per_track)]
			xchg cx,ax
			div word [VAR(sectors_per_track)]
			xchg cx,dx

; DX:AX=quotient, CX=remainder=sector (S) - 1
; divide quotient by number of heads
			mov bx, ax
			xchg ax, dx
			xor dx, dx
			div word [VAR(heads)]
			xchg bx, ax
			div word [VAR(heads)]

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
			mov dl,[VAR(boot_unit)] ; dl = drive
			 jnz .err	; error if cylinder >= 1024 -->
					; ! bx = 0 (for 13.02 call)

; we call INT 13h AH=02h once for each sector. Multi-sector reads
; may fail if we cross a track or 64K boundary
			pop es
			mov ax, 0201h
			int 13h		; read one sector
			jnc .done
; reset drive
			xor ax, ax
			int 13h
			jc .err
; try read again
			mov ax, 0201h
			int 13h
			jc .err

.done:
; increment segment
	mov bx, es
%endif

.chs_done:
%if _FIX_SECTOR_SIZE
	add bx, _FIX_SECTOR_SIZE >> 4
%else
	add bx, [VAR(para_per_sector)]
%endif

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
	mov al, 'R'	; Disk 'R'ead error
	jmp error


%if !_NO_LIMIT
available:
	_fill 508,38,start

signatures:
	dw 0
; 2-byte magic bootsector signature
	dw 0AA55h

%assign num signatures-available
%warning FAT 32: num bytes still available.
%else	; for testing
	align 4
signatures:
	dw 0
; 2-byte magic bootsector signature
	dw 0AA55h
%endif

	align 16, nop
end:

fsiboot:
	dd "RRaA"
	db "FSIBOOT", 0

.table:		; these are to be initialised by the loader
.error:		dw 0
.success:	dw 0
.memory_full:	dw 0
.read_sector:	dw 0
.load_name:	dw 0

.start:

		; INP:	ss:bp -> boot sector, with EBPB
		;	adj_sectors_per_cluster (uninit), data_start (uninit),
		;	load_seg (uninit), last_available_sector,
		;	para_per_sector (uninit), entries_per_sector (uninit)
		;	Stack layout has to match!
; calculate some values that we need:
; adjusted sectors per cluster (store in a word,
;  and decode EDR-DOS's special value 0 meaning 256)
	mov al, [VAR(sectors_per_cluster)]
	dec al
	inc ax
	mov [VAR(adj_sectors_per_cluster)], ax

; 16-byte paragraphs per sector
	mov ax, [VAR(bytes_per_sector)]
	mov cx, 4			; ! ch = 0
	shr ax, cl
	mov [VAR(para_per_sector)], ax
	sub word [VAR(last_available_sector)], ax

; 32-byte FAT directory entries per sector
	shr ax, 1			; /2 = 32-byte entries per sector
	mov word [VAR(entries_per_sector)], ax


	xor ax, ax
; first sector of root directory
	mov al,[VAR(num_fats)]		; ! ah = 0, hence ax = number of FATs
	push ax
	mul word [VAR(sectors_per_fat_large)]
		; ax = low word SpF*nF
		; dx = high word
	xchg bx, ax
	xchg cx, dx
		; cx:bx = first mul
	pop ax
	mul word [VAR(sectors_per_fat_large + 2)]
		; ax = high word adjust
		; dx = third word
	test dx, dx
	jnz fsiboot_error_badchain
	xchg dx, ax
		; dx = high word adjust
	add dx, cx
		; dx:bx = result
	xchg ax, bx
		; dx:ax = result
	
	add ax,[VAR(num_reserved_sectors)]
	adc dx, 0
	jc fsiboot_error_badchain

	xor di, di

; first sector of disk data area:
	mov [VAR(data_start)], ax
	mov [VAR(data_start+2)], dx

	mov ax, [VAR(root_cluster)]
	mov dx, [VAR(root_cluster + 2)]
	mov di, -1
	mov si, di
	call check_clust
	jc file_not_found

next_root_clust:
	call clust_to_first_sector
	push cx
	push bx
	mov cx, [VAR(adj_sectors_per_cluster)]
next_root_sect:
	push cx
	mov cx, [VAR(entries_per_sector)]

; Scan root directory for file. We don't bother to check for deleted
;  entries (E5h) or entries that mark the end of the directory (00h).
	mov bx, ADR_DIRBUF>>4
	call near word [fsiboot.read_sector]

	push di
	xor di, di		; es:di-> first entry in this sector
next_ent:
	push si
	push di
	push cx
	mov si, [fsiboot.load_name]	; ds:si-> name to match
	mov cx, 11		; length of padded 8.3 FAT filename
	repe cmpsb		; check entry
	pop cx
	pop di
	pop si
	lea di, [di + 32]	; bytes/dirent
	je found_it		; found entry -->

	loop next_ent		; count down sector's entries (jumps iff cx >0)
	pop di
	pop cx
	loop next_root_sect
	pop bx
	pop cx
	call clust_next
	jnc next_root_clust
file_not_found:
	mov al, 'F'
	db __TEST_IMM16
fsiboot_error_badchain:
	mov al, 'B'

	jmp near word [fsiboot.error]




		; INP:	dx:ax = cluster - 2 (0-based cluster)
		; OUT:	cx:bx = input dx:ax
		;	dx:ax = first sector of that cluster
		; CHG:	-
clust_to_first_sector:
	push dx
	push ax
	 push dx
	mul word [VAR(adj_sectors_per_cluster)]
	xchg bx, ax
	xchg cx, dx
	 pop ax
	mul word [VAR(adj_sectors_per_cluster)]
	test dx, dx
	jnz fsiboot_error_badchain
	xchg dx, ax
	add dx, cx
	xchg ax, bx

	add ax, [VAR(data_start)]
	adc dx, [VAR(data_start + 2)]
	jc fsiboot_error_badchain
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

	add ax, ax
	adc dx, dx
	add ax, ax
	adc dx, dx		; * 4 = byte offset into FAT (0--4000_0000h)
	 push ax
	xchg ax, dx
	xor dx, dx		; dx:ax = high word
	div word [VAR(bytes_per_sector)]
	mov bx, ax
	 pop ax			; dx = remainder, ax = low word
	div word [VAR(bytes_per_sector)]
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
	push bx
	add ax, [VAR(fat_start)]
	adc dx, 0
	mov bx, ADR_FATBUF>>4
	call near word [fsiboot.read_sector]
	pop bx
@@:
	mov ax, [es:bx]
	mov dx, [es:bx + 2]

		; INP:	dx:ax = cluster value, 2-based
		; OUT:	dx:ax -= 2 (makes it 0-based)
		;	CY iff invalid cluster
check_clust:
	and dx, 0FFFh
	sub ax, 2
	sbb dx, 0
	cmp dx, 0FFFh
	jb @F		; CY here means valid ...-
	cmp ax, 0FFF7h - 2
@@:			;  -... or if NC first, CY here also
	cmc		; NC if valid
	retn


found_it:
; get starting cluster of file
		mov ax, [es:di + 26 - 32]
		mov dx, [es:di + 20 - 32]
		pop di			; restore si:di = loaded FAT sector

		push dx
		push ax			; remember cluster for later

		mov word [VAR(load_seg)], _LOAD_ADR>>4	; :0-> load address
		call check_clust
		jc fsiboot_error_badchain

next_load_cluster:
		call clust_to_first_sector
			; dx:ax = first sector of cluster
			; cx:bx = cluster value
		push cx
		push bx			; preserve cluster number for later

		mov cx, [VAR(adj_sectors_per_cluster)]

		mov bx, [VAR(load_seg)]
; xxx - this will always load an entire cluster (e.g. 64 sectors),
; even if the file is shorter than this
@@:
		cmp bx, [VAR(last_available_sector)]
		jbe @F
		jmp near word [fsiboot.memory_full]

@@:
		push es		; (must preserve ADR_FATBUF reference)
		call near word [fsiboot.read_sector]
		pop es

		loop @B
		mov [VAR(load_seg)], bx
		pop bx
		pop cx
		call clust_next
		jnc next_load_cluster
		inc ax
		inc ax
		test ax, 8	; set in 0FFF_FFF8h--0FFF_FFFFh,
				;  clear in 0, 1, and 0FFF_FFF7h
		jz fsiboot_error_badchain
		jmp near word [fsiboot.success]


fsinfo_available:
	_fill 480 + 4,38,fsiboot

%assign num $-fsinfo_available
%warning FSINFO: num bytes still available.

	dd "rrAa"
	dd 0		; number of free clusters
	dd 0		; first free cluster
	times 3 dd 0	; FSINFO.reserved2
	dd 0_AA55_0000h	; FSINFO.signature3
