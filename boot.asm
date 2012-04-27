
%if 0

File system boot sector loader code for FAT12

Adapted from 2002-11-26 fatboot.zip/fat12.asm,
 released as public domain by Chris Giese

Public domain by C. Masloch, 2012

%endif


%include "lmacros1.mac"

	numdef FREEDOS_COMPAT,	0	; partial FreeDOS load compatibility

	strdef OEM_NAME,	"    lDOS"
%ifn _FREEDOS_COMPAT
	strdef LOAD_NAME,	"LDOS"
	strdef LOAD_EXT,	"BIN"	; name of file to load
	numdef LOAD_ADR,	00610h	; where to load
	numdef EXEC_SEG_ADJ,	0	; how far cs will be from _LOAD_ADR
	numdef EXEC_OFS,	0	; what value ip will be
	numdef SET_BL_UNIT,	0	; if to pass unit in bl as well
%else	; Following set is for _FREEDOS_COMPAT.
	; Uses different defaults and forces one option on.
	strdef LOAD_NAME,	"KERNEL"
	strdef LOAD_EXT,	"SYS"
	numdef LOAD_ADR,	00600h
	numdef EXEC_SEG_ADJ,	0
	numdef EXEC_OFS,	0
 %assign _SET_BL_UNIT		1
%endif

%if 0

Notes about partial FreeDOS load compatibility

* Boot unit is always passed in dl;
   with _SET_BL_UNIT turned on we _additionally_ pass it in bl
* Load address defaults to 00600h, as expected/required
* Execution address adjustments default to 0, ie 0060h:0000h
* Called "partial" as we do not relocate to 27A00h (1FE0h:7C00h)

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
%elif _LOAD_ADR > (POSITION-256) && (POSITION+512) < _LOAD_ADR
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

; first-stage address				offset	linear
%define 	FS_ORG	100h			; 100h	7C00h

; 512-byte stack. Put this ABOVE the code in memory, so this code
; can also be built as a .COM file (for testing purposes only!)
ADR_STACK	equ	(FS_ORG + 400h)		; 500h	8000h

; one-sector directory buffer. I assume FAT sectors are no larger than 4K
ADR_DIRBUF	equ	ADR_STACK		; 500h	8000h

; two-sector FAT buffer -- two sectors because FAT12
; entries are 12 bits and may straddle a sector boundary
ADR_FATBUF	equ	(ADR_DIRBUF + 1000h)	; 1500h	9000h

; start of unused memory:			  3500h	B000h

; use byte-offset addressing from BP for smaller code
%define	VAR(x)	((x) - start) + bp

; bootsector loaded at physical address 07C00h, but address 100h
; will work if we load IP and segment registers properly.
; This is also the ORG address of a DOS .COM file
	ORG FS_ORG
start:

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; VARIABLES
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; (1 byte) drive we booted from; 0=A, 80h=C
boot_drive		EQU (start - 1)

; (2 bytes) number of 16-byte paragraphs per sector
para_per_sector		EQU (boot_drive - 2)

; (2 bytes) number of 32-byte FAT directory entries per sector
dir_ents_per_sector	EQU (para_per_sector - 2)

; (2 bytes) sector where the actual disk data starts
; This is relative to partition start, so we need only 16 bits
data_start		EQU (dir_ents_per_sector - 2)

; (2 bytes) number of 16-byte paragraphs per cluster
para_per_cluster	EQU (data_start - 2)

	jmp strict short skip_bpb
	nop

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; MINIMAL BIOS PARAMETER BLOCK (BPB)
;
; 'Minimal' means just enough of a BPB so DOS/Windows:
; - recognizes this disk as a FAT12 floppy,
; - doesn't complain when you try to access the disk,
; - doesn't insist on a full format if you say "FORMAT /Q A:"
;
; Installation will use the BPB already present on your floppy disk.
; The values shown here work only with 1.44 meg disks (CHS=80:2:18)
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
	dw 18 * 2 * 80
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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; CODE
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

skip_bpb:
; put CPU into a known state
	jmp ((7C00h - FS_ORG) / 16):fix_cs
fix_cs:
	mov ax,cs
	mov ds,ax
	mov es,ax
	mov ss,ax
	mov sp,ADR_STACK
	mov bp,start
	mov [VAR(boot_drive)],dl
	cld

; calculate some values that we need:
; 16-byte paragraphs per sector
	mov ax,[VAR(bytes_per_sector)]
	mov cl,4
	shr ax,cl
	mov [VAR(para_per_sector)],ax

; 16-byte paragraphs per cluster
	xor dh,dh
	mov dl,[VAR(sectors_per_cluster)]
	mul dx
	mov [VAR(para_per_cluster)],ax

