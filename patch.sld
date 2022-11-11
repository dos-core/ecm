@goto :help

Patch iniload script
 by C. Masloch, 2021

Usage of the works is permitted provided that this
instrument is retained with the works, so that any entity
that uses the works is notified of this instrument.

DISCLAIMER: THE WORKS ARE WITHOUT WARRANTY.


@:help
; Available patches:
;
; :patch_iniload_no_query_geometry
; :patch_iniload_no_lba
; :patch_iniload_no_chs
; :query_patch_iniload
;
; Inputs: vef = nonzero to debug
;	  ve8 = what to set for new style query patch
;	  ve9 = what to clear for new style query patch
;         cs:0 -> iniload
; Output: vee = nonzero if error
;         iniload patched
; Change: ve0 to vef, src, sro, aao, stack
;
; Requires lDebug release 3 or later
@goto :eof


:query_patch_iniload
@if not (vef) then r ysf |= C000
@:query_patch_common
r ve0 word (sp - 100)
a ss:ve0
 mov dl, byte [bp + 40]
 mov ax, 0
 .
r ve1 := aao - 2
r vec := ve1 - ve0
s cs:0 l #8192 range ss:ve0 l vec
if not (src) then goto :eof
a ss:ve0
 test dl, dl
 jns (ve0 + 6)
 db 86,C4	; xchg al, ah
 .
if (word [srs:sro + vec + 2] != word [ss:ve0 + 0]) then goto :query_patch_error
if (word [srs:sro + vec + 4] != word [ss:ve0 + 2]) then goto :query_patch_error
if (word [srs:sro + vec + 6] != word [ss:ve0 + 4]) then goto :query_patch_error
r word [srs:sro + vec] or:= ve8
r word [srs:sro + vec] and:= ~ve9
:query_patch_success
r vee := 0
r ve8 := 0
r ysf &= ~C000
; Patched successfully (new style)
@goto :eof

:query_patch_error
r vee := 1
r ve8 := 0
r ysf &= ~C000
; Patch failed (new style)
@goto :eof


:patch_iniload_no_query_geometry
@if not (vef) then r ysf |= C000
if not (ve8) then r ve8 := 404
if not (ve8 == -1) then y :query_patch_common
@if not (ve8) then goto :eof

r ve0 word (sp - 100)
a ss:ve0
 mov ah, 08
 xor cx, cx
 stc
 int 13
 jc (ve0)
 .
r ve1 := aao - 1
r vec := ve1 - ve0
s cs:0 l #8192 range ss:ve0 l vec
if not (src) then goto :error
r word [srs:sro + vec - 3] := 9090
goto :success


:patch_iniload_no_lba
@if not (vef) then r ysf |= C000
if not (ve8) then r ve8 := 101
if not (ve8 == -1) then y :query_patch_common
@if not (ve8) then goto :eof

r ve0 word (sp - 100)
a ss:ve0
 mov ah, 41
 mov dl, byte [bp + 40]
 mov bx, 55AA
 stc
 int 13
 mov al, 0
 jc (ve0)
 .
r ve1 := aao - 1
r vec := ve1 - ve0
s cs:0 l #8192 range ss:ve0 l vec
if (src) then goto :patch_iniload_no_lba.success
a ss:ve0
 mov ah, 41
 pop dx
 mov bx, 55AA
 stc
 int 13
 mov al, 0
 jc (ve0)
 .
r ve1 := aao - 1
r vec := ve1 - ve0
s cs:0 l #8192 range ss:ve0 l vec
if not (src) then goto :error

:patch_iniload_no_lba.success
r word [srs:sro + vec - 5] := 9090
goto :success

:success
r vee := 0
r ysf &= ~C000
; Patched successfully
@goto :eof


:patch_iniload_no_chs
@if not (vef) then r ysf |= C000
if not (ve8) then r ve8 := 202
if not (ve8 == -1) then y :query_patch_common
@if not (ve8) then goto :eof

:error
r vee := 1
r ysf &= ~C000
; Patch failed
@goto :eof
