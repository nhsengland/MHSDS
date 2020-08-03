
DECLARE @EndRP INT
DECLARE @ReportingPeriodStart DATE
DECLARE @ReportingPeriodEnd DATE

SET @EndRP = (SELECT UniqMonthID
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_MostRecentFlag = 'Y')

SET @ReportingPeriodStart = (SELECT ReportingPeriodStartDate FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] WHERE UniqMonthID = @EndRP) 

SET @ReportingPeriodEnd = (SELECT ReportingPeriodEndDate FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] WHERE UniqMonthID = @EndRP+1)

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP FOUR - ASSESSMENTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ASSESSMENTS - DROP EXISTING INDEXES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

-- LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments Drop Index Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DROP INDEXES

DROP INDEX ix_Assessment ON [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Assessments]

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments Drop Index End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ASSESSMENTS - DELETE PRIMARY DATA FROM LAST MONTH
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments Delete Primary Data Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DELETE DATA

DELETE FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Assessments] WHERE UniqMonthID = @EndRP

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Referral Delete Primary Data End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ASSESSMENTS - UNION MHS606, MHS607, MHS801							
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 -- LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessment Union Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE

SELECT
	'CON' AS Der_AssTable,
	a.[UniqMonthID],
	a.[CodedAssToolType],
	a.[PersScore],
	c.CareContDate AS Der_AssToolCompDate,
	a.[RecordNumber],
	a.[MHS607UniqID] AS Der_AssUniqID,
	a.[OrgIDProv],
	a.[Person_ID],
	a.[UniqServReqID],
	a.[AgeAssessToolCont] AS Der_AgeAssessTool,
	a.[UniqCareContID],
	a.[UniqCareActID]

INTO #Ass

FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS607CodedScoreAssessmentAct] a 

LEFT JOIN [NHSE_MH_PrePublication].[dbo].[V4_MHS201CareContact] c ON a.RecordNumber = c.RecordNumber AND a.UniqServReqID = c.UniqServReqID AND a.UniqCareContID = c.UniqCareContID

WHERE a.UniqMonthID >= @EndRP AND a.Der_Use_Submission_Flag = 'Y'  

INSERT INTO #Ass

SELECT
	'REF' AS Der_AssTable,
	r.[UniqMonthID],
	r.[CodedAssToolType],
	r.[PersScore],
	r.AssToolCompDate  AS Der_AssToolCompDate,
	r.[RecordNumber],
	r.[MHS606UniqID] AS Der_AssUniqID,
	r.[OrgIDProv],
	r.[Person_ID],
	r.[UniqServReqID],
	r.AgeAssessToolReferCompDate AS Der_AgeAssessTool,
	NULL AS [UniqCareContID],
	NULL AS [UniqCareActID]

FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS606CodedScoreAssessmentRefe] r 

WHERE r.UniqMonthID >= @EndRP AND r.Der_Use_Submission_Flag = 'Y'  

INSERT INTO #Ass

SELECT
	'CLU' AS Der_AssTable,
	c.[UniqMonthID],
	a.[CodedAssToolType],
	a.[PersScore],
	c.AssToolCompDate AS Der_AssToolCompDate,
	c.[RecordNumber],
	a.[MHS802UniqID] AS Der_AssUniqID,
	a.[OrgIDProv],
	a.[Person_ID],
	r.[UniqServReqID],
	NULL AS Der_AgeAssessTool,
	NULL AS [UniqCareContID],
	NULL AS [UniqCareActID]

FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS802ClusterAssess] a

LEFT JOIN [NHSE_MH_PrePublication].[dbo].[V4_MHS801ClusterTool] c ON c.UniqClustID = a.UniqClustID AND c.RecordNumber = a.RecordNumber

LEFT JOIN [NHSE_MH_PrePublication].[dbo].[V4_MHS101Referral] r ON r.RecordNumber = c.RecordNumber AND c.AssToolCompDate BETWEEN r.ReferralRequestReceivedDate AND ISNULL(r.ServDischDate,@ReportingPeriodEnd)

WHERE a.UniqMonthID >= @EndRP AND a.Der_Use_Submission_Flag = 'Y' AND c.AssToolCompDate BETWEEN @ReportingPeriodStart AND @ReportingPeriodEnd

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessment Union End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ASSESSMENTS - BUILD IN MONTH DERIVATIONS					
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

 INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessment In Month Derivations Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE

SELECT 	
	a.[Der_AssUniqID],
	a.[Der_AssTable], 
	a.[Person_ID],	
	a.[UniqMonthID],	
	a.[OrgIDProv],
	a.[RecordNumber],	
	a.[UniqServReqID],	
	a.[UniqCareContID],	
	a.[UniqCareActID],		
	a.Der_AssToolCompDate,
	a.[CodedAssToolType],
	a.[PersScore],
	a.Der_AgeAssessTool,
	r.Category AS Der_AssessmentCategory,
	r.[Assessment Tool Name] AS Der_AssessmentToolName,
	r.[Preferred Term (SNOMED-CT)] AS Der_PreferredTermSNOMED,
	r.[SNOMED Code Version] AS Der_SNOMEDCodeVersion,
	r.[Lower Range] AS Der_LowerRange,
	r.[Upper Range] AS Der_UpperRange,
	CASE 
		WHEN ISNUMERIC(a.PersScore) = 1 AND a.PersScore <> '-' AND a.PersScore BETWEEN r.[Lower Range] AND r.[Upper Range] THEN 'Y' 
		ELSE NULL 
	END AS Der_ValidScore,
	CASE 
		WHEN ROW_NUMBER () OVER (PARTITION BY a.Person_ID, a.Der_AssToolCompDate, ISNULL(a.UniqServReqID,0), r.[Preferred Term (SNOMED-CT)], a.PersScore ORDER BY a.Der_AssUniqID ASC) = 1
		THEN 'Y' 
		ELSE NULL 
	END AS Der_UniqAssessment

INTO #Ass2

FROM #Ass a

LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[Reference_MHAssessments] r ON a.CodedAssToolType = r.[Active Concept ID (SNOMED CT)] 

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessment In Month Derivations End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ASSESSMENTS - INSERT DATA				
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

 INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessment Insert Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Assessments]

SELECT 
	a.[Der_AssUniqID],	
	a.[Der_AssTable], 
	a.[Person_ID],	
	a.[UniqMonthID],	
	a.[OrgIDProv],
	a.[RecordNumber],	
	a.[UniqServReqID],	
	a.[UniqCareContID],	
	a.[UniqCareActID],		
	a.[Der_AssToolCompDate],
	a.[CodedAssToolType],
	a.[PersScore],
	a.[Der_AgeAssessTool],
	a.[Der_AssessmentToolName],
	a.[Der_PreferredTermSNOMED], 
	a.[Der_SNOMEDCodeVersion],
	a.[Der_LowerRange],
	a.[Der_UpperRange],
	a.[Der_ValidScore],
	a.[Der_UniqAssessment],
	a.[Der_AssessmentCategory],
	NULL AS Der_AssOrderAsc, 
	NULL AS Der_AssOrderDesc
		
FROM #Ass2 a

WHERE Der_UniqAssessment = 'Y'

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessment Insert End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ASSESSMENTS - BUILD DERIVATIONS					
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

 INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments Global Derivations Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE

SELECT
	a.Der_RecordID,
	ROW_NUMBER () OVER (PARTITION BY a.Person_ID, a.UniqServReqID, a.CodedAssToolType ORDER BY a.Der_AssToolCompDate ASC) AS Der_AssOrderAsc, --First assessment
	ROW_NUMBER () OVER (PARTITION BY a.Person_ID, a.UniqServReqID, a.CodedAssToolType ORDER BY a.Der_AssToolCompDate DESC) AS Der_AssOrderDesc -- Last assessment

INTO #AssTemp

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Assessments] a

WHERE a.Der_ValidScore = 'Y'

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments Global Derivations End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ASSESSMENTS - UPDATE DERIVATIONS					
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

 INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments Update Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE

UPDATE a

SET 
	a.Der_AssOrderAsc = t.Der_AssOrderAsc,
	a.Der_AssOrderDesc = t.Der_AssOrderDesc

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Assessments] a

LEFT JOIN #AssTemp t ON t.Der_RecordID = a.Der_RecordID

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments Update End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ACTIVITY - RECREATE INDEXES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessment Create Index Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - CREATE INDEXES

CREATE INDEX ix_Assessment ON [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Assessments] ([UniqMonthID], [RecordNumber], [OrgIDProv], [Person_ID], [UniqServReqID])

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessment Create Index End' AS Step,
	GETDATE() AS [TimeStamp]