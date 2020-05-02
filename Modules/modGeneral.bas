Attribute VB_Name = "modGeneral"
Option Explicit

'Set the following in the Project Properties

'#Const CLIPBOARD_BACKUP = 1
'#Const DEBUG_MODE = 0
       
Private Declare Function FindWindowEx Lib "user32.dll" Alias "FindWindowExA" (ByVal hWndParent As Long, ByVal hWndChildAfter As Long, ByVal lpBUTTON_SIZEClass As String, ByVal lpBUTTON_SIZEWindow As String) As Long
Private Declare Function SetWindowPos Lib "user32.dll" (ByVal hWnd As Long, ByVal hWndInsertAfter As Long, ByVal X As Long, ByVal Y As Long, ByVal cx As Long, ByVal cy As Long, ByVal wFlags As Long) As Long
Private Declare Function SetParent Lib "user32" (ByVal hWndChild As Long, ByVal hWndNewParent As Long) As Long
Private Declare Function RegOpenKey Lib "advapi32.dll" Alias "RegOpenKeyA" (ByVal hKey As Long, ByVal lpSubKey As String, phkResult As Long) As Long 'Opens a handle to the specified key
Private Declare Function RegCloseKey Lib "advapi32" (ByVal hKey As Long) As Long 'Closes a handle to a key
Private Declare Function RegQueryValueEx Lib "advapi32.dll" Alias "RegQueryValueExA" (ByVal hKey As Long, ByVal lpValueName As String, ByVal lpReserved As Long, lpType As Long, lpData As Any, lpcbData As Long) As Long 'Retrieves the data stored in the
Private Declare Function RegSetValueEx Lib "advapi32.dll" Alias "RegSetValueExA" (ByVal hKey As Long, ByVal lpValueName As String, ByVal Reserved As Long, ByVal dwType As Long, lpData As Any, ByVal cbData As Long) As Long
Private Declare Function EbMode Lib "vba6" () As Long
Private Declare Function GetWindow Lib "user32.dll" (ByVal hWnd As Long, ByVal wCmd As Long) As Long
Private Declare Function GetClassName Lib "user32.dll" Alias "GetClassNameA" (ByVal hWnd As Long, ByVal lpClassName As String, ByVal nMaxCount As Long) As Long
Private Declare Function GetWindowText Lib "user32.dll" Alias "GetWindowTextA" (ByVal hWnd As Long, ByVal lpString As String, ByVal cch As Long) As Long

Public Declare Function GetTickCount Lib "kernel32.dll" () As Long 'Retrieves how many miliseconds elapsed since windows started. Usefull for benchmarking among other things

Public Enum IDE_StateResults
        
    ideDesign = 0
    ideRuntime = 1
    ideBreak = 2
        
End Enum

Public Enum ConfigCodes

    ccGroupNoBars = 0
    ccGroupExceptStandard = 1
    ccGroupAllBars = 2
    ccDockGaugeStandard = 4
    ccDockGaugeMenu = 8
    ccShowToggleBar = 16
    ccLockToolbars = 32
    ccCustomLayouts = 64
    ccForceFirstRow = 128
    ccSkipDebugBar = 256
    ccHideToolbarsInRuntime = 512
    ccForceLinearToolbars = 1024
            
End Enum

Public Enum ToggleIDs

    tidProjectExplorer = 2557
    tidProperties = 222
    tidFormLayout = 3046
    tidToolbox = 548
    tidObjectBrowser = 473
    tidColorPallete = 207
    tidImmediateWindow = 2554
    tidLocalsWindow = 2555
    tidWatchesWindow = 2556
    tidDesignWindow = 2553
    tidCodeWindow = 2558
    
    tidEmpty = 746
    tidGauge = 3201
    tidMoreActiveXDesigners = 32816
    tidLockButton = 519
    
End Enum

Private Type LayoutElement

    Visible As Boolean
    Width As Long
    Height As Long
    
End Type

Private Type OriginalLayout

    Immediate As LayoutElement
    Watches As LayoutElement
    Locals As LayoutElement
    FormLayout As LayoutElement
            
End Type

Private Type RECT
    Left As Long
    Top As Long
    Right As Long
    Bottom As Long
End Type

Private Const HWND_TOPMOST As Long = -1
Private Const SWP_NOMOVE As Long = &H2
Private Const SWP_NOSIZE As Long = &H1
Private Const GW_HWNDNEXT As Long = 2
Private Const GW_ENABLEDPOPUP As Long = 6

Private Const HKEY_CURRENT_USER As Long = &H80000001
Private Const REG_BUTTON_SIZE As Long = 1
Private Const ADDIN_REGISTRY_KEY As String = "Software\Microsoft\Visual Basic\6.0\Addins\ModernVB.Connect"

Public Const MODERN_TOOLBAR_PREFIX As String = "Modern "
Public Const ADDIN_TOOLBAR_COLLAPSE As String = "Collapse Windows (Add-in)"

Public Const VB_MENU_INDEX As Integer = 1
Public Const VB_TOOLBAR_STANDARD As String = "Standard"
Public Const VB_TOOLBAR_EDIT As String = "Edit"
Public Const VB_TOOLBAR_DEBUG As String = "Debug"
Public Const VB_TOOLBAR_FORM_EDITOR As String = "Form Editor"
Public Const VB_TOOLBAR_COLLAPSE As String = "Collapse Windows"
Public Const VB_TOOLBAR_RUNTIME As String = "Runtime"
Public Const CHECKMARK As String = "�"

