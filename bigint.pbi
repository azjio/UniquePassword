;  wilbert
; https://www.purebasic.fr/english/viewtopic.php?p=458493#p458493
; BigInt module by Wilbert (SSE2 required)

; Last updated : Jan 2, 2018

; #BigIntBits constant can be set to a multiple of 512

; Multiplication based on Knuth's Algorithm M
; Division based on Knuth's Algorithm D

DeclareModule BigInt

  #BigIntBits = 2048; 512

  Structure BigInt
    StructureUnion
      l.l[#BigIntBits >> 5]
      q.q[#BigIntBits >> 6]
    EndStructureUnion
    extra_bytes.i
  EndStructure

  Macro Assign(n0, n1)
    ; n0 = n1
    CopyMemory(n1, n0, SizeOf(BigInt::BigInt))
  EndMacro

  Declare.i Add(*n0.BigInt, *n1.BigInt)
  Declare.i Compare(*n0.BigInt, *n1.BigInt)
  Declare.i Divide(*n0.BigInt, *n1.BigInt, *n2.BigInt, *r.BigInt = 0)
  Declare.i GetBit(*n.BigInt, bit)
  Declare.s GetHex(*n.BigInt)
  Declare.i IsZero(*n.BigInt)
  Declare   LoadValue(*n.BigInt, *mem, length.i, little_endian = #True)
  Declare   ModMul(*n0.BigInt, *n1.BigInt, *n2.BigInt)
  Declare   ModPow(*n0.BigInt, *n1.BigInt, *n2.BigInt, *n3.BigInt)
  Declare   Multiply(*n0.BigInt, *n1.BigInt)
  Declare.i NumberSize(*n.BigInt)
  Declare   Neg(*n.BigInt)
  Declare   ResetBit(*n.BigInt, bit)
  Declare   SetBit(*n.BigInt, bit)
  Declare   SetHexValue(*n.BigInt, value.s)
  Declare   SetValue(*n.BigInt, value.q = 0, unsigned = #True)
  Declare   Shr1(*n.BigInt)
  Declare.i Subtract(*n0.BigInt, *n1.BigInt)

EndDeclareModule


Module BigInt

  EnableASM
  DisableDebugger
  EnableExplicit

  #LS = #BigIntBits >> 5
  #LSx4 = #LS << 2
  #BITMASK = #LS << 5 - 1

  Structure BigInt_x2
    StructureUnion
      l.l[#LS << 1]
      q.q[#LS]
    EndStructureUnion
    extra_bytes.i
  EndStructure

  Structure digits
    d.u[3]
  EndStructure

  CompilerIf #PB_Compiler_Processor = #PB_Processor_x86
    #x64 = #False
    Macro rax : eax : EndMacro
    Macro rbx : ebx : EndMacro
    Macro rcx : ecx : EndMacro
    Macro rdx : edx : EndMacro
    Macro rdi : edi : EndMacro
    Macro rsi : esi : EndMacro
  CompilerElse
    #x64 = #True
  CompilerEndIf

  Macro M_movd(arg1, arg2)
    !movd arg1, arg2
  EndMacro

  Macro M_movdqu(arg1, arg2)
    !movdqu arg1, arg2
  EndMacro

  Macro ClearBigInt(n)
    ; n = 0
    FillMemory(n, #LSx4)
  EndMacro

  ; *** Private procedures ***

  Procedure.i uint32_used(*n.BigInt)
    mov ecx, #LS
    mov rdx, *n
    !bigint.l_used_loop:
    M_movdqu(xmm3, [rdx + rcx * 4 - 16])
    M_movdqu(xmm2, [rdx + rcx * 4 - 32])
    M_movdqu(xmm1, [rdx + rcx * 4 - 48])
    M_movdqu(xmm0, [rdx + rcx * 4 - 64])
    !packssdw xmm2, xmm3
    !packssdw xmm0, xmm1
    !pxor xmm3, xmm3
    !packsswb xmm0, xmm2
    !pcmpeqb xmm0, xmm3
    !pmovmskb eax, xmm0
    !xor ax, 0xffff
    !jnz bigint.l_used_cont
    !sub ecx, 16
    !jnz bigint.l_used_loop
    !xor eax, eax
    ProcedureReturn
    !bigint.l_used_cont:
    !bsr edx, eax
    !lea eax, [edx + ecx - 15]
    ProcedureReturn
  EndProcedure

  Procedure.i nlz(l.l)
    !mov eax, [p.v_l]
    !bsr ecx, eax
    !mov eax, 31
    !sub eax, ecx
    ProcedureReturn
  EndProcedure

  Procedure normalize(*src, *dst, num_longs.i, bits.i)
    !mov ecx, 32
    !sub ecx, [p.v_bits]
    !movd xmm2, ecx
    mov rax, *dst
    mov rdx, *src
    mov rcx, num_longs
    !pxor xmm1, xmm1
    !normalize_loop:
    M_movd(xmm0, [rdx + rcx * 4 - 4])
    !punpckldq xmm0, xmm1
    !movdqa xmm1, xmm0
    !psrlq xmm0, xmm2
    M_movd([rax + rcx * 4], xmm0)
    dec rcx
    !jnz normalize_loop
    !psllq xmm1, 32
    !psrlq xmm1, xmm2
    M_movd([rax], xmm1)
  EndProcedure

  Procedure unnormalize(*src, *dst, num_longs.i, bits.i)
    mov rax, *dst
    mov rdx, *src
    mov rcx, num_longs
    lea rax, [rax + rcx * 4]
    lea rdx, [rdx + rcx * 4]
    neg rcx
    !movd xmm2, [p.v_bits]
    M_movd(xmm0, [rdx + rcx * 4])
    !unnormalize_loop:
    M_movd(xmm1, [rdx + rcx * 4 + 4])
    !punpckldq xmm0, xmm1
    !psrlq xmm0, xmm2
    M_movd([rax + rcx * 4], xmm0)
    !movdqa xmm0, xmm1
    inc rcx
    !jnz unnormalize_loop
    !psrlq xmm1, xmm2
    M_movd([rax], xmm1)
  EndProcedure

  Procedure divmod_private(*n0.BigInt, *n1.BigInt, n1_size.i, *n2.BigInt, n2_size.i, *r.BigInt = 0, mm = #False)
    ; n0 = n1 / n2, r = remainder
    Protected.BigInt un, vn, *vn
    Protected.i qhat, rhat, *un.Quad
    Protected.i s, i, j
    Protected.l l, vn1, vn2

    If n2_size = 0
      ; division by zero
      EnableDebugger
      Debug "*** Division by zero ***"
      DisableDebugger
    ElseIf n2_size = 1
      ; division by uint32
      If mm
        *n0 = *n1
      Else
        If *n0 = 0 : *n0 = @un : EndIf
        If *n0 <> *n1 : Assign(*n0, *n1) : EndIf
      EndIf
      mov rax, *n0
      mov rdx, *n2
      mov rcx, n1_size
      push rbx
      push rdi
      mov ebx, [rdx]
      mov rdi, rax
      !xor edx, edx
      !bigint.l_div32_loop:
      mov eax, [rdi + rcx * 4 - 4]
      !div ebx
      mov [rdi + rcx * 4 - 4], eax
      sub rcx, 1
      !ja bigint.l_div32_loop
      pop rdi
      pop rbx
      mov l, edx
      If *r : ClearBigInt(*r) : *r\l[0] = l : EndIf
    Else
      If n1_size < n2_size
        ; n1 < n2 (result is 0, remainder is n1)
        If *r : Assign(*r, *n1) : EndIf
        If *n0 : ClearBigInt(*n0) : EndIf
      Else
        ; main division routine
        ; normalize n1 and n2
        ; store result into 'un' and 'vn'
        s = nlz(*n2\l[n2_size-1])
        If mm
          normalize(*n1, *n1, n1_size, s)
        Else
          normalize(*n1, @un, n1_size, s)
          *n1 = @un
        EndIf
        normalize(*n2, @vn, n2_size, s)
        If *n0 : ClearBigInt(*n0) : EndIf
        vn1 = vn\l[n2_size-1]
        vn2 = vn\l[n2_size-2]
        For j = n1_size - n2_size To 0 Step -1

          ; *** compute estimate qhat of q[j] ***
          *un = *n1 + (j+n2_size-1)<<2
          mov rax, *un
          mov ecx, vn1
          mov edx, [rax + 4]
          mov eax, [rax]
          !cmp edx, ecx
          !jb bigint.l_qhat_cont0
          ; handle division overflow
          !mov dword [p.v_qhat], -1
          !sub edx, ecx
          !add eax, ecx
          !adc edx, 0
          !jnz bigint.l_qhat_cont2
          !mov [p.v_rhat], eax
          !jmp bigint.l_qhat_loop
          ; divide when no overflow
          !bigint.l_qhat_cont0:
          !div ecx
          !mov [p.v_qhat], eax
          !mov [p.v_rhat], edx
          ; qhat correction when qhat*vn2 > rhat << 32 | un[j+n-2]
          !bigint.l_qhat_loop:
          !mov eax, [p.v_qhat]
          !mul dword [p.v_vn2]
          !cmp edx, [p.v_rhat]
          !ja bigint.l_qhat_cont1
          !jne bigint.l_qhat_cont2
          mov rdx, *un
          cmp eax, [rdx - 4]
          !jna bigint.l_qhat_cont2
          !bigint.l_qhat_cont1:
          !dec dword [p.v_qhat]         ; qhat -= 1
          !add dword [p.v_rhat], ecx    ; rhat += vn1
          !jnc bigint.l_qhat_loop       ; rhat < 2^32 => loop
          !bigint.l_qhat_cont2:
          If qhat = 0 : Continue : EndIf

          ; *** Multiply and subtract ***
          *un = *n1 + j<<2
          *vn = @vn
          mov rax, *un
          mov rdx, *vn
          !pxor xmm0, xmm0
          M_movd(xmm2, [p.v_qhat])
          mov rcx, n2_size
          !bigint.l_div_ms_loop:
          M_movd(xmm1, [rdx])
          !pmuludq xmm1, xmm2
          add rdx, 4
          M_movd(xmm3, [rax])
          !psubq xmm3, xmm0
          !pshufd xmm0, xmm1, 11111100b
          !psubq xmm3, xmm0
          M_movd([rax], xmm3)
          !psubd xmm1, xmm3
          add rax, 4
          !pshufd xmm0, xmm1, 11111101b
          dec rcx
          !jnz bigint.l_div_ms_loop
          M_movd(xmm1, [rax])
          !psubq xmm1, xmm0
          M_movd([rax], xmm1)
          !pmovmskb eax, xmm1
          !test eax, 0x80
          !jz bigint.l_div_addback_cont
          ; add back when subtracted too much
          !dec dword [p.v_qhat]
          mov rax, *un
          mov rdx, *vn
          mov rcx, n2_size
          push rbx
          lea rax, [rax + rcx * 4]
          lea rdx, [rdx + rcx * 4]
          neg rcx
          !clc
          !bigint.l_div_addback_loop:
          mov ebx, [rdx + rcx * 4]
          adc [rax + rcx * 4], ebx
          inc rcx
          !jnz bigint.l_div_addback_loop
          adc dword [rax], 0
          pop rbx
          !bigint.l_div_addback_cont:

          ; *** store quotient digit ***
          If *n0 : *n0\l[j] = qhat : EndIf
        Next
        If *r
          ClearBigInt(*r)
          unnormalize(*n1, *r, n2_size, s)
        EndIf
      EndIf
    EndIf
  EndProcedure

  ; *** Public procedures ***

  Procedure.i NumberSize(*n.BigInt)
    ; returns the amount of bytes the number uses
    Protected l.l, n_size.i = uint32_used(*n)
    If n_size
      l = *n\l[n_size - 1]
      n_size = n_size << 2 - nlz(l) >> 3
    EndIf
    ProcedureReturn n_size
  EndProcedure

  Procedure ResetBit(*n.BigInt, bit)
    mov rdx, *n
    mov ecx, [p.v_bit]
    And ecx, #BITMASK
    btr [rdx], ecx
  EndProcedure

  Procedure SetBit(*n.BigInt, bit)
    mov rdx, *n
    mov ecx, [p.v_bit]
    And ecx, #BITMASK
    bts [rdx], ecx
  EndProcedure

  Procedure GetBit(*n.BigInt, bit)
    mov rdx, *n
    mov ecx, [p.v_bit]
    And ecx, #BITMASK
    bt [rdx], ecx
    sbb eax, eax
    neg eax
    ProcedureReturn
  EndProcedure

  Procedure SetValue(*n.BigInt, value.q = 0, unsigned = #True)
    ; n = value
    If unsigned Or value >= 0
      ClearBigInt(*n)
    Else
      FillMemory(*n, #LSx4, -1)
    EndIf
    *n\q[0] = Value
  EndProcedure

  Procedure LoadValue(*n.BigInt, *mem, length.i, little_endian = #True)
    ; n = mem value
    ClearBigInt(*n)
    If length <= #LSx4
      FillMemory(*n + length, #LSx4 - length)
      If little_endian
        CopyMemory(*mem, *n, length)
      Else
        mov rax, *n
        mov rdx, *mem
        mov rcx, length
        push rbx
        !bigint.l_loadvalue_loop:
        mov bl, [rdx + rcx - 1]
        mov [rax], bl
        inc rax
        dec rcx
        !jnz bigint.l_loadvalue_loop
        pop rbx
      EndIf
    EndIf
  EndProcedure

  Procedure SetHexValue(*n.BigInt, value.s)
    ; n = value
    Protected.i i, p = Len(value) - 15
    ClearBigInt(*n)
    While p >= 1
      *n\q[i] = Val("$" + Mid(value, p, 16))
      i + 1 : p - 16
      If i = #LS >> 1
        ProcedureReturn
      EndIf
    Wend
    *n\q[i] = Val("$" + Left(value, p + 15))
  EndProcedure

  Procedure.i IsZero(*n.BigInt)
    If *n\l[0] = 0 And uint32_used(*n) = 0
      ProcedureReturn #True
    Else
      ProcedureReturn #False
    EndIf
  EndProcedure

  Procedure.i Compare(*n0.BigInt, *n1.BigInt)
    ; unsigned compare
    ; n0 = n1 => return value is 0
    ; n0 > n1 => return value is positive
    ; n0 < n1 => return value is negative
    mov ecx, #LS
    mov rax, *n0
    mov rdx, *n1
    push rbx
    !bigint.l_cmp_loop:
    M_movdqu(xmm3, [rdx + rcx * 4 - 16])
    M_movdqu(xmm2, [rdx + rcx * 4 - 32])
    M_movdqu(xmm1, [rax + rcx * 4 - 16])
    M_movdqu(xmm0, [rax + rcx * 4 - 32])
    !pcmpeqd xmm1, xmm3
    !pcmpeqd xmm0, xmm2
    !packssdw xmm0, xmm1
    !pmovmskb ebx, xmm0
    !xor bx, 0xffff
    !jnz bigint.l_cmp_cont
    !sub ecx, 8
    !jnz bigint.l_cmp_loop
    !xor eax, eax
    pop rbx
    ProcedureReturn
    !bigint.l_cmp_cont:
    !bsr ebx, ebx
    !shr ebx, 1
    !lea ecx, [ebx + ecx - 8]
    mov ebx, [rax + rcx * 4]
    cmp ebx, [rdx + rcx * 4]
    pop rbx
    sbb rax, rax
    lea rax, [rax * 2 + 1]
    ProcedureReturn
  EndProcedure

  Macro M_addsub(opc)
    mov rax, *n0
    mov rdx, *n1
    mov rcx, n1_size
    CompilerIf #x64
      !inc rcx
      !shr rcx, 1
      !sub r9, r9
      !bigint.l_#opc#_loop0:
      !mov r8, [rdx + r9 * 8]
      !opc [rax + r9 * 8], r8
      !inc r9
      !dec rcx
      !jnz bigint.l_#opc#_loop0
      !bigint.l_#opc#_loop1:
      !opc qword [rax + r9 * 8], 0
      !inc r9
      !jc bigint.l_#opc#_loop1
    CompilerElse
      !push ebx
      !push edi
      !sub ebx, ebx
      !bigint.l_#opc#_loop0:
      !mov edi, [edx + ebx * 4]
      !opc [eax + ebx * 4], edi
      !inc ebx
      !dec ecx
      !jnz bigint.l_#opc#_loop0
      !bigint.l_#opc#_loop1:
      !opc dword [eax + ebx * 4], 0
      !inc ebx
      !jc bigint.l_#opc#_loop1
      !pop edi
      !pop ebx
    CompilerEndIf
  EndMacro

  Procedure.i Add(*n0.BigInt, *n1.BigInt)
    ; n0 += n1
    Protected n1_size.i = uint32_used(*n1)
    If n1_size
      *n0\extra_bytes = 0
      M_addsub(adc)
    EndIf
    ProcedureReturn *n0\extra_bytes
  EndProcedure

  Procedure.i Subtract(*n0.BigInt, *n1.BigInt)
    ; n0 -= n1
    Protected n1_size.i = uint32_used(*n1)
    If n1_size
      *n0\extra_bytes = 1
      M_addsub(sbb)
    EndIf
    ProcedureReturn 1 - *n0\extra_bytes
  EndProcedure

  Procedure Neg(*n.BigInt)
    ; n = -n
    *n\extra_bytes = 0
    mov ecx, #LS
    mov rdx, *n
    !pcmpeqd xmm2, xmm2
    !bigint.l_neg_loop0:
    M_movdqu(xmm0, [rdx + rcx * 4 - 16])
    M_movdqu(xmm1, [rdx + rcx * 4 - 32])
    !pandn xmm0, xmm2
    !pandn xmm1, xmm2
    M_movdqu([rdx + rcx * 4 - 16], xmm0)
    M_movdqu([rdx + rcx * 4 - 32], xmm1)
    !sub ecx, 8
    !jnz bigint.l_neg_loop0
    !stc
    !bigint.l_neg_loop1:
    CompilerIf #x64
      !adc qword [rdx + rcx * 8], 0
    CompilerElse
      !adc dword [edx + ecx * 4], 0
    CompilerEndIf
    !inc ecx
    !jc bigint.l_neg_loop1
  EndProcedure

  Macro M_Multiply(mm)
    Protected *tmp, *n0_ = *n0
    Protected.i n0_size, n1_size, i0, i1, m, i1_max
    n0_size = uint32_used(*n0)
    n1_size = uint32_used(*n1)
    If n0_size > n1_size
      Swap *n0, *n1
      Swap n0_size, n1_size
    EndIf
    CompilerIf mm = 1
      i1_max = n1_size
    CompilerEndIf
    While i0 < n0_size
      CompilerIf mm = 0
        i1_max = #LS - i0
        If i1_max > n1_size
          i1_max = n1_size
        EndIf
      CompilerEndIf
      *tmp = @tmp\l[i0]
      m = *n0\l[i0]
      If m
        mov rax, *tmp
        mov rdx, *n1
        !pxor xmm0, xmm0
        !movd xmm2, [p.v_m]
        mov rcx, i1_max
        !bigint.l_mul#mm#_loop:
        movd xmm1, [rdx]
        !pmuludq xmm1, xmm2
        add rdx, 4
        movd xmm3, [rax]
        !paddq xmm0, xmm1
        !paddq xmm0, xmm3
        movd [rax], xmm0
        !psrlq xmm0, 32
        add rax, 4
        dec rcx
        !jnz bigint.l_mul#mm#_loop
        movd [rax], xmm0
      EndIf
      i0 + 1
    Wend
  EndMacro

  Procedure Multiply(*n0.BigInt, *n1.BigInt)
    ; n0 *= n1
    Protected tmp.BigInt
    M_Multiply(0)
    Assign(*n0_, @tmp)
  EndProcedure

  Procedure ModMul(*n0.BigInt, *n1.BigInt, *n2.BigInt)
    ; n0 = n0 * n1 mod n2
    Protected tmp.BigInt_x2
    M_Multiply(1)
    divmod_private(0, @tmp, n0_size + n1_size, *n2, uint32_used(*n2), *n0_, #True)
  EndProcedure

  Procedure ModPow(*n0.BigInt, *n1.BigInt, *n2.BigInt, *n3.BigInt)
    ; Compute n0 = n1^*n2 mod n3
    Protected tmp.BigInt
    Protected.i n2_size, i, num_bits
    n2_size = uint32_used(*n2)
    If n2_size
      num_bits = n2_size << 5 - nlz(*n2\l[n2_size-1])
      Assign(@tmp, *n1)
      SetValue(*n0, 1)
      While i < num_bits
        mov rdx, *n2
        mov rcx, i
        bt [rdx], ecx
        !jnc bigint.l_modpow_cont
        ModMul(*n0, @tmp, *n3)
        !bigint.l_modpow_cont:
        ModMul(@tmp, @tmp, *n3)
        i + 1
      Wend
    Else
      SetValue(*n0, 1)
    EndIf
  EndProcedure

  Procedure Divide(*n0.BigInt, *n1.BigInt, *n2.BigInt, *r.BigInt = 0)
    ; n0 = n1 / n2
    ; r = remainder
    divmod_private(*n0, *n1, uint32_used(*n1), *n2, uint32_used(*n2), *r, #False)
  EndProcedure

  Procedure Shr1(*n.BigInt)
    ; n >> 1
    Protected n_size.i = uint32_used(*n)
    If n_size
      mov rdx, *n
      !mov ecx, [p.v_n_size]
      CompilerIf #x64
        !add ecx, 1
        !shr ecx, 1
      CompilerEndIf
      !clc
      !bigint.l_shr1_loop:
      CompilerIf #x64
        !rcr qword [rdx + rcx * 8 - 8], 1
      CompilerElse
        !rcr dword [edx + ecx * 4 - 4], 1
      CompilerEndIf
      !dec ecx
      !jnz bigint.l_shr1_loop
    EndIf
  EndProcedure

  Procedure.s GetHex(*n.BigInt)
    Protected result.s, s.s, *r
    Protected.i i, l, u = (uint32_used(*n) + 1) >> 1
    If u
      result = LSet("", u << 4, "0")
      *r = @result + (u << 4) * SizeOf(Character)
      While i < u
        s = Hex(*n\q[i]) : l = StringByteLength(s) : i + 1
        CopyMemory(@s, *r - l, l) : *r - SizeOf(Character) << 4
      Wend
      ProcedureReturn PeekS(*r + SizeOf(Character) << 4 - l)
    Else
      ProcedureReturn "0"
    EndIf
  EndProcedure

EndModule
