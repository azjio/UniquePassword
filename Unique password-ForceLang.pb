;- TOP

; AZJIO
; 09.06.24
; 17.06.22


EnableExplicit

; Определяет язык ОС
Define UserIntLang
Define ForceLang

CompilerSelect #PB_Compiler_OS
	CompilerCase #PB_OS_Windows
		Global *Lang
		If OpenLibrary(0, "kernel32.dll")
			*Lang = GetFunction(0, "GetUserDefaultUILanguage")
			If *Lang And CallFunctionFast(*Lang) = 1049 ; ru
				UserIntLang = 1
			EndIf
			CloseLibrary(0)
		EndIf
	CompilerCase #PB_OS_Linux
		If ExamineEnvironmentVariables()
			While NextEnvironmentVariable()
				If Left(EnvironmentVariableName(), 4) = "LANG" And Left(EnvironmentVariableValue(), 2) = "ru"
					; LANG=ru_RU.UTF-8
					; LANGUAGE=ru
					UserIntLang = 1
					Break
				EndIf
			Wend
		EndIf
CompilerEndSelect


;- ● Lang1
#CountStrLang = 12 ; число строк перевода и соответсвенно массива
Global Dim Lng.s(#CountStrLang)
Lng(1) = "Set key phrase"
Lng(2) = "Grab domain from link in clipboard"
Lng(3) = "Hide Password"
Lng(4) = "Password:"
Lng(5) = "Calculate the password"
Lng(6) = "Copy the password"
Lng(7) = "Key phrase"
Lng(8) = "For example, the name of the cat"
Lng(9) = "Insert password"
Lng(10) = "Domain and keyword must not be shorter than 10 characters in total"
Lng(11) = "Save domain?"
Lng(12) = "Open ini file"



; UseMD5Fingerprint()
; UseSHA1Fingerprint()
; UseSHA2Fingerprint()
UseSHA3Fingerprint()

;- # Constants
#Window = 0
#Menu = 0
#RegExp = 0
;- ● XIncludeFile
XIncludeFile "Big-NumToDec-DecToNum.pb"
; XIncludeFile "NumToDec-DecToNum.pb"
CompilerIf  #PB_Compiler_OS = #PB_OS_Windows
	XIncludeFile "SendKey.pb"
CompilerEndIf

;- ● Global
Global MaxMenu = 0
; Global flgExecute = 1
Global ini$
Global tmp.s, itmp
Global Key_phrase.s
Global Base1.s = "0123456789abcdef"
Global Base2.s = "0123456789qwertyuiopasdfghjklzxcvbnm"
Global Limit = 14
Global Hide = 1
Global AES = 256
; Global Resources.s = "purebasic.fr|WhatsApp|Skype|ICQ|QIP|gmail|7z|rar"
Global NewList ResourcesLst.s()
Global Error_Procedure = 0
Global StrG1, StrG2
; Base2 = "0123456789qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM!@#$%^&*(){}[];:,.\/+=-_|"
; Base2 = "0123456789qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM"

Define ReClip$
Define w, h, i

;- ● Declare
Declare.s Unique(String$)
Declare Execute()
Declare SplitL(String.s, List StringList.s(), Separator.s = " ")
Declare AddDomen()

; Гаджеты
;- ● Enumeration
Enumeration
	#btnGenPass
	#StrG1
	#StrG2
	#StrG1Pass
	#StrG2Pass
	#TxtPw
	#LenPw
	#btnPhrase
	#btnCopy
	#btnDomen
	#btnCustom
	#ChHPass
	#btnPaste
	#btnSet
EndEnumeration

; Procedure.s IsCorrectNumber(sample.s, set.s)
; 	Protected i, Dim Arr.s{1}(1)
; 	StrToArrLetter1(Arr(), set)
; 	For i = 0 To ArraySize(Arr())
; 		sample = ReplaceString(sample, Arr(i), "")
; 	Next
; 	ProcedureReturn sample
; EndProcedure

CompilerIf  #PB_Compiler_OS = #PB_OS_Linux
	; https://www.purebasic.fr/english/viewtopic.php?p=531374#p531374
	ImportC ""
		gtk_window_set_icon(a.l,b.l)
	EndImport
CompilerEndIf

UseGIFImageDecoder()
; UsePNGImageDecoder() ; + 160 kb (жалко)

;- DataSection
DataSection
	IconTitle:
	IncludeBinary "images" + #PS$ + "GenPass.gif"
	link:
	IncludeBinary "images" + #PS$ + "link.gif"
	calculate:
	IncludeBinary "images" + #PS$ + "calculate.gif"
	copy:
	IncludeBinary "images" + #PS$ + "copy.gif"
	insert:
	IncludeBinary "images" + #PS$ + "insert.gif"
	set:
	IncludeBinary "images" + #PS$ + "set.gif"
EndDataSection

CatchImage(0, ?IconTitle)
CatchImage(3, ?link)
CatchImage(1, ?calculate)
CatchImage(2, ?copy)
CatchImage(4, ?insert)
CatchImage(5, ?set)

;- ini
; получаем путь к ини по имени программы


Global flgINI = 0
Global PathConfig$
PathConfig$ = GetPathPart(ProgramFilename())
If FileSize(PathConfig$ + "UniquePassword.ini") = -1
	CompilerSelect #PB_Compiler_OS
		CompilerCase #PB_OS_Windows
			PathConfig$ = GetHomeDirectory() + "AppData\Roaming\UniquePassword\"
		CompilerCase #PB_OS_Linux
			PathConfig$ = GetHomeDirectory() + ".config/UniquePassword/"
	CompilerEndSelect
EndIf

ini$ = PathConfig$ + "UniquePassword.ini"

CompilerIf  #PB_Compiler_OS = #PB_OS_Linux
	If FileSize(ini$) < 0 And FileSize("/usr/share/UniquePassword/UniquePassword.ini") > 0
		CreateDirectory(PathConfig$)
		CopyFile("/usr/share/UniquePassword/UniquePassword.ini", ini$)
	EndIf
CompilerEndIf

If FileSize(ini$) > 3 And OpenPreferences(ini$, #PB_Preference_NoSpace | #PB_Preference_GroupSeparator)
	flgINI = 1
	PreferenceGroup("Set")
	tmp = ReadPreferenceString("Symbols", Base2)
	If Len(tmp) > 1
		Base2 = tmp
	Else
		WritePreferenceString("Symbols" , Base2) ; Сразу исправляем неверные данные
	EndIf
	itmp = ReadPreferenceInteger("Limit", Limit)
	If itmp < 40 Or itmp > 1
		Limit = itmp
	Else
		WritePreferenceInteger("Limit" , Limit) ; Сразу исправляем неверные данные
	EndIf
	Hide = ReadPreferenceInteger("Hide", Hide)
	If Hide And Hide <> 1
		Hide = 1
		WritePreferenceInteger("Hide" , Hide) ; Сразу исправляем неверные данные
	EndIf
	itmp = ReadPreferenceInteger("AES", AES)
	Select itmp
		Case 128
			AES = 128
		Case 192
			AES = 192
		Default
			AES = 256
	EndSelect
	If AES = 256 And itmp <> 256
		WritePreferenceInteger("AES" , AES) ; Сразу исправляем неверные данные
	EndIf
	ForceLang = ReadPreferenceInteger("ForceLang", ForceLang)
; 	Resources = ReadPreferenceString("Resources", Resources)
	PreferenceGroup("Domain")
	ExaminePreferenceKeys()
	While NextPreferenceKey()
		If AddElement(ResourcesLst())
			ResourcesLst() = PreferenceKeyName()
		EndIf
	Wend
	ClosePreferences()
EndIf
; SplitL(Resources, ResourcesLst(), "|")


; Тем самым будучи в России можно выбрать англ язык или будучи в союзных республиках выбрать русский язык
If ForceLang = 1
	UserIntLang = 0
ElseIf ForceLang = 2
	UserIntLang = 1
EndIf

Procedure SetLangTxt(PathLang$)
	Protected file_id, Format, i, tmp$
	
	file_id = ReadFile(#PB_Any, PathLang$) 
	If file_id ; Если удалось открыть дескриптор файла, то
		Format = ReadStringFormat(file_id) ;  перемещаем указатель после метки BOM
		i=0
		While Eof(file_id) = 0        ; Цикл, пока не будет достигнут конец файла. (Eof = 'Конец файла')
			tmp$ =  ReadString(file_id, Format) ; читаем строку
								  ; If Left(tmp$, 1) = ";"
								  ; Continue
								  ; EndIf
; 			tmp$ = ReplaceString(tmp$ , #CR$ , "") ; коррекция если в Windows
			tmp$ = RTrim(tmp$ , #CR$) ; коррекция если в Windows
			If Asc(tmp$) And Asc(tmp$) <> ';'
				i+1
				If i > #CountStrLang ; массив Lng() уже задан, но если строк больше нужного, то не разрешаем лишнее
					Break
				EndIf
; 				Lng(i) = UnescapeString(tmp$) ; позволяет в строке иметь экранированные метасимволы, \n \t и т.д.
				Lng(i) = ReplaceString(tmp$, "\n", #LF$) ; В ini-файле проблема только с переносами, поэтому заменяем только \n
			Else
				Continue
			EndIf
		Wend
		CloseFile(file_id)
	EndIf
	; Else
	; SaveFile_Buff(PathLang$, ?LangFile, ?LangFileend - ?LangFile)
EndProcedure

; Если языковой файл существует, то использует его
If FileSize(PathConfig$ + "Lang.ini") > 100
	UserIntLang = 0
	SetLangTxt(PathConfig$ + "Lang.ini")
EndIf

;- ● Lang2
If UserIntLang
	Lng(1) = "Задать ключевую фразу"
	Lng(2) = "Захватить домен из ссылки в буфере обмена"
	Lng(3) = "Скрыть пароль"
	Lng(4) = "Пароль:"
	Lng(5) = "Вычислить пароль"
	Lng(6) = "Скопировать пароль"
	Lng(7) = "Ключевая фраза"
	Lng(8) = "Например, имя кота"
	Lng(9) = "Вставить пароль"
	Lng(10) = "Домен и ключевая фраза не должны в сумме быть короче 10 символов"
	Lng(11) = "Сохранить домен?"
	Lng(12) = "Открыть ini-файл"
EndIf


Base2 = LCase(Base2)
Base2 = Unique(Base2)

;-┌──GUI──┐
If OpenWindow(#Window, 0, 0, 600, 135, "Unique password", #PB_Window_SystemMenu | #PB_Window_MinimizeGadget | #PB_Window_ScreenCentered)
	CompilerIf  #PB_Compiler_OS = #PB_OS_Linux
		gtk_window_set_icon_(WindowID(#Window), ImageID(0)) ; назначаем иконку в заголовке
	CompilerEndIf
	
	; 	WindowBounds(#Window, 300, 250, #PB_Ignore, #PB_Ignore)
	
	ButtonImageGadget(#btnPhrase, 260, 1, 30, 30, ImageID(0))
	GadgetToolTip(#btnPhrase , Lng(1)) ; Задать ключевую фразу
	ButtonImageGadget(#btnDomen, 300, 1, 30, 30, ImageID(3))
	GadgetToolTip(#btnDomen , Lng(2)) ; Захватить домен из ссылки в буфере обмена
	
	If flgINI
		ButtonImageGadget(#btnSet, 388, 1, 30, 30, ImageID(5))
		GadgetToolTip(#btnSet , Lng(12)) ; ini-файл
	EndIf
	
	CheckBoxGadget(#ChHPass, 150, 108, 130, 22, Lng(3)) ; Скрыть пароль
	
	
	StringGadget(#StrG1, 7, 40, 551, 30 , "")
	StringGadget(#StrG2, 88, 75, 292, 30 , "", #PB_String_ReadOnly)
	
	StringGadget(#StrG1Pass, 7, 40, 551, 30 , "", #PB_String_Password)
	StringGadget(#StrG2Pass, 88, 75, 292, 30 , "", #PB_String_ReadOnly | #PB_String_Password)
	If Hide
		StrG1 = #StrG1Pass
		StrG2 = #StrG2Pass
		HideGadget(#StrG1, #True)
		HideGadget(#StrG2, #True)
		SetGadgetState(#ChHPass, #True)
	Else
		StrG1 = #StrG1
		StrG2 = #StrG2
		HideGadget(#StrG1Pass, #True)
		HideGadget(#StrG2Pass, #True)
	EndIf
	
	TextGadget(#TxtPw, 7, 80, 80, 30, Lng(4)) ; Пароль
	TextGadget(#LenPw, 381, 80, 30, 30, "")	  ; длина пароля
											  ; 	ButtonGadget(#btnGenPass, 277, 165, 30, 22, "Получить")
	ButtonImageGadget(#btnGenPass, 560, 40, 30, 30, ImageID(1))
	GadgetToolTip(#btnGenPass , Lng(5)) ; Вычислить пароль
										; 	ButtonImageGadget(#btnCopy, 560, 80, 20, 20, ImageID(2))
	ButtonImageGadget(#btnCopy, 420, 75, 30, 30, ImageID(2))
	GadgetToolTip(#btnCopy , Lng(6)) ; Скопировать пароль
									 ; 	ButtonImageGadget(#btnCopy, 260, 110, 20, 20, ImageID(2))
	ButtonImageGadget(#btnPaste, 460, 75, 30, 30, ImageID(4))
	GadgetToolTip(#btnPaste , Lng(9)) ; Вставить пароль
	
;- ├ Menu
	MaxMenu = ListSize(ResourcesLst())
	If MaxMenu
		ButtonGadget(#btnCustom, 340, 1, 30, 30, Chr($25BC))			; "v"
		If CreatePopupMenu(#Menu) ; Создаёт всплывающее меню
			i = 0
			ForEach ResourcesLst()
				MenuItem(i, ResourcesLst())
				i + 1
			Next
		EndIf
	EndIf
	
	SetActiveGadget(StrG1)
; 	AddKeyboardShortcut(#Window , #PB_Shortcut_Return , 1001)
	
;-┌──Loop──┐
	Repeat
		Select WaitWindowEvent()
				; 			Case #PB_Event_SizeWindow
			Case #PB_Event_Gadget
				Select EventGadget()
						; 					Case #StrG1
						; 						If EventType() = #PB_EventType_Change
						; 							Execute()
						; 						EndIf
					Case StrG1
						If EventType() = #PB_EventType_Change
							Execute()
							
; 							Делал двойное вычисление, так как повторо второго был стабильный, проблема была в окончаниях строк при шифровании
; 							If flgExecute
; 								Execute()
; 								flgExecute = 0
; 							EndIf
						EndIf
					Case #ChHPass
						If GetGadgetState(#ChHPass)
							StrG1 = #StrG1Pass
							StrG2 = #StrG2Pass
							HideGadget(#StrG1, #True)
							HideGadget(#StrG2, #True)
							HideGadget(#StrG1Pass, #False)
							HideGadget(#StrG2Pass, #False)
							Hide = 1
							SetGadgetText(#StrG1Pass, GetGadgetText(#StrG1))
							SetGadgetText(#StrG2Pass, GetGadgetText(#StrG2))
						Else
							StrG1 = #StrG1
							StrG2 = #StrG2
							HideGadget(#StrG1Pass, #True)
							HideGadget(#StrG2Pass, #True)
							HideGadget(#StrG1, #False)
							HideGadget(#StrG2, #False)
							Hide = 0
							SetGadgetText(#StrG1, GetGadgetText(#StrG1Pass))
							SetGadgetText(#StrG2, GetGadgetText(#StrG2Pass))
						EndIf
					Case #btnCustom
						DisplayPopupMenu(#Menu, WindowID(#Window))
					Case #btnPhrase
						; 						Ключевая фраза    Например имя кота
						Key_phrase = InputRequester(Lng(7), Lng(8), Key_phrase, Hide)
; 						Если есть данные, то сразу вычисляем
						If GetGadgetText(StrG1) <> ""
							Execute()
						EndIf
					Case #btnDomen
						AddDomen()
						
					Case #btnSet
						CompilerSelect #PB_Compiler_OS
							CompilerCase #PB_OS_Windows
								RunProgram(ini$)
							CompilerCase #PB_OS_Linux
								RunProgram("xdg-open", ini$, "")
						CompilerEndSelect


					Case #btnPaste
						Execute()
						tmp = GetGadgetText(StrG2)
						If Asc(tmp)
							SetWindowState(#Window, #PB_Window_Minimize)
							CompilerIf  #PB_Compiler_OS = #PB_OS_Windows
								Delay(1000)
								ReClip$ = GetClipboardText()
							CompilerEndIf
							SetClipboardText(tmp)
							CompilerSelect #PB_Compiler_OS
								CompilerCase #PB_OS_Windows
									SendKey(#VK_INSERT, #MOD_LSHIFT)
									SetClipboardText(ReClip$)
								CompilerCase #PB_OS_Linux
									RunProgram("xdotool", "key ctrl+v", "")
							CompilerEndSelect
							ReClip$ = ""
							tmp = ""
						EndIf
						
					Case #btnCopy
						Execute()
						tmp = GetGadgetText(StrG2)
						If Asc(tmp)
							SetClipboardText(tmp)
							tmp = ""
						EndIf
						
					Case #btnGenPass
						Execute()
				EndSelect
				
			Case #PB_Event_Menu        ; кликнут элемент всплывающего Меню
				itmp = EventMenu()	   ; получим кликнутый элемент Меню...
				Select itmp
					Case 0 To MaxMenu - 1
						SetGadgetText(StrG1, GetMenuItemText(#Menu, itmp))
						Execute()
; 					Case 1001
; 						Execute()
				EndSelect
			Case #PB_Event_CloseWindow
				CloseWindow(#Window)
				Break
		EndSelect
	ForEver
EndIf





Procedure AddDomen()
	Protected itmp, tmp.s, flgNotFound

	tmp = GetClipboardText()
	itmp = FindString(tmp, #LF$)
	If itmp
		ProcedureReturn
	EndIf
	
; 	Вместо регулярного выражения сделал текстовый анализ для извлечения ссылки
	If Mid(tmp, 1, 4) = "http"
		tmp = Mid(tmp, 5)
		If Mid(tmp, 1, 1) = "s"
			tmp = Mid(tmp, 2)
		EndIf
		If Mid(tmp, 1, 3) = "://"
			tmp = Mid(tmp, 4)
			If Mid(tmp, 1, 4) = "www."
				tmp = Mid(tmp, 5)
			EndIf
			itmp = FindString(tmp, "/")
			If itmp
				tmp = Mid(tmp, 1, itmp - 1)
			EndIf
		EndIf
	EndIf
; 	Вместо регулярного выражения сделал текстовый анализ для извлечения ссылки
; 	Движок регуоярных выражений добавляет 150-200 кб к проге
; 	If CreateRegularExpression(#RegExp, "\A(?:https?://)*(?:www\.)*([^/\s\\]+?[^\/]*)(?:.*)\z")
; 		If ExamineRegularExpression(#RegExp, tmp)
; 			While NextRegularExpressionMatch(#RegExp)
; 				tmp = RegularExpressionGroup(#RegExp, 1)
; 				SetGadgetText(StrG1, tmp)
; 				Break
; 			Wend
; 		EndIf
; 		FreeRegularExpression(#RegExp)
; 	EndIf
	; Execute()
	If flgINI
		flgNotFound = 1
		ForEach ResourcesLst()
			If ResourcesLst() = tmp
				flgNotFound = 0
				Break
			EndIf
		Next
		If flgNotFound And MessageRequester(Lng(11), tmp, #PB_MessageRequester_YesNoCancel) = #PB_MessageRequester_Yes
			If OpenPreferences(ini$, #PB_Preference_NoSpace | #PB_Preference_GroupSeparator)
				PreferenceGroup("Domain")
				WritePreferenceString(tmp, "")
				ClosePreferences()
			EndIf
			If AddElement(ResourcesLst())
				ResourcesLst() = tmp
				MenuItem(MaxMenu, tmp)
				MaxMenu + 1
			EndIf
		EndIf
	EndIf
	SetGadgetText(StrG1, tmp)
	Execute()
EndProcedure


Procedure.s Unique(String$)
	Protected NewMap uni.i(), NewList uniL.s(), *c.Character = @String$, res.s, tmp.s
	While *c\c
		tmp = Chr(*c\c)
		If Not FindMapElement(uni(), tmp)
			AddMapElement(uni(), tmp, #PB_Map_NoElementCheck)
			AddElement(uniL())
			uniL() = tmp
		EndIf
		*c + SizeOf(Character)
	Wend
	ForEach uniL()
		res + uniL()
	Next
	ProcedureReturn res
EndProcedure


Procedure.s Upper(Pasw$, Dec$)
	Protected Out.s, Dim a.s{1}(1), Dim n.s{1}(1), i, Symbol_0$, LenPasw, Len2, k, Str2.s, *c.Character;, tmp$
; 	Protected NewMap uni.s()
	Protected Dim n2(0)
	LenPasw = Len(Pasw$)
	Symbol_0$ = "123456789abcdefghijklmnopqrstuvwxyz" ; для 35 символьного пароля
	StrToArrLetter1(a(), Pasw$)
	
	; 	tmp$ = Unique(DecToNum(Dec$, Left(Symbol_0$, LenPasw)))
	Str2 = Unique(DecToNum(Dec$, Left(Symbol_0$, LenPasw))) ; разрядность определяются длинной пароля
; 	Debug Dec$
; 	Debug Pasw$
; 	Debug Unique(DecToNum(Dec$, Left(Symbol_0$, LenPasw)))
; 	Debug  Left(Symbol_0$, LenPasw)
	ReDim n2(Len(Str2) - 1)
	*c.Character = @Str2
	i = 0
	While *c\c
; 		Debug *c\c
		If *c\c > 96 And *c\c < 123
			n2(i) = *c\c - 87
			i+1
		ElseIf *c\c > 48 And *c\c < 58
			n2(i) = *c\c - 48
			i+1
		EndIf
		*c + SizeOf(Character)
	Wend
	
	i = 0
	*c.Character = @Pasw$
	While *c\c
		If *c\c > 96 And *c\c < 123
			i+1
		EndIf
		*c + SizeOf(Character)
	Wend
	Len2 = i/2
	
	; 	Debug Pasw$
	; 	Debug Len2
	k = 0
	For i = 0 To ArraySize(n2())
		; убрано условие проверки n2(i)<=a(0) And (если число не больше ширины пароля и)
		If n2(i) > ArraySize(a())
			; 			Debug n2(i)
			Continue
		EndIf
		If Asc(a(n2(i))) > 96 And Asc(a(n2(i))) < 123 ; если в этой позиции в пароле буква, то
													  ; 			Debug a(n2(i))
			a(n2(i)) = UCase(a(n2(i)))				  ; делаем её заглавной
													  ; 			Debug a(n2(i))
			k + 1
			If k >= Len2 ; закончили, если сделана половина замен
				Break
			EndIf
		EndIf
	Next
	Pasw$ = ""
	For i = 0 To ArraySize(a())
		Pasw$ + a(i)
	Next
	
	ProcedureReturn Pasw$
EndProcedure



Procedure Execute()
	Protected String$, Pasw$, Dec$, BLen, *Ciphered
	
	String$ = GetGadgetText(StrG1)
	; 	Debug String$
	If Not Asc(String$) Or Len(Base2) < 2
		SetGadgetText(StrG2, "")
		ProcedureReturn
	EndIf
	If Not Asc(Key_phrase)
		; 		Ключевая фраза    Например имя кота
		Key_phrase = InputRequester(Lng(7), Lng(8), "", Hide)
		If Not Asc(Key_phrase)
			SetGadgetText(StrG2, "")
			ProcedureReturn
		EndIf
	EndIf

; 	String$ + Key_phrase + "passwordpasswordpasswordpassword" ; строка 32 символа по 2 байта, тут лишнего в 2 раза
	String$ + Key_phrase
; 	Если строка менее 16 символа, то удваваем строку, это нужно для ключа шифрования
	While Len(String$) < 16
		String$ + String$
	Wend
; 	Debug Len(String$)
; 	Debug String$

	BLen = StringByteLength(String$) + SizeOf(Character)
	*Ciphered = AllocateMemory(BLen)
	If *Ciphered And AESEncoder(@String$, *Ciphered, BLen, @String$, AES, 0, #PB_Cipher_ECB)
		; 		из-за того что StringFingerprint работает только со строкой была добавлена Base64Encoder (по указателю бинарные данные после AESEncoder)
; 		String$ = Left(String$, Len(String$) - 4)
; 		Debug BLen
; 		Debug PeekS(*Ciphered)
; 		нашлась проблема, флаг #PB_Cipher_NoPadding
		String$ = Base64Encoder(*Ciphered, BLen)
		FreeMemory(*Ciphered)
; 		String$ = Left(String$, Len(String$) - 8)
; 		Debug String$
		String$ = StringFingerprint(String$, #PB_Cipher_SHA3, 512)
		; 		String$ = StringFingerprint(String$, #PB_Cipher_SHA1)
; 				Debug String$
		; 		Base1 = "0123456789abcdef"
		; 		Base2 = "0123456789qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM!@#$%^&*(){}[];:,.\/+=-_|"
		; 		Base2 = "0123456789qwertyuiopasdfghjklzxcvbnmQWERTYUIOPASDFGHJKLZXCVBNM"
		; 		Base2 = "0123456789qwertyuiopasdfghjklzxcvbnm"
		Dec$ = NumToDec(String$, Base1)
		String$ = DecToNum(Dec$, Base2)
; 		Debug String$
		String$ = Unique(String$)
; 		Debug String$
		Pasw$ = Left(String$, Limit)
		Pasw$ = Upper(Pasw$, Dec$)
		SetGadgetText(StrG2, Pasw$)
		SetGadgetText(#LenPw, Str(Len(Pasw$)))
		; 		tmp = Str(Val("$" + NumToDec(sg3, Base1)))
		; 		SetGadgetText(out, DecToNum(Hex(Val(tmp)), Base2))
	EndIf
	
	
EndProcedure
; IDE Options = PureBasic 6.04 LTS (Windows - x64)
; CursorPosition = 268
; FirstLine = 258
; Folding = --
; EnableXP
; DPIAware
; UseIcon = Unique password.ico
; Executable = UniquePassword.exe
; CompileSourceDirectory
; Compiler = PureBasic 6.04 LTS (Windows - x64)
; DisableCompileCount = 4
; EnableBuildCount = 0
; EnableExeConstant
; IncludeVersionInfo
; VersionField0 = 0.4.1.%BUILDCOUNT
; VersionField2 = AZJIO
; VersionField3 = UniquePassword
; VersionField4 = 0.4.1
; VersionField6 = UniquePassword
; VersionField9 = AZJIO