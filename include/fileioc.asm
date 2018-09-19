;-------------------------------------------------------------------------------
include '../include/library.inc'
;-------------------------------------------------------------------------------

library 'FILEIOC', 4

;-------------------------------------------------------------------------------
; no dependencies
;-------------------------------------------------------------------------------

;-------------------------------------------------------------------------------
; v1 functions
;-------------------------------------------------------------------------------
	export ti_CloseAll
	export ti_Open
	export ti_OpenVar
	export ti_Close
	export ti_Write
	export ti_Read
	export ti_GetC
	export ti_PutC
	export ti_Delete
	export ti_DeleteVar
	export ti_Seek
	export ti_Resize
	export ti_IsArchived
	export ti_SetArchiveStatus
	export ti_Tell
	export ti_Rewind
	export ti_GetSize
;-------------------------------------------------------------------------------
; v2 functions
;-------------------------------------------------------------------------------
	export ti_GetTokenString
	export ti_GetDataPtr
	export ti_Detect
	export ti_DetectVar
;-------------------------------------------------------------------------------
; v3 functions
;-------------------------------------------------------------------------------
	export ti_SetVar
	export ti_StoVar
	export ti_RclVar
	export ti_AllocString
	export ti_AllocList
	export ti_AllocMatrix
	export ti_AllocCplxList
	export ti_AllocEqu
;-------------------------------------------------------------------------------
; v4 functions
;-------------------------------------------------------------------------------
	export ti_DetectAny
	export ti_GetVATPtr
	export ti_GetName
	export ti_Rename
	export ti_RenameVar
