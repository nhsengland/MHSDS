
DECLARE @EndRP INT
DECLARE @ReportingPeriodEnd DATE

SET @EndRP = (SELECT UniqMonthID
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_MostRecentFlag = 'Y')

SET @ReportingPeriodEnd = (SELECT ReportingPeriodEndDate FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] WHERE UniqMonthID = @EndRP)

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
INPATIENTS - DELETE PRIMARY DATA FROM LAST MONTH
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Inpatients Delete Primary Data Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DELETE DATA

DELETE FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Inpatients] WHERE UniqMonthID = @EndRP

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Inpatients Delete Primary Data End' AS Step,
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
	h.[MHS501UniqID],
	h.[Person_ID],
	h.[OrgIDProv],
	h.[UniqMonthID],
	h.[RecordNumber],
	h.[UniqHospProvSpellNum],
	h.[UniqServReqID],
	h.[StartDateHospProvSpell],
	h.[StartTimeHospProvSpell],
	h.[SourceAdmCodeHospProvSpell],
	h.[AdmMethCodeHospProvSpell],
	h.[EstimatedDischDateHospProvSpell],
	h.[PlannedDischDateHospProvSpell],
	h.[DischDateHospProvSpell],
	h.[DischTimeHospProvSpell],
	h.[DischMethCodeHospProvSpell],
	h.[DischDestCodeHospProvSpell],
	h.[InactTimeHPS],
	h.[PlannedDischDestCode],
	h.[PostcodeDistrictMainVisitor],
	h.[PostcodeDistrictDischDest],
	w.[MHS502UniqID],
	w.[UniqWardStayID],
	w.[StartDateWardStay],
	w.[StartTimeWardStay],
	w.[SiteIDOfTreat],
	w.[WardType],
	w.[WardSexTypeCode],
	w.[IntendClinCareIntenCodeMH],
	w.[WardSecLevel],
	w.[SpecialisedMHServiceCode],
	w.[WardCode],
	w.[WardLocDistanceHome],
	w.[LockedWardInd],
	w.[InactTimeWS],
	w.[WardAge],
	w.[HospitalBedTypeMH],
	w.[EndDateMHTrialLeave],
	w.[EndDateWardStay],
	w.[EndTimeWardStay],
	CASE WHEN h.DischDateHospProvSpell IS NOT NULL THEN 'CLOSED' ELSE 'OPEN' END AS Der_HospSpellStatus,
	NULL AS Der_HospSpellRecordOrder,
	NULL AS Der_FirstWardStayRecord,
	NULL AS Der_LastWardStayRecord,
	he.ReportingPeriodStartDate,
	he.ReportingPeriodEndDate,
	he.Der_FY
	
FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS501HospProvSpell] h

LEFT JOIN [NHSE_MH_PrePublication].[dbo].[V4_MHS502WardStay] w ON w.UniqServReqID = h.UniqServReqID AND w.UniqHospProvSpellNum = h.UniqHospProvSpellNum AND w.RecordNumber = h.RecordNumber

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header he ON he.UniqMonthID = h.UniqMonthID

WHERE h.UniqMonthID >= @EndRP AND h.Der_Use_Submission_Flag = 'Y' 

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
	ROW_NUMBER () OVER(PARTITION BY i.Person_ID, i.UniqServReqID, i.UniqHospProvSpellNum ORDER BY i.UniqMonthID DESC, i.InactTimeWS DESC, i.EndDateWardStay DESC, i.MHS502UniqID DESC) AS Der_FirstWardStayRecord,
	ROW_NUMBER () OVER(PARTITION BY i.Person_ID, i.UniqServReqID, i.UniqHospProvSpellNum ORDER BY i.UniqMonthID ASC, i.InactTimeWS ASC, i.EndDateWardStay ASC, i.MHS502UniqID ASC) AS Der_LastWardStayRecord

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
