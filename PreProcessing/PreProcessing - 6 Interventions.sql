
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

-- LOG START

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
INTERVENTIONS - COMBINE DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

--LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Interventions Combine Start' AS Step,
	GETDATE() AS [TimeStamp]

SELECT
	CAST('DIRECT' As varchar(10)) AS [Der_InterventionType],
	ca.MHS202UniqID AS [Der_InterventionUniqID],
	ca.UniqMonthID,
	ca.OrgIDProv,
	ca.Person_ID,
	ca.RecordNumber,
	ca.UniqServReqID,
	cc.CareContDate AS Der_ContactDate,
	ca.UniqCareContID,
	ca.UniqCareActID,
	ca.ClinContactDurOfCareAct AS Der_InterventionDuration,
	ca.FindSchemeInUse,
	ca.CodeFind,
	ca.ObsSchemeInUse,
	ca.CodeObs,
	ca.ObsValue,
	ca.UnitMeasure,
	ca.CodeProcAndProcStatus,
	CASE
		WHEN CHARINDEX(':',ca.CodeProcAndProcStatus) > 0
		THEN LEFT(ca.CodeProcAndProcStatus,CHARINDEX(':',ca.CodeProcAndProcStatus)-1)
		ELSE ca.CodeProcAndProcStatus
	END AS Der_SNoMEDProcCode,
	CASE
		WHEN CHARINDEX('=',ca.CodeProcAndProcStatus) > 0
		THEN RIGHT(ca.CodeProcAndProcStatus,CHARINDEX('=',REVERSE(ca.CodeProcAndProcStatus))-1)
		ELSE NULL
	END AS Der_SNoMEDProcQual,
	h.ReportingPeriodStartDate,
	h.ReportingPeriodEndDate,
	h.Der_FY

INTO #Int

FROM NHSE_MH_PrePublication.[dbo].[V4_MHS202CareActivity] ca

LEFT JOIN NHSE_MH_PrePublication.[dbo].[V4_MHS201CareContact] cc ON ca.RecordNumber = cc.RecordNumber AND ca.UniqCareContID = cc.UniqCareContID

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON h.UniqMonthID = ca.UniqMonthID 

WHERE ca.UniqMonthID >= @EndRP AND ca.Der_Use_Submission_Flag = 'Y' AND (ca.CodeFind IS NOT NULL OR ca.CodeObs IS NOT NULL OR ca.CodeProcAndProcStatus IS NOT NULL)

INSERT INTO #Int

SELECT 
	'INDIRECT' AS [Der_InterventionType],
	i.MHS204UniqID AS [Der_InterventionUniqID],
	i.UniqMonthID,
	i.OrgIDProv,
	i.Person_ID,
	i.RecordNumber,
	i.UniqServReqID,
	i.IndirectActDate AS Der_ContactDate,
	NULL AS UniqCareContID,
	NULL AS UniqCareActID,
	i.DurationIndirectAct AS Der_InterventionDuration,
	i.FindSchemeInUse,
	i.CodeFind,
	NULL AS ObsSchemeInUse,
	NULL AS CodeObs,
	NULL AS ObsValue,
	NULL AS UnitMeasure,
	i.CodeProcAndProcStatus,
	CASE
		WHEN CHARINDEX(':',i.CodeProcAndProcStatus) > 0
		THEN LEFT(i.CodeProcAndProcStatus,CHARINDEX(':',i.CodeProcAndProcStatus)-1)
		ELSE i.CodeProcAndProcStatus
	END AS Der_SNoMEDProcCode,
	CASE
		WHEN CHARINDEX('=',i.CodeProcAndProcStatus) > 0
		THEN RIGHT(i.CodeProcAndProcStatus,CHARINDEX('=',REVERSE(i.CodeProcAndProcStatus))-1)
		ELSE NULL
	END AS Der_SNoMEDProcQual,
	h.ReportingPeriodStartDate,
	h.ReportingPeriodEndDate,
	h.Der_FY

FROM NHSE_MH_PrePublication.dbo.V4_MHS204IndirectActivity i

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON h.UniqMonthID = i.UniqMonthID 

WHERE i.UniqMonthID >= @EndRP AND i.Der_Use_Submission_Flag = 'Y' AND (i.CodeFind IS NOT NULL OR i.CodeProcAndProcStatus IS NOT NULL)

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Interventions Combine End' AS Step,
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
	i.Der_InterventionType,
	i.Der_InterventionUniqID,
	i.UniqMonthID,
	i.OrgIDProv,
	i.Person_ID,
	i.RecordNumber,
	i.UniqServReqID,
	i.Der_ContactDate,
	i.UniqCareContID,
	i.UniqCareActID,
	i.Der_InterventionDuration,
	i.FindSchemeInUse,
	i.CodeFind,
	s2.Term AS Der_SNoMEDFindTerm,
	CASE WHEN s2.Term IS NULL THEN NULL WHEN s2.Effective_To IS NULL OR s2.Effective_To > i.Der_ContactDate THEN 'Current' ELSE 'Retired' END AS Der_SNoMEDFindValidity,
	i.ObsSchemeInUse,
	i.CodeObs,
	s3.Term AS Der_SNoMEDObsTerm,
	CASE WHEN s3.Term IS NULL THEN NULL WHEN s3.Effective_To IS NULL OR s3.Effective_To > i.Der_ContactDate THEN 'Current' ELSE 'Retired' END AS Der_SNoMEDObsValidity,
	i.ObsValue,
	i.UnitMeasure,
	i.CodeProcAndProcStatus,
	i.Der_SNoMEDProcCode,
	i.Der_SNoMEDProcQual,
	s1.Term AS Der_SNoMEDProcTerm,
	CASE WHEN s1.Term IS NULL THEN NULL WHEN s1.Effective_To IS NULL OR s1.Effective_To > i.Der_ContactDate THEN 'Current' ELSE 'Retired' END AS Der_SNoMEDProcValidity,
	i.ReportingPeriodStartDate,
	i.ReportingPeriodEndDate,
	i.Der_FY

FROM #Int i

LEFT JOIN  [NHSE_UKHF].[SNOMED].[vw_Descriptions_SCD] s1 ON i.Der_SNoMEDProcCode = CAST(s1.[Concept_ID] AS VARCHAR) AND s1.Type_ID = 900000000000003001 AND s1.Is_Latest = 1 AND s1.Active = 1

LEFT JOIN  [NHSE_UKHF].[SNOMED].[vw_Descriptions_SCD] s2 ON i.CodeFind = CAST(s2.[Concept_ID] AS VARCHAR) AND s2.Type_ID = 900000000000003001 AND s2.Is_Latest = 1 AND s2.Active = 1

LEFT JOIN  [NHSE_UKHF].[SNOMED].[vw_Descriptions_SCD] s3 ON i.CodeObs = CAST(s3.[Concept_ID] AS VARCHAR) AND s3.Type_ID = 900000000000003001 AND s3.Is_Latest = 1 AND s3.Active = 1

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

-- LOG START

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
