

Global SendKeyDelay = 5
Global SendKeyDownDelay = 5

EnumerationBinary
	#MOD_LALT      = #MOD_ALT
	#MOD_LCONTROL  = #MOD_CONTROL
	#MOD_LSHIFT    = #MOD_SHIFT
	#MOD_LWIN      = #MOD_WIN
	#MOD_RALT
	#MOD_RCONTROL
	#MOD_RSHIFT
	#MOD_RWIN
EndEnumeration

#KEYEVENTF_UNICODE = 4

Macro IIf(expr, truepart)
	If expr
		truepart
	EndIf
EndMacro

Procedure keybd_event_send(vk.a, flag.l, extra.i = 0)
	Protected input.INPUT
	input\type = #INPUT_KEYBOARD
	input\ki\wVk = vk
	input\ki\wScan = MapVirtualKey_(vk, #MAPVK_VK_TO_VSC)
	input\ki\dwFlags = flag
	input\ki\dwExtraInfo = extra
	SendInput_(1, @input, SizeOf(INPUT))
EndProcedure

; Only left shift, left ctrl, and left alt don't need EXTENDEDKEY
Procedure SendModifier(modifier.u, type.l = 0)
	Macro SendModifierNoExt(vk)
		keybd_event_send(vk, type)
		Delay(SendKeyDelay)
	EndMacro
	
	Macro SendModifierExt(vk)
		keybd_event_send(vk, type | #KEYEVENTF_EXTENDEDKEY)
		Delay(SendKeyDelay)
	EndMacro
	
	IIf(modifier & #MOD_LSHIFT, SendModifierNoExt(#VK_LSHIFT))
	IIf(modifier & #MOD_RSHIFT, SendModifierExt(#VK_RSHIFT))
	IIf(modifier & #MOD_LCONTROL, SendModifierNoExt(#VK_LCONTROL))
	IIf(modifier & #MOD_RCONTROL, SendModifierExt(#VK_RCONTROL))
	IIf(modifier & #MOD_LALT, SendModifierNoExt(#VK_LMENU))
	IIf(modifier & #MOD_RALT, SendModifierExt(#VK_RMENU))
	IIf(modifier & #MOD_LWIN, SendModifierExt(#VK_LWIN))
	IIf(modifier & #MOD_RWIN, SendModifierExt(#VK_RWIN))
EndProcedure

Procedure SendKey(vk.a, modifier.u, extend = 0)
	
	SendModifier(modifier, 0)

	keybd_event_send(vk, extend)
	Delay(SendKeyDownDelay)
	keybd_event_send(vk, #KEYEVENTF_KEYUP | extend)
	Delay(SendKeyDelay)
	
	SendModifier(modifier, #KEYEVENTF_KEYUP)
EndProcedure

; IDE Options = PureBasic 5.72 (Windows - x86)
; CursorPosition = 67
; FirstLine = 26
; Folding = --
; EnableAsm
; EnableXP
; DPIAware
; Executable = Send1.exe