Public g_colEventHandlers As Collection
Public g_ideVB As VBIDE.VBE
Public g_tlbModernStandard As CommandBar
Public g_tlbVBStandard As CommandBar
Public g_tlbVBToggle As CommandBar
Public g_tlbAddinToggle As CommandBar
Public g_tlbRuntime As CommandBar
Public g_btnGauge As Object
Public g_btnStatusPanel As CommandBarButton
Public g_olOriginalLayout As OriginalLayout
Public g_colModernBars As Collection
Public g_lngConfigCodes As ConfigCodes
Public g_lngPrevIDEState As Long
Public g_blnMustInitDocumentWindow As Boolean
Public g_lngStatusDelay As Long
Public g_blnFolderView As Boolean

Private m_intIndex As Integer
Private m_blnRepeatIcon As Boolean
Private m_lngMaxBarSize As Long

'FUNCTIONS AND SUBROUTINES
'**************************

'Read Setting
'*************
Public Function ReadSetting(ByRef Key As String, Optional Path As String = ADDIN_REGISTRY_KEY) As Long

    Dim strRet As String, hKey As Long: strRet = String$(2, vbNullChar)
    
    RegOpenKey HKEY_CURRENT_USER, Path, hKey
    
    If RegQueryValueEx(hKey, Key, 0, REG_BUTTON_SIZE, ByVal strRet, Len(strRet)) = 0 Then
    
        ReadSetting = Val(Chr$(AscB(strRet))): RegCloseKey hKey
        
    End If

End Function

'Write Setting
'**************
Public Function WriteSetting(ByRef Key As String, Value As String, Optional Path As String = ADDIN_REGISTRY_KEY) As Long

    Dim hKey As Long: RegOpenKey HKEY_CURRENT_USER, Path, hKey
        
    If RegSetValueEx(hKey, Key, 0, REG_BUTTON_SIZE, ByVal Value, Len(Value)) = 0 Then RegCloseKey hKey

End Function

'Always on Top
'**************
Public Sub AlwaysOnTop(hWnd As Long)

    Call SetWindowPos(hWnd, HWND_TOPMOST, 0, 0, 0, 0, SWP_NOMOVE Or SWP_NOSIZE)

End Sub

'IDE State
'**********
Public Function IDE_State() As IDE_StateResults

    'This function only works correctly when the Add-in is compiled. While running in the IDE, it will always return ideRuntime

    Static blnUpdate As Boolean

    IDE_State = EbMode: If blnUpdate Then g_lngPrevIDEState = IDE_State
    
    blnUpdate = (IDE_State <> g_lngPrevIDEState)

End Function

'Wait
'*****
Public Sub Wait(Milliseconds As Long)

    Dim lngStart As Long: lngStart = GetTickCount
    
    Do Until GetTickCount > lngStart + Milliseconds: DoEvents: Loop

End Sub

'Find Window
'***********
Public Function FindWindow(ByVal WindowType As VBIDE.vbext_WindowType) As Window

    Dim i As Long

    If WindowType = vbext_wt_Toolbox Then Set FindWindow = g_ideVB.Windows(""): Exit Function
    
    For i = 1 To g_ideVB.Windows.Count
    
        If g_ideVB.Windows(i).Type = WindowType Then Set FindWindow = g_ideVB.Windows(i): Exit For
    
    Next i
    
End Function

'Find Menu
'**********
Public Function FindMenu(ByVal MenuName As String, ByVal MenuItem As String) As CommandBarButton

    Dim i As Long, j As Long
    
    With g_ideVB.CommandBars(VB_MENU_INDEX)
    
        For i = 1 To .Controls.Count 'Echo .Controls(i).Caption
        
            If .Controls(i).Caption = MenuName Then
            
                For j = 1 To .Controls(i).CommandBar.Controls.Count 'Echo .Controls(i).CommandBar.Controls(j).Caption
                
                    If .Controls(i).CommandBar.Controls(j).Caption = MenuItem Then
                    
                        Set FindMenu = .Controls(i).CommandBar.Controls(j): Exit Function
                    
                    End If
                
                Next j
            
            End If
        
        Next i
    
    End With
    
End Function

'Find Button
'************
Public Function FindButton(Caption As String, Bar As CommandBar) As CommandBarButton

    Dim i As Long
        
    For i = 1 To Bar.Controls.Count
    
        If TypeOf Bar.Controls(i) Is CommandBarPopup Then
        
            Set FindButton = FindButton(Caption, Bar.Controls(i).CommandBar)
            
            If Not FindButton Is Nothing Then Exit Function
        
        Else 'Echo Bar.Controls(i).Caption
            
            If Replace$(Bar.Controls(i).Caption, "&", vbNullString) = Replace$(Caption, "&", vbNullString) Then
            
                Set FindButton = Bar.Controls(i): Exit Function
                
            End If
        
        End If
    
    Next i

End Function

