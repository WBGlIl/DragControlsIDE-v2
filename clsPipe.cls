VERSION 1.0 CLASS
BEGIN
  MultiUse = -1  'True
  Persistable = 0  'NotPersistable
  DataBindingBehavior = 0  'vbNone
  DataSourceBehavior  = 0  'vbNone
  MTSTransactionMode  = 0  'NotAnMTSObject
END
Attribute VB_Name = "clsPipe"
Attribute VB_GlobalNameSpace = False
Attribute VB_Creatable = True
Attribute VB_PredeclaredId = False
Attribute VB_Exposed = False
'====================================================
'����:      �ܵ��࣬������DOS�������ͨѶ
'����:      ����
'�ļ�:      clsPipe.cls
'====================================================

Option Explicit

'��ȡ�ܵ����ݶ�����չܵ��������
Private Declare Function PeekNamedPipe Lib "kernel32" (ByVal hNamedPipe As Long, ByVal lpBuffer As Long, ByVal nBufferSize As Long, _
    ByRef lpBytesRead As Long, ByRef lpTotalBytesAvail As Long, ByRef lpBytesLeftThisMessage As Long) As Long

'��������
Private Declare Function CreateProcess Lib "kernel32" Alias "CreateProcessA" (ByVal lpApplicationName As Long, ByVal lpCommandLine As String, _
    lpProcessAttributes As SECURITY_ATTRIBUTES, lpThreadAttributes As SECURITY_ATTRIBUTES, ByVal bInheritHandles As Long, ByVal dwCreationFlags As Long, _
    ByVal lpEnvironment As Long, ByVal lpCurrentDirectory As Long, lpStartupInfo As STARTUPINFO, lpProcessInformation As PROCESS_INFORMATION) As Long

'��ָ���ļ�д������
Private Declare Function WriteFile Lib "kernel32" (ByVal hfile As Long, lpBuffer As Any, ByVal nNumberOfBytesToWrite As Long, _
    ByRef lpNumberOfBytesWritten As Long, ByVal lpOverlapped As Long) As Long
'��ָ���ļ���ȡ����
Private Declare Function ReadFile Lib "kernel32" (ByVal hfile As Long, lpBuffer As Any, ByVal nNumberOfBytesToRead As Long, _
    ByRef lpNumberOfBytesRead As Long, ByVal lpOverlapped As Long) As Long

Private hInputRead      As Long, hInputWrite    As Long, hInput     As Long     '������
Private hOutputRead     As Long, hOutputWrite   As Long, hOutput    As Long     '������

Dim pi                  As PROCESS_INFORMATION                                  '������Ϣ
Dim bStopOutput         As Boolean                                              'ֹͣ��ȡ������ź�

'�ӿ�
Public Event Output(strOutput As String)                                        'Ŀ������������
Public Event OutputFinished()                                                   'Ŀ�����������

'����:      ��ȡ��ǰ�ܵ���Ŀ����̵Ľ��̾��
'����ֵ:    Ŀ����̵Ľ��̾��
Public Property Get hProcess() As Long
    hProcess = pi.hProcess
End Property

'����:      ��ȡ��ǰ�ܵ���Ŀ����̵Ľ���ID
'����ֵ:    Ŀ����̵Ľ���ID
Public Property Get dwProcessId() As Long
    dwProcessId = pi.dwProcessId
End Property

'����:      ����Dos���롢����ܵ�
'����:      CommandLine: ��Ҫִ�еĳ���
'����ֵ:    1���������ɹ���0��������ʧ��
Public Function InitDosIO(CommandLine As String) As Long
    Dim sa      As SECURITY_ATTRIBUTES                              '��ȫ����
    Dim si      As STARTUPINFO                                      '����������Ϣ
    Dim ret     As Long                                             '��������ֵ
    
    With sa                                                         '���ð�ȫ����
        .nLength = Len(sa)
        .bInheritHandle = 1                                             '����ɼ̳�
        .lpSecurityDescriptor = 0
    End With
    
    '--------------------------------------------------
    '�������롢������
    ret = CreatePipe(hInputRead, hInputWrite, sa, 1024)             '������
    If ret = 0 Then
        InitDosIO = 0
        Exit Function
    End If
    
    ret = CreatePipe(hOutputRead, hOutputWrite, sa, 65536)          '������
    If ret = 0 Then                                                 '����ʧ����ص��ոմ�����������
        CloseHandle hInputRead
        CloseHandle hInputWrite
        InitDosIO = 0
        Exit Function
    End If
    
    'ת��������
    ret = DuplicateHandle(GetCurrentProcess(), hInputWrite, GetCurrentProcess(), hInput, 0, 1, DUPLICATE_SAME_ACCESS)
    If ret = 0 Then                                                 'ת��ʧ����ص��ոմ��������롢������
        CloseHandle hInputRead
        CloseHandle hInputWrite
        CloseHandle hOutputRead
        CloseHandle hOutputWrite
        InitDosIO = 0
        Exit Function
    End If
    CloseHandle hInputWrite
    
    'ת��������
    ret = DuplicateHandle(GetCurrentProcess(), hOutputRead, GetCurrentProcess(), hOutput, 0, 1, DUPLICATE_SAME_ACCESS)
    If ret = 0 Then                                                 'ת��ʧ����ص��ոմ��������롢������
        CloseHandle hInputRead
        CloseHandle hInputWrite
        CloseHandle hOutputRead
        CloseHandle hOutputWrite
        InitDosIO = 0
        Exit Function
    End If
    CloseHandle hOutputRead
    
    '--------------------------------------------------
    '����Ŀ�����
    With si                                                         '���ý���������Ϣ
        .cb = Len(si)
        .dwFlags = STARTF_USESTDHANDLES Or STARTF_USESHOWWINDOW         'Ҫ�����ʹ��stdio�����������ʾ����
        .hStdOutput = hOutputWrite                                      '�ض���������롢���
        .hStdError = hOutputWrite
        .hStdInput = hInputRead
    End With
    
    If CreateProcess(ByVal 0, CommandLine, sa, sa, ByVal 1, NORMAL_PRIORITY_CLASS, ByVal 0, ByVal 0, si, pi) <> 1 Then
        InitDosIO = 0
    End If
    
    InitDosIO = 1
End Function

'����:      �ر�Dos���롢����ܵ�
'����ֵ:    1�����رչܵ��ɹ���0�����رչܵ�ʧ��
Public Function CloseDosIO() As Long
    CloseHandle hInputRead
    CloseHandle hInputWrite
    CloseHandle hOutputRead
    CloseHandle hOutputWrite
    TerminateProcess pi.hProcess, 0
    CloseHandle pi.hThread
    CloseHandle pi.hProcess
End Function

'����:      ��Ŀ����̽�������
'����:      strInput: ��Ҫ���������
'����ֵ:    1��������ɹ���0��������ʧ��
Public Function DosInput(ByVal strInput As String) As Long
    Dim bWritten    As Long                                                 '�ɹ�д����ֽ���
    Dim InputData() As Byte                                                 'д�������
    Dim szInputData As Long                                                 'д������ݴ�С
    
    InputData = StrConv(strInput, vbFromUnicode)                            '��������ת�����ֽ�����
    szInputData = UBound(InputData) + 1                                     '����д�����ݵĴ�С
    WriteFile hInput, InputData(0), ByVal szInputData, bWritten, 0          '������ܵ�д������
    
    If bWritten = 0 Then                                                    '��Ȼɶ��ûд�룿����
        DosInput = 0
        Exit Function
    End If
    DosInput = 1
End Function

'����:      ��ȡĿ����̵����
'����:      lpStrOutput: ���������ַ���
'           EndingStr:
'����ֵ:    1������ȡ�ɹ���0������ȡʧ��
Public Function DosOutput(ByRef strOutput As String, ByVal EndingStr As String) As Long
    Dim ret         As Long                                                 '�����ķ���ֵ
    Dim bRead       As Long                                                 '�ɹ���ȡ�����ݴ�С
    Dim OutData()   As Byte                                                 '��ȡ������
    Dim szOutData   As Long                                                 '�ܹ���Ҫ��ȡ�����ݴ�С
    
    bStopOutput = False
    strOutput = ""
    Do
        If bStopOutput Then                                                     '���յ�ֹͣ��ȡ������źţ���������
            RaiseEvent OutputFinished
            DosOutput = 0
            Exit Function
        End If
        ret = PeekNamedPipe(hOutput, 0, 0, ByVal 0, szOutData, ByVal 0)         '��ѯ����ܵ������Ϣ��
        If ret = 0 Then
            DosOutput = 0
            Exit Function
        End If
        
        If szOutData > 0 Then                                                   '����ܵ����пɹ���ȡ������
            ReDim OutData(szOutData)                                                '���仺�������չܵ���Ϣ
            ret = ReadFile(hOutput, OutData(0), szOutData, bRead, 0)                '�ӹܵ����ȡ����
            If ret = 0 Then
                DosOutput = 0
                Exit Function
            End If
            
            strOutput = strOutput & StrConv(OutData, vbUnicode)
            strOutput = Left(strOutput, Len(strOutput) - 1)
            strOutput = Replace(strOutput, vbLf, vbCrLf)
        End If
        
        DoEvents                                                                '��Ҫ��ռ�������߳�
        Sleep 10
        RaiseEvent Output(strOutput)
        
        If Not ProcessExists(pi.hProcess) Then                                  '���Ŀ�������ֹͣ����
            Exit Do
        End If
    Loop Until (Right(strOutput, Len(EndingStr)) = EndingStr)
    RaiseEvent OutputFinished
    DosOutput = 1
End Function

'����:      �жϵ�ǰ���ڽ����е�DosOutput()�����µ�������ݽ����ᱻ��ȡ��DosOutput()������ֱ�ӷ���0
Public Sub StopRecvOutput()
    bStopOutput = True
End Sub

'����:      ����ж�ص�ʱ��رչܵ�������Ŀ����̲�����̨
Private Sub Class_Terminate()
    Call StopRecvOutput                                                     'ֹͣ��ȡ���
    Call CloseDosIO                                                         '�ر����йܵ�
End Sub



