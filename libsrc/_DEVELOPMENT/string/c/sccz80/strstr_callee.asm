
; char *strstr(const char *s1, const char *s2)

SECTION code_clib
SECTION code_string

PUBLIC strstr_callee

EXTERN asm_strstr

strstr_callee:

   pop bc
   pop hl
   pop de
   push bc
   
   jp asm_strstr

; SDCC bridge for Classic
IF __CLASSIC
PUBLIC _strstr_callee
defc _strstr_callee = strstr_callee
ENDIF

