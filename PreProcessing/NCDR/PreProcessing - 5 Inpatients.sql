
DECLARE @EndRP INT

SET @EndRP = (SELECT UniqMonthID
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_MostRecentFlag = 'Y')

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP FIVE - INPATIENTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
INPATIENTS - DROP EXISTING INDEXES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

--LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Inpatients Drop Index Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DROP INDEXES

DROP INDEX ix_Inpatient ON [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Inpatients]

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Inpatients Drop Index End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
INPATIENTS - DELETE DATA THAT HAS BEEN SUPERCEDED BY OTHER DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Inpatients Delete Data Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DELETE DATA

DELETE FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Inpatients] WHERE CONCAT(OrgIDProv,UniqMonthID) IN (SELECT CONCAT(OrgIDProvider,UniqMonthID) FROM NHSE_MH_PrePublication.Test.MHS000Header)

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Inpatients Delete Data End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
INPATIENTS - JOIN MHS501, MHS502							
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

-- LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Inpatients Insert Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Inpatients]

SELECT
	-- core bits
	he.[ReportingPeriodStartDate],
	he.[ReportingPeriodEndDate],
	he.[Der_FY],
	h.[UniqSubmissionID],
	h.[NHSEUniqSubmissionID],
	h.[UniqMonthID],
	h.[OrgIDProv],
	h.[Der_Person_ID] AS Person_ID,
	h.[RecordNumber],
	-- hospital spell
	h.[MHS501UniqID],
	h.[UniqHospProvSpellID] AS [UniqHospProvSpellNum], --new for v5
	h.[UniqServReqID],
	NULL AS [DecidedToAdmitDate], --new for v5
	NULL AS [DecidedToAdmitTime], --new for v5
	h.[StartDateHospProvSpell],
	h.[StartTimeHospProvSpell],
	h.[SourceAdmMHHospProvSpell] AS [SourceAdmCodeHospProvSpell], --new for v5
	h.[MethAdmMHHospProvSpell] AS [AdmMethCodeHospProvSpell], --new for v5
	h.[EstimatedDischDateHospProvSpell],
	h.[PlannedDischDateHospProvSpell],
	h.[PlannedDestDisch] AS [PlannedDischDestCode],
	h.[DischDateHospProvSpell],
	h.[DischTimeHospProvSpell],
	h.[MethOfDischMHHospProvSpell] AS [DischMethCodeHospProvSpell], --new for v5
	h.[DestOfDischHospProvSpell] AS [DischDestCodeHospProvSpell], --new for v5
	h.[PostcodeDistrictMainVisitor],
	h.[PostcodeDistrictDischDest],
	-- ward stays
	w.[MHS502UniqID],
	w.[UniqWardStayID],
	w.[StartDateWardStay],
	w.[StartTimeWardStay],
	w.[EndDateMHTrialLeave],
	w.[EndDateWardStay],
	w.[EndTimeWardStay],
	w.[SiteIDOfTreat],
	w.[WardType],
	w.[WardAge],
	w.[WardSexTypeCode],
	w.[IntendClinCareIntenCodeMH],
	w.[WardSecLevel],
	w.[LockedWardInd],
	w.[HospitalBedTypeMH],
	w.[SpecialisedMHServiceCode],
	w.[WardCode],
	w.[WardLocDistanceHome],
	CASE WHEN h.DischDateHospProvSpell IS NOT NULL THEN 'CLOSED' ELSE 'OPEN' END AS Der_HospSpellStatus,
	NULL AS Der_HospSpellRecordOrder,
	NULL AS Der_FirstWardStayRecord,
	NULL AS Der_LastWardStayRecord
	
FROM [NHSE_MH_PrePublication].[Test].[MHS501HospProvSpell] h

LEFT JOIN [NHSE_MH_PrePublication].[Test].[MHS502WardStay] w ON w.UniqServReqID = h.UniqServReqID 
AND w.UniqHospProvSpellID = h.UniqHospProvSpellID --new for v5
AND w.RecordNumber = h.RecordNumber

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header he ON he.UniqMonthID = h.UniqMonthID

 --LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Inpatients Insert End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
INPATIENTS - BUILD DERIVATIONS					
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

 INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Inpatients Derivations Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE

SELECT
	i.Der_RecordID,
	ROW_NUMBER () OVER(PARTITION BY i.Person_ID, i.UniqServReqID, i.UniqHospProvSpellNum ORDER BY i.UniqMonthID DESC) AS Der_HospSpellRecordOrder, 
	ROW_NUMBER () OVER(PARTITION BY i.Person_ID, i.UniqServReqID, i.UniqHospProvSpellNum ORDER BY i.UniqMonthID DESC, i.EndDateWardStay DESC, i.MHS502UniqID DESC) AS Der_LastWardStayRecord,
	ROW_NUMBER () OVER(PARTITION BY i.Person_ID, i.UniqServReqID, i.UniqHospProvSpellNum ORDER BY i.UniqMonthID ASC, i.EndDateWardStay ASC, i.MHS502UniqID ASC) AS Der_FirstWardStayRecord

INTO #InpatTemp

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Inpatients] i

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Inpatients Derivations End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
INPATIENTS - UPDATE DERIVATIONS					
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

 INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Inpatients Update Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE

UPDATE i

SET 
	i.Der_HospSpellRecordOrder = t.Der_HospSpellRecordOrder,
	i.Der_FirstWardStayRecord = t.Der_FirstWardStayRecord,
	i.Der_LastWardStayRecord = t.Der_LastWardStayRecord

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Inpatients] i

INNER JOIN #InpatTemp t ON t.Der_RecordID = i.Der_RecordID

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Inpatients Update End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
INPATIENTS - RECREATE INDEXES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Inpatients Create Index Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - CREATE INDEXES

CREATE INDEX ix_Inpatient ON [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Inpatients] ([UniqMonthID], [RecordNumber], [OrgIDProv], [Person_ID], [UniqServReqID])

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Inpatients Create Index End' AS Step,
	GETDATE() AS [TimeStamp]
