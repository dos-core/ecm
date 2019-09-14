%if 0

Create a boot image file (default: 1440 KiB diskette) in NASM
 2019, by C. Masloch

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif

%if 0

_PAYLOADFILE must be defined to a list of strings and/or keywords.
Keywords are accepted only as (non-string) tokens. The available
keywords are:

::empty		Ignored. Can be used to create an image without files.

::chdir		Change into subdirectory. May be followed by a ..
		 (dotdot) keyword to back out of a directory.
		 Otherwise, the filename of the subdirectory to
		 create (relative to the current directory),
		 as a string, is expected in the next list item.

Note that there is no check for duplicate directories, so if
the string ::chdir,'foo',::chdir,..,::chdir,'foo' is used,
there will be two subdirectories with the same name in the same
parent directory. Likewise, files may be duplicated and are
also not checked for this.

The order of the files' directory entries and cluster chains in
the file system is determined by the order they were specified
in the list. Particularly, in FAT12 and FAT16 images, the first
two files specified will be placed consecutively at the start
of the data area, which may be necessary for some loaders.
As this is not known to be required by any FAT32 loaders,
the FAT32 root directory counts as the first file.

Files and directories are always written into a single run of
clusters each, that is, there is no fragmentation.

Some things are not supported yet:

* File dates and times.

* Attributes other than the directory bit.

* A volume label directory entry.

* Long file names.

* FSINFO sector for FAT32.

* Backup boot sectors for FAT32.

* Boot sector loaders that are not exactly 512 bytes long.

* Automatic calculation of some parameters such as SPF.


A directory is always terminated with one or more directory
entries that are filled with all-zeros.

To specify the _PAYLOADFILE list to NASM from a bash shell,
the quoting must be doubled, eg -D_PAYLOADFILE="'file.bin'"
(The outer quotes are parsed and swallowed by bash, while
the inner quotes are passed verbatim to NASM.)

If _BOOTFILE is specified (not the empty quoted string),
it is expected that the (E)BPB of that boot sector matches
the file system parameters specified to the bootimg.asm file.
If _BOOTFILE equals "" then a proper (E)BPB is created,
along with a default loader (which aborts with an error).

%endif


%include "lmacros3.mac"

	defaulting

	numdef SPI, 2880	; sectors per image
	numdef BPS, 512		; bytes per sector
	numdef SPC, 1		; sectors per cluster
	numdef SPF, 9		; sectors per FAT
	numdef BPE, 12		; bits per entry
	numdef NUMFATS, 2	; number of FATs
	numdef NUMROOT, 224	; number of root directory entries
	numdef NUMRESERVED, 1	; number of reserved sectors
	numdef MEDIAID, 0F0h	; media ID
	numdef EOF, 15		; suffix of EOF entry marker

	numdef UNIT, 0		; load unit in BPB
	numdef CHS_SECTORS, 18	; CHS geometry field for sectors
	numdef CHS_HEADS, 2	; CHS geometry field for heads
	numdef HIDDEN, 0	; number of hidden sectors

	strdef BOOTFILE, "boot12.bin"
	strdef PAYLOADFILE, ""

	strdef OEM_NAME,	"    lDOS"
	strdef OEM_NAME_FILL,	'_'
	strdef DEFAULT_LABEL,	"NO NAME"


%ifidn _PAYLOADFILE, ""
  %error No payload files specified!
%endif


%if _BPE == 12
%elif _BPE == 16
%elif _BPE == 32
%else
 %error Invalid BPE (_BPE)
%endif

%if _BPE != 32
 %assign ROOTSECTORS (_NUMROOT * 32 + _BPS - 1) / _BPS
%else
 %assign ROOTSECTORS 0
%endif
%assign FATSECTORS _NUMFATS * _SPF
%assign DATASECTORS (_SPI - _NUMRESERVED - FATSECTORS - ROOTSECTORS)
%assign DATACLUSTERS (DATASECTORS / _SPC)
%assign NUMENTRIES _SPF * _BPS * 8 / _BPE
%if NUMENTRIES < (DATACLUSTERS + 2)
 %error Too few FAT sectors specified