; 32-byte FAT directory entries per sector
	mov ax,[VAR(bytes_per_sector)]
	mov bx,32 ; bytes/dirent
	xor dx,dx
	div bx
	mov [VAR(dir_ents_per_sector)],ax

; number of sectors used for root directory (store in CX)
	mov ax,[VAR(num_root_dir_ents)]
	mul bx
	div word [VAR(bytes_per_sector)]
	mov cx,ax

; first sector of root directory
	xor ah,ah
	mov al,[VAR(num_fats)]
	mul word [VAR(sectors_per_fat)]
	add ax,[VAR(num_reserved_sectors)]

; first sector of disk data area:
	mov si,ax
	add si,cx
	mov [VAR(data_start)],si

; scan root directory for file. We don't bother to check for deleted
; entries or 'virgin' entries (first byte = 0) that mark end of directory
	mov bx,ADR_DIRBUF
next_sect:
	push cx
		mov cx,1
		call read_sectors_chs
	pop cx
	jc disk_error
	mov si,bx
	push cx
		mov cx,[VAR(dir_ents_per_sector)]
next_ent:
		mov di,load_name
		push si
		push cx
			mov cx,11 ; 8.3 FAT filename
			rep cmpsb
		pop cx
		pop si
		je found_it
		add si,32	; bytes/dirent
		loop next_ent
	pop cx
	add ax,byte 1	; next sector
	adc dx,byte 0
	loop next_sect
	mov al,'F'	; file not found; display blinking 'F'

; 'hide' the next 2-byte instruction by converting it to CMP AX,NNNN
; I learned this trick from Microsoft's Color Computer BASIC :)
	db 3Dh
disk_error:
	mov al,'R'	; disk read error; display blinking 'R'
error:
	mov ah,9Fh	; blinking blue-on-white attribute
	mov bx,0B800h	; xxx - 0B800h assumes color emulation...
	mov es,bx	; ...should still be able to hear the beep
	mov [es:0],ax

	mov ax,0E07h	; *** BEEEP ***
	int 10h
exit:
	mov ah,0	; await key pressed
	int 16h

	int 19h		; re-start the boot process

found_it:
; leave the old CX value on the stack to save a byte or two
; Get conventional memory size (Kbytes) in AX
		int 12h

; subtract load address
		sub ax,(_LOAD_ADR>>10)

; convert from K to bytes
		mov dx,1024
		mul dx

; 32-bit file size (4 bytes) is at [si + 28]
; If second stage file is too big...
		sub ax,[si + 28]
		sbb dx,[si + 30]

; ...display a blinking 'M'
		mov al,'M'
		jc error

; get starting cluster of file
		mov si,[si + 26]

; set load address DI:BX
		xor bx,bx
		mov di,(_LOAD_ADR>>4)
		xor ch,ch
		mov cl,[VAR(sectors_per_cluster)]
next_cluster:
; convert 16-bit cluster value (in SI) to 32-bit LBA sector value (in DX:AX)
; and get next cluster in SI
		call walk_fat
		jc disk_error

; xxx - this will always load an entire cluster (e.g. 64 sectors),
; even if the file is shorter than this
		mov es,di
		call read_sectors_chs
		jc disk_error
		add di,[VAR(para_per_cluster)]

; 0FF6h: reserved	0FF7h: bad cluster
; 0FF8h-0FFEh: reserved	0FFFh: end of cluster chain
		cmp si,0FF6h
		jb next_cluster

; turn off floppy motor
		mov dx,3F2h
		mov al,0
		out dx,al

; jump to second stage
		mov ax,(_LOAD_ADR>>4) + _EXEC_SEG_ADJ
		mov ds,ax
		mov es,ax

; we leave SS:SP as they were
; Here is the actual far 'jump' to the second stage (RETF, actually)
		push ax
		mov bx,_EXEC_OFS
		push bx
		retf

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; name:			read_sectors_chs
; action:		reads one or more disk sectors using INT 13h AH=02h
; in:			DX:AX=LBA number of sector to read (relative to
;			start of partition), CX=sector count, ES:BX -> buffer
; out (disk error):	CY=1
; out (success):	CY=0
; modifies:		(nothing)
; minimum CPU:		8088
; notes:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

read_sectors_chs:
	push es
	push di
	push dx
	push cx
	push ax

; DX:AX==LBA sector number
; add partition start (= number of hidden sectors)
		add ax,[VAR(hidden_sectors + 0)]
		adc dx,[VAR(hidden_sectors + 2)]
		inc cx
		jmp short rsc_3