'Find Panel
'**********
Public Function FindPanel(WindowType As vbext_WindowType, Optional ByVal Show As Boolean = True) As Window

    Dim i As Long
    
    Select Case WindowType

        Case vbext_WindowType.vbext_wt_CodeWindow
        
            If Not g_ideVB.SelectedVBComponent Is Nothing Then
            
                If Not g_ideVB.SelectedVBComponent.CodeModule Is Nothing Then
                
                    If Show Then g_ideVB.SelectedVBComponent.CodeModule.CodePane.Show
                
                    Set FindPanel = g_ideVB.SelectedVBComponent.CodeModule.CodePane.Window
                
                End If
                
            Else
            
                If g_ideVB.CodePanes.Count <> 0 Then
                    
                    g_ideVB.CodePanes(1).Show
                    
                    Set FindPanel = g_ideVB.CodePanes(1).Window
                    
                Else
                
                    If Not g_ideVB.ActiveVBProject Is Nothing Then
                    
                        If g_ideVB.ActiveVBProject.VBComponents.Count <> 0 Then
                        
                            For i = 1 To g_ideVB.ActiveVBProject.VBComponents.Count
                            
                                If Not g_ideVB.ActiveVBProject.VBComponents(i).CodeModule Is Nothing Then
                                
                                    If Show Then g_ideVB.ActiveVBProject.VBComponents(i).CodeModule.CodePane.Show
                
                                    Set FindPanel = g_ideVB.ActiveVBProject.VBComponents(i).CodeModule.CodePane.Window: Exit Function
                                
                                End If
                            
                            Next i
                        
                        End If
                    
                    End If
                    
                End If
                
            End If
            
        Case vbext_WindowType.vbext_wt_Designer
        
            If Not g_ideVB.SelectedVBComponent Is Nothing Then
            
                If Not g_ideVB.SelectedVBComponent.DesignerWindow Is Nothing Then
                
                    Set FindPanel = g_ideVB.SelectedVBComponent.DesignerWindow
                    
                    If Show Then FindPanel.Visible = True: Exit Function
                    
                End If
                
            End If
                
            For i = 1 To g_ideVB.ActiveVBProject.VBComponents.Count
                    
                If Not g_ideVB.ActiveVBProject.VBComponents(i).DesignerWindow Is Nothing Then
                        
                    Set FindPanel = g_ideVB.ActiveVBProject.VBComponents(i).DesignerWindow
                    
                    If Show Then FindPanel.Visible = True: Exit Function
                        
                End If
                    
            Next i
    
    End Select
    
End Function

'Replace Context Menu Icons
'***************************
Public Sub ReplaceContextMenuIcons(Menu As CommandBar)

    On Error GoTo ReplaceContextMenuIcons_Err

    Dim M As CommandBarButton, i As Long
    
    For i = 1 To Menu.Controls.Count
    
        With Menu.Controls(i) 'Echo .Caption & " (" & .Id & ")"
            
            If TypeOf Menu.Controls(i) Is CommandBarPopup Then
            
                ReplaceContextMenuIcons .CommandBar
                
            Else
        
                If .BuiltInFace Then
            
                    Select Case .Caption
                        
                        Case "&Add File...", "Add Multiple Files...": Set M = FindMenu("&Project", .Caption)
                        
                        Case Else: If .Id <> 746 Then Set M = g_ideVB.CommandBars(VB_MENU_INDEX).FindControl(Id:=.Id, Recursive:=True) ''Dim strCaption As String: If .Id = 746 Then strCaption = Replace$(.Caption, "Add ", vbNullString) Else strCaption = .Caption: Set M = FindButton(strCaption, g_tlbModernStandard)
                        
                    End Select
                    
                    If Not M Is Nothing Then M.CopyFace: .PasteFace: .Style = msoButtonIconAndCaption
                                                
                End If
                
            End If
            
        End With
        
NextItem: Next i
    
ReplaceContextMenuIcons_Err:
    
    Resume Next

End Sub

'Update Runtime Toolbar Icons
'*****************************
Public Sub UpdateRuntimeToolbarIcons()

    If Not g_tlbRuntime Is Nothing Then
    
        Dim i As Long, M As CommandBarButton, strClipboard As String
        
        For i = 1 To g_tlbRuntime.Controls.Count
        
            With g_tlbRuntime.Controls(i)
        
                If Not .Enabled Then
                
                    If LenB(.Tag) = 0 Then 'Echo "Disabling: " & g_tlbRuntime.Controls(i).Caption
                    
                        Set M = Nothing: Set M = g_ideVB.CommandBars(VB_TOOLBAR_DEBUG).FindControl(Id:=.Id, Recursive:=True)
                        
                        If Not M Is Nothing Then
                        
                            If LenB(strClipboard) = 0 Then GoSub ClipSave
                        
                            M.CopyFace: .PasteFace: .Tag = CHECKMARK: Clipboard.Clear
                    
                        End If
                        
                    End If
                
                Else
                
                    If .Tag = CHECKMARK Then 'Echo "Enabling: " & g_tlbRuntime.Controls(i).Caption
                    
                        Set M = Nothing: Set M = g_ideVB.CommandBars(VB_MENU_INDEX).FindControl(Id:=.Id, Recursive:=True)
                
                        If Not M Is Nothing Then
                        
                            If LenB(strClipboard) = 0 Then GoSub ClipSave
                            
                            M.CopyFace: .PasteFace: .Tag = vbNullString: Clipboard.Clear
                            
                        End If
                        
                    End If
                    
                End If
            
            End With
            
        Next i
        
        If LenB(strClipboard) <> 0 Then
        
            #If CLIPBOARD_BACKUP = 0 Then
                If strClipboard <> vbNullChar Then Clipboard.SetText strClipboard, vbCFText
            #Else
                Call ClipboardRestore
            #End If
            
        End If
        
    End If
    
    Exit Sub
    
ClipSave:

    #If CLIPBOARD_BACKUP = 0 Then
        strClipboard = Clipboard.GetText(vbCFText): If LenB(strClipboard) = 0 Then strClipboard = vbNullChar
    #Else
        ClipboardSave g_ideVB.MainWindow.hWnd: strClipboard = vbNullChar
    #End If
    
    Return
    
End Sub

