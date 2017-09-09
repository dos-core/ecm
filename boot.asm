
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

	numdef QUERY_GEOMETRY,	0	; query geometry via 13.08
	numdef USE_PART_INFO,	0	; use ds:si-> partition info from MBR, if any
	numdef RPL,		0	; support RPL and do not overwrite it

	numdef SET_BL_UNIT,	0	; if to pass unit in bl as well
	numdef SET_AXBX_DATA,	0	; if to pass first data sector in ax:bx
	numdef SET_DSSI_DPT,	0	; if to pass DPT address in ds:si
	numdef PUSH_DPT,	0	; if to push DPT address
	numdef MEMORY_CONTINUE,	0	; if to just execute when memory full
	numdef SET_DI_CLUSTER,	0	; if to pass first load file cluster in di

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
%endif

%if _COMPAT_IBM
	strdef LOAD_NAME,	"IBMBIO"
	strdef LOAD_EXT,	"COM"
	numdef LOAD_ADR,	00700h
	numdef EXEC_SEG_ADJ,	0
	numdef EXEC_OFS,	0
 %assign _SET_AXBX_DATA		1
 %assign _SET_DSSI_DPT		1
 %assign _PUSH_DPT		1
 %assign _MEMORY_CONTINUE	1
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
 %assign _SET_DI_CLUSTER	1
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

; one-sector directory buffer. Assumes sectors are no larger than 8 KiB
ADR_DIRBUF	equ	end -start+7C00h	; 07E00h

; two-sector FAT buffer -- two sectors because FAT12
;  entries are 12 bits and may straddle a sector boundary
; this shares its area with the directory buffer as they
;  are not simultaneously used
ADR_FATBUF	equ	ADR_DIRBUF		; 07E00h

; start of unused memory:
ADR_FREE	equ	(ADR_FATBUF + 2*8192)	; 0BE00h

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

lowest_variable		equ last_available_sector

	jmp strict short skip_bpb
	nop


; BIOS Parameter Block (BPB)
;
; Installation will use the BPB already present on your floppy disk.
; The values shown here work only with 1440 KiB disks (CHS=80:2:18)

oem_id:			; offset 03h (03) - not used by this code
	fill 8,OEM_NAME_FILL,db _OEM_NAME
bytes_per_sector:	; offset 0Bh (11)
	dw 512
sectors_per_cluster:	; offset 0Dh (13)
	db 1
fat_start:
num_reserved_sectors:	; offset 0Eh (14)
	dw 1
num_fats:		; offset 10h (16)
	db 2
num_root_dir_ents:	; offset 11h (17)
	dw 224
total_sectors:		; offset 13h (19) - not used by this code
	dw 18 * 2 * 80	; (= 2880)
media_id:		; offset 15h (21) - not used by this code
	db 0F0h
sectors_per_fat:	; offset 16h (22)
	dw 9
sectors_per_track:	; offset 18h (24)
	dw 18
heads:			; offset 1Ah (26)
	dw 2
hidden_sectors:		; offset 1Ch (28)
	dd 0
total_sectors_large:	; offset 20h (32) - not used by this code
	dd 0

; Extended BPB

boot_unit:		db 0
			db 0
ext_bpb_signature:	db 29h
serial_number:		dd 0
volume_label:		fill 11,32,db _DEFAULT_LABEL
filesystem_identifier:	fill 8,32,db "FAT1",'2'+4*!!_FAT16


; Initialised data

load_name:
	fill 8,32,db _LOAD_NAME
	fill 3,32,db _LOAD_EXT


; Code

skip_bpb:
	cli
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
	cld


