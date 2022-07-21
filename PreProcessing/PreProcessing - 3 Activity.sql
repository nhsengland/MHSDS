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
ACTIVITY - DE-DUPLICATE MHS204							
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

SELECT
	i.[UniqSubmissionID],
	i.[NHSEUniqSubmissionID],
	i.[UniqMonthID],
	i.[OrgIDProv],
	i.[Der_Person_ID],
	i.[RecordNumber],
	i.[UniqServReqID],
	i.[OrgIDComm],
	i.[CareProfTeamLocalId],
	i.[IndirectActDate],
	i.[IndirectActTime],
	i.[DurationIndirectAct],
	i.[MHS204UniqID],
	ROW_NUMBER () OVER(PARTITION BY i.UniqServReqID, i.IndirectActDate, i.IndirectActTime ORDER BY i.MHS204UniqID DESC) AS Der_ActRN

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_PreProc_Indirect

FROM [NHSE_MH_PrePublication].[Test].[MHS204IndirectActivity] i

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
	CASE 
		WHEN c.AttendOrDNACode IN ('5','6') AND (c.[ConsMechanismMH] IN ('01', '02', '04', '11') 
		OR c.OrgIDProv = 'DFC' AND c.[ConsMechanismMH] IN ('05','09', '10', '13')) 
		THEN 1 ELSE NULL 
	END AS [Der_Contact],
	CASE 
		WHEN c.AttendOrDNACode IN ('5','6') AND c.[ConsMechanismMH] IN ('01', '02', '04', '11') 
		THEN 1 ELSE NULL 
	END AS [Der_DirectContact],
	CASE 
		WHEN c.AttendOrDNACode IN ('5','6') AND c.[ConsMechanismMH] IN ('01', '11') 
		THEN 1 ELSE NULL 
	END AS [Der_FacetoFaceContact]

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
	1 AS [Der_Contact],
	NULL AS [Der_DirectContact],
	NULL AS [Der_FacetoFaceContact]

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_PreProc_Indirect i

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON h.UniqMonthID = i.UniqMonthID

WHERE i.Der_ActRN = 1

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Insert End' AS Step,
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

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ACTIVITY - DROP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

-- LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Drop Tables Start' AS Step,
	GETDATE() AS [TimeStamp]

-- DROP TABLES

DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_PreProc_Indirect 


-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Activity Drop Tables End' AS Step,
	GETDATE() AS [TimeStamp]

END