'Toggle Topmost Toolbars
'************************
Public Sub ToggleTopmostToolbars(ByVal Show As Boolean)

    Dim i As Long
    
    For i = VB_MENU_INDEX + 1 To g_ideVB.CommandBars.Count
    
        If g_ideVB.CommandBars(i).Position = msoBarTop And Not g_ideVB.CommandBars(i).BuiltIn Then
        
            If Not g_ideVB.CommandBars(i).Visible = Show Then g_ideVB.CommandBars(i).Visible = Show
            
        End If
        
    Next i
        
End Sub

'Create Toggle Toolbar
'**********************
Public Sub CreateToggleToolbar()

    On Error Resume Next
    
    Dim OriginalButton As CommandBarButton, NewButton As CommandBarButton, strNewCaption As String
    
    Set g_tlbVBToggle = g_ideVB.CommandBars(VB_TOOLBAR_COLLAPSE): g_tlbVBToggle.Visible = False

    Set g_tlbAddinToggle = Nothing: Set g_tlbAddinToggle = g_ideVB.CommandBars(ADDIN_TOOLBAR_COLLAPSE)
        
    If g_tlbAddinToggle Is Nothing Then
    
        Set g_tlbAddinToggle = g_ideVB.CommandBars.Add(ADDIN_TOOLBAR_COLLAPSE, msoBarRight, , True)
        
        Set OriginalButton = g_ideVB.CommandBars(VB_MENU_INDEX).FindControl(Id:=tidCodeWindow, Recursive:=True): GoSub AddButton
        Set OriginalButton = g_ideVB.CommandBars(VB_MENU_INDEX).FindControl(Id:=tidDesignWindow, Recursive:=True): GoSub AddButton
        Set OriginalButton = g_ideVB.CommandBars(VB_MENU_INDEX).FindControl(Id:=tidProjectExplorer, Recursive:=True): GoSub AddButton
        Set OriginalButton = g_ideVB.CommandBars(VB_MENU_INDEX).FindControl(Id:=tidProperties, Recursive:=True): GoSub AddButton
        Set OriginalButton = g_ideVB.CommandBars(VB_MENU_INDEX).FindControl(Id:=tidFormLayout, Recursive:=True): GoSub AddButton
        Set OriginalButton = g_ideVB.CommandBars(VB_MENU_INDEX).FindControl(Id:=tidToolbox, Recursive:=True): GoSub AddButton
        Set OriginalButton = g_ideVB.CommandBars(VB_MENU_INDEX).FindControl(Id:=tidObjectBrowser, Recursive:=True): GoSub AddButton
        Set OriginalButton = g_ideVB.CommandBars(VB_MENU_INDEX).FindControl(Id:=tidColorPallete, Recursive:=True): GoSub AddButton
        Set OriginalButton = g_ideVB.CommandBars(VB_MENU_INDEX).FindControl(Id:=tidImmediateWindow, Recursive:=True): GoSub AddButton
        Set OriginalButton = g_ideVB.CommandBars(VB_MENU_INDEX).FindControl(Id:=tidLocalsWindow, Recursive:=True): GoSub AddButton
        Set OriginalButton = g_ideVB.CommandBars(VB_MENU_INDEX).FindControl(Id:=tidWatchesWindow, Recursive:=True): GoSub AddButton
        
        g_tlbAddinToggle.Visible = True
        
    End If
    
    Exit Sub
    
AddButton:

    If Not OriginalButton Is Nothing Then
    
        Set NewButton = g_tlbAddinToggle.Controls.Add(msoControlButton, OriginalButton.Id, Temporary:=True)
        
        strNewCaption = Replace$(OriginalButton.Caption, " Window", vbNullString)
        strNewCaption = Replace$(strNewCaption, " &Window", vbNullString)
        strNewCaption = Replace$(strNewCaption, "Properties", "Proper&ties")
        strNewCaption = Replace$(strNewCaption, "O&bject", "&Design")
        
        NewButton.Caption = strNewCaption
        
        NewButton.ToolTipText = "Toggle " & OriginalButton.ToolTipText: NewButton.Style = msoButtonIconAndCaption: NewButton.BeginGroup = True
        
        OriginalButton.CopyFace: NewButton.PasteFace

    End If
    
    Return
    
End Sub

'Register Toggles
'*****************
Public Sub RegisterToggles(ParamArray ButtonID() As Variant)

    On Error Resume Next
    
    If IsMissing(ButtonID) Then
    
        RegisterToggles tidProjectExplorer, tidProperties, tidFormLayout, tidToolbox, tidObjectBrowser, tidColorPallete, _
                        tidImmediateWindow, tidLocalsWindow, tidWatchesWindow, tidCodeWindow, tidDesignWindow
                        
        Exit Sub
    
    End If
    
    Dim Button As CommandBarButton, Handler As CEventHandler, Host As CommandBar, i As Long
        
    Set Host = g_ideVB.CommandBars(ADDIN_TOOLBAR_COLLAPSE): If Host Is Nothing Then Exit Sub
    
    For i = 0 To UBound(ButtonID)
    
        Set Button = g_ideVB.CommandBars(VB_MENU_INDEX).FindControl(Id:=ButtonID(i), Recursive:=True): GoSub RegisterButton
        Set Button = g_ideVB.CommandBars(ADDIN_TOOLBAR_COLLAPSE).FindControl(Id:=ButtonID(i)): GoSub RegisterButton
        
    Next i
        
    Exit Sub
        
RegisterButton:

    If Not Button Is Nothing Then

        Set Handler = New CEventHandler
        
        Set Handler.MenuHandler = g_ideVB.Events.CommandBarEvents(Button)
    
        Set Handler.SourceBar = Button.Parent
        
        Handler.Key = Button.Parent.Name & "." & Button.Id
        
        Handler.Host = Host: g_colEventHandlers.Add Handler, Handler.Key
    
    End If
    
    Return
    