rsc_1:
		push dx
		push cx
		push ax

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
			mov di,ax
			mov ax,dx
			xor dx,dx
			div word [VAR(heads)]
			xchg di,ax
			div word [VAR(heads)]
			xchg di,dx

; DX:AX=quotient=cylinder (C), DI=remainder=head (H)
; error if cylinder >=1024
			or dx,dx	; DX != 0; so cyl >= 65536
			stc
			jne rsc_2
			cmp ah,4	; AH >= 4; so cyl >= 1024
			cmc
			jb rsc_2

; move variables into registers for INT 13h AH=02h
			mov dx,di
			mov dh,dl	; DH=head
			inc cx		; CL5:0=sector
			mov ch,al	; CH=cylinder 7:0
			shl cl,1
			shl cl,1
			shr ah,1
			rcr cl,1
			shr ah,1
			rcr cl,1	; CL7:6=cylinder 9:8
			mov dl,[VAR(boot_drive)] ; DL=drive

; we call INT 13h AH=02h once for each sector. Multi-sector reads
; may fail if we cross a track or 64K boundary
			mov ax,0201h	; AH=02h, AL=num_sectors
			int 13h
			jnc rsc_2
; reset drive
			xor ax,ax
			int 13h
			jc rsc_2
; try read again
			mov ax,0201h
			int 13h
rsc_2:
		pop ax
		pop cx
		pop dx
		jc rsc_4

; increment segment part of address and LBA sector number, and loop
		mov di,es
		add di,[VAR(para_per_sector)]
		mov es,di
		inc ax
		jne rsc_3
		inc dx
rsc_3:
		loop rsc_1
rsc_4:
	pop ax
	pop cx
	pop dx
	pop di
	pop es
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; name:			walk_fat
; action:		converts cluster number to sector number and
;			finds next cluster in chain
; in:			SI = cluster
; out (disk error):	CY=1
; out (success):	CY=0, SI = next cluster, DX:AX = sector number
; modifies:		AX, DX, SI
; minimum CPU:		8088
; notes:
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

walk_fat:
	push es
	push di
	push cx
	push bx

; cluster 2 is the first data cluster
		lea ax,[si - 2]

; convert from clusters to sectors
		mov dh,0
		mov dl,[VAR(sectors_per_cluster)]
		mul dx
		add ax,[VAR(data_start)]
		adc dx,byte 0

; DX:AX is return value: save it
		push dx
		push ax

; prepare to load FAT
			mov ax,(ADR_FATBUF / 16)
			mov es,ax
			xor bx,bx

; FAT12 entries are 12 bits, bytes are 8 bits. Ratio is 3 / 2,
; so multiply cluster by 3 now, and divide by 2 later.
			xor dx,dx
			mov ax,si
			shl ax,1
			rcl dx,1
			add ax,si
			adc dx,byte 0

; DX:AX b0	=use high or low 12 bits of 16-bit value read from FAT
; DX:AX b9:1	=byte offset into FAT sector (9 bits assumes 512-byte sectors)
; DX:AX b?:10	=which sector of FAT to load
			mov di,ax
			shr dx,1
			rcr ax,1
			div word [VAR(bytes_per_sector)]

; remainder is byte offset into FAT sector: put it in SI
			mov si,dx

; quotient in AX is FAT sector: add FAT starting sector
			add ax,[VAR(fat_start)]

; check the FAT buffer to see if this sector is already loaded
; (simple disk cache; speeds things up a little --
; actually, it speeds things up a lot)
			cmp ax,[curr_sector]
			je wf_1
			mov [curr_sector],ax

; read the target FAT sector. FAT12 entries may straddle a sector
; boundary, so read 2 sectors.
			xor dx,dx
			mov cx,2
			call read_sectors_chs
			jc wf_4
wf_1:
; get 16 bits from FAT
			mov ax,[es:bx + si]

; look at DI:0 to see if we want the high 12 bits or the low 12 bits
			shr di,1
			jc wf_2
			and ax,0FFFh	; CY=1: use low 12 bits
			jmp short wf_3
wf_2:
			mov cl,4
			shr ax,cl	; CY=0: use high 12 bits
wf_3:
			mov si,ax

; clear CY bit to signal success
			xor dx,dx
wf_4:
		pop ax
		pop dx
	pop bx
	pop cx
	pop di
	pop es
	ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; DATA
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; which sector is in the FAT buffer
; this is relative to partition start, so we need only 16 bits
curr_sector:
	dw -1
load_name:
	fill 8,32,db _LOAD_NAME
	fill 3,32,db _LOAD_EXT

	_fill 508,38,start

	dw 0
; 2-byte magic bootsector signature
	dw 0AA55h
