
DECLARE @EndRP INT
DECLARE @ReportingPeriodEnd DATE

SET @EndRP = (SELECT UniqMonthID
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_MostRecentFlag = 'Y')

SET @ReportingPeriodEnd = (SELECT ReportingPeriodEndDate FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] WHERE UniqMonthID = @EndRP)

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP SIX - INTERVENTIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
INTERVENTIONS - DROP EXISTING INDEXES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

--LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Interventions Drop Index Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DROP INDEX

DROP INDEX ix_Interventions ON [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Interventions]

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Interventions Drop Index End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
INTERVENTIONS - DELETE PRIMARY DATA FROM LAST MONTH
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Interventions Delete Primary Data Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DELETE DATA

DELETE FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Interventions] WHERE UniqMonthID = @EndRP

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Interventions Delete Primary Data End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
INTERVENTIONS - INSERT DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

--LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Interventions Insert Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Interventions]

SELECT
	ca.MHS202UniqID,
	ca.UniqMonthID,
	ca.OrgIDProv,
	ca.Person_ID,
	ca.RecordNumber,
	ca.UniqServReqID,
	cc.CareContDate,
	ca.UniqCareContID,
	ca.UniqCareActID,
	ca.ClinContactDurOfCareAct,
	ca.FindSchemeInUse,
	ca.CodeFind,
	s2.Term AS Der_SNoMEDFindTerm,
	CASE WHEN s2.Effective_To IS NULL OR s2.Effective_To > cc.CareContDate THEN 'Current' ELSE 'Retired' END AS Der_SNoMEDFindValidity,
	ca.ObsSchemeInUse,
	ca.CodeObs,
	s3.Term AS Der_SNoMEDObsTerm,
	CASE WHEN s3.Effective_To IS NULL OR s3.Effective_To > cc.CareContDate THEN 'Current' ELSE 'Retired' END AS Der_SNoMEDObsValidity,
	ca.ObsValue,
	ca.UnitMeasure,
	ca.CodeProcAndProcStatus,
	CASE
		WHEN CHARINDEX(':',ca.CodeProcAndProcStatus) > 0
		THEN LEFT(ca.CodeProcAndProcStatus,CHARINDEX(':',ca.CodeProcAndProcStatus)-1)
		ELSE ca.CodeProcAndProcStatus
	END AS Der_SNoMEDProcCode,
	CASE
		WHEN CHARINDEX('=',CodeProcAndProcStatus) > 0
		THEN RIGHT(CodeProcAndProcStatus,CHARINDEX('=',REVERSE(CodeProcAndProcStatus))-1)
		ELSE NULL
	END AS Der_SNoMEDProcQual,
	s1.Term AS Der_SNoMEDProcTerm,
	CASE WHEN s1.Effective_To IS NULL OR s1.Effective_To > cc.CareContDate THEN 'Current' ELSE 'Retired' END AS Der_SNoMEDProcValidity

FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS202CareActivity] ca

LEFT JOIN [NHSE_MH_PrePublication].[dbo].[V4_MHS201CareContact] cc ON ca.RecordNumber = cc.RecordNumber AND ca.UniqCareContID = cc.UniqCareContID

LEFT JOIN  [NHSE_UKHF].[SNOMED].[vw_Descriptions_SCD] s1 ON CASE WHEN CHARINDEX(':',ca.CodeProcAndProcStatus) > 0 THEN LEFT(ca.CodeProcAndProcStatus,CHARINDEX(':',ca.CodeProcAndProcStatus)-1)
		ELSE ca.CodeProcAndProcStatus END = CAST(s1.[Concept_ID] AS VARCHAR) AND s1.Type_ID = 900000000000003001 AND s1.Is_Latest = 1 AND s1.Active = 1

LEFT JOIN  [NHSE_UKHF].[SNOMED].[vw_Descriptions_SCD] s2 ON ca.CodeFind = CAST(s2.[Concept_ID] AS VARCHAR) AND s2.Type_ID = 900000000000003001 AND s2.Is_Latest = 1 AND s2.Active = 1

LEFT JOIN  [NHSE_UKHF].[SNOMED].[vw_Descriptions_SCD] s3 ON ca.CodeObs = CAST(s3.[Concept_ID] AS VARCHAR) AND s3.Type_ID = 900000000000003001 AND s3.Is_Latest = 1 AND s3.Active = 1

WHERE ca.UniqMonthID >= @EndRP AND 
ca.Der_Use_Submission_Flag = 'Y' AND (ca.CodeFind IS NOT NULL OR ca.CodeObs IS NOT NULL OR ca.CodeProcAndProcStatus IS NOT NULL)

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Interventions Insert End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
INTERVENTIONS - RECREATE INDEX
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Interventions Create Index Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - CREATE INDEX

CREATE INDEX ix_Interventions ON [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Interventions] ([UniqMonthID], [RecordNumber], [OrgIDProv], [Person_ID], [UniqServReqID])

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Interventions Create Index End' AS Step,
	GETDATE() AS [TimeStamp]