End Sub

'Create Modern Toolbars
'***********************
Public Sub CreateModernToolbars(GroupBars As Boolean, ParamArray Names() As Variant)

    On Error GoTo CreateModernToolbars_Error

    Dim Source As CommandBar, Modern As CommandBar
    Dim i As Integer, j As Integer, blnGrouped As Boolean

    If IsMissing(Names) Then Exit Sub

    For i = 0 To UBound(Names)

        Set Source = g_ideVB.CommandBars(Names(i))

        If Not Source Is Nothing Then
        
            Source.Visible = False
            
            If (g_lngConfigCodes And ccSkipDebugBar) <> 0 Then If Names(i) = VB_TOOLBAR_DEBUG Then GoTo NextBar

            If Not GroupBars Or Not blnGrouped Then
            
                Set Modern = Nothing

                Set Modern = g_ideVB.CommandBars.Add(MODERN_TOOLBAR_PREFIX & Names(i), msoBarTop, Temporary:=True)
                                        
                Modern.Visible = False: blnGrouped = True: g_colModernBars.Add Modern ', Modern.Name

            End If

            For j = 1 To Source.Controls.Count: AddButton Modern, Source, Source.Controls(j): Next j

            m_intIndex = 0: Modern.Left = 0 ': If Not GroupBars Then Modern.Visible = True
                        
            If g_colModernBars.Count > 1 Then
        
                Modern.RowIndex = g_colModernBars(g_colModernBars.Count - 1).RowIndex
                
                m_lngMaxBarSize = m_lngMaxBarSize + Source.Width
            
                If (g_lngConfigCodes And ccLockToolbars) = 0 Then If Not GroupBars Or i = 0 Then m_lngMaxBarSize = m_lngMaxBarSize + 12
        
                If (g_lngConfigCodes And ccForceLinearToolbars) = 0 Then
            
                    If m_lngMaxBarSize > (Screen.Width \ Screen.TwipsPerPixelX) Then m_lngMaxBarSize = Modern.Width: Modern.RowIndex = Modern.RowIndex + 1
                    
                End If
            
            Else
            
                If (g_lngConfigCodes And ccForceFirstRow) <> 0 Then Modern.RowIndex = 2
            
                m_lngMaxBarSize = Modern.Width
            
                If (g_lngConfigCodes And ccDockGaugeStandard) <> 0 And Not g_btnGauge Is Nothing Then m_lngMaxBarSize = m_lngMaxBarSize + g_btnGauge.Width
            
            End If
                            
        End If
        
NextBar: Next i ': If Not Modern Is Nothing Then Modern.Visible = True

    'Rearrange and display the Modern toolbars
    
    Dim k As Long: For k = g_colModernBars.Count To 1 Step -1: g_colModernBars(k).Left = 0: g_colModernBars(k).Visible = True: Next k
    
    On Error GoTo 0
    
    Exit Sub

CreateModernToolbars_Error:

    #If DEBUG_MODE = 1 Then
        Echo "Error " & Err.Number & " (" & Err.Description & ") while creating toolbar " & MODERN_TOOLBAR_PREFIX & Source.Name, vbLogEventTypeError
    #End If

End Sub

'Add Button
'***********
Public Sub AddButton(Host As CommandBar, Source As CommandBar, Button As CommandBarControl)
    
    On Error GoTo AddButton_Err
    
    Dim Btn As CommandBarControl, BtnImg As StdPicture, i As Integer
    
    Dim Handler As CEventHandler
    
    If LenB(Button.Caption) = 0 Then Exit Sub 'Skip for empty caption buttons
    
    Select Case Button.Id
    
        Case tidEmpty: If UCase$(Button.Caption) = "[EMPTY]" Then Exit Sub 'Skip strange outlier invisible Webclass button
        Case tidMoreActiveXDesigners: Exit Sub 'Ignore invisible More ActiveX Designers menu
        Case tidGauge: Set g_btnGauge = Button: Exit Sub
        
    End Select
    
    Set Btn = Host.Controls.Add(msoControlButton)
    
    With Button
                
        #If DEBUG_MODE = 1 Then
            LogButton Button, App.Path & "\toolbars.txt"
        #End If

        If LenB(.ToolTipText) = 0 Then .ToolTipText = .Caption

        Btn.BeginGroup = .BeginGroup: Btn.Caption = .Caption
        Btn.HelpContextID = .HelpContextID: Btn.HelpFile = .HelpFile
        Btn.ToolTipText = .ToolTipText: Btn.OLEUsage = .OLEUsage
        Btn.Priority = .Priority: Btn.Visible = True

        If Not m_blnRepeatIcon Then m_intIndex = m_intIndex + 1 Else m_blnRepeatIcon = False
        
        On Error Resume Next
        
            .Visible = True: Btn.Tag = "CTRL" & m_intIndex: .Tag = Btn.Tag
        
        On Error GoTo AddButton_Err
            
