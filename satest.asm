
start:
	int3
	mov ax, 4CFFh
	int 21h

	align 64

	db 0
	; This message is used by mak.sh to detect that we
	;  are building with boot load support.
	db 13,10,"Boot loader",13,10
	db 0

; for tellsize
	mov bx, (end - start + 256 + 15) >> 4
	mov ah, 4Ah
	int 21h

	align 64
	times 56 * 1024 - 128 db 0

%imacro lfsrstep 1.nolist
 %if _%1 & 1
  %assign _%1 (_%1 >> 1) ^ 8020_0003h
 %else
  %assign _%1 (_%1 >> 1)
 %endif
%endmacro

%rep 2
%assign _NUMBER 1
%rep 1024
	dd _NUMBER
lfsrstep NUMBER
%endrep
%endrep

	times 64 db 26
end:
