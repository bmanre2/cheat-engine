unit frmThreadlistunit;

{$MODE Delphi}

interface

uses
  jwawindows, windows, LCLIntf, Messages, SysUtils, Classes, Graphics, Controls, Forms,
  Dialogs, ComCtrls, Menus, StdCtrls, LResources,cefuncproc, CEDebugger, debugHelper, newkernelhandler;

type

  { TfrmThreadlist }

  TfrmThreadlist = class(TForm)
    miClearDebugRegisters: TMenuItem;
    miFreezeThread: TMenuItem;
    miResumeThread: TMenuItem;
    PopupMenu1: TPopupMenu;
    miBreak: TMenuItem;
    threadTreeview: TTreeView;
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure miBreakClick(Sender: TObject);
    procedure miClearDebugRegistersClick(Sender: TObject);
    procedure miFreezeThreadClick(Sender: TObject);
    procedure miResumeThreadClick(Sender: TObject);
    procedure threadTreeviewDblClick(Sender: TObject);
    procedure threadTreeviewExpanding(Sender: TObject; Node: TTreeNode;
      var AllowExpansion: Boolean);
  private
    { Private declarations }
  public
    { Public declarations }
    procedure FillThreadlist;
  end;

var
  frmThreadlist: TfrmThreadlist;

implementation

uses debugeventhandler;

resourcestring
  rsPleaseFirstAttachTheDebuggerToThisProcess = 'Please first attach the debugger to this process';
  rsCouldnTObtainContext = 'Couldn''t obtain context';
  rsCouldnTOpenHandle = 'Couldn''t open handle';

procedure TfrmThreadlist.FormClose(Sender: TObject;
  var Action: TCloseAction);
begin
  action:=cafree;
  frmthreadlist:=nil;
end;

procedure TfrmThreadlist.FormCreate(Sender: TObject);
begin
  fillthreadlist;
end;

procedure TFrmthreadlist.FillThreadlist;
var i: integer;
    lastselected: integer;
    threadlist: tlist;
    li: TListitem;

    ths: THandle;
    te32: TThreadEntry32;
begin
  if threadTreeview.Selected<>nil then
    lastselected:=threadTreeview.selected.index
  else
    lastselected:=-1;

  threadTreeview.BeginUpdate;
  threadTreeview.Items.Clear;

  if debuggerthread<>nil then
  begin
    threadlist:=debuggerthread.lockThreadlist;
    try
      for i:=0 to threadlist.Count-1 do
        threadTreeview.Items.Add(nil,inttohex(TDebugThreadHandler(threadlist[i]).ThreadId,1));

    finally
      debuggerthread.unlockThreadlist;
    end;
  end
  else
  begin
    //get the list using thread32first/next
    ths:=CreateToolhelp32Snapshot(TH32CS_SNAPTHREAD,0);
    if ths<>INVALID_HANDLE_VALUE then
    begin
      zeromemory(@te32,sizeof(te32));
      te32.dwSize:=sizeof(te32);
      if Thread32First(ths, te32) then
      repeat
        if te32.th32OwnerProcessID=processid then
          threadTreeview.Items.add(nil,inttohex(te32.th32ThreadID,1));

      until Thread32Next(ths, te32)=false;
      closehandle(ths);
    end;
  end;

  for i:=0 to threadTreeview.Items.Count-1 do
    threadTreeview.Items[i].HasChildren:=true;

  if (lastselected<>-1) and (threadTreeview.Items.Count>lastselected) then
    threadTreeview.Items[lastselected].Selected:=true;

  threadTreeview.EndUpdate;
end;

procedure TfrmThreadlist.miBreakClick(Sender: TObject);
var threadlist: tlist;
i: integer;
begin
  if debuggerthread<>nil then
  begin
    if (threadTreeview.Selected<>nil) and (threadTreeview.selected.Level=0) then
    begin
      threadlist:=debuggerthread.lockThreadlist;
      try
        for i:=0 to threadlist.Count-1 do
        begin
          if TDebugThreadHandler(threadlist[i]).ThreadId=strtoint('$'+threadTreeview.selected.Text) then
          begin
            TDebugThreadHandler(threadlist[i]).breakThread;
            break;
          end;
        end;
      finally
        debuggerthread.unlockThreadlist;
      end;

    end;

  end
  else
    raise exception.create(rsPleaseFirstAttachTheDebuggerToThisProcess);

end;

procedure TfrmThreadlist.miClearDebugRegistersClick(Sender: TObject);
var threadlist: tlist;
i,j: integer;
s: ttreenode;
begin
  if debuggerthread<>nil then
  begin
    for j:=0 to threadTreeview.SelectionCount-1 do
    begin
      s:=threadTreeview.Selections[j];

      // if (threadTreeview.Selected<>nil) then
      begin
        //s:=threadTreeview.Selected;
        while s.level>0 do
          s:=s.parent;


        threadlist:=debuggerthread.lockThreadlist;
        try
          for i:=0 to threadlist.Count-1 do
          begin
            if TDebugThreadHandler(threadlist[i]).ThreadId=strtoint('$'+s.Text) then
            begin
              TDebugThreadHandler(threadlist[i]).clearDebugRegisters;
              break;
            end;
          end;
        finally
          debuggerthread.unlockThreadlist;
        end;
      end;

    end;

  end
  else
    raise exception.create(rsPleaseFirstAttachTheDebuggerToThisProcess);
end;

procedure TfrmThreadlist.miFreezeThreadClick(Sender: TObject);
var
  i: integer;
  s: TTreeNode;
  threadlist: tlist;

  tid: dword;
  th: THandle;
begin
  s:=threadTreeview.Selected;
  if s<>nil then
  begin

    while s.level>0 do
      s:=s.Parent;

    tid:=strtoint('$'+s.Text);

    if debuggerthread<>nil then
    begin
      threadlist:=debuggerthread.lockThreadlist;
      try
        for i:=0 to threadlist.Count-1 do
        begin
          if TDebugThreadHandler(threadlist[i]).ThreadId=tid then
          begin
            SuspendThread(TDebugThreadHandler(threadlist[i]).handle);
            break;
          end;
        end;
      finally
        debuggerthread.unlockThreadlist;
      end;
    end
    else
    begin
      th:=OpenThread(THREAD_SUSPEND_RESUME, false, tid);

      if th<>0 then
      begin
        SuspendThread(th);
        closehandle(th);
      end;
    end;

  end;
end;

procedure TfrmThreadlist.miResumeThreadClick(Sender: TObject);
var
  i: integer;
  s: TTreeNode;
  threadlist: tlist;

  tid: dword;
  th: Thandle;
begin
  s:=threadTreeview.Selected;
  if s<>nil then
  begin

    while s.level>0 do
      s:=s.Parent;

    tid:=strtoint('$'+s.Text);

    if debuggerthread<>nil then
    begin
      threadlist:=debuggerthread.lockThreadlist;
      try
        for i:=0 to threadlist.Count-1 do
        begin
          if TDebugThreadHandler(threadlist[i]).ThreadId=tid then
          begin
            SuspendThread(TDebugThreadHandler(threadlist[i]).handle);
            break;
          end;
        end;
      finally
        debuggerthread.unlockThreadlist;
      end;
    end
    else
    begin
      th:=OpenThread(THREAD_SUSPEND_RESUME, false, tid);

      if th<>0 then
      begin
        ResumeThread(th);
        closehandle(th);
      end;
    end;

  end;
end;

procedure TfrmThreadlist.threadTreeviewDblClick(Sender: TObject);
var s: TTreeNode;
  th: thandle;
  c: tcontext;

  regnr: integer;

  regaddress: PPtrUInt;

  v: ptruint;

  input: string;
  tid: dword;

  ai: integer;
  x: boolean;
begin
  //change the selected register


  s:=threadTreeview.Selected;
  if (s<>nil) and (s.level=1) then //selected a registers
  begin
    regnr:=s.Index;
    ai:=s.AbsoluteIndex;

    while s.level>0 do
      s:=s.Parent;

    tid:=strtoint('$'+s.Text);




    th:=OpenThread(THREAD_SUSPEND_RESUME or THREAD_GET_CONTEXT or THREAD_SET_CONTEXT or THREAD_QUERY_INFORMATION, false, tid);

    if th<>0 then
    begin
      suspendthread(th);

      ZeroMemory(@c, sizeof(c));
      c.ContextFlags:=CONTEXT_ALL or CONTEXT_EXTENDED_REGISTERS;
      if GetThreadContext(th, c) then
      begin
        case regnr of
          0: regaddress:=@c.Dr0;
          1: regaddress:=@c.Dr1;
          2: regaddress:=@c.Dr2;
          3: regaddress:=@c.Dr3;
          4: regaddress:=@c.Dr6;
          5: regaddress:=@c.Dr7;

          6: regaddress:=@c.{$ifdef cpu64}rax{$else}eax{$endif};
          7: regaddress:=@c.{$ifdef cpu64}rbx{$else}ebx{$endif};
          8: regaddress:=@c.{$ifdef cpu64}rcx{$else}ecx{$endif};
          9: regaddress:=@c.{$ifdef cpu64}rdx{$else}edx{$endif};
          10: regaddress:=@c.{$ifdef cpu64}rsi{$else}esi{$endif};
          11: regaddress:=@c.{$ifdef cpu64}rdi{$else}edi{$endif};
          12: regaddress:=@c.{$ifdef cpu64}rbp{$else}ebp{$endif};
          13: regaddress:=@c.{$ifdef cpu64}rsp{$else}esp{$endif};
          14: regaddress:=@c.{$ifdef cpu64}rip{$else}eip{$endif};

          {$ifdef cpu64}
          15: regaddress:=@c.r8;
          16: regaddress:=@c.r9;
          17: regaddress:=@c.r10;
          18: regaddress:=@c.r11;
          19: regaddress:=@c.r12;
          20: regaddress:=@c.r13;
          21: regaddress:=@c.r14;
          22: regaddress:=@c.r15;
          {$endif}
        end;

        if processhandler.is64Bit then
          v:=regaddress^
        else
          v:=pdword(regaddress)^;

        input:=inttohex(v,8);
        InputQuery('Change value','What should the new value of this register be?', input);

        v:=StrToQWordEx('$'+input);

        if processhandler.is64Bit then
          regaddress^:=v
        else
          pdword(regaddress)^:=v;

        c.ContextFlags:=CONTEXT_ALL or CONTEXT_EXTENDED_REGISTERS;
        if SetThreadContext(th, c)=false then
          showmessage('failed. Errorcode='+inttostr(GetLastError));
      end;

      resumethread(th);
      closehandle(th);



      threadTreeviewExpanding(threadTreeview, s,x);


      threadTreeview.Items.SelectOnlyThis(threadTreeview.Items[ai]);
      threadTreeview.Selected:=threadTreeview.Items[ai];



    end;


  end;




  //suspend the thread
  //get the current register value
  //show and edit
  //convert back to integer
  //resume thread