'            Debug.Print "Name: " & SanitizeTooltip(.ToolTipText)
'            Debug.Print "ID: " & .Id

        Set BtnImg = GetResourceImage(Button, Btn)
        
        CopyBitmapAsButtonFace BtnImg, vbMagenta: Btn.PasteFace

        If TypeOf Button Is CommandBarButton Then
            
            Btn.OnAction = .OnAction: Btn.State = .State: Btn.Style = .Style
            
            Set Handler = New CEventHandler
            Set Handler.MenuHandler = g_ideVB.Events.CommandBarEvents(Btn)
            Set Handler.SourceBar = Source
            
            Set Handler.Host = Host: g_colEventHandlers.Add Handler
    
            If .Id = tidLockButton Then Handler.Toggle = True 'Handle the toggling Lock Button special case in the Form Editor bar

        ElseIf TypeOf Button Is CommandBarPopup Then
                        
            Set Handler = New CEventHandler
            Set Handler.MenuHandler = g_ideVB.Events.CommandBarEvents(Btn)
            Set Handler.SourceBar = .CommandBar
            
            Set Handler.Host = Host: g_colEventHandlers.Add Handler
            
            Set Btn = Host.Controls.Add(msoControlPopup)
            
            Btn.Caption = "&": m_blnRepeatIcon = True
            
            For i = 1 To .CommandBar.Controls.Count
                AddButton Btn.CommandBar, .CommandBar, .CommandBar.Controls(i)
            Next i

        End If

    End With
        
    Exit Sub
        
AddButton_Err:
    
    #If DEBUG_MODE = 1 Then
        Echo "Error '" & Err.Number & "' while copying button " & Button.Index & " [" & Button.Caption & "]: " & Err.Description, vbLogEventTypeError
    #End If
    
    Stop
    
    Resume Next

End Sub

'Get Resource Image
'*******************
Private Function GetResourceImage(Button As CommandBarControl, Target As CommandBarControl) As IPictureDisp

    On Error GoTo GetResourceImage_Err
    
    Dim ResourceID As Variant

    With Button
    
        Select Case .Id
        
            Case 746
            
                If .ShortcutText = "Ctrl+N" Then
                    ResourceID = "NEW_PROJECT"
                ElseIf .ShortcutText = "Ctrl+D" Then
                    ResourceID = "ADD_FILE"
                ElseIf .ShortcutText = "Ctrl+T" Then
                    ResourceID = "COMPONENT_GALLERY"
                ElseIf UCase$(.ToolTipText) Like "*.EXE*" Or UCase$(.ToolTipText) Like "*MAKE*" Then
                    ResourceID = "MAKE_EXE"
                ElseIf .Parent.Name = "Standard" Then
                    ResourceID = "MEMBER_ATTRIBUTES"
                ElseIf .Parent.Name = "Debug" Then
                    ResourceID = "FULL_START"
                Else
                    ResourceID = SanitizeTooltip(.ToolTipText)
                End If
                
            Case 1
                ResourceID = SanitizeTooltip(.ToolTipText)
            Case Else
                ResourceID = .Id
        
        End Select
    
    End With

    Set GetResourceImage = LoadResPicture(ResourceID, vbResBitmap)
        
    Exit Function
    
GetResourceImage_Err:

    #If DEBUG_MODE = 1 Then
        Echo "Error '" & Err.Number & "' while reading resource " & ResourceID & " for button " & Button.Index & " [" & Button.Caption & "]: " & Err.Description, vbLogEventTypeError
    #End If
    
    'If Err.Number = 326 Then 'Resource not found

    Set GetResourceImage = LoadResPicture("DEFAULT", vbResBitmap)
    
    Target.ToolTipText = "I'm sorry sir, this button does not appear to be supported."
    
    Target.Style = msoButtonIconAndCaption
        
    'End If
    
End Function

'Sanitize Tooltip
'*****************
Public Function SanitizeTooltip(Tooltip As String) As String
        
    Dim intPos As Integer: intPos = InStr(1, Tooltip, "(")
    
    If intPos <> 0 Then SanitizeTooltip = Left$(Tooltip, intPos - 1) Else SanitizeTooltip = Tooltip
    
    SanitizeTooltip = UCase$(Trim$(SanitizeTooltip))
    
    SanitizeTooltip = Replace$(SanitizeTooltip, "&", vbNullString)
    SanitizeTooltip = Replace$(SanitizeTooltip, "...", vbNullString)
    SanitizeTooltip = Replace$(SanitizeTooltip, "'", vbNullString)
    SanitizeTooltip = Replace$(SanitizeTooltip, "/", "_")
    SanitizeTooltip = Replace$(SanitizeTooltip, "-", "_")
    SanitizeTooltip = Replace$(SanitizeTooltip, " ", "_")

End Function

'Restore Buttons
'****************
Public Sub RestoreButtons(ParamArray Toolbars() As Variant)

    On Error Resume Next

    If Not IsMissing(Toolbars) Then
    
        Dim i As Integer, j As Integer, CB As CommandBar
        
        For i = 0 To UBound(Toolbars)
            
            Set CB = g_ideVB.CommandBars(Toolbars(i))
        
            If Not CB Is Nothing Then
        
                CB.Visible = False: CB.Protection = msoBarNoProtection
                
                For j = 1 To CB.Controls.Count: CB.Controls(j).Visible = True: Next j
                
                CB.Left = 0: CB.Visible = True
    
            End If
    
        Next i
    
    End If
    
End Sub

'Dock Standard Bar To Window
'****************************
Public Sub DockStandardBarToWindow(ByVal X As Long, Optional ByVal Width As Long, Optional ByVal Height As Long, Optional ByVal ParentWindowName As String)
    
    Dim hStandard As Long, hParent As Long
    
    g_tlbVBStandard.Position = msoBarFloating: g_tlbVBStandard.Protection = msoBarNoMove
    
    hParent = FindWindowEx(g_ideVB.MainWindow.hWnd, ByVal 0&, "MsoCommandBarDock", "MsoDockTop") 'hMainWindow = FindWindowEx(0&, 0&, "wndclass_desked_gsk", g_ideVB.MainWindow.Caption)
    
    If hParent = 0 Then Exit Sub
    
    hStandard = FindStandardToolbar() 'FindWindowEx(ByVal 0&, ByVal 0&, "MsoCommandBar", VB_TOOLBAR_STANDARD)
    hParent = FindWindowEx(hParent, ByVal 0&, "MsoCommandBar", ParentWindowName)

    If hParent <> 0 And hStandard <> 0 Then SetParent hStandard, hParent
            
    SetWindowPos hStandard, 0, X, -Height - 2, Width + 10, Height * 2 + 5, 0&
    SetWindowPos hStandard, -1, 0, 0, 0, 0, 3&
       
