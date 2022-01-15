
DECLARE @EndRP INT
DECLARE @FYStart INT

SET @EndRP = (SELECT UniqMonthID
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_MostRecentFlag = 'Y')

SET @FYStart = (SELECT MAX(UniqMonthID)
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_FYStart = 'Y')

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP THREE - ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ACTIVITY - DROP EXISTING INDEXES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

--LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Drop Index Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DROP INDEXES

DROP INDEX ix_Activity ON [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity]

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Drop Index End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ACTIVITY - DELETE DATA THAT HAS BEEN SUPERCEDED BY OTHER DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Delete Data Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DELETE DATA

DELETE FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity] WHERE CONCAT(OrgIDProv,UniqMonthID) IN (SELECT CONCAT(OrgIDProvider,UniqMonthID) FROM NHSE_MH_PrePublication.Test.MHS000Header)

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Delete Data End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ACTIVITY - INSERT DATA FROM MHS201 AND MHS204							
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

--LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Insert Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity]

SELECT	
	-- header
	h.[ReportingPeriodStartDate],
	h.[ReportingPeriodEndDate],
	h.[Der_FY],
	-- core bits
	c.[UniqSubmissionID],
	c.[NHSEUniqSubmissionID],
	c.[UniqMonthID],
	c.[OrgIDProv],
	c.[Der_Person_ID] AS Person_ID,
	c.[RecordNumber],
	c.[UniqServReqID],
	-- contacts
	c.[UniqCareContID],
	c.[OrgIDComm],
	c.[AdminCatCode],
	c.[SpecialisedMHServiceCode],
	c.[ConsType],
	c.[CareContSubj],
	c.[ConsMechanismMH] AS [ConsMediumUsed],
	c.[ActLocTypeCode],
	c.[PlaceOfSafetyInd],
	c.[SiteIDOfTreat],
	c.[ComPeriMHPartAssessOfferInd], -- new for v5
	c.[PlannedCareContIndicator], -- new for v5
	c.[CareContPatientTherMode], -- new for v5
	c.[AttendOrDNACode],
	c.[EarliestReasonOfferDate],
	c.[EarliestClinAppDate],
	c.[CareContCancelDate],
	c.[CareContCancelReas],
	c.[ReasonableAdjustmentMade], -- new for v5
	c.[AgeCareContDate],
	c.[ContLocDistanceHome],
	c.[TimeReferAndCareContact],
	-- derivations
	c.[UniqCareProfTeamID] AS [Der_UniqCareProfTeamID],
	c.[CareContDate] AS [Der_ContactDate],
	c.[CareContTime] AS [Der_ContactTime],
	c.[ClinContDurOfCareCont] AS [Der_ContactDuration],
	'DIRECT' AS [Der_ActivityType],
	c.[MHS201UniqID] AS [Der_ActivityUniqID],
	NULL AS [Der_ContactOrder],
	NULL AS [Der_FYContactOrder],
	NULL AS [Der_DirectContactOrder],
	NULL AS [Der_FYDirectContactOrder],
	NULL AS [Der_FacetoFaceContactOrder],
	NULL AS [Der_FYFacetoFaceContactOrder]

FROM [NHSE_MH_PrePublication].[Test].[MHS201CareContact] c

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON h.UniqMonthID = c.UniqMonthID

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity]

