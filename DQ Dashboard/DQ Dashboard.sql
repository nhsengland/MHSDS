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

SET @StartRP = @EndRP - 12

DECLARE @ReportingPeriodEnd DATE

SET @ReportingPeriodEnd = (SELECT ReportingPeriodEndDate
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE Der_MostRecentFlag = 'p')

--/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
--GET DISTINCT LIST OF PROVIDERS
-->>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#MHSDSOrgs') IS NOT NULL
DROP TABLE #MHSDSOrgs

--Get list of providerds from Master Provider List

SELECT
	m.[Org Code] AS OrgIDProvider,
	m.[Organisation Name],
	m.[STP code],
	m.[Region code],
	m.Status

INTO #MHSDSOrgs

FROM NHSE_Sandbox_MentalHealth.dbo.Staging_DQMasterProviderList m

--Supplment this with orgs that did submit but are missing from the NHS D list

UNION

SELECT DISTINCT
	r.OrgIDProvider,
	NULL AS [Organisation Name],
	NULL AS [STP code],
	NULL AS [Region code],
	'In scope' AS Status 
	
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_RecordCounts r WHERE r.OrgIDProvider NOT IN (SELECT m.[Org Code] FROM NHSE_Sandbox_MentalHealth.dbo.Staging_DQMasterProviderList m)

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
	o.[Organisation Name],
	o.[STP code],
	o.[Region code],
	o.Status

INTO #Base

FROM #MHSDSOrgs o

CROSS JOIN

(SELECT h.ReportingPeriodEndDate, h.UniqMonthID FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h) d

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
	COALESCE(b.[Organisation Name], p.Organisation_Name) AS [Provider name],
	COALESCE(b.[STP code], p.STP_Code,'Missing / Invalid') AS [STP code],
	COALESCE(s.STP_Name,'Missing / Invalid') AS [STP name],
	COALESCE(b.[Region code], p.Region_Code,'Missing / Invalid') AS [Region code],
	COALESCE(r.Region_Name,'Missing / Invalid') AS [Region name],
	CASE 
		WHEN COALESCE(b.[Region code], p.Region_Code) = 'Y56' THEN 'E40000003'
		WHEN COALESCE(b.[Region code], p.Region_Code) = 'Y59' THEN 'E40000005'
		WHEN COALESCE(b.[Region code], p.Region_Code) = 'Y58' THEN 'E40000006'
		WHEN COALESCE(b.[Region code], p.Region_Code) = 'Y61' THEN 'E40000007'
		WHEN COALESCE(b.[Region code], p.Region_Code) = 'Y60' THEN 'E40000008'
		WHEN COALESCE(b.[Region code], p.Region_Code) = 'Y63' THEN 'E40000009'
		WHEN COALESCE(b.[Region code], p.Region_Code) = 'Y62' THEN 'E40000010'
	END AS Der_RegionONSCode,
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

LEFT JOIN (SELECT DISTINCT Region_Code, Region_Name FROM NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies) r ON r.Region_Code = COALESCE(b.[Region code], p.Region_Code) COLLATE DATABASE_DEFAULT 

LEFT JOIN (SELECT DISTINCT STP_Code, STP_Name FROM NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies) s ON s.STP_Code = COALESCE(b.[STP code], p.STP_Code) COLLATE DATABASE_DEFAULT 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET SUBMISSION STATUS AND POPULATE TABLE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT
	o.ReportingPeriodEndDate,
	o.UniqMonthID,
	o.[Provider code],
	o.[Provider name],
	o.[STP code],
	o.[STP name],
	o.[Region code],
	o.[Region name],
	o.Der_RegionONSCode,
	o.Der_CurrentSubmissionWindow,
	o.Der_OrgSubmissionStatus,
	CAST('Submission status - major charts' AS varchar(255)) AS Dashboard,
	CAST('Submission status' AS varchar(50)) AS Breakdown,
	CAST('Submission status' AS varchar(255)) AS [Breakdown category],
	CAST('Submission' AS varchar(255)) AS MeasureName,
	MAX(CASE WHEN r.SubmissionType IS NOT NULL THEN 1 ELSE 0 END) AS MeasureValue, 
	CAST('Last submission' AS varchar(255)) AS DenominatorName,
	CAST(MAX(r.SubmissionType) AS INT) AS DenominatorValue,
	CAST('Number of resubmissions' AS varchar(255)) AS TargetName,
	COUNT(CASE WHEN r.SubmissionType > 2 THEN r.SubmissionType END) AS TargetValue

INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality2]

FROM #OrgStat o

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_RecordCounts r ON o.[Provider code] = r.OrgIDProvider AND o.UniqMonthID = r.UniqMonthID AND r.TableName = 'MHS000Header'

GROUP BY o.ReportingPeriodEndDate, o.UniqMonthID, o.[Provider code], o.[Provider name], o.[STP code], o.[STP name], o.[Region code], o.[Region name], o.Der_RegionONSCode, o.Der_CurrentSubmissionWindow, o.Der_OrgSubmissionStatus

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET NUMBER OF SUBMITTERS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT
	o.ReportingPeriodEndDate,
	o.UniqMonthID,
	'ALL' AS [Provider code],
	'ALL' AS [Provider name],
	o.[STP code],
	o.[STP name],
	[Region code],
	[Region name],
	Der_RegionONSCode,
	Der_CurrentSubmissionWindow,
	Der_OrgSubmissionStatus,
	'Submission status - time series' AS Dashboard,
	'Submission type' AS Breakdown,
	CASE 
		WHEN r.SubmissionType = 1 THEN 'Primary'
		WHEN r.SubmissionType = 2 THEN 'Performance'
		WHEN r.SubmissionType > 2 THEN 'Resubmission'
		ELSE 'Non-submitter'
	END AS [Breakdown category],
	'Submission' AS MeasureName,
	COUNT(r.SubmissionType) AS MeasureValue, 
	'Expected Submitters' AS DenominatorName,
	SUM(CASE WHEN o.Der_OrgSubmissionStatus NOT IN ('Closed organisation', 'No longer in scope') THEN 1 ELSE 0 END) AS DenominatorValue,
	'Coverage' AS TargetName,
	70 AS TargetValue

FROM #OrgStat o

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_RecordCounts r ON r.UniqMonthID = o.UniqMonthID AND r.OrgIDProvider = o.[Provider code] AND r.TableName = 'MHS000Header'

GROUP BY o.ReportingPeriodEndDate, o.UniqMonthID, o.[STP code], o.[STP name], o.[Region code], o.[Region name], Der_RegionONSCode, Der_CurrentSubmissionWindow, Der_OrgSubmissionStatus, 
	CASE WHEN r.SubmissionType = 1 THEN 'Primary' WHEN r.SubmissionType = 2 THEN 'Performance' WHEN r.SubmissionType > 2 THEN 'Resubmission' ELSE 'Non-submitter' END

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET SUBMISSIONS OVER LAST FIVE MONTHS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT
	o.ReportingPeriodEndDate,
	o.UniqMonthID,
	o.[Provider code],
	o.[Provider name],
	o.[STP code],
	o.[STP name],
	o.[Region code],
	o.[Region name],
	o.Der_RegionONSCode,
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
GET RECORD COUNTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT
	o.ReportingPeriodEndDate,
	o.UniqMonthID,
	o.[Provider code],
	o.[Provider name],
	o.[STP code],
	o.[STP name],
	o.[Region code],
	o.[Region name],
	o.Der_RegionONSCode,
	o.Der_CurrentSubmissionWindow,
	o.Der_OrgSubmissionStatus,
	'Record counts' AS Dashboard,
	'Submission type' AS Breakdown,
	r.SubmissionType AS [Breakdown category],
	r.[TableName] AS MeasureName,
	r.RecordCount AS MeasureValue, 
	'Rolling count' AS DenominatorName,
	AVG(r.RecordCount) OVER (PARTITION BY r.OrgIDProvider, r.TableName, r.SubmissionType ORDER BY r.UniqMonthID ROWS BETWEEN 6 PRECEDING AND 1 PRECEDING) AS DenominatorValue,
	NULL AS TargetName,
	NULL AS TargetValue

FROM #OrgStat o

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_RecordCounts r ON r.UniqMonthID = o.UniqMonthID AND r.OrgIDProvider = o.[Provider code] 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET DQMI MHSDS DATA SET SCORE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT DISTINCT
	o.ReportingPeriodEndDate,
	o.UniqMonthID,
	o.[Provider code],
	o.[Provider name],
	o.[STP code],
	o.[STP name],
	o.[Region code],
	o.[Region name],
	o.Der_RegionONSCode,
	o.Der_CurrentSubmissionWindow,
	o.Der_OrgSubmissionStatus,
	'DQMI' AS Dashboard,
	'Data set score' AS Breakdown,
	'Data set score' AS [Breakdown category],
	'Data set score' AS MeasureName,
	d.Dataset_Score AS MeasureValue, 
	NULL AS DenominatorName,
	NULL AS DenominatorValue,
	'Data set score' AS TargetName,
	70 AS TargetValue

FROM #OrgStat o

INNER JOIN [NHSE_UKHF].[Data_Quality_Maturity_Index].[vw_Open_Data1] d ON d.Effective_Snapshot_Date = o.ReportingPeriodEndDate AND 
	CASE WHEN d.Data_Provider_Code = 'GAJ' THEN 'GAJ01' ELSE d.Data_Provider_Code END = o.[Provider code] COLLATE DATABASE_DEFAULT 

WHERE d.Dataset = 'MHSDS' AND d.Report_Period_Length = 'Monthly' AND d.Effective_Snapshot_Date >= '2019-04-30'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET DQMI DATA ITEM SCORES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT
	o.ReportingPeriodEndDate,
	o.UniqMonthID,
	o.[Provider code],
	o.[Provider name],
	o.[STP code],
	o.[STP name],
	o.[Region code],
	o.[Region name],
	o.Der_RegionONSCode,
	o.Der_CurrentSubmissionWindow,
	o.Der_OrgSubmissionStatus,
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
	NULL AS TargetName,
	NULL AS TargetValue

FROM #OrgStat o

INNER JOIN [NHSE_UKHF].[Data_Quality_Maturity_Index].[vw_Open_Data1] d ON d.Effective_Snapshot_Date = o.ReportingPeriodEndDate AND 
	CASE WHEN d.Data_Provider_Code = 'GAJ' THEN 'GAJ01' ELSE d.Data_Provider_Code END = o.[Provider code] COLLATE DATABASE_DEFAULT 

WHERE d.Dataset = 'MHSDS' AND d.Report_Period_Length = 'Monthly' AND d.Effective_Snapshot_Date >= '2019-04-30'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET CQUIN DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT
	o.ReportingPeriodEndDate,
	o.UniqMonthID,
	o.[Provider code],
	o.[Provider name],
	o.[STP code],
	o.[STP name],
	o.[Region code],
	o.[Region name],
	o.Der_RegionONSCode,
	o.Der_CurrentSubmissionWindow,
	o.Der_OrgSubmissionStatus,
	'Outcomes CQUIN' AS Dashboard,
	'Service type' AS Breakdown,
	c.[Service Type] AS [Breakdown category],
	c.MeasureName,
	c.MeasureValue, 
	'Closed referrals open more than 14 days with two or more contacts' AS DenominatorName,
	c.Denominator AS DenominatorValue,
	'Outcomes CQUIN' AS TargetName,
	30 AS TargetValue

FROM #OrgStat o

INNER JOIN [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CQUIN2021] c ON o.ReportingPeriodEndDate = c.ReportingPeriodEndDate AND o.[Provider code] = c.[Organisation Code] AND c.[Assessment Name] = 'All' AND 
	c.MeasureName = 'Closed referrals open more than 14 days with two or more contacts and a paired score'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET SNOMED COMPLIANCE - CARE CONTACTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT
	o.ReportingPeriodEndDate,
	o.UniqMonthID,
	o.[Provider code],
	o.[Provider name],
	o.[STP code],
	o.[STP name],
	o.[Region code],
	o.[Region name],
	o.Der_RegionONSCode,
	o.Der_CurrentSubmissionWindow,
	o.Der_OrgSubmissionStatus,
	'SNoMED CT' AS Dashboard,
	'Coverage' AS Breakdown,
	'Care contacts' AS [Breakdown category],
	'Contacts with SNoMED CT' AS MeasureName,
	COUNT(DISTINCT i.UniqCareContID) AS MeasureValue,
	'Total contacts' AS DenominatorName,
	COUNT(DISTINCT a.UniqCareContID) AS DenominatorValue, 
	'SNoMED CT' AS TargetName,
	70 AS TargetName

FROM #OrgStat o

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a ON a.UniqMonthID = o.UniqMonthID AND a.OrgIDProv = o.[Provider code] AND a.AttendOrDNACode IN ('5','6') AND a.UniqMonthID >= @StartRP

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Interventions i ON a.UniqCareContID = i.UniqCareContID AND a.RecordNumber = i.RecordNumber

GROUP BY o.ReportingPeriodEndDate, o.UniqMonthID, o.[Provider code], o.[Provider name], o.[STP code], o.[STP name], o.[Region code], o.[Region name], o.Der_RegionONSCode, o.Der_CurrentSubmissionWindow, o.Der_OrgSubmissionStatus

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET SNOMED COMPLIANCE - INDIRECT ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_DataQuality]

SELECT
	o.ReportingPeriodEndDate,
	o.UniqMonthID,
	o.[Provider code],
	o.[Provider name],
	o.[STP code],
	o.[STP name],
	o.[Region code],
	o.[Region name],
	o.Der_RegionONSCode,
	o.Der_CurrentSubmissionWindow,
	o.Der_OrgSubmissionStatus,
	'SNoMED CT' AS Dashboard,
	'Coverage' AS Breakdown,
	'Indirect activity' AS [Breakdown category],
	'Contacts with SNoMED CT' AS MeasureName,
	COUNT(DISTINCT i.Der_InterventionUniqID) AS MeasureValue,
	'Total contacts' AS DenominatorName,
	COUNT(DISTINCT a.Der_ActivityUniqID) AS DenominatorValue, 
	'SNoMED CT' AS TargetName,
	70 AS TargetValue

FROM #OrgStat o

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a ON a.UniqMonthID = o.UniqMonthID AND a.OrgIDProv = o.[Provider code] AND a.Der_ActivityType = 'Indirect' AND a.UniqMonthID >= @StartRP

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Interventions i ON a.Der_ActivityUniqID = i.Der_InterventionUniqID AND a.RecordNumber = i.RecordNumber AND i.Der_InterventionType = 'Indirect'

GROUP BY o.ReportingPeriodEndDate, o.UniqMonthID, o.[Provider code], o.[Provider name], o.[STP code], o.[STP name],o.[Region code], o.[Region name], o.Der_RegionONSCode, o.Der_CurrentSubmissionWindow, o.Der_OrgSubmissionStatus

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UPDATE TABLE IN EVERYONE SCHEMA 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/
	
DROP TABLE NHSE_Sandbox_MentalHealth.Everyone.Dashboard_DataQuality

SELECT * INTO NHSE_Sandbox_MentalHealth.Everyone.Dashboard_DataQuality
FROM NHSE_Sandbox_MentalHealth.dbo.Dashboard_DataQuality	