End Sub

'Find Standard Toolbar
'**********************
Private Function FindStandardToolbar() As Long

    Dim hTemp As Long, strClass As String, strText As String, lngRet As Long
    
    hTemp = g_ideVB.MainWindow.hWnd: strClass = String$(256, vbNullChar): strText = String$(Len(VB_TOOLBAR_STANDARD) + 1, vbNullChar)

    Do While hTemp <> 0
    
        hTemp = GetWindow(hTemp, GW_ENABLEDPOPUP Or GW_HWNDNEXT)
        
        If hTemp <> 0 Then
        
            lngRet = GetClassName(hTemp, strClass, Len(strClass))
        
            If Left$(strClass, lngRet) = "MsoCommandBar" Then
            
                lngRet = GetWindowText(hTemp, strText, Len(VB_TOOLBAR_STANDARD) + 1)
            
                If Left$(strText, lngRet) = VB_TOOLBAR_STANDARD Then FindStandardToolbar = hTemp: Exit Do
            
            End If
        
        End If
    
    Loop
    
    'Not reliable if there are multiple instances of VB6.exe running, but fallback if the window wasn't found
    If FindStandardToolbar = 0 Then FindStandardToolbar = FindWindowEx(ByVal 0&, ByVal 0&, "MsoCommandBar", VB_TOOLBAR_STANDARD)
        
End Function

'Save Panel
'***********
Public Sub SavePanel(Panel As Window, Layout As LayoutElement)

    If Not Panel Is Nothing Then
        
        Layout.Visible = Panel.Visible: Layout.Height = Panel.Height: Layout.Width = Panel.Width
        
    End If
                
End Sub

'Restore Panels
'***************
Public Sub RestorePanels(ByVal AffectVisibility As Boolean)

    Dim W As Window: Set W = FindWindow(vbext_wt_Immediate)
    
    If Not W Is Nothing Then
        If AffectVisibility Then W.Visible = g_olOriginalLayout.Immediate.Visible
        W.Height = g_olOriginalLayout.Immediate.Height
        W.Width = g_olOriginalLayout.Immediate.Width
    End If
    
    Set W = FindWindow(vbext_wt_Locals)
    
    If Not W Is Nothing Then
        If AffectVisibility Then W.Visible = g_olOriginalLayout.Locals.Visible
        W.Height = g_olOriginalLayout.Locals.Height
        W.Width = g_olOriginalLayout.Locals.Width
    End If
    
    Set W = FindWindow(vbext_wt_Watch)
    
    If Not W Is Nothing Then
        If AffectVisibility Then W.Visible = g_olOriginalLayout.Watches.Visible
        W.Height = g_olOriginalLayout.Watches.Height
        W.Width = g_olOriginalLayout.Watches.Width
    End If
    
    Set W = FindWindow(vbext_wt_Preview)
    
    If Not W Is Nothing Then
        If AffectVisibility Then W.Visible = g_olOriginalLayout.FormLayout.Visible
        W.Height = g_olOriginalLayout.FormLayout.Height
        W.Width = g_olOriginalLayout.FormLayout.Width
    End If
    
End Sub

'Set Code Layout
'****************
Public Sub SetCodeLayout()

    Dim W As Window: Set W = FindWindow(vbext_wt_CodeWindow)

    If W Is Nothing Then Set W = FindPanel(vbext_wt_CodeWindow)

    If Not W Is Nothing Then

        If (g_lngConfigCodes And ccCustomLayouts) <> 0 Then
                        
            'FindWindow(vbext_wt_Immediate).Visible = False
            FindWindow(vbext_wt_Toolbox).Visible = False
            FindWindow(vbext_wt_PropertyWindow).Visible = False
            FindWindow(vbext_wt_Watch).Visible = False
            FindWindow(vbext_wt_Locals).Visible = False
            FindWindow(vbext_wt_Browser).Visible = False
            FindWindow(vbext_wt_Preview).Visible = False
            
            If g_blnMustInitDocumentWindow Then
            
                FindMenu("&Add-Ins", "Document Map Window").Execute
            
            Else
            
                Dim DocumentMap As Window: Set DocumentMap = FindWindow(vbext_wt_ToolWindow)
            
                If DocumentMap.Caption = "Document Map" Then DocumentMap.Visible = True
                
            End If
            
            FindMenu("&CodeSMART", "Co&de Flow Explorer").Execute
            
        End If: W.SetFocus
        
    End If

End Sub

'Set Object Layout
'******************
Public Sub SetObjectLayout()

    Dim W As Window: Set W = FindWindow(vbext_wt_Designer)

    If W Is Nothing Then Set W = FindPanel(vbext_wt_Designer)
    
    If Not W Is Nothing Then
    
        If (g_lngConfigCodes And ccCustomLayouts) <> 0 Then
        
            'FindWindow(vbext_wt_Immediate).Visible = False
            FindWindow(vbext_wt_Toolbox).Visible = True
            FindWindow(vbext_wt_PropertyWindow).Visible = True
            FindWindow(vbext_wt_Watch).Visible = False
            FindWindow(vbext_wt_Locals).Visible = False
            FindWindow(vbext_wt_Browser).Visible = False
            FindWindow(vbext_wt_Preview).Visible = True
            FindWindow(vbext_wt_ToolWindow).Visible = False 'Hide documents window
            
            FindMenu("&CodeSMART", "De&signer Explorer").Execute
            
        End If: W.SetFocus
    
    End If