SELECT
	-- header
	h.[ReportingPeriodStartDate],
	h.[ReportingPeriodEndDate],
	h.[Der_FY],
	-- core bits
	i.[UniqSubmissionID],
	i.[NHSEUniqSubmissionID],
	i.[UniqMonthID],
	i.[OrgIDProv],
	i.[Der_Person_ID] AS Person_ID,
	i.[RecordNumber],
	i.[UniqServReqID],
	-- indirect activity
	NULL AS [UniqCareContID],
	i.[OrgIDComm],
	NULL AS [AdminCatCode],
	NULL AS [SpecialisedMHServiceCode],
	NULL AS [ConsType],
	NULL AS [CareContSubj],
	NULL AS [ConsMediumUsed],
	NULL AS [ActLocTypeCode],
	NULL AS [PlaceOfSafetyInd],
	NULL AS [SiteIDOfTreat],
	NULL AS [ComPeriMHPartAssessOfferInd],
	NULL AS [PlannedCareContIndicator],
	NULL AS [CareContPatientTherMode],
	NULL AS [AttendOrDNACode],
	NULL AS [EarliestReasonOfferDate],
	NULL AS [EarliestClinAppDate],
	NULL AS [CareContCancelDate],
	NULL AS [CareContCancelReas],
	NULL AS [ReasonableAdjustmentMade],
	NULL AS [AgeCareContDate],
	NULL AS [ContLocDistanceHome],
	NULL AS [TimeReferAndCareContact],
	-- derivations
	i.[OrgIDProv] + i.[CareProfTeamLocalId] AS [Der_UniqCareProfTeamID],
	i.[IndirectActDate] AS [Der_ContactDate],
	i.[IndirectActTime] AS [Der_ContactTime],
	i.[DurationIndirectAct] AS [Der_ContactDuration],
	'INDIRECT' AS [Der_ActivityType],
	i.[MHS204UniqID] AS [Der_ActivityUniqID],
	NULL AS [Der_ContactOrder],
	NULL AS [Der_FYContactOrder],
	NULL AS [Der_DirectContactOrder],
	NULL AS [Der_FYDirectContactOrder],
	NULL AS [Der_FacetoFaceContactOrder],
	NULL AS [Der_FYFacetoFaceContactOrder]

FROM [NHSE_MH_PrePublication].[Test].[MHS204IndirectActivity] i

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON h.UniqMonthID = i.UniqMonthID

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Insert End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ACTIVITY - BUILD DERIVATIONS					
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

 INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Derivations Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE

---- ATTENDED OR INDIRECT CONTACT ORDER 

SELECT 
	a.Der_RecordID, 
	ROW_NUMBER() OVER (PARTITION BY CASE WHEN a.OrgIDProv = 'DFC' THEN a.UniqServReqID ELSE a.Person_ID END, a.UniqServReqID ORDER BY a.Der_ContactDate ASC, a.Der_ContactTime ASC, a.Der_ActivityUniqID ASC) AS Der_ContactOrder,
	ROW_NUMBER() OVER (PARTITION BY CASE WHEN a.OrgIDProv = 'DFC' THEN a.UniqServReqID ELSE a.Person_ID END, a.UniqServReqID, a.Der_FY ORDER BY a.Der_ContactDate ASC, a.Der_ContactTime ASC, a.Der_ActivityUniqID ASC) AS Der_FYContactOrder

INTO #ContOrder_Temp

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity] a  

WHERE a.UniqMonthID < 1459 AND ((a.[Der_ActivityType] = 'DIRECT' AND a.AttendOrDNACode IN ('5','6') AND (a.ConsMediumUsed NOT IN ('05','06') OR OrgIDProv = 'DFC' AND a.ConsMediumUsed IN ('05','06'))) OR a.[Der_ActivityType] = 'INDIRECT') OR
	a.UniqMonthID >= 1459 AND ((a.[Der_ActivityType] = 'DIRECT' AND a.AttendOrDNACode IN ('5','6') AND (a.ConsMediumUsed IN ('01', '02', '04', '11') OR OrgIDProv = 'DFC' AND a.ConsMediumUsed IN ('05','09', '10', '13'))) OR a.[Der_ActivityType] = 'INDIRECT')

---- ATTENDED DIRECT CONTACT ORDER 

SELECT 
	a.Der_RecordID, 
	ROW_NUMBER() OVER (PARTITION BY CASE WHEN a.OrgIDProv = 'DFC' THEN a.UniqServReqID ELSE a.Person_ID END, a.UniqServReqID ORDER BY a.Der_ContactDate ASC, a.Der_ContactTime ASC, a.Der_ActivityUniqID ASC) AS Der_DirectContactOrder,
	ROW_NUMBER() OVER (PARTITION BY CASE WHEN a.OrgIDProv = 'DFC' THEN a.UniqServReqID ELSE a.Person_ID END, a.UniqServReqID, a.Der_FY ORDER BY a.Der_ContactDate ASC, a.Der_ContactTime ASC, a.Der_ActivityUniqID ASC) AS Der_FYDirectContactOrder

INTO #DirectOrder_Temp

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity] a  

WHERE a.[Der_ActivityType] = 'DIRECT' AND a.AttendOrDNACode IN ('5','6') AND (a.UniqMonthID < 1459 AND a.ConsMediumUsed NOT IN ('05','06') OR a.UniqMonthID >= 1459 AND a.ConsMediumUsed IN ('01', '02', '04', '11'))

--- DIRECT FACE TO FACE CONTACT ORDER 

SELECT 
	a.Der_RecordID,
	ROW_NUMBER() OVER (PARTITION BY CASE WHEN a.OrgIDProv = 'DFC' THEN a.UniqServReqID ELSE a.Person_ID END, a.UniqServReqID ORDER BY a.Der_ContactDate ASC, a.Der_ContactTime ASC, a.Der_ActivityUniqID ASC) AS Der_FacetoFaceContactOrder,
	ROW_NUMBER() OVER (PARTITION BY CASE WHEN a.OrgIDProv = 'DFC' THEN a.UniqServReqID ELSE a.Person_ID END, a.UniqServReqID, a.Der_FY ORDER BY a.Der_ContactDate ASC, a.Der_ContactTime ASC, a.Der_ActivityUniqID ASC) AS Der_FYFacetoFaceContactOrder

INTO #F2F_Temp 

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity] a 

WHERE a.[Der_ActivityType] = 'DIRECT' AND a.AttendOrDNACode IN ('5','6') AND (a.UniqMonthID < 1459 AND a.ConsMediumUsed IN ('01', '03') OR a.UniqMonthID >= 1459 AND a.ConsMediumUsed IN ('01', '11')) 

---- COMBINE TEMP TABLES
 
SELECT 
	a.Der_RecordID,
	a.Der_ContactOrder,
	a.Der_FYContactOrder,
	b.Der_FacetoFaceContactOrder,
	b.Der_FYFacetoFaceContactOrder,
	c.Der_DirectContactOrder,
	c.Der_FYDirectContactOrder

INTO #ActTemp

FROM #ContOrder_Temp a 

LEFT JOIN #F2F_Temp b ON a.Der_RecordID = b.Der_RecordID

LEFT JOIN #DirectOrder_Temp c ON a.Der_RecordID = c.Der_RecordID 

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Derivations End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ACTIVITY - UPDATE DERIVATIONS					
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

 INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Update Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE

UPDATE a

SET 
	a.Der_ContactOrder = t.Der_ContactOrder,
	a.Der_FYContactOrder = t.Der_FYContactOrder,
	a.Der_DirectContactOrder = t.Der_DirectContactOrder,
	a.Der_FYDirectContactOrder = t.Der_FYDirectContactOrder,
	a.Der_FacetoFaceContactOrder = t.Der_FacetoFaceContactOrder,
	a.Der_FYFacetoFaceContactOrder = t.Der_FYFacetoFaceContactOrder
		
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity] a

LEFT JOIN #ActTemp t ON t.Der_RecordID = a.Der_RecordID

WHERE a.UniqMonthID >= @FYStart

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Update End' AS Step,
	GETDATE() AS [TimeStamp]
	
WAITFOR DELAY '00:00:01'	
	
/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ACTIVITY - RECREATE INDEXES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

-- LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Create Index Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - CREATE INDEXES

CREATE INDEX ix_Activity ON [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity] ([UniqMonthID], [RecordNumber], [OrgIDProv], [Person_ID], [UniqServReqID])

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Create Index End' AS Step,
	GETDATE() AS [TimeStamp]
