
%if 0

lbasuch.asm - LBA search strings for instsect
 2024 by E. C. Masloch

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif


%define SEARCHES dw ""
%define METASEARCHES dw ""
%define METASTRINGS dw ""

	%macro search_wildcard 1-2 0
%assign %%wc $ + %2 - %1
%if %%wc == 0
 %error Wildcard at beginning of search string is not allowed
%endif
%xdefine WILDCARDS WILDCARDS, dw %%wc
	%endmacro

	%macro ldosboot_lba_search_string 10
%define WILDCARDS dw ""
%assign _FORCE_CHS %2
%assign _LBA_SKIP_CHECK %3
%assign _LBA_SKIP_CY %4
%assign _LBA_SKIP_LBA_RETRY %5
%assign _LBA_SKIP_ANY %6
%assign _RETRY_RESET %7
%assign _LBA_RETRY %8
%assign _LBA_WORKAROUND %9
%assign _CHS 1
%assign _LDOSBOOT32 %10


%if _FORCE_CHS
 %define %%identifier label_%1_chs
 %define %%other label_%1_lba
%else
 %define %%identifier label_%1_lba
 %define %%other label_%1_chs
%endif

%%start:
%[%%identifier %+ _search_string]:

 %if _LBA_SKIP_CHECK		; -14 bytes
	mov dl, [bp + 127]
search_wildcard %%start, -1
 %else
  %if _LBA_WORKAROUND
	push ds
	mov bx, 40h
	mov ds, bx
; Setting ds = 40h for the function 41h detection is a workaround
;  for a bug in the Book8088's Xi8088 BIOS. Refer to
;  https://www.bttr-software.de/forum/forum_entry.php?id=21275
  %endif
	mov ah, 41h
	mov dl, [bp + 127]
search_wildcard %%start, -1
	mov bx, 55AAh
	stc
%if _FORCE_CHS
	nop
	nop
%else
	int 13h		; 13.41.bx=55AA extensions installation check
%endif
  %if _LBA_WORKAROUND
	pop ds
  %endif
	jc .no_lba
search_wildcard %%start, -1
	cmp bx, 0AA55h
	jne .no_lba
search_wildcard %%start, -1
	shr cl, 1	; support bitmap bit 0
	jnc .no_lba
search_wildcard %%start, -1
 %endif

%if _LBA_RETRY
 %if _LBA_SKIP_CHECK && _LBA_SKIP_CY
	stc
 %endif
	mov ah, 42h
%if _FORCE_CHS
	nop
	stc
%else
	int 13h		; 13.42 extensions read
%endif
	jnc .lba_done
search_wildcard %%start, -1

 %if _RETRY_RESET
	xor ax, ax
	int 13h		; reset disk
 %endif

		; have to reset the LBAPACKET's lpCount, as the handler may
		;  set it to "the number of blocks successfully transferred".
		; (in any case, the high byte is still zero.)
	mov byte [si + 2], 1
%endif

 %if _LBA_SKIP_CHECK && _LBA_SKIP_CY
	stc
 %endif
%if _FORCE_CHS
	mov ah, 01h
	nop
	stc
%else
	mov ah, 42h
	int 13h
%endif
 %if _LBA_SKIP_CHECK && _CHS
 %if _LDOSBOOT32
  %if _LBA_SKIP_ANY
	jc .no_lba
search_wildcard %%start, -1
  %else
	jnc .lba_done
search_wildcard %%start, -1
	cmp ah, 1	; invalid function?
	je .no_lba	; try CHS instead -->
search_wildcard %%start, -1
  %endif
 %else
  %if _LBA_SKIP_ANY
	jc .no_lba
search_wildcard %%start, -1
  %else
	jc .lba_check_error_1
search_wildcard %%start, -1
  %endif
 %endif
 %else
.cy_err:
	jc .lba_error
search_wildcard %%start, -1
 %endif

.lba_error:
.lba_check_error_1:
.lba_done:
.no_lba:
%%end:

%if _FORCE_CHS
 %define %%message lba_search_msg.forcechs
%else
 %if _LBA_SKIP_CHECK
  %define %%message lba_search_msg.autoskip
 %else
  %define %%message lba_search_msg.auto
 %endif
%endif
%xdefine SEARCHES SEARCHES, %%identifier:, dw %%start, dw %%end - %%start, \
	 dw %%message, dw %%other, WILDCARDS, dw 0
%xdefine METASEARCHES METASEARCHES, dw %%metaname
%defstr %%name %%identifier
%xdefine METASTRINGS METASTRINGS, %%metaname:, {asciz %%name}
%[%%identifier %+ _length]: equ %%end - %%start
%if _FORCE_CHS
 %if %[%%identifier %+ _length] != %[%%other %+ _length]
  %error Expected same length of replacement
 %endif
%endif
	%endmacro

	%macro freedos_lba_search_string 4