end;

procedure TfrmThreadlist.threadTreeviewExpanding(Sender: TObject;
  Node: TTreeNode; var AllowExpansion: Boolean);
var tid: dword;
th: thandle;
c: TContext;
prefix: char;
begin
  if node.level=0 then
  begin
    //extract thread info
    if node.HasChildren then
      Node.DeleteChildren;

    tid:=strtoint('$'+Node.text);
    th:=OpenThread(THREAD_QUERY_INFORMATION or THREAD_GET_CONTEXT, false, tid);
    if th<>0 then
    begin
      zeromemory(@c,SizeOf(c));
      c.ContextFlags:=CONTEXT_ALL or CONTEXT_EXTENDED_REGISTERS;
      if GetThreadContext(th, c) then
      begin
        threadTreeview.items.AddChild(node,'dr0='+inttohex(c.Dr0,{$ifdef cpu64}16{$else}8{$endif}));
        threadTreeview.items.AddChild(node,'dr1='+inttohex(c.Dr1,{$ifdef cpu64}16{$else}8{$endif}));
        threadTreeview.items.AddChild(node,'dr2='+inttohex(c.Dr2,{$ifdef cpu64}16{$else}8{$endif}));
        threadTreeview.items.AddChild(node,'dr3='+inttohex(c.Dr3,{$ifdef cpu64}16{$else}8{$endif}));
        threadTreeview.items.AddChild(node,'dr6='+inttohex(c.Dr6,{$ifdef cpu64}16{$else}8{$endif}));
        threadTreeview.items.AddChild(node,'dr7='+inttohex(c.Dr7,{$ifdef cpu64}16{$else}8{$endif}));

        if processhandler.is64Bit then
          prefix:='r'
        else
          prefix:='e';

        threadTreeview.items.AddChild(node,prefix+'ax='+inttohex(c.{$ifdef cpu64}rax{$else}eax{$endif},8));
        threadTreeview.items.AddChild(node,prefix+'bx='+inttohex(c.{$ifdef cpu64}rbx{$else}ebx{$endif},8));
        threadTreeview.items.AddChild(node,prefix+'cx='+inttohex(c.{$ifdef cpu64}rcx{$else}ecx{$endif},8));
        threadTreeview.items.AddChild(node,prefix+'dx='+inttohex(c.{$ifdef cpu64}rdx{$else}edx{$endif},8));
        threadTreeview.items.AddChild(node,prefix+'si='+inttohex(c.{$ifdef cpu64}rsi{$else}esi{$endif},8));
        threadTreeview.items.AddChild(node,prefix+'di='+inttohex(c.{$ifdef cpu64}rdi{$else}edi{$endif},8));
        threadTreeview.items.AddChild(node,prefix+'bp='+inttohex(c.{$ifdef cpu64}rbp{$else}ebp{$endif},8));
        threadTreeview.items.AddChild(node,prefix+'sp='+inttohex(c.{$ifdef cpu64}rsp{$else}esp{$endif},8));
        threadTreeview.items.AddChild(node,prefix+'ip='+inttohex(c.{$ifdef cpu64}rip{$else}eip{$endif},8));

        {$ifdef cpu64}
        if processhandler.is64bit then
        begin
          threadTreeview.items.AddChild(node,'r8='+inttohex(c.r8,8));
          threadTreeview.items.AddChild(node,'r9='+inttohex(c.r9,8));
          threadTreeview.items.AddChild(node,'r10='+inttohex(c.r10,8));
          threadTreeview.items.AddChild(node,'r11='+inttohex(c.r11,8));
          threadTreeview.items.AddChild(node,'r12='+inttohex(c.r12,8));
          threadTreeview.items.AddChild(node,'r13='+inttohex(c.r13,8));
          threadTreeview.items.AddChild(node,'r14='+inttohex(c.r14,8));
          threadTreeview.items.AddChild(node,'r15='+inttohex(c.r15,8));
        end;
        {$endif}
      end
      else threadTreeview.items.AddChild(node, rsCouldnTObtainContext);
      closehandle(th);
    end else
      threadTreeview.items.AddChild(node, rsCouldnTOpenHandle);

    AllowExpansion:=true;
  end
  else
    AllowExpansion:=false;
end;

initialization
  {$i frmThreadlistunit.lrs}

end.
