
%if 0

Multiboot header and loader
 2008--2019 by C. Masloch

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.

%endif

%macro mbootchecksummed 1.nolist 1BADB002h
	dd %2		; signature
	dd %1		; flags
	dd -(%2+%1)	; checksum: dword sum of these three = 0
%endmacro

MBOOTBASE equ (1024+64)*1024		; one paragraph above the HMA

		; Multiboot header
		; must be dword aligned and in first 8 KiB!
	align 4, db 0
mbootheader:
	mbootchecksummed 00010000h
			; flags: provides info where to load image
	dd MBOOTBASE + mbootheader	; load address of header
	dd MBOOTBASE			; load address
	dd MBOOTBASE + (payload.actual_end - $$ + 0)
					; load area end (0 = load whole file)
	dd 0				; uninitialised area end (0 = none)
	dd MBOOTBASE + mbootentry	; entry point

%unmacro mbootchecksummed 1.nolist 1BADB002h

%if ($-$$) > 8192
 %fatal Multiboot header must be in the first 8 KiB
%endif

	struc MBI
mbiFlags:	resd 1
		resb 8
mbiBootDevice:	resd 1
mbiCmdLine:	resd 1
mbiModuleCount:	resd 1
mbiModuleTable:	resd 1
		; (More data follows but none which seems useful.)
	endstruc

[cpu 386]
[bits 32]

	numdef MULTIBOOT_CHECKS, 1

 %if _MULTIBOOT_CHECKS
mbootentry.halt:
		; Unfortunately, as the environment is unknown, we can only
		;  literally halt here, as we don't know how to do I/O.
	cli
@@:
	hlt
	jmp short @B
 %endif

		; INP:	eax = 2BADB002h
		;	ebx-> multiboot info structure
		; STT:	loaded and executed according to Multiboot header, ie
		;	 loaded at MBOOTBASE
		;	 eip = MBOOTBASE+mbootentry
		;	in PM32 with paging disabled
		;	CPL 0
		;	cs,ds,es,fs,gs,ss = flat 32-bit code/data selectors
		;	DI
		;	! stack not set up
		;	! GDT might not be set up
		;	! IDT might not be set up
		;	A20 on
		;
		; Note:	Although A20 is on, HMA access without an XMM
		;	 to manage it might be undesirable. Multiboot
		;	 also doesn't tell us whether and if so then
		;	 how we can switch A20.
mbootentry:
 %if _MULTIBOOT_CHECKS
[bits 16]
	test ax, 0			; (test eax if in 32-bit segment)
	jmp short .halt			; (skipped if in 32-bit segment)
[bits 32]
	cmp eax, 2BADB002h		; signature ?
	jne short .halt			; no -->
	smsw eax
	rol eax, 1			; 2 = protection, 1 = paging
	and al, 3			; mask off others
	cmp al, 2			; PE but not PG ?
	jne short .halt			; no -->
	mov eax, cs
	and al, 3			; CPL 0 ?
	jnz short .halt			; no -->
 %endif

		; prepare this and that
	mov esi, MBOOTBASE

	or edx, -1
		; locate boot drive in Multiboot info structure
	test byte [ ebx + mbiFlags ], 2	; boot device info valid ?
	jz @F
	mov eax, [ ebx + mbiBootDevice ]; get the info
	bswap eax
	mov edx, eax			; dl = boot load unit (or 0FFh),
					;  dh = partition (or 0FFh)
					;  (edxh = subpartition numbers)
@@:

		; A20 is on. set up some things
	xor ecx, ecx
	mov edi, 1024*1024
	xor eax, eax
	mov cl, 10h			; (ecx = 10h)
	rep stosd			; clear this area so A20 tests succeed
; The above writes to 10_0000h..10_003Fh, leaving edi = 10_0040h
	mov al, 0C0h			; (eax = C0h)
	mov byte [ edi-40h+eax ], 0EAh
	mov [ edi-40h+eax+1 ], eax	; write jump for CP/M entry hack here
; The above writes to 10_00C0h..10_00C4h

		; relocate image to optimal location, 000600h
	mov edi, 000600h
	mov ecx, dword [ MBOOTBASE+mbootheader.load_area_end ]
	sub ecx, esi
	rep movsb

		; now back to real mode
	o32 lgdt [ MBOOTBASE+mbootgdtdesc ]
					; set our GDT
	mov ax, 10h
	mov ds, ax
	mov es, ax
	mov ss, ax
	mov fs, ax
	mov gs, ax			; set 64 KiB segment limits
	mov esp, 600h			; set a valid stack; also required by RM entry
	push 0
	popf				; reset all flags
	jmp 08h:.pm16			; use 16-bit selector

[bits 16]
		; now really switch to real mode
		; (already executing relocated code)
.pm16:
	mov eax, cr0
	dec ax
	mov cr0, eax				; clear PE bit

	jmp dword 60h:.rm			; reload cs

		; Set up registers and the environment for
		; the kernel entry point. It doesn't need initialised
		; segment registers but we'll initialise them in case
		; they still contain selector content.
.rm:
		; some sources indicate we should set the IDT
	o32 lidt [mbootidtdesc]			; set IDT to RM IVT
	xor ax, ax
	mov ds, ax
	mov es, ax
	mov fs, ax
	mov gs, ax
	mov ss, ax
	mov dl, -1
.dl: equ $-1
 %if _FIX_FREEDOS_LOAD
	mov dh, dl
 %endif
	mov ax, cs
	; (cs should be = 60h now, need no far jump)
	jmp loadentry.mbootenter		; enter this RM entry -->

	align 16, db 0				; right.. shouldn't this be aligned?
mbootgdt:
	dw 0,0
	db 0,0,0,0

		; selector 8: 16-bit real mode CS
		; base = 00000600h, limit 0FFFFh (1 B Granularity), present
		; type = 16-bit code execute/read only/conforming, DPL = 0
	dw 0FFFFh,600h
	db 0,9Eh,0,0

		; selector 10h: 16-bit real mode DS
		; base = 00000000h, limit 0FFFFh (1 B Granularity), present
		; type = 16-bit data read/write, DPL = 0
	dw 0FFFFh,0
	db 0,92h,0,0
	endarea mbootgdt

mbootgdtdesc:
	dw mbootgdt_size-1	; limit
	dd MBOOTBASE+mbootgdt	; address

mbootidtdesc:
	dw 400h-1		; limit
	dd 0			; address (RM IVT)

__CPU__