%define WILDCARDS dw ""
%assign _FORCE_CHS %2
%assign _OEM_BOOT %3
%assign _FORCE_CHS_DISKETTE %4


%if _FORCE_CHS_DISKETTE
 %define %%identifier label_%1_chs_diskette
 %define %%other label_%1_special
%elif _FORCE_CHS
 %define %%identifier label_%1_chs
 %define %%other label_%1_lba
%else
 %define %%identifier label_%1_lba
 %define %%other label_%1_chs
%endif

%%start:
%[%%identifier %+ _search_string]:

	mov ah, 41h
	mov bx, 55AAh
	mov dl, [bp + 127]
search_wildcard %%start, -1

%if _FORCE_CHS
	xor dl, dl
	jz @F
%elif _FORCE_CHS_DISKETTE
	test dl, dl
	jz @F
%else
	test dl, dl
	nop
	nop
%endif
	int 13h
	jc @F
	shr cx, 1
	sbb bx, 0AA55h - 1
	jne @F

%if _OEM_BOOT
	lea si, [bp + 1023]
search_wildcard %%start, -2
search_wildcard %%start, -1
	mov word [bp + 1023], bx
search_wildcard %%start, -2
search_wildcard %%start, -1
	mov word [bp + 1023], bx
search_wildcard %%start, -2
search_wildcard %%start, -1
%else
	lea si, [bp - 128]
search_wildcard %%start, -1
	mov word [bp - 128], bx
search_wildcard %%start, -1
	mov word [bp - 128], bx
search_wildcard %%start, -1
%endif
	mov ah, 42h
	jmp strict short @F
search_wildcard %%start, -1
@@:
%%end:


%if _FORCE_CHS
 %define %%message lba_search_msg.forcechs
%else
 %if _FORCE_CHS_DISKETTE
  %define %%message lba_search_msg.autohdd
 %else
  %define %%message lba_search_msg.auto
 %endif
%endif
%xdefine SEARCHES SEARCHES, %%identifier:, dw %%start, dw %%end - %%start, \
	 dw %%message, dw %%other, WILDCARDS, dw 0
%xdefine METASEARCHES METASEARCHES, dw %%metaname
%defstr %%name %%identifier
%xdefine METASTRINGS METASTRINGS, %%metaname:, {asciz %%name}
%[%%identifier %+ _length]: equ %%end - %%start
%if _FORCE_CHS
 %if %[%%identifier %+ _length] != %[%%other %+ _length]
  %error Expected same length of replacement
 %endif
%endif
	%endmacro


lba_search_msg:
.auto:		asciz "Auto LBA detection"
.autohdd:	asciz "Auto LBA detection (HDD only)"
.autoskip:	asciz "Auto LBA detection (skip check)"
.forcechs:	asciz "Forced CHS access"

lba_search_strings_lba:
	freedos_lba_search_string freedos, 0, 0, 0
	freedos_lba_search_string freedos_oem, 0, 1, 0
%assign variant 0
%rep 512
 %if variant == 256
lba_search_strings_chs:
	freedos_lba_search_string freedos, 1, 0, 0
	freedos_lba_search_string freedos_oem, 1, 1, 0
 %endif
 %assign identifier variant & ~256
	ldosboot_lba_search_string \
	 identifier, \
	 variant & 256, \
	 variant & 1, \
	 variant & 2, \
	 variant & 4, \
	 variant & 8, \
	 variant & 16, \
	 variant & 32, \
	 variant & 64, \
	 variant & 128
 %assign variant variant + 1
%endrep

lba_search_strings_hdd:
	freedos_lba_search_string freedos_hdd, 0, 0, 1
	freedos_lba_search_string freedos_hdd_oem, 0, 1, 1
lba_search_strings_end:

%ifn label_freedos_chs_length == label_freedos_hdd_chs_diskette_length
  %error Expected same length of replacement
%endif
%ifn label_freedos_lba_length == label_freedos_hdd_chs_diskette_length
  %error Expected same length of replacement
%endif
%ifn label_freedos_oem_chs_length == label_freedos_hdd_oem_chs_diskette_length
  %error Expected same length of replacement
%endif
%ifn label_freedos_oem_lba_length == label_freedos_hdd_oem_chs_diskette_length
  %error Expected same length of replacement
%endif


	align 2, db 0
label_hdd_special:

label_freedos_hdd_special:
	dw label_freedos_hdd_chs_diskette
	dw label_freedos_chs
	dw label_freedos_lba

label_freedos_hdd_oem_special:
	dw label_freedos_hdd_oem_chs_diskette
	dw label_freedos_oem_chs
	dw label_freedos_oem_lba

	dw 0,0,0


	%macro dumpsearches 1-*
%rep %0
 %1
 %rotate 1
%endrep
	%endmacro

	align 2, db 0
lba_search_metadata:
dumpsearches SEARCHES
	dw 0,0