; calculate some values that we need:
; adjusted sectors per cluster (store in a word,
;  and decode EDR-DOS's special value 0 meaning 256)
	mov al, [VAR(sectors_per_cluster)]
	dec al
	inc ax
	mov [VAR(adj_sectors_per_cluster)], ax

%if _QUERY_GEOMETRY	; +27 bytes
	test dl, dl		; floppy?
	jns @F			; don't attempt query, might fail -->
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

; 16-byte paragraphs per sector
	mov ax,[VAR(bytes_per_sector)]
	mov cx,4			; ! ch = 0
	shr ax,cl
	mov [VAR(para_per_sector)],ax

; 32-byte FAT directory entries per sector
	shr ax, 1			; /2 = 32-byte entries per sector

; number of sectors used for root directory (store in CX)
	xor dx, dx
	mov si, [VAR(num_root_dir_ents)]
	mov bx, ax
	dec ax				; rounding up
	add ax, si			; from BPB
	adc dx, dx			; account for overflow (dx was zero)
	div bx				; get number of root sectors
	xchg ax, cx			; cx = number of root secs, ! ah = 0

; first sector of root directory
	mov al,[VAR(num_fats)]		; ! ah = 0, hence ax = number of FATs
	mul word [VAR(sectors_per_fat)]
	add ax,[VAR(num_reserved_sectors)]
	adc dl, dh			; account for overflow (dh was and is 0)

	xor di, di

; first sector of disk data area:
	add cx, ax
	adc di, dx
	mov [VAR(data_start)], cx
	mov [VAR(data_start+2)], di

; Scan root directory for file. We don't bother to check for deleted
;  entries (E5h) or entries that mark the end of the directory (00h).
		; number of root entries in si here
next_sect:
	mov cx, bx		; entries per sector as loop counter
	call read_sector_buf
	mov bx, cx		; restore bx for next iteration later

	xor di, di		; es:di-> first entry in this sector
next_ent:
	push si
	push di
	push cx
	mov si, load_name	; ds:si-> name to match
	mov cx, 11		; length of padded 8.3 FAT filename
	repe cmpsb		; check entry
	pop cx
	pop di
	pop si
	lea di, [di + 32]	; bytes/dirent
	je found_it		; found entry -->

	dec si			; count down entire root's entries
	loopnz next_ent		; count down sector's entries (jumps iff si >0 && cx >0)
	jnz next_sect		; (jumps iff si >0 && cx ==0)
				; ends up here iff si ==0
				;  ie all root entries checked unsuccessfully

	mov al,'F'	; File not 'F'ound

%ifn _MEMORY_CONTINUE
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


found_it:
%if _LOAD_ADR >= ADR_FREE
; Get conventional memory size and store it
		int 12h
		mov cl, 6
		shl ax, cl
%if _RPL
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
%endif
		sub ax, [VAR(para_per_sector)]
		mov [VAR(last_available_sector)], ax
%elif _LOAD_ADR < ADR_STACK_LOW
%else
 %error Load address within used memory
%endif

; get starting cluster of file
		mov si,[es:di + 26 - 32]
%if _SET_DI_CLUSTER
		push si			; remember cluster for later
%endif

%if !_FAT16
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
		mov cx, [VAR(sectors_per_fat)]
					; maximum size of this FS's FAT
		xor dx, dx
		mov ax, [VAR(fat_start)]; = first FAT sector
		mov bx, ADR_FATBUF>>4
@@:
		call read_sector	; read next FAT sector
		sub di, [VAR(bytes_per_sector)]
					; di = bytes still left to read
		jbe @F			; if none -->
					; (jbe means jump if CF || ZF)
		loop @B			; if any FAT sector still remains -->
@@:					; one of the limits reached; FAT read
%endif

		mov bx, _LOAD_ADR>>4	; :0-> load address
%if _FAT16
		mov di, -1		; = no FAT sector read yet
%endif

next_cluster:
; convert 16-bit cluster value (in SI) to 32-bit LBA sector value (in DX:AX)
; and get next cluster in SI


		; Converts cluster number to sector number
		;  and finds next cluster in chain
		;
		; INP:	si = valid cluster number
		;	(!_FAT16) [ADR_FATBUF] = entire FAT as read from FS
		;	(_FAT16) di = currently buffered FAT sector, -1 if none
		; OUT:	If unable to read a FAT sector,
		;	 ! jumps to error instead of returning
		;	If everything is okay,
		;	 si = next cluster number (or EOC value)
		;	 dx:ax = sector number
		;	 (_FAT16) di = currently buffered FAT sector
		; CHG:	cx

		push si			; preserve cluster number for later

; prepare to load entry from FAT

%if _FAT16
; Multiply cluster number by 2.
		xchg ax, si
		xor dx, dx		; dx:ax = entry to load (0..FFF6h)
		add ax, ax
		adc dx, dx		; dx:ax = byte offset into FAT (0..131052)

; Divide by sector size to split dx:ax into the remainder as the byte offset
;  into the FAT sector, and quotient as the sector offset into the FAT.
		div word [VAR(bytes_per_sector)]
		mov si, dx		; = byte offset in sector
			; dx = byte offset into sector (0..8190)
			; ax = sector offset into FAT (0..4095)

; quotient in AX is FAT sector.
; check the FAT buffer to see if this sector is already loaded
; (simple disk cache; speeds things up a little --
; actually, it speeds things up a lot)
		cmp ax, di
		je @F
		mov di, ax

; read the target FAT sector.
		push bx
		xor dx, dx
		add ax, [VAR(fat_start)]
		adc dx, dx		; (account for overflow)
		call read_sector_buf
		pop bx
@@:

; get 16 bits from FAT
		es lodsw
%else
; FAT12 entries are 12 bits, bytes are 8 bits. Ratio is 3 / 2,
;  so multiply cluster number by 3 first, then divide by 2.
		mov ax, si		; = cluster number (up to 12 bits set)
		xor dx, dx
		shl ax, 1		; = 2n (up to 13 bits set)
		add ax, si		; = 2n+n = 3n (up to 14 bits set)
		shr ax, 1		; ax = byte offset into FAT (0..6129)
					; CF = whether to use high 12 bits
		sbb cx, cx		; = -1 iff CY, else 0

; Use the calculated byte offset as an offset into the FAT
;  buffer, which holds all of the FAT's relevant data.
		add ax, ADR_FATBUF	; -> 16-bit word in FAT to load
		xchg ax, si

; get 16 bits from FAT
		lodsw

		and cl, 4	; = 4 iff CY after shift, else 0
		shr ax, cl	; shift down iff odd entry, else unchanged
		and ax, 0FFFh	; insure it's only 12 bits
%endif
		xchg ax, si
		pop ax		; restore cluster number
; adjust cluster number to make it 0-based
		dec ax
		dec ax

; convert from clusters to sectors
		mul word [VAR(adj_sectors_per_cluster)]
		add ax, [VAR(data_start)]
		adc dx, [VAR(data_start)+2]
				; dx:ax = sector number

; xxx - this will always load an entire cluster (e.g. 64 sectors),
; even if the file is shorter than this
		mov cx, [VAR(adj_sectors_per_cluster)]
@@:		
%if _LOAD_ADR >= ADR_FREE
		cmp bx, [VAR(last_available_sector)]
%elif _LOAD_ADR < ADR_STACK_LOW
		cmp bx, (ADR_STACK_LOW-8192)>>4
%else
 %error Load address within used memory
%endif
%if _MEMORY_CONTINUE
		ja @F
%else
		ja error_filetoobig
%endif
%if _FAT16
		push es		; (must preserve ADR_FATBUF reference)
%endif
		call read_sector
%if _FAT16
		pop es
%endif
		loop @B

%if _FAT16
; FFF7h: bad cluster
; FFF8h-FFFFh: end of cluster chain
		cmp si, 0FFF7h
%else
; 0FF7h: bad cluster
; 0FF8h-0FFFh: end of cluster chain
		cmp si, 0FF7h
%endif
		jb next_cluster

@@:

; turn off floppy motor
		mov dx,3F2h
		mov al,0
		out dx,al

; Set-up registers for and jump to loaded file
; Already: ss:bp-> boot sector containing BPB
		mov dl, [VAR(boot_unit)]	; set dl to unit
%if _SET_DI_CLUSTER && (_PUSH_DPT || _SET_DSSI_DPT)
		pop cx
%endif
%if _SET_BL_UNIT
		mov bl, dl		; set bl to unit, too
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
%if _SET_DI_CLUSTER
 %if _PUSH_DPT || _SET_DSSI_DPT
		mov di, cx
 %else
		pop di
 %endif
%endif
		jmp (_LOAD_ADR>>4)+_EXEC_SEG_ADJ:_EXEC_OFS


		; INP:	dx:ax = sector
		; OUT:	only if successful
		;	dx:ax = incremented
		;	bx:0-> behind read sector
		;	es = ADR_FATBUF>>4 = ADR_DIRBUF>>4
		; CHG:	-
read_sector_buf:
%if ADR_DIRBUF != ADR_FATBUF
 %error Buffers assumed to be the same.
%endif
	mov bx, ADR_FATBUF>>4

		; Read a sector using Int13.02
		;
		; INP:	dx:ax = sector number within partition
		;	bx:0-> buffer
		; OUT:	If unable to read,
		;	 ! jumps to error instead of returning
		;	If sector has been read,
		;	 dx:ax = next sector number (has been incremented)
		;	 bx:0-> next buffer (bx = es+word[para_per_sector])
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
	add bx, [VAR(para_per_sector)]

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


available:
	_fill 508,38,start

signatures:
	dw 0
; 2-byte magic bootsector signature
	dw 0AA55h

%assign num signatures-available
%warning num bytes still available.

end:
