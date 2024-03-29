/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DQ DASHBOARD
ASSET: PRE-PROCESSED TABLES
CREATED BY CARL MONEY 27/01/2021
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DECLARE @EndRP INT

SET @EndRP = (SELECT UniqMonthID
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE Der_MostRecentFlag = 'p')

DECLARE @StartRP INT

SET @StartRP = @EndRP - 24

DECLARE @ReportingPeriodEnd DATE

SET @ReportingPeriodEnd = (SELECT ReportingPeriodEndDate
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE UniqMonthID = @EndRP)

DECLARE @ReportingPeriodStart DATE

SET @ReportingPeriodStart = (SELECT ReportingPeriodEndDate
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE UniqMonthID = @StartRP)

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET DISTINCT LIST OF PROVIDERS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#MHSDSOrgs') IS NOT NULL
DROP TABLE #MHSDSOrgs

--Get list of providerds from Master Provider List

SELECT
	m.[Org Code] AS OrgIDProvider,
	m.[Organisation name] AS ProviderName,
	m.[Region code] AS RegionCode,
	m.Status

INTO #MHSDSOrgs

FROM NHSE_Sandbox_MentalHealth.dbo.Staging_DQMasterProviderList m

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CREATE PADDED TABLE FOR EACH ORG AND MONTH
COMBINATION
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Base') IS NOT NULL
DROP TABLE #Base

SELECT
	d.ReportingPeriodEndDate,
	d.UniqMonthID,
	CASE 
		WHEN d.UniqMonthID = @EndRP -1 THEN 'Performance'
		WHEN d.UniqMonthID = @EndRP THEN 'Provisional'
		ELSE 'Historical'
	END AS Der_CurrentSubmissionWindow,
	o.OrgIDProvider,
	o.Status

INTO #Base

FROM #MHSDSOrgs o

CROSS JOIN

(SELECT h.ReportingPeriodEndDate, h.UniqMonthID FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h WHERE UniqMonthID BETWEEN @StartRP AND @EndRP) d

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ORGANISATION STATUS FOR LATEST PERIOD AND 
LINK TO REFERENCE DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#OrgStat') IS NOT NULL
DROP TABLE #OrgStat

SELECT
	b.ReportingPeriodEndDate,
	b.UniqMonthID,
	b.OrgIDProvider AS [Provider code],
	b.Der_CurrentSubmissionWindow,
	CASE 
		WHEN b.Status = 'Not in scope' THEN 'No longer in scope'
		WHEN f.FirstSub IS NULL THEN 'Provider not yet submitting'
		WHEN f.FirstSub IS NOT NULL AND f.SubmissionType IS NULL AND p.Effective_To IS NULL THEN 'Missing submission'
		WHEN p.Effective_To IS NOT NULL THEN 'Closed organisation'
		ELSE 'Successful submission' 
	END AS Der_OrgSubmissionStatus

INTO #OrgStat

FROM #Base b

LEFT JOIN
(SELECT
	r.OrgIDProvider,
	MAX(CASE WHEN r.UniqMonthID = @EndRP-1 THEN SubmissionType END) AS SubmissionType,
	MIN(r.UniqMonthID) AS FirstSub

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_RecordCounts r

WHERE TableName = 'MHS000Header' AND r.SubmissionType <= 2 AND r.RecordCount IS NOT NULL

GROUP BY r.OrgIDProvider) f ON b.OrgIDProvider = f.OrgIDProvider

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies p ON b.OrgIDProvider = p.Organisation_Code COLLATE DATABASE_DEFAULT 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET NUMBER OF SUBMITTERS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT
	o.ReportingPeriodEndDate,
	CAST(NULL AS int) AS UniqMonthID,
	o.[Provider code],
	CAST(NULL AS varchar(255)) AS [Provider name],
	CAST(NULL AS varchar(10)) AS [STP code],
	CAST(NULL AS varchar(255)) AS [STP name],
	CAST(NULL AS varchar(10)) AS [Region code],
	CAST(NULL AS varchar(255)) AS [Region name],
	Der_CurrentSubmissionWindow,
	Der_OrgSubmissionStatus,
	CAST('Submission status - time series' AS varchar(255)) AS Dashboard,
	CAST('Submission type' AS varchar(255)) AS Breakdown,
	CAST(CASE 
		WHEN r.SubmissionType = 1 THEN 'Primary'
		WHEN r.SubmissionType = 2 THEN 'Performance'
		WHEN r.SubmissionType > 2 THEN 'Resubmission'
		ELSE 'Non-submitter'
	END AS varchar(255)) AS [Breakdown category],
	CAST('Submission' AS varchar(255)) AS MeasureName,
	COUNT(r.SubmissionType) AS MeasureValue, 
	CAST('Expected Submitters' AS varchar(255)) AS DenominatorName,
	SUM(CASE WHEN o.Der_OrgSubmissionStatus NOT IN ('Closed organisation', 'No longer in scope') THEN 1 ELSE 0 END) AS DenominatorValue,
	CAST('Coverage' AS varchar(255)) AS TargetName,
	70 AS TargetValue

INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

FROM #OrgStat o

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_RecordCounts r ON r.UniqMonthID = o.UniqMonthID AND r.OrgIDProvider = o.[Provider code] AND r.TableName = 'MHS000Header'

GROUP BY o.ReportingPeriodEndDate, o.[Provider code], Der_CurrentSubmissionWindow, Der_OrgSubmissionStatus, CASE WHEN r.SubmissionType = 1 THEN 'Primary' WHEN r.SubmissionType = 2 THEN 'Performance' WHEN r.SubmissionType > 2 THEN 'Resubmission' ELSE 'Non-submitter' END

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET SUBMISSIONS OVER LAST FIVE MONTHS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT
	o.ReportingPeriodEndDate,
	NULL AS UniqMonthID,
	o.[Provider code],
	NULL AS [Provider name],
	NULL AS [STP code],
	NULL AS [STP name],
	NULL AS [Region code],
	NULL AS [Region name],
	o.Der_CurrentSubmissionWindow,
	o.Der_OrgSubmissionStatus,
	'Submission status - major charts' AS Dashboard,
	'Submission consistency' AS Breakdown,
	'Submission consistency' AS [Breakdown category],
	'Submissions over last five months' AS MeasureName,
	COUNT(r.SubmissionType) OVER (PARTITION BY r.OrgIDProvider ORDER BY r.UniqMonthID ROWS BETWEEN 4 PRECEDING AND CURRENT ROW) AS MeasureValue, 
	NULL AS DenominatorName,
	NULL AS DenominatorValue,
	'Expected Submissions' AS TargetName,
	5 AS TargetValue

FROM #OrgStat o

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_RecordCounts r ON r.OrgIDProvider = o.[Provider code] AND r.UniqMonthID = o.UniqMonthID AND r.TableName = 'MHS000Header' AND r.SubmissionType = 2

WHERE o.Der_OrgSubmissionStatus = 'Successful submission' AND o.UniqMonthID BETWEEN @StartRP AND @EndRP -1

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET DQMI MHSDS DATA SET SCORE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT DISTINCT
	d.Effective_Snapshot_Date AS ReportingPeriodEndDate,
	NULL AS UniqMonthID,
	d.Data_Provider_Code AS [Provider code],
	NULL AS [Provider name],
	NULL AS [STP code],
	NULL AS [STP name],
	NULL AS [Region code],
	NULL AS [Region name],
	'N/A' AS Der_CurrentSubmissionWindow,
	'N/A' AS Der_OrgSubmissionStatus,
	'DQMI' AS Dashboard,
	'Data set score' AS Breakdown,
	'Data set score' AS [Breakdown category],
	'Data set score' AS MeasureName,
	d.Dataset_Score AS MeasureValue, 
	NULL AS DenominatorName,
	NULL AS DenominatorValue,
	'Data set score' AS TargetName,
	70 AS TargetValue

FROM [NHSE_UKHF].[Data_Quality_Maturity_Index].[vw_Open_Data1] d 

WHERE d.Dataset = 'MHSDS' AND d.Report_Period_Length = 'Monthly' AND d.Effective_Snapshot_Date >= '2019-04-30'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET DQMI DATA ITEM SCORES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT
	d.Effective_Snapshot_Date AS ReportingPeriodEndDate,
	NULL AS UniqMonthID,
	d.Data_Provider_Code AS [Provider code],
	NULL AS [Provider name],
	NULL AS [STP code],
	NULL AS [STP name],
	NULL AS [Region code],
	NULL AS [Region name],
	'N/A' AS Der_CurrentSubmissionWindow,
	'N/A' AS Der_OrgSubmissionStatus,
	'DQMI' AS Dashboard,
	'Data item score' AS Breakdown,
	'Data item'  AS [Breakdown category],
	CASE 
		WHEN d.Recoded_Data_Item = 'CLINICAL RESPONSE PRIORITY TYPE' THEN 'CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER)'
		ELSE d.Recorded_Data_Item
	END AS MeasureName,
	d.Data_Item_Score AS MeasureValue, 
	'National data item score' AS DenominatorName,
	d.National_Data_Item_Average AS DenominatorValue,
	'Data item score' AS TargetName,
	70 AS TargetValue

FROM [NHSE_UKHF].[Data_Quality_Maturity_Index].[vw_Open_Data1] d 

WHERE d.Dataset = 'MHSDS' AND d.Report_Period_Length = 'Monthly' AND d.Effective_Snapshot_Date >= '2019-04-30'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET CQUIN DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT
	c.ReportingPeriodEndDate,
	NULL AS UniqMonthID,
	c.[Organisation Code] AS [Provider code],
	NULL AS [Provider name],
	NULL AS [STP code],
	NULL AS [STP name],
	NULL AS [Region code],
	NULL AS [Region name],
	'N/A' AS Der_CurrentSubmissionWindow,
	'N/A' AS Der_OrgSubmissionStatus,
	'Outcomes CQUIN' AS Dashboard,
	'Service type' AS Breakdown,
	c.[Service Type] AS [Breakdown category],
	'Referrals with a paired score' AS MeasureName,
	SUM(c.MeasureValue) AS MeasureValue, 
	'Referrals with two or more contacts' AS DenominatorName,
	SUM(c.Denominator) AS DenominatorValue,
	'Outcomes CQUIN' AS TargetName,
	40 AS TargetValue

FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CQUIN2223] c 

WHERE c.Dashboard = 'Percentages' AND [Service Type] NOT IN ('CYP','Perinatal')

GROUP BY c.ReportingPeriodEndDate, c.[Organisation Code], c.[Service Type]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET SNOMED COMPLIANCE - CARE CONTACTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT
	a.ReportingPeriodEndDate,
	NULL AS UniqMonthID,
	a.OrgIDProv AS [Provider code],
	NULL AS [Provider name],
	NULL AS [STP code],
	NULL AS [STP name],
	NULL AS [Region code],
	NULL AS [Region name],
	'N/A' AS Der_CurrentSubmissionWindow,
	'N/A' AS Der_OrgSubmissionStatus,
	'SNoMED CT' AS Dashboard,
	'Coverage' AS Breakdown,
	'Care contacts' AS [Breakdown category],
	'Contacts with SNoMED CT' AS MeasureName,
	COUNT(DISTINCT i.UniqCareContID) AS MeasureValue,
	'Total contacts' AS DenominatorName,
	COUNT(DISTINCT a.UniqCareContID) AS DenominatorValue, 
	'SNoMED CT' AS TargetName,
	70 AS TargetName

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Interventions i ON a.UniqCareContID = i.UniqCareContID AND a.RecordNumber = i.RecordNumber

WHERE a.UniqMonthID >= @StartRP AND a.AttendOrDNACode IN ('5','6')

GROUP BY a.ReportingPeriodEndDate, a.OrgIDProv

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET SNOMED COMPLIANCE - INDIRECT ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT
	a.ReportingPeriodEndDate,
	NULL AS UniqMonthID,
	a.OrgIDProv AS [Provider code],
	NULL AS [Provider name],
	NULL AS [STP code],
	NULL AS [STP name],
	NULL AS [Region code],
	NULL AS [Region name],
	'N/A' AS Der_CurrentSubmissionWindow,
	'N/A' AS Der_OrgSubmissionStatus,
	'SNoMED CT' AS Dashboard,
	'Coverage' AS Breakdown,
	'Indirect activity' AS [Breakdown category],
	'Contacts with SNoMED CT' AS MeasureName,
	COUNT(DISTINCT i.Der_InterventionUniqID) AS MeasureValue,
	'Total contacts' AS DenominatorName,
	COUNT(DISTINCT a.Der_ActivityUniqID) AS DenominatorValue, 
	'SNoMED CT' AS TargetName,
	70 AS TargetValue

FROM  NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a  

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Interventions i ON a.Der_ActivityUniqID = i.Der_InterventionUniqID AND a.RecordNumber = i.RecordNumber AND i.Der_InterventionType = 'Indirect'

WHERE a.Der_ActivityType = 'Indirect' AND a.UniqMonthID >= @StartRP

GROUP BY a.ReportingPeriodEndDate, a.OrgIDProv

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
MAP TO ORGANISTION REFERENCE DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

UPDATE a

SET 
a.[Provider name] = p.Organisation_Name,
a.[STP code] = p.STP_Code,
a.[STP name] = p.STP_Name,
a.[Region code] = p.Region_Code,
a.[Region name] = p.Region_Name

FROM NHSE_Sandbox_MentalHealth.dbo.Dashboard_DataQuality a

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies p ON a.[Provider code] = p.Organisation_Code

UPDATE a

SET a.UniqMonthID = h.UniqMonthID

FROM NHSE_Sandbox_MentalHealth.dbo.Dashboard_DataQuality a

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON a.ReportingPeriodEndDate = h.ReportingPeriodEndDate

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
MAP ORGS THAT DON'T YET EXIST IN CORP REF DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

UPDATE a

SET 
a.[Provider name] = m.ProviderName,
a.[Region code] = m.RegionCode,
a.[Region name] = p.Region_Name

FROM NHSE_Sandbox_MentalHealth.dbo.Dashboard_DataQuality a

LEFT JOIN #MHSDSOrgs m ON a.[Provider code] = m.OrgIDProvider

LEFT JOIN (SELECT DISTINCT Region_Code, Region_Name FROM NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies) p ON m.RegionCode = p.Region_Code

WHERE a.[Provider name] IS NULL
