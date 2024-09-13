/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP ONE - UPDATE HEADER TABLE AND CHECK RECORD COUNTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
SET PERFORMANCE REPORTING PERIOD
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

DECLARE @EndRP INT
DECLARE @ReportingPeriodEnd DATE

SET @EndRP = (SELECT MAX(UniqMonthID)
FROM [NHSE_MH_PrePublication].[Test].[MHS000Header]
WHERE FileType = 2)

SET @ReportingPeriodEnd = (SELECT MAX(ReportingPeriodEndDate) FROM [NHSE_MH_PrePublication].[Test].[MHS000Header] WHERE UniqMonthID = @EndRP) 

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UPDATE HEADER TABLE									
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]

SELECT DISTINCT
	h.UniqMonthID,
	h.ReportingPeriodStartDate,
	h.ReportingPeriodEndDate,
	NULL AS [Der_MostRecentFlag],
	NULL AS [Der_FYStart],
	NULL AS [Der_FY]

FROM [NHSE_MH_PrePublication].[Test].[MHS000Header] h

WHERE h.UniqMonthID = @EndRP +1

UPDATE h 
	SET [Der_MostRecentFlag] = CASE WHEN h.UniqMonthID = @EndRP THEN 'Y' WHEN h.UniqMonthID = @EndRP+1 THEN 'P' ELSE NULL END,
		[Der_FYStart] = CASE WHEN MONTH(h.ReportingPeriodStartDate) = 4 THEN 'Y' ELSE NULL END,
		[Der_FY] = d.[FinYear_YY_YY]

	FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] h 
	
	INNER JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_Dates] d ON h.UniqMonthID = d.CMHT_MonthID


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

--/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
--RECORD COUNTS - INSERT DATA
-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

----LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'MHSDS Record Counts Insert Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts]
	SELECT 'MHS000Header' AS [TableName], h.OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS000Header] h
	GROUP BY h.OrgIDProvider, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS001MPI' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS001MPI] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS002GP' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS002GP] h
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS003AccommStatus' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS003AccommStatus] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS004EmpStatus' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS004EmpStatus] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS005PatInd' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS005PatInd] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS006MHCareCoord' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS006MHCareCoord] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS007DisabilityType' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS007DisabilityType] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS008CarePlanType' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS008CarePlanType] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS009CarePlanAgreement' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS009CarePlanAgreement] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS010AssTechToSupportDisTyp' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS010AssTechToSupportDisTyp] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS011SocPerCircumstances' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS011SocPerCircumstances] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS012OverseasVisitorChargCat' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS012OverseasVisitorChargCat] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS101Referral' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS101Referral] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS102ServiceTypeReferredTo' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS102ServiceTypeReferredTo] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS103OtherReasonReferral' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS103OtherReasonReferral] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS104RTT' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS104RTT] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS105OnwardReferral' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS105OnwardReferral] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS106DischargePlanAgreement' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS106DischargePlanAgreement] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS107MedicationPrescription' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS107MedicationPrescription] h
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS201CareContact' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS201CareContact] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS202CareActivity' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS202CareActivity] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS203OtherAttend' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS203OtherAttend] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS204IndirectActivity' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS204IndirectActivity] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS301GroupSession' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS301GroupSession] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS302MHDropInContact' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS302MHDropInContact] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS401MHActPeriod' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS401MHActPeriod] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS402RespClinicianAssignment' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS402RespClinicianAssignment] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS403ConditionalDischarge' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS403ConditionalDischarge] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS404CommTreatOrder' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS404CommTreatOrder] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts]
	SELECT 'MHS405CommTreatOrderRecall' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS405CommTreatOrderRecall] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS501HospProvSpell' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount]
	FROM [NHSE_MH_PrePublication].[Test].[MHS501HospProvSpell] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS502WardStay' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS502WardStay] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts]
	SELECT 'MHS503AssignedCareProf' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS503AssignedCareProf] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS504DelayedDischarge' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS504DelayedDischarge] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS505RestrictiveInterventionInc' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS505RestrictiveInterventInc] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS506Assault' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS506Assault] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS507SelfHarm' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS507SelfHarm] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS509HomeLeave' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS509HomeLeave] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS510LeaveOfAbsence' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS510LeaveOfAbsence] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS511AbsenceWithoutLeave' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS511AbsenceWithoutLeave] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS512HospSpellComm' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS512HospSpellComm] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS513SubstanceMisuse' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS513SubstanceMisuse] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS514TrialLeave' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS514TrialLeave] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS515RestrictiveInterventType' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS515RestrictiveInterventType] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS516PoliceAssistanceRequest' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS516PoliceAssistanceRequest] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS517SMHExceptionalPackOfCare' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS517SMHExceptionalPackOfCare] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS601MedHistPrevDiag' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS601MedHistPrevDiag] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS603ProvDiag' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS603ProvDiag] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS604PrimDiag' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS604PrimDiag] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS605SecDiag' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS605SecDiag] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS606CodedScoreAssessmentRefe' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS606CodedScoreAssessmentRefer] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS607CodedScoreAssessmentAct' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS607CodedScoreAssessmentAct] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS608AnonSelfAssess' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS608AnonSelfAssess] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS701CPACareEpisode' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS701CPACareEpisode] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS702CPAReview' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount]
	FROM [NHSE_MH_PrePublication].[Test].[MHS702CPAReview] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS801ClusterTool' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS801ClusterTool] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS802ClusterAssess' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount]
	FROM [NHSE_MH_PrePublication].[Test].[MHS802ClusterAssess] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS803CareCluster' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS803CareCluster] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS804FiveForensicPathways' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS804FiveForensicPathways] h	
	GROUP BY OrgIDProv, h.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'MHS901StaffDetails' AS [TableName], OrgIDProv AS OrgIDProvider, h.UniqMonthID, MIN((@EndRP - h.UniqMonthID) +2) AS SubmissionType, COUNT(*) AS [RecordCount] 
	FROM [NHSE_MH_PrePublication].[Test].[MHS901StaffDetails] h	
	GROUP BY OrgIDProv, h.UniqMonthID

-- GET DATA FROM PREVIOUS PRIMARY SUBMISSIONS WHERE THERE WAS NO 'PERFORMANCE' SUBMISSION

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT r.[TableName], r.[OrgIDProvider], r.[UniqMonthID], 2 AS SubmissionType, [RecordCount] 
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] r
	INNER JOIN NHSE_MH_PrePublication.Test.MHSDS_SubmissionFlags m ON m.OrgIDProvider = r.OrgIDProvider AND m.UniqMonthID = r.UniqMonthID AND m.FileType = 1 AND m.Der_IsLatest = 'Y'
	WHERE r.UniqMonthID = @EndRP

--LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'MHSDS Record Counts Insert End' AS Step,
	GETDATE() AS [TimeStamp]

-- CAN'T RESET INDEX UNTIL ALL PRE-PROC SCRIPTS FINISH, SO THIS IS INCLUDED AT THE END OF PREPROCESSING - 7 RECORD COUNTS

SELECT [TableName]
      ,[UniqMonthID]
      ,[SubmissionType]
      ,SUM([RecordCount])
  FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts]

  WHERE SubmissionType <> 'PreProc'

  GROUP BY  [TableName]
      ,[UniqMonthID]
      ,[SubmissionType]