%endif
%if NUMENTRIES > 0FF0h
 %if _BPE == 12
  %error FAT would be detected as FAT16
 %endif
%endif
%if NUMENTRIES < 1000h
 %if _BPE == 16
  %error FAT would be detected as FAT12
 %endif
%endif


%if _EOF < 8 || _EOF > 15
 %error Invalid EOF value (_EOF)
%endif

%if _BPE != 32
 %assign MAXENTRY (1 << _BPE) - 1
%else
 %assign MAXENTRY (1 << 28) - 1
%endif
%assign EOFSTARTENTRY MAXENTRY - 7
%assign EOFENDENTRY MAXENTRY
%assign BADENTRY MAXENTRY - 8
%assign EOFENTRY MAXENTRY - 15 + _EOF


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


	addsection boot, start=0 vstart=7C00h
boot_start:
%ifnidn _BOOTFILE, ""
	incbin _BOOTFILE
%else
	jmp strict short boot_after_bpb
	nop

oem_id:			; offset 03h (03) - not used by this code
	fill 8,_OEM_NAME_FILL,db _OEM_NAME
bytes_per_sector:	; offset 0Bh (11)
	dw _BPS
sectors_per_cluster:	; offset 0Dh (13)
	db _SPC
num_reserved_sectors:	; offset 0Eh (14)
	dw _NUMRESERVED
num_fats:		; offset 10h (16)
	db _NUMFATS
num_root_dir_ents:	; offset 11h (17)
%if _BPE != 32
	dw _NUMROOT
%else
	dw 0
%endif
total_sectors:		; offset 13h (19) - not used by this code
%if _SPI < 1_0000h
	dw _SPI		; (= 2880)
%else
	dw 0
%endif
media_id:		; offset 15h (21) - not used by this code
	db _MEDIAID
sectors_per_fat:	; offset 16h (22)
%if _BPE != 32
	dw _SPF
%else
	dw 0
%endif
sectors_per_track:	; offset 18h (24)
	dw _CHS_SECTORS
heads:			; offset 1Ah (26)
	dw _CHS_HEADS
hidden_sectors:		; offset 1Ch (28)
	dd _HIDDEN
total_sectors_large:	; offset 20h (32) - not used by this code
	dd _SPI

; Extended BPB		; offset 24h (36)

%if _BPE == 32
sectors_per_fat_large:	; offset 24h (36)
	dd _SPF
fsflags:		; offset 28h (40)
	dw 0
fsversion:		; offset 2Ah (42)
	dw 0
root_cluster:		; offset 2Ch (44)
	dd rootcluster
fsinfo_sector:		; offset 30h (48)
	dw 0
backup_sector:		; offset 32h (50)
	dw 0

	times 12 db 0	; offset 34h (52) reserved

; Extended BPB		; offset 40h (64)
%endif

boot_unit:		db _UNIT
			db 0
ext_bpb_signature:	db 29h
serial_number:		dd 0
volume_label:		fill 11,32,db _DEFAULT_LABEL
filesystem_identifier:
%if _BPE == 12
	fill 8,32,db "FAT12"
%elif _BPE == 16
	fill 8,32,db "FAT16"
%elif _BPE == 32
	fill 8,32,db "FAT32"
%else
 %error Invalid BPE
%endif


boot_after_bpb:
	cli
	cld
	xor ax, ax
	mov es, ax
	mov ds, ax
	mov ss, ax
	mov sp, 7C00h
	sti
	mov si, boot_message
@@:
	lodsb
	test al, al
	jz @F
	mov ah, 0Eh
	mov bh, [462h]
	mov bl, 7
	int 10h
	jmp @B

@@:
	xor ax, ax
	int 13h
	xor ax, ax
	int 16h
	int 19h

boot_message:
	db "Unable to boot, loader not written.",13,10
	db 13,10
	db "Press any key to reboot.",13,10
	db 0

	times 508 - ($ - $$) db 0
	dw 0
	dw 0AA55h
%endif
boot_end:

%if (boot_end - boot_start) != 512
 %error Boot file has wrong size
%endif
	align _BPS

	times (_NUMRESERVED * _BPS) - ($ - $$) db 0


	addsection fat, follows=boot align=_BPS


		; %1 = name for the equ to receive the start cluster,
		;	_start_cluster will be appended
		; %2 = how many clusters/entries to allocate
		;	(if zero, %1_start_cluster equ will be zero)
	%macro addfatchain 2.nolist
%xdefine FATCHAINS FATCHAINS,%1,%2
	%endmacro
%define FATCHAINS secondentry,1

		; %1 = numeric value to put into next entry
	%macro addfatentry 1.nolist
%xdefine FATENTRIES FATENTRIES,%1
	%endmacro


	%macro expandfatchains 2-*.nolist
%assign FATENTRIES (_MEDIAID | (MAXENTRY - 15))
				; first entry has media ID byte
%assign ii 1			; FATENTRIES has entry at index 0,
				;  next is index 1
%rep %0 / 2			; for each pair
 %if %2
  %1_start_cluster equ ii	; equ for start cluster
  %rep %2 - 1			; as many as are non-EOF entries
   %assign ii ii + 1
   addfatentry ii		; link to next cluster
  %endrep
  %assign ii ii + 1
  addfatentry EOFENTRY		; EOF entry
 %else
  %1_start_cluster equ 0	; empty chain, start cluster is 0
 %endif
 %rotate 2			; rotate to next pair
%endrep
	%endmacro


	addsection fixed_root, follows=fat align=_BPS
	sectalign off


		; %1 = directory name ("" if is root)
		; %2 = data section name to use
		; %3 = data section name of dir to write to (none if is root)
		; %4 = data cluster number of parent dir (0 if root is parent)
	%macro incdir 4.nolist
	usesection %2
%2 %+ _start:
%ifnidni %1, ""
	istruc DIRENTRY
at deName,		fill 8,32,db "."
at deExt,		fill 3,32,db 32
at deAttrib,		db ATTR_DIRECTORY
at deClusterHigh,	dw %%file_start_cluster >> 16
at deClusterLow,	dw %%file_start_cluster & 0FFFFh
at deSize,		dd 0
	iend
	istruc DIRENTRY
at deName,		fill 8,32,db ".."
at deExt,		fill 3,32,db 32
at deAttrib,		db ATTR_DIRECTORY
at deClusterHigh,	dw %4 >> 16
at deClusterLow,	dw %4 & 0FFFFh
at deSize,		dd 0
	iend
%endif

%xdefine CHAINLIST CHAINLIST,%%file

%ifnidni %3, none

%define string %1
%strlen length string
%assign ii 1
%rep length
 %substr cc string length - ii + 1
 %ifidn cc,"/"
  %error Subsubdirectory not supported yet
  %substr string string length -ii + 2, -1
  %exitrep
 %endif
 %ifidn cc,"\"
  %error Subsubdirectory not supported yet
  %substr string string length -ii + 2, -1
  %exitrep
 %endif
 %assign ii ii + 1
%endrep
%strlen length string
%assign ii 1
%define name ""
%define ext ""
%assign dotyet 0
%rep length
 %substr cc string ii
 %assign ii ii + 1
 %if cc >= 'a' && cc <= 'z'
  %substr cc "ABCDEFGHIJKLMNOPQRSTUVWXYZ" (cc - 'a' + 1)
 %endif
 %ifn dotyet
  %ifidn cc,"."
   %assign dotyet 1
  %else
   %strlen ll name
   %if ll >= 8
    %error Too long name part in %1
    %exitrep
   %endif
   checkchar %1,cc
   %strcat name name,cc
  %endif
 %else
  %strlen ll ext
  %if ll >= 3
   %error Too long ext part in %1
   %exitrep
  %else
   checkchar %1,cc,"."
   %strcat ext ext,cc
  %endif
 %endif
%endrep
%ifidn name,""
 %error Invalid empty name part in %1
%endif

	usesection %3
	istruc DIRENTRY
at deName,		fill 8,32,db name
at deExt,		fill 3,32,db ext
at deAttrib,		db ATTR_DIRECTORY
at deClusterHigh,	dw %%file_start_cluster >> 16
at deClusterLow,	dw %%file_start_cluster & 0FFFFh
at deSize,		dd 0
	iend
%else
 rootcluster equ %%file_start_cluster
%endif
%2 %+ _start_cluster equ %%file_start_cluster
	%endmacro


		; %1 = filename, may include a directory
		;	(the directory is only used to locate
		;	the file on the host system, the file
		;	will be written to the image with only
		;	its base name used, and in all-caps.)
		; %2 = data section name to use
		; %3 = data section name of directory to write to
	%macro incfile 3.nolist
	usesection %2
%2 %+ _start:
incbin %1
%assign filesize ($ - %2 %+ _start)

%xdefine CHAINLIST CHAINLIST,%%file

%define string %1
%strlen length string
%assign ii 1
%rep length
 %substr cc string length - ii + 1
 %ifidn cc,"/"
  %substr string string length -ii + 2, -1
  %exitrep
 %endif
 %ifidn cc,"\"
  %substr string string length -ii + 2, -1
  %exitrep
 %endif
 %assign ii ii + 1
%endrep
%strlen length string
%assign ii 1
%define name ""
%define ext ""
%assign dotyet 0
%rep length
 %substr cc string ii
 %assign ii ii + 1
 %if cc >= 'a' && cc <= 'z'
  %substr cc "ABCDEFGHIJKLMNOPQRSTUVWXYZ" (cc - 'a' + 1)
 %endif
 %ifn dotyet
  %ifidn cc,"."
   %assign dotyet 1
  %else
   %strlen ll name
   %if ll >= 8
    %error Too long name part in %1
    %exitrep
   %endif
   checkchar %1,cc
   %strcat name name,cc
  %endif
 %else
  %strlen ll ext
  %if ll >= 3
   %error Too long ext part in %1
   %exitrep
  %else
   checkchar %1,cc,"."
   %strcat ext ext,cc
  %endif
 %endif
%endrep
%ifidn name,""
 %error Invalid empty name part in %1
%endif

	usesection %3
	istruc DIRENTRY
at deName,		fill 8,32,db name
at deExt,		fill 3,32,db ext
at deClusterHigh,	dw %%file_start_cluster >> 16
at deClusterLow,	dw %%file_start_cluster & 0FFFFh
at deSize,		dd filesize
	iend
	%endmacro

	%macro checkchar 2-3.nolist 0
%if %2 <= ' ' || %2 >= 128 || \
	%2 == '/' || %2 == '\' || \
	%2 == '"' || %2 == %3
 %error Invalid character (%2) in name (%1)
%endif
	%endmacro


	%macro setup_a_section 0.nolist
	addsection data %+ filescount, follows= %+ ff vstart=0
data %+ filescount %+ _start:
  %xdefine ff data %+ filescount
  %assign filescount filescount + 1
	%endmacro

	%macro count_files_setup_sections 1-*.nolist
%assign filescount 0
%define ff fixed_root
%assign chdir 0
%rep %0
 %if chdir
  %ifnidni %1, ..		; (not if backing out of directory)
	setup_a_section		; add a section for a directory
  %endif
  %assign chdir 0
 %elifidni %1, ::chdir
  %assign chdir 1		; note next list entry is directory name
 %elifnidni %1, ::empty
	setup_a_section		; add a section for a file
 %endif
 %rotate 1
%endrep
%if chdir
 %error No directory to create specified
%endif
%if _BPE == 32
	setup_a_section		; add a section for root directory
%endif
	addsection empty, follows= %+ ff vstart=0
	%endmacro
	count_files_setup_sections _PAYLOADFILE


%define DIRLIST none
%define CHAINLIST none
	%macro multiincfile 1-*.nolist