End Sub

'No longer in use:

'Public Sub AddMissingMenuIcons(Menu As CommandBar)
'
'    Dim i As Long, j As Long
'    Dim Modern As Variant, Button As CommandBarButton
'
'    For i = 1 To Menu.Controls.Count
'
'        If TypeOf Menu.Controls(i) Is CommandBarPopup Then
'
'            AddMissingMenuIcons Menu.Controls(i).CommandBar
'
'        Else
'
'            'Debug.Print Menu.Controls(i).Caption
'
'            With Menu.Controls(i)
'
'                'Clipboard.Clear: .CopyFace
'
'                If .BuiltInFace Or .Caption = "Data &View Window" Then
'
'                    Dim strCaption As String: If .Id = 746 Then strCaption = Mid$(.Caption, 5) Else strCaption = .Caption
'
'                    For Each Modern In g_colModernBars
'
'                        Set Button = FindButton(strCaption, Modern.Reference)
'
'                        On Error Resume Next
'
'                        If Not Button Is Nothing Then Button.CopyFace: .PasteFace: Exit For
'
'                    Next Modern
'
'                End If
'
'            End With
'
'        End If
'
'    Next i
'
'End Sub

'Helper subs for debugging

#If DEBUG_MODE = 1 Then

    'Echo
    '*****
    Public Sub Echo(ByRef Expression As String, Optional Kind As LogEventTypeConstants, Optional ByVal LogFilePath As String, Optional Verbose As Boolean = False, Optional ByRef Prefix As String = "> ")
    
            Dim strOutput As String: strOutput = Prefix
    
            If Verbose Then strOutput = strOutput & "[" & Now & "] " & UCase$(App.EXEName) & ".EXE - "
    
            Select Case Kind
                Case vbLogEventTypeError
                    strOutput = strOutput & "ERROR "
                Case vbLogEventTypeWarning
                    strOutput = strOutput & "WARNING: "
                Case vbLogEventTypeInformation
                    strOutput = strOutput & "INFO: "
            End Select
    
            strOutput = strOutput & Expression
    
            If LenB(LogFilePath) = 0 Then LogFilePath = App.Path & "\" & App.EXEName & "-" & Format$(Date, "yyyy.mm.dd") & ".log" ' "-" & Format$(Time, "HH.MM.SS") & ".log"
    
            Dim hFile As Integer: hFile = FreeFile()
    
            Open LogFilePath For Append As #hFile: Print #hFile, strOutput: Close #hFile
    
            If App.LogMode = 0 Then Debug.Print strOutput
    
    End Sub

    'Log Menus
    '**********
    Private Sub LogMenus(Menu As CommandBar, LogFile As String)
    
        Dim i As Long, Button As Object
    
        On Error Resume Next
    
        For i = 1 To Menu.Controls.Count
    
            Set Button = Menu.Controls(i)
    
            With Button
    
                Echo "Commmand bar: " & .Parent.Name & " (" & .Parent.Parent.Name & ")", , LogFile
                Echo "Control " & .Index & " of " & .Parent.Controls.Count, , LogFile
                Echo String$(20, "-"), , LogFile
                Echo "Type: " & TypeName(Button), , LogFile
                Echo "Caption: " & .Caption, , LogFile
                Echo "ID: " & .Id, , LogFile
                Echo "FaceID: " & .FaceId, , LogFile
                Echo "DescriptionText: " & .DescriptionText, , LogFile
                Echo "Tooltip: " & .ToolTipText, , LogFile
                Echo "Sanitized Tooltip: " & SanitizeTooltip(.ToolTipText), , LogFile
                Echo "OnAction: " & .OnAction, , LogFile
                Echo "Parameter: " & .Parameter, , LogFile
                Echo "Priority: " & .Priority, , LogFile
                Echo "ShortcutText: " & .ShortcutText, , LogFile
                Echo "Tag: " & .Tag, , LogFile
                Echo ""
    
            End With
    
            If TypeOf Button Is CommandBarPopup Then LogMenus Button.CommandBar, LogFile
    
        Next i
    
    End Sub
    
    'Log Button
    '***********
    Private Sub LogButton(Button As Object, ByVal LogFile As String)
    
        With Button
    
            Echo "Commmand bar: " & .Parent.Name & " (" & .Parent.Parent.Name & ")", , LogFile
            Echo "Control " & .Index & " of " & .Parent.Controls.Count, , LogFile
            Echo String$(20, "-"), , LogFile
            Echo "Type: " & TypeName(Button), , LogFile
            Echo "Caption: " & .Caption, , LogFile
            Echo "ID: " & .Id, , LogFile
            Echo "FaceID: " & .FaceId, , LogFile
            Echo "Help ID: " & .HelpContextID
            Echo "Name File: " & .HelpFile
            Echo "DescriptionText: " & .DescriptionText, , LogFile
            Echo "Tooltip: " & .ToolTipText, , LogFile
            Echo "Sanitized Tooltip: " & SanitizeTooltip(.ToolTipText), , LogFile
            Echo "OnAction: " & .OnAction, , LogFile
            Echo "Parameter: " & .Parameter, , LogFile
            Echo "Priority: " & .Priority, , LogFile
            Echo "ShortcutText: " & .ShortcutText, , LogFile
            Echo "Tag: " & .Tag, , LogFile
            Echo ""
    
        End With
    
    End Sub

#End If
