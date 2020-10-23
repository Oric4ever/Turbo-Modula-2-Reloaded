MODULE ED;
IMPORT Editor, EditPos;
BEGIN
  Editor.global17     := EditPos.global17;
  Editor.editPosition := EditPos.editPos;
  Editor.Edit;
  EditPos.global17    := Editor.global17;
  EditPos.editPos     := Editor.editPosition;
END ED.