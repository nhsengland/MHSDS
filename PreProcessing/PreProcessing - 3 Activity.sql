
DECLARE @EndRP INT
DECLARE @ReportingPeriodEnd DATE

SET @EndRP = (SELECT UniqMonthID
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_MostRecentFlag = 'Y')

SET @ReportingPeriodEnd = (SELECT ReportingPeriodEndDate FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] WHERE UniqMonthID = @EndRP)

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
ACTIVITY - DELETE PRIMARY DATA FROM LAST MONTH
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Delete Primary Data Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DELETE DATA

DELETE FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity] WHERE UniqMonthID = @EndRP

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Delete Primary Data End' AS Step,
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
	'DIRECT' AS [Der_ActivityType],
	c.MHS201UniqID AS [Der_ActivityUniqID],
	c.[Person_ID],
	c.[UniqMonthID],
	c.[OrgIDProv],
	c.[RecordNumber],
	c.[UniqServReqID],
	c.[OrgIDComm],
	c.[CareContDate] AS Der_ContactDate,
	c.[CareContTime] AS Der_ContactTime,
	c.[AdminCatCode],
	c.[SpecialisedMHServiceCode],
	c.[ClinContDurOfCareCont] AS Der_ContactDuration,
	c.[ConsType],
	c.[CareContSubj],
	c.[ConsMediumUsed],
	c.[ActLocTypeCode],
	c.[SiteIDOfTreat],
	c.[GroupTherapyInd],
	c.[AttendOrDNACode],
	c.[EarliestReasonOfferDate],
	c.[EarliestClinAppDate],
	c.[CareContCancelDate],
	c.[CareContCancelReas],
	c.[RepApptOfferDate],
	c.[RepApptBookDate],
	c.[UniqCareContID],
	c.[AgeCareContDate],
	c.[ContLocDistanceHome],
	c.[TimeReferAndCareContact],
	c.[UniqCareProfTeamID] AS Der_UniqCareProfTeamID,
	c.[PlaceOfSafetyInd],
	NULL AS Der_ContactOrder,
	NULL AS Der_DirectContactOrder,
	NULL AS Der_FacetoFaceContactOrder

FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS201CareContact] c

WHERE c.UniqMonthID >= @EndRP AND c.Der_Use_Submission_Flag = 'Y' 

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity]

SELECT
	'INDIRECT' AS [Der_ActivityType],
	i.MHS204UniqID AS [Der_ActivityUniqID],
	i.[Person_ID],
	i.[UniqMonthID],
	i.[OrgIDProv],
	i.[RecordNumber],
	i.[UniqServReqID],
	i.[OrgIDComm],
	i.IndirectActDate AS Der_ContactDate,
	i.IndirectActTime AS Der_ContactTime,
	NULL AS AdminCatCode,
	NULL AS SpecialisedMHServiceCode,
	i.DurationIndirectAct AS Der_ContactDuration,
	NULL AS ConsType,
	NULL AS CareContSubj,
	NULL AS ConsMediumUsed,
	NULL AS ActLocTypeCode,
	NULL AS SiteIDOfTreat,
	NULL AS GroupTherapyInd,
	NULL AS AttendOrDNACode,
	NULL AS EarliestReasonOfferDate,
	NULL AS EarliestClinAppDate,
	NULL AS CareContCancelDate,
	NULL AS CareContCancelReas,
	NULL AS RepApptOfferDate,
	NULL AS RepApptBookDate,
	NULL AS UniqCareContID,
	NULL AS AgeCareContDate,
	NULL AS ContLocDistanceHome,
	NULL AS TimeReferAndCareContact,
	i.OrgIDProv + i.CareProfTeamLocalId AS Der_UniqCareProfTeamID,
	NULL AS PlaceOfSafetyInd,
	NULL AS Der_ContactOrder,
	NULL AS Der_DirectContactOrder,
	NULL AS Der_FacetoFaceContactOrder

FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS204IndirectActivity] i

WHERE i.UniqMonthID >= @EndRP AND i.Der_Use_Submission_Flag = 'Y' 

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
	ROW_NUMBER() OVER (PARTITION BY a.Person_ID, a.UniqServReqID ORDER BY a.Der_ContactDate ASC, a.Der_ContactTime ASC, a.Der_ActivityUniqID ASC) AS Der_ContactOrder

INTO #ContOrder_Temp

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity] a  

WHERE (a.[Der_ActivityType] = 'DIRECT' AND a.AttendOrDNACode IN ('5','6') AND (a.ConsMediumUsed NOT IN ('05','06') OR OrgIDProv = 'DFC' AND a.ConsMediumUsed IN ('05','06'))) OR a.[Der_ActivityType] = 'INDIRECT'

---- ATTENDED DIRECT CONTACT ORDER 

SELECT 
	a.Der_RecordID, 
	ROW_NUMBER() OVER (PARTITION BY a.Person_ID, a.UniqServReqID ORDER BY a.Der_ContactDate ASC, a.Der_ContactTime ASC, a.Der_ActivityUniqID ASC) AS Der_DirectContactOrder

INTO #DirectOrder_Temp

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity] a  

WHERE a.[Der_ActivityType] = 'DIRECT' AND a.AttendOrDNACode IN ('5','6') AND a.ConsMediumUsed NOT IN ('05','06') 

--- DIRECT FACE TO FACE CONTACT ORDER 

SELECT 
	a.Der_RecordID,
	ROW_NUMBER() OVER (PARTITION BY a.Person_ID, a.UniqServReqID ORDER BY a.Der_ContactDate ASC, a.Der_ContactTime ASC, a.Der_ActivityUniqID ASC) AS Der_FacetoFaceContactOrder

INTO #F2F_Temp 

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity] a 

WHERE (a.[Der_ActivityType] = 'DIRECT' AND a.AttendOrDNACode IN ('5','6') AND a.ConsMediumUsed IN ('01', '03')) 

---- COMBINE TEMP TABLES
 
SELECT 
	a.Der_RecordID,
	a.Der_ContactOrder,
	b.Der_FacetoFaceContactOrder,
	c.Der_DirectContactOrder

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
	a.Der_DirectContactOrder = t.Der_DirectContactOrder,
	a.Der_FacetoFaceContactOrder = t.Der_FacetoFaceContactOrder
		
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity] a

LEFT JOIN #ActTemp t ON t.Der_RecordID = a.Der_RecordID

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

 --LOG START

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