%assign chainindex 0
%assign chdir 0
%push ROOT
%if _BPE == 32
	incdir "", data %+ chainindex, none, 0
 %xdefine nextdir data %+ chainindex
 %xdefine DIRLIST DIRLIST,nextdir
 %xdefine %$parent nextdir
; %xdefine %$parentcluster %$parent %+ _start_cluster
 %define %$parentcluster 0
 %assign chainindex chainindex + 1
%else
 %define %$parent fixed_root
 %define %$parentcluster 0
%endif
%rep %0
 %if chdir
  %ifidni %1, ..
   %ifctx ROOT
    %error Cannot back out over root
   %else
    %pop
   %endif
  %else
   %push SUB
	incdir %1, data %+ chainindex, %$$parent, %$$parentcluster
   %xdefine nextdir data %+ chainindex
   %xdefine DIRLIST DIRLIST,nextdir
   %xdefine %$parent nextdir
   %xdefine %$parentcluster %$parent %+ _start_cluster
   %assign chainindex chainindex + 1
  %endif
  %assign chdir 0
 %elifidni %1, ::chdir
  %assign chdir 1
 %elifnidni %1, ::empty
	incfile %1, data %+ chainindex, %$parent
  %assign chainindex chainindex + 1
 %endif
 %rotate 1
%endrep
%if chdir
 %error No directory to create specified
%endif
%rep 1024
 %ifctx ROOT
  %exitrep
 %else
  %pop
 %endif
%endrep
%pop
	%endmacro
	multiincfile _PAYLOADFILE


	%macro extenddirectories 1-*.nolist
%ifnidni %1, none
 %error Expected a none entry to start dir list
%endif
%rotate 1
%rep %0 - 1
	usesection %1
	times 32 db 0
		; Insure at least one entry. Makes things
		;  easier to handle for the loader too.
		;  (Can depend on a zero-filled entry
		;  that terminates the directory.)
 %rotate 1
%endrep
	%endmacro

	extenddirectories DIRLIST


	%macro allocatechains 1-*.nolist
%ifnidni %1, none
 %error Expected a none entry to start chain list
%endif
%rotate 1
%assign ii 0
%rep %0 - 1
	usesection data %+ ii
	align _BPS * _SPC
 %assign clusters ($ - data %+ ii %+ _start) / (_BPS * _SPC)
	addfatchain %1,clusters
 %assign ii ii + 1
 %rotate 1
%endrep
	%endmacro

	allocatechains CHAINLIST


%assign data_used 0
%assign ii 0
%rep filescount
	usesection data %+ ii
	align _BPS * _SPC
data %+ ii %+ _end:
 %assign data_used data_used \
	+ (data %+ ii %+ _end - data %+ ii %+ _start)
 %assign ii ii + 1
%endrep


	usesection fixed_root
%if _BPE != 32
	times 32 db 0
%endif
	times ROOTSECTORS * _BPS - ($ - $$)	db 0

	usesection empty
	times DATASECTORS * _BPS - data_used	db 0


%if _BPE == 32
 %define dumpfatentries dd
%elif _BPE == 16
 %define dumpfatentries dw
%elif _BPE == 12
	%macro dumpfatentries 2-*.nolist
%if (%0 & 1) == 1
 %error Expected even number of entries
%endif
%rep %0 / 2
	db (%1) & 0FFh
	db ((%1) >> 8) \
		| (((%2) & 0Fh) << 4)
	db ((%2) >> 4)
 %rotate 2
%endrep
	%endmacro
%else
 %error Invalid bits per entry (_BPE)
%endif


	expandfatchains FATCHAINS


	%macro assigncluster 2-*.nolist
%assign cluster %0
	%endmacro

	assigncluster FATENTRIES
%if _BPE == 12 && (cluster & 1) == 1
	addfatentry 0
%endif


	usesection fat
%assign ii 0
%rep _NUMFATS
fat%[ii]:
	dumpfatentries FATENTRIES
	times _SPF * _BPS - ($ - fat%[ii]) db 0
%assign ii ii+1
%endrep
%if FATSECTORS * _BPS - ($ - $$)
 %error Internal error in FAT filling
%endif
