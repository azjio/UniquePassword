; AZJIO
; https://www.autoitscript.com/forum/topic/141984-_num1_to_num2


EnableExplicit

; bigint.pbi - https://www.purebasic.fr/english/viewtopic.php?p=458493#p458493
; IncludeFile("bigint.pbi")
XIncludeFile "bigint.pbi"
; IncludeFile("radi.pbi") ; https://www.purebasic.fr/english/viewtopic.php?p=459536#p459536

UseModule BigInt
; UseModule Radi

Global Error_Procedure = 0

; число в массив, быстрая
Procedure StrToArrLetter1(Array Arr.s{1}(1), String$)
	Protected LenStr, i
	LenStr = Len(String$)
	If LenStr
		ReDim Arr(LenStr - 1)
		PokeS(Arr(), String$, -1, #PB_String_NoZero)
	EndIf
EndProcedure

Procedure.s DecToNum(Dec$, Symbol$)
	Protected.BigInt BigDec, BigOst, Big1, BigArrSz, BigDec2
	Protected Out.s, Dim Arr.s{1}(1), ArrSz
	SetValue(Big1, 1)
	StrToArrLetter1(Arr(), Symbol$)
	ArrSz = ArraySize(Arr()) + 1
	If Error_Procedure Or ArrSz < 2
		Error_Procedure = 1
		ProcedureReturn ""
	EndIf
	SetHexValue(BigDec, Dec$)
	SetValue(BigArrSz, ArrSz)
	Repeat
		Assign(BigOst, BigDec)
		ModMul(BigOst, Big1, BigArrSz)
		Subtract(BigDec, BigOst)
		Divide(BigDec2, BigDec, BigArrSz)
		Assign(BigDec, BigDec2)
		
		Out = Arr(Val("$" + GetHex(BigOst))) + Out
	Until Compare(BigDec2, Big1) = -1
	ProcedureReturn Out
EndProcedure

Procedure.s NumToDec(num$, Symbol$, casesense = 0)
	Protected.BigInt BigLenStr, BigM, BigOut, BigPos
	Protected i, j, Pos, LenStr, ArrSz, Dim Arr.s{1}(1)
	LenStr = Len(Symbol$) ; если набор символов менее 2-х, то не имеет смысла
	If LenStr < 2
		Error_Procedure = 1
		ProcedureReturn "0"
	EndIf
	SetValue(BigLenStr, LenStr)	

	StrToArrLetter1(Arr(), num$) ; число в массив
	If Error_Procedure
		Error_Procedure = 1
		ProcedureReturn "0"
	EndIf
	ArrSz = ArraySize(Arr())
	For i = 0 To ArrSz
		Pos = FindString(Symbol$, Arr(i), 1, casesense)
		If Not Pos
			Error_Procedure = 2
			ProcedureReturn "0"
		EndIf
		SetValue(BigM, 1)
		For j = 1 To ArrSz - i
			Multiply(BigM, BigLenStr)
		Next
		SetValue(BigPos, Pos - 1)
		Multiply(BigM, BigPos)
		Add(BigOut, BigM)
	Next
	ProcedureReturn GetHex(BigOut)
EndProcedure

; Debug "NumToDec = " + NumToDec("101", "01")
; абвгдежзийклмнопрстуфхцчшщъыьэюя

; Define baza$, resDec$
; baza$ =  " АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯабвгдеёжзийклмнопрстуфхцчшщъыьэюя,!"
; resDec$ = NumToDec("Закодировал длиную строку", baza$)
; resDec$ = NumToDec("при", baza$)
; Debug "NumToDec = " + resDec$
; Debug Radi::Hex2Dec(resDec$)
; Debug Hex2Dec(resDec$)
; Debug "DecToNum = " + DecToNum(resDec$, baza$)
; Debug "NumToDec = " + NumToDec("101", "0123456789")
; Debug DecToNum("255", "0123456789ABCDEF")
; Debug NumToDec("ff", "0123456789abcdef")
; Debug Str(Val("$" + NumToDec("ff", "0123456789ABCDEF", 1)))
; Debug "Error = " + Error_Procedure
; MessageRequester("", resDec$)
; IDE Options = PureBasic 5.70 LTS (Linux - x64)
; CursorPosition = 1
; Folding = 8
; EnableXP
; Executable = тест.exe