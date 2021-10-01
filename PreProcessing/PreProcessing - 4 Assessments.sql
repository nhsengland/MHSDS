
DECLARE @EndRP INT

SET @EndRP = (SELECT UniqMonthID
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_MostRecentFlag = 'Y')

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
ASSESSMENTS - DELETE DATA THAT HAS BEEN SUPERCEDED BY OTHER DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments Delete Data Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DELETE DATA

DELETE FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Assessments] WHERE CONCAT(OrgIDProv,UniqMonthID) IN (SELECT CONCAT(OrgIDProvider,UniqMonthID) FROM NHSE_MH_PrePublication.Test.MHS000Header)

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments Delete Data End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ASSESSMENTS - UNION MHS606, MHS607, MHS801							
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 -- LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments Union Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE

SELECT
	'CON' AS Der_AssTable,
	h.[ReportingPeriodStartDate],
	h.[ReportingPeriodEndDate],
	h.[Der_FY],
	a.[UniqSubmissionID],
	a.[NHSEUniqSubmissionID],
	a.[UniqMonthID],
	a.[CodedAssToolType],
	a.[PersScore],
	c.CareContDate AS Der_AssToolCompDate,
	a.[RecordNumber],
	a.[MHS607UniqID] AS Der_AssUniqID,
	a.[OrgIDProv],
	a.[Der_Person_ID] AS Person_ID,
	a.[UniqServReqID],
	a.[AgeAssessToolCont] AS Der_AgeAssessTool,
	a.[UniqCareContID],
	a.[UniqCareActID]

INTO #Ass

FROM [NHSE_MH_PrePublication].[Test].[MHS607CodedScoreAssessmentAct] a 

LEFT JOIN [NHSE_MH_PrePublication].[Test].[MHS201CareContact] c ON a.RecordNumber = c.RecordNumber AND a.UniqServReqID = c.UniqServReqID AND a.UniqCareContID = c.UniqCareContID

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON h.UniqMonthID = a.UniqMonthID

INSERT INTO #Ass

SELECT
	'REF' AS Der_AssTable,
	h.[ReportingPeriodStartDate],
	h.[ReportingPeriodEndDate],
	h.[Der_FY],
	r.[UniqSubmissionID],
	r.[NHSEUniqSubmissionID],
	r.[UniqMonthID],
	r.[CodedAssToolType],
	r.[PersScore],
	r.AssToolCompDate  AS Der_AssToolCompDate,
	--r.AssToolCompTimestamp AS Der_AssToolCompDate, -- new field for v5
	r.[RecordNumber],
	r.[MHS606UniqID] AS Der_AssUniqID,
	r.[OrgIDProv],
	r.[Der_Person_ID] AS Person_ID,
	r.[UniqServReqID],
	r.AgeAssessToolReferCompDate AS Der_AgeAssessTool,
	NULL AS [UniqCareContID],
	NULL AS [UniqCareActID]

FROM [NHSE_MH_PrePublication].[Test].[MHS606CodedScoreAssessmentRefer] r 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON h.UniqMonthID = r.UniqMonthID

INSERT INTO #Ass

SELECT
	'CLU' AS Der_AssTable,
	h.[ReportingPeriodStartDate],
	h.[ReportingPeriodEndDate],
	h.[Der_FY],
	a.[UniqSubmissionID],
	a.[NHSEUniqSubmissionID],
	c.[UniqMonthID],
	a.[CodedAssToolType],
	a.[PersScore],
	c.AssToolCompDate AS Der_AssToolCompDate,
	c.[RecordNumber],
	a.[MHS802UniqID] AS Der_AssUniqID,
	a.[OrgIDProv],
	a.[Der_Person_ID] AS Person_ID,
	r.[UniqServReqID],
	NULL AS Der_AgeAssessTool,
	NULL AS [UniqCareContID],
	NULL AS [UniqCareActID]

FROM [NHSE_MH_PrePublication].[Test].[MHS802ClusterAssess] a

LEFT JOIN [NHSE_MH_PrePublication].[Test].[MHS801ClusterTool] c ON c.UniqClustID = a.UniqClustID AND c.RecordNumber = a.RecordNumber

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON h.UniqMonthID = a.UniqMonthID

INNER JOIN [NHSE_MH_PrePublication].[Test].[MHS101Referral] r ON r.RecordNumber = c.RecordNumber AND c.AssToolCompDate BETWEEN r.ReferralRequestReceivedDate AND ISNULL(r.ServDischDate,h.ReportingPeriodEndDate)

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments Union End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ASSESSMENTS - BUILD IN MONTH DERIVATIONS					
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

 INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments In Month Derivations Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE

SELECT 
	a.[ReportingPeriodStartDate],
	a.[ReportingPeriodEndDate],
	a.[Der_FY],
	a.[UniqSubmissionID],
	a.[NHSEUniqSubmissionID],
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
		WHEN TRY_CONVERT(FLOAT,a.PersScore) BETWEEN r.[Lower Range] AND r.[Upper Range] THEN 'Y' 
		ELSE NULL 
	END AS Der_ValidScore,
	CASE 
		WHEN ROW_NUMBER () OVER (PARTITION BY a.Person_ID, a.Der_AssToolCompDate, ISNULL(a.UniqServReqID,0), r.[Preferred Term (SNOMED-CT)], a.PersScore ORDER BY a.Der_AssUniqID ASC) = 1
		THEN 'Y' 
		ELSE NULL 
	END AS Der_UniqAssessment,
	CONCAT(a.Der_AssToolCompDate,a.UniqServReqID,a.CodedAssToolType,a.PersScore) AS Der_AssKey,
	CASE WHEN a.Der_AssToolCompDate BETWEEN a.ReportingPeriodStartDate AND a.ReportingPeriodEndDate THEN 1 ELSE 0 END AS Der_AssInMonth

INTO #Ass2

FROM #Ass a

LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[Reference_MHAssessments] r ON a.CodedAssToolType = r.[Active Concept ID (SNOMED CT)] 

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments In Month Derivations End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ASSESSMENTS - INSERT DATA				
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

 INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments Insert Start' AS Step,
	GETDATE() AS [TimeStamp]

--START CODE - ASSESSMENT IN MONTH

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Assessments]

SELECT 
	a.ReportingPeriodStartDate,
	a.ReportingPeriodEndDate,
	a.Der_FY,
	a.UniqSubmissionID,
	a.NHSEUniqSubmissionID,
	a.UniqMonthID,
	a.OrgIDProv,
	a.Person_ID,
	a.RecordNumber,
	a.UniqServReqID,
	a.UniqCareContID,
	a.UniqCareActID,
	a.CodedAssToolType,
	a.PersScore,
	a.Der_AssUniqID,
	a.Der_AssTable,
	a.Der_AssToolCompDate,
	a.Der_AgeAssessTool,
	a.Der_AssessmentToolName,
	a.Der_PreferredTermSNOMED,
	a.Der_SNOMEDCodeVersion,
	a.Der_LowerRange,
	a.Der_UpperRange,
	a.Der_ValidScore,
	a.Der_AssessmentCategory,
	NULL AS Der_AssOrderAsc,
	NULL AS Der_AssOrderDesc,
	a.Der_AssKey
	
FROM #Ass2 a

WHERE Der_UniqAssessment = 'Y' AND Der_AssInMonth = 1

--START CODE - ASSESSMENT NOT IN MONTH

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Assessments]

SELECT 
	a.ReportingPeriodStartDate,
	a.ReportingPeriodEndDate,
	a.Der_FY,
	a.UniqSubmissionID,
	a.NHSEUniqSubmissionID,
	a.UniqMonthID,
	a.OrgIDProv,
	a.Person_ID,
	a.RecordNumber,
	a.UniqServReqID,
	a.UniqCareContID,
	a.UniqCareActID,
	a.CodedAssToolType,
	a.PersScore,
	a.Der_AssUniqID,
	a.Der_AssTable,
	a.Der_AssToolCompDate,
	a.Der_AgeAssessTool,
	a.Der_AssessmentToolName,
	a.Der_PreferredTermSNOMED,
	a.Der_SNOMEDCodeVersion,
	a.Der_LowerRange,
	a.Der_UpperRange,
	a.Der_ValidScore,
	a.Der_AssessmentCategory,
	NULL AS Der_AssOrderAsc,
	NULL AS Der_AssOrderDesc,
	a.Der_AssKey
	
FROM #Ass2 a

WHERE Der_UniqAssessment = 'Y' AND Der_AssInMonth = 0 AND a.Der_AssKey NOT IN (SELECT Der_AssKey FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Assessments])

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments Insert End' AS Step,
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
ASSESSMENT - RECREATE INDEXES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments Create Index Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - CREATE INDEXES

CREATE INDEX ix_Assessment ON [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Assessments] ([UniqMonthID], [RecordNumber], [OrgIDProv], [Person_ID], [UniqServReqID])

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Assessments Create Index End' AS Step,
	GETDATE() AS [TimeStamp]
