/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP ONE - UPDATE HEADER TABLE AND CHECK RECORD COUNTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
SET PERFORMANCE REPORTING PERIOD
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

DECLARE @EndRP INT
DECLARE @ReportingPeriodEnd DATE

SET @EndRP = (SELECT MAX(UniqMonthID)
FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS000Header]
WHERE FileType = 2)

SET @ReportingPeriodEnd = (SELECT MAX(ReportingPeriodEndDate) FROM NHSE_MH_PrePublication.dbo.V4_MHS000Header WHERE UniqMonthID = @EndRP) 

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UPDATE HEADER TABLE									
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]

SELECT DISTINCT
	h.UniqMonthID,
	h.ReportingPeriodStartDate,
	h.ReportingPeriodEndDate,
	NULL AS [Der_MostRecentFlag],
	NULL AS [Der_FYStart]

FROM NHSE_MH_PrePublication.dbo.V4_MHS000Header h

WHERE h.UniqMonthID = @EndRP +1

UPDATE [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] 
	SET [Der_MostRecentFlag] = CASE WHEN UniqMonthID = @EndRP THEN 'Y' WHEN UniqMonthID = @EndRP+1 THEN 'P' ELSE NULL END,
		[Der_FYStart] = CASE WHEN MONTH(ReportingPeriodStartDate) = 4 THEN 'Y' ELSE NULL END

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
RECORD COUNTS - DROP INDEXES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 
		
INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Record Counts Drop Index Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DROP INDEXES

DROP INDEX ix_RecordCounts ON [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts]

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Record Counts Drop Index End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
RECORD COUNTS - INSERT DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

--LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'MHSDS Record Counts Insert Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts]
	SELECT 'MHS000Header' AS [TableName], OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS000Header] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProvider, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS001MPI' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS001MPI] 	
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS002GP' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS002GP] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS003AccommStatus' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS003AccommStatus]	
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS004EmpStatus' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS004EmpStatus] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS005PatInd' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS005PatInd] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS006MHCareCoord' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS006MHCareCoord] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS007DisabilityType' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS007DisabilityType] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS008CarePlanType' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS008CarePlanType] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS009CarePlanAgreement' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS009CarePlanAgreement] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS010AssTechToSupportDisTyp' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS010AssTechToSupportDisTyp] WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS011SocPerCircumstances' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS011SocPerCircumstances] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS012OverseasVisitorChargCat' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS012OverseasVisitorChargCat] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS101Referral' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS101Referral] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS102ServiceTypeReferredTo' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS102ServiceTypeReferredTo] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS103OtherReasonReferral' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS103OtherReasonReferral] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS104RTT' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS104RTT] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS105OnwardReferral' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS105OnwardReferral] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS106DischargePlanAgreement' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS106DischargePlanAgreement]
	 WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS107MedicationPrescription' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS107MedicationPrescription] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS201CareContact' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS201CareContact] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS202CareActivity' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS202CareActivity] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS203OtherAttend' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS203OtherAttend] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS204IndirectActivity' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS204IndirectActivity] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS301GroupSession' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS301GroupSession] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS401MHActPeriod' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS401MHActPeriod] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS402RespClinicianAssignment' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS402RespClinicianAssignment] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS403ConditionalDischarge' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS403ConditionalDischarge] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS404CommTreatOrder' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS404CommTreatOrder] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts]
	SELECT 'MHS405CommTreatOrderRecall' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS405CommTreatOrderRecall] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS501HospProvSpell' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount]
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS501HospProvSpell] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS502WardStay' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS502WardStay] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts]
	SELECT 'MHS503AssignedCareProf' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS503AssignedCareProf] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS504DelayedDischarge' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS504DelayedDischarge] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS505RestrictiveIntervention' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS505RestrictiveIntervention] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS506Assault' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS506Assault] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS507SelfHarm' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS507SelfHarm] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS509HomeLeave' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS509HomeLeave] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS510LeaveOfAbsence' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS510LeaveOfAbsence] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS511AbsenceWithoutLeave' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS511AbsenceWithoutLeave] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS512HospSpellComm' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS512HospSpellComm] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS513SubstanceMisuse' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS513SubstanceMisuse] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS514TrialLeave' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS514TrialLeave] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS601MedHistPrevDiag' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS601MedHistPrevDiag] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS603ProvDiag' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS603ProvDiag] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS604PrimDiag' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS604PrimDiag] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS605SecDiag' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS605SecDiag] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS606CodedScoreAssessmentRefe' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS606CodedScoreAssessmentRefe] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS607CodedScoreAssessmentAct' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS607CodedScoreAssessmentAct] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS608AnonSelfAssess' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS608AnonSelfAssess] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS701CPACareEpisode' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS701CPACareEpisode] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS702CPAReview' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount]
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS702CPAReview] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS801ClusterTool' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS801ClusterTool]
	 WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS802ClusterAssess' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount]
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS802ClusterAssess] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS803CareCluster' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS803CareCluster] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS804FiveForensicPathways' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS804FiveForensicPathways] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS901StaffDetails' AS [TableName], OrgIDProv AS OrgIDProvider, UniqMonthID, MIN((@EndRP - UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS901StaffDetails] 
	WHERE UniqMonthID <> @EndRP OR (UniqMonthID = @EndRP AND Der_Use_Submission_Flag = 'Y')
	GROUP BY OrgIDProv, UniqMonthID

--LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'MHSDS Record Counts Insert End' AS Step,
	GETDATE() AS [TimeStamp]

-- CAN'T RESET INDEX UNTIL ALL PRE-PROC SCRIPTS FINISH, SO THIS IS INCLUDED AT THE END OF PREPROCESSING - 7 RECORD COUNTS