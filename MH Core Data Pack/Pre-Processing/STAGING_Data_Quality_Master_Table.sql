/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DQ DASHBOARD
ASSET: PRE-PROCESSED TABLES
CREATED BY CARL MONEY 27/01/2021
Updatedf to UDAL Version April 2024
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DECLARE @EndRP INT

SET @EndRP = (SELECT max(UniqMonthID)
FROM MHDInternal.PreProc_Header)

PRINT @EndRP

DECLARE @StartRP INT

SET @StartRP = 1424 -- November 2018 need to go back this far to report from Apr-19 so consistency has previous 5 months.

PRINT @StartRP

DECLARE @ReportingPeriodEnd DATE

SET @ReportingPeriodEnd = (SELECT ReportingPeriodEndDate
FROM MHDInternal.PreProc_Header
WHERE UniqMonthID = @EndRP)

PRINT @ReportingPeriodEnd

DECLARE @ReportingPeriodStart DATE

SET @ReportingPeriodStart = (SELECT ReportingPeriodEndDate
FROM MHDInternal.PreProc_Header
WHERE UniqMonthID = @StartRP)

PRINT @ReportingPeriodStart

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET DISTINCT LIST OF PROVIDERS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--Get list of providers from Master Provider List

-- Use Max month to pull latest data from MPL


DECLARE @MAXMPLMONTH DATE
SET @MAXMPLMONTH = (SELECT MAX([Reporting_Period]) from MHDInternal.[REFERENCE_MHSDS_Submission_Tracker])


SELECT distinct
	m.[Org_Code] AS OrgIDProvider,
	m.[Organisation_Name] AS ProviderName,
	m.[Region_Code] AS RegionCode,
	p2.Region_Name AS RegionName,
	p1.STP_Name AS STPName,
	[ICB_Code] AS STPCode,
	CASE WHEN current_status IN ('No longer expected to submit','Not currently expected to submit') THEN 'Not in scope'
	ELSE 'In scope' END AS 'Status'

INTO MHDInternal.[TEMP_CDP_Data_Quality_Master_MHSDSOrgs]

FROM MHDInternal.[REFERENCE_MHSDS_Submission_Tracker] m

LEFT JOIN Reporting_UKHD_ODS.Provider_Hierarchies p1 ON m.ICB_Code = p1.STP_Code -- GET NAMES FROM REFERENCE TABLE 
LEFT JOIN Reporting_UKHD_ODS.Provider_Hierarchies p2 ON m.Region_Code = p2.Region_Code -- GET NAMES FROM REFERENCE TABLE 

WHERE [Reporting_Period] = @MAXMPLMONTH




/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CREATE PADDED TABLE FOR EACH ORG AND MONTH
COMBINATION
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

SELECT
	d.ReportingPeriodEndDate,
	d.UniqMonthID,
	CASE 
		WHEN (d.UniqMonthID < 1483 AND d.UniqMonthID = @EndRP -1) THEN 'Performance'
		WHEN (d.UniqMonthID >= 1483 AND d.UniqMonthID = @EndRP) THEN 'Performance' -- NEW PERFORMANCE WINDOW FROM OCT-23
		WHEN (d.UniqMonthID < 1483 AND d.UniqMonthID = @EndRP) THEN 'Provisional'
		ELSE 'Historical'
	END AS Der_CurrentSubmissionWindow,
	o.OrgIDProvider,
	o.Status

INTO MHDInternal.[TEMP_CDP_Data_Quality_Master_Base]

FROM MHDInternal.[TEMP_CDP_Data_Quality_Master_MHSDSOrgs] o

CROSS JOIN

(SELECT h.ReportingPeriodEndDate, h.UniqMonthID FROM MHDInternal.PreProc_Header h WHERE UniqMonthID BETWEEN @StartRP AND @EndRP) d

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ORGANISATION STATUS FOR LATEST PERIOD AND 
LINK TO REFERENCE DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

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
		ELSE 'Successful submission' -- misleading as some months may not have a submission? basically just saying that they are in scope and have submitted at least once before 
	END AS Der_OrgSubmissionStatus

INTO MHDInternal.[TEMP_CDP_Data_Quality_Master_OrgStat]

FROM MHDInternal.[TEMP_CDP_Data_Quality_Master_Base] b

LEFT JOIN
(SELECT
	r.OrgIDProvider,
	MAX(CASE WHEN r.UniqMonthID = @EndRP-1 THEN SubmissionType END) AS SubmissionType,
	MIN(r.UniqMonthID) AS FirstSub

FROM MHDInternal.PreProc_RecordCounts r

WHERE TableName = 'MHS000Header' AND r.SubmissionType <= 2 AND r.RecordCount IS NOT NULL

GROUP BY r.OrgIDProvider) f ON b.OrgIDProvider = f.OrgIDProvider

LEFT JOIN Reporting_UKHD_ODS.Provider_Hierarchies p ON b.OrgIDProvider = p.Organisation_Code COLLATE DATABASE_DEFAULT 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET NUMBER OF SUBMITTERS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DELETE FROM  MHDInternal.[STAGING_Data_Quality_Master_Table]

INSERT INTO MHDInternal.[STAGING_Data_Quality_Master_Table]

SELECT
	o.ReportingPeriodEndDate,
	CAST(NULL AS int) AS UniqMonthID,
	'Provider' AS Org_Type,
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
		WHEN (r.UniqMonthID < 1483 AND r.SubmissionType = 1) THEN 'Primary'
		WHEN (r.UniqMonthID < 1483 AND r.SubmissionType = 2) THEN 'Performance'
		WHEN (r.UniqMonthID >= 1483 AND r.SubmissionType = 1) THEN 'Performance' -- NEW PERFORMANCE WINDOW FROM OCT-23
		WHEN (r.UniqMonthID < 1483 AND r.SubmissionType > 2) THEN 'Resubmission'
		WHEN (r.UniqMonthID >= 1483 AND r.SubmissionType > 1) THEN 'Resubmission' -- NEW PERFORMANCE WINDOW FROM OCT-23
		ELSE 'Non-submitter'
	END AS varchar(255)) AS [Breakdown category],
	CAST('Submission' AS varchar(255)) AS MeasureName,
	COUNT(r.SubmissionType) AS MeasureValue, 
	CAST('Expected Submitters' AS varchar(255)) AS DenominatorName,
	SUM(CASE WHEN o.Der_OrgSubmissionStatus NOT IN ('Closed organisation', 'No longer in scope') THEN 1 ELSE 0 END) AS DenominatorValue,
	CAST('Coverage' AS varchar(255)) AS TargetName,
	70 AS TargetValue,
	NULL AS Name_Source


FROM MHDInternal.[TEMP_CDP_Data_Quality_Master_OrgStat] o

LEFT JOIN MHDInternal.PreProc_RecordCounts r ON r.UniqMonthID = o.UniqMonthID AND r.OrgIDProvider = o.[Provider code] AND r.TableName = 'MHS000Header'

GROUP BY o.ReportingPeriodEndDate, o.[Provider code], Der_CurrentSubmissionWindow, Der_OrgSubmissionStatus, CASE 
		WHEN (r.UniqMonthID < 1483 AND r.SubmissionType = 1) THEN 'Primary'
		WHEN (r.UniqMonthID < 1483 AND r.SubmissionType = 2) THEN 'Performance'
		WHEN (r.UniqMonthID >= 1483 AND r.SubmissionType = 1) THEN 'Performance' -- NEW PERFORMANCE WINDOW FROM OCT-23
		WHEN (r.UniqMonthID < 1483 AND r.SubmissionType > 2) THEN 'Resubmission'
		WHEN (r.UniqMonthID >= 1483 AND r.SubmissionType > 1) THEN 'Resubmission' -- NEW PERFORMANCE WINDOW FROM OCT-23
		ELSE 'Non-submitter'
	END

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET SUBMISSIONS OVER LAST FIVE MONTHS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/
select o.UniqMonthID, o.OrgIDProvider, SubmissionType

into MHDInternal.[TEMP_CDP_Data_Quality_Master_Submission_History]

FROM (
select b.UniqMonthID, a.OrgIDProvider

from (select distinct OrgIDProvider from MHDInternal.PreProc_RecordCounts) a

cross join (select distinct uniqmonthid from MHDInternal.PreProc_RecordCounts) b ) o

LEFT JOIN (SELECT * FROM MHDInternal.PreProc_RecordCounts WHERE ((UniqMonthID < 1483 AND SubmissionType = 2) OR (UniqMonthID >= 1483 AND SubmissionType = 1))
AND TableName = 'MHS000Header') r ON o.OrgIDProvider = r.OrgIDProvider AND o.UniqMonthID = r.UniqMonthID 

INSERT INTO MHDInternal.[STAGING_Data_Quality_Master_Table]

SELECT
	o.ReportingPeriodEndDate,
	NULL AS UniqMonthID,
	'Provider' AS Org_Type,
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
	5 AS TargetValue,
	NULL AS Name_Source
	
FROM MHDInternal.[TEMP_CDP_Data_Quality_Master_OrgStat] o

LEFT JOIN MHDInternal.[TEMP_CDP_Data_Quality_Master_Submission_History] r ON o.[Provider code] = r.OrgIDProvider AND o.UniqMonthID = r.UniqMonthID

WHERE o.Der_OrgSubmissionStatus = 'Successful submission' AND o.UniqMonthID BETWEEN @StartRP AND @EndRP

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET DQMI MHSDS DATA SET SCORE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO MHDInternal.[STAGING_Data_Quality_Master_Table]

SELECT DISTINCT
	d.Effective_Snapshot_Date AS ReportingPeriodEndDate,
	NULL AS UniqMonthID,
	'Provider' AS Org_Type,
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
	70 AS TargetValue,
	NULL AS Name_Source

FROM [UKHF_Data_Quality_Maturity_Index].[Open_Data1] d 

WHERE d.Dataset = 'MHSDS' AND d.Report_Period_Length = 'Monthly' AND d.Effective_Snapshot_Date >= '2019-04-30'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET DQMI DATA ITEM SCORES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--INSERT INTO [NHSE_Sandbox_Policy].[dbo].[STAGING_Data_Quality_Master_Table]

--SELECT
--	d.Effective_Snapshot_Date AS ReportingPeriodEndDate,
--	NULL AS UniqMonthID,
-- 'Provider' AS Org_Type,
--	d.Data_Provider_Code AS [Provider code],
--	NULL AS [Provider name],
--	NULL AS [STP code],
--	NULL AS [STP name],
--	NULL AS [Region code],
--	NULL AS [Region name],
--	'N/A' AS Der_CurrentSubmissionWindow,
--	'N/A' AS Der_OrgSubmissionStatus,
--	'DQMI' AS Dashboard,
--	'Data item score' AS Breakdown,
--	'Data item'  AS [Breakdown category],
--	CASE 
--		WHEN d.Recoded_Data_Item = 'CLINICAL RESPONSE PRIORITY TYPE' THEN 'CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER)'
--		ELSE d.Recorded_Data_Item
--	END AS MeasureName,
--	d.Data_Item_Score AS MeasureValue, 
--	'National data item score' AS DenominatorName,
--	d.National_Data_Item_Average AS DenominatorValue,
--	'Data item score' AS TargetName,
--	70 AS TargetValue,
--	NULL AS Name_Source

--FROM [NHSE_UKHF].[Data_Quality_Maturity_Index].[vw_Open_Data1] d 

--WHERE d.Dataset = 'MHSDS' AND d.Report_Period_Length = 'Monthly' AND d.Effective_Snapshot_Date >= '2019-04-30'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET CQUIN DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO MHDInternal.[STAGING_Data_Quality_Master_Table]

SELECT 
	c.ReportingPeriodEndDate,
	NULL AS UniqMonthID,
	'Provider' AS Org_Type,
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
	40 AS TargetValue,
	NULL AS Name_Source

FROM [MHDInternal].[Dashboard_CQUIN2324] c
--[NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CQUIN2223] c 

WHERE c.Dashboard = 'Percentages' AND [Service Type] NOT IN ('CYP','Perinatal') AND MeasureGroup = 'All OMs'

GROUP BY c.ReportingPeriodEndDate, c.[Organisation Code], c.[Service Type]


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET SNOMED COMPLIANCE - CARE CONTACTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO MHDInternal.[STAGING_Data_Quality_Master_Table]

SELECT
	a.ReportingPeriodEndDate,
	NULL AS UniqMonthID,
	'Provider' AS Org_Type,
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
	70 AS TargetName,
	NULL AS Name_Source

FROM MHDInternal.PreProc_Activity a 

LEFT JOIN MHDInternal.PreProc_Interventions i ON a.UniqCareContID = i.UniqCareContID AND a.RecordNumber = i.RecordNumber

WHERE a.UniqMonthID >= @StartRP AND a.AttendOrDNACode IN ('5','6')

GROUP BY a.ReportingPeriodEndDate, a.OrgIDProv

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET SNOMED COMPLIANCE - INDIRECT ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO MHDInternal.[STAGING_Data_Quality_Master_Table]

SELECT
	a.ReportingPeriodEndDate,
	NULL AS UniqMonthID,
	'Provider' AS Org_Type,
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
	70 AS TargetValue,
	NULL AS Name_Source

FROM  MHDInternal.PreProc_Activity a  

LEFT JOIN MHDInternal.PreProc_Interventions i ON a.Der_ActivityUniqID = i.Der_InterventionUniqID AND a.RecordNumber = i.RecordNumber AND i.Der_InterventionType = 'Indirect'

WHERE a.Der_ActivityType = 'Indirect' AND a.UniqMonthID >= @StartRP

GROUP BY a.ReportingPeriodEndDate, a.OrgIDProv

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CHANGE MAPPING FOR COVERAGE, CONSISTENCY AND DQMI TO MPL (ODS WHERE NOT PRESENT)
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

UPDATE a

SET 
a.[Provider name] = COALESCE(p.[ProviderName],ph.[organisation_name]),
a.[STP code] = COALESCE(p.STPCode,ph.stp_code),
a.[STP name] = COALESCE(p.[stpname],ph.stp_name),
a.[Region code] = COALESCE(p.[RegionCode],ph.Region_Code),
a.[Region name] = COALESCE(p.[RegionName], ph.Region_Name),
a.Name_Source = CASE WHEN p.OrgIDProvider is NOT NULL THEN 'MPL' 
WHEN ph.[organisation_code] IS NOT NULL THEN 'ODS' ELSE NULL END

FROM MHDInternal.[STAGING_Data_Quality_Master_Table]  a

LEFT JOIN MHDInternal.[TEMP_CDP_Data_Quality_Master_MHSDSOrgs] p ON a.[Provider code] = p.[OrgIDProvider]
LEFT JOIN Reporting_UKHD_ODS.Provider_Hierarchies ph ON a.[Provider Code] = ph.[organisation_code] 

WHERE Dashboard NOT IN ('SNoMED CT','Outcomes CQUIN') AND Org_Type = 'Provider'

UPDATE a

SET a.UniqMonthID = h.UniqMonthID

FROM  MHDInternal.[STAGING_Data_Quality_Master_Table] a

LEFT JOIN MHDInternal.PreProc_Header h ON a.ReportingPeriodEndDate = h.ReportingPeriodEndDate


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CHANGE MAPPING FOR OUTCOMES & SNOMED TO ODS (MPL WHERE NOT PRESENT)
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

UPDATE a

SET 
a.[Provider name] = COALESCE(ph.[organisation_name],p.[ProviderName]),
a.[Region code] = COALESCE(ph.Region_Code, p.[RegionCode]),
a.[Region name] = COALESCE(ph.Region_Name, p.[RegionName]),
a.[stp code] = COALESCE(ph.stp_code,p.STPCode),
a.[stp name] = COALESCE(ph.stp_name,p.[stpname]),
a.Name_Source = CASE WHEN ph.Organisation_Name IS NOT NULL THEN 'ODS' 
WHEN p.OrgIDProvider IS NOT NULL THEN 'MPL' else [name_Source] END

FROM MHDInternal.[STAGING_Data_Quality_Master_Table] a

LEFT JOIN Reporting_UKHD_ODS.Provider_Hierarchies ph ON a.[Provider Code] = ph.[organisation_code] 
LEFT JOIN MHDInternal.[TEMP_CDP_Data_Quality_Master_MHSDSOrgs] p ON a.[Provider code] = p.[OrgIDProvider]

WHERE Dashboard IN ('SNoMED CT','Outcomes CQUIN') AND Org_Type = 'Provider'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CQUIN OUTCOMES FOR ICB LEVEL - GP Postcode methodology
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE AT ICB LEVEL 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_CQUIN23RefAgg_ICB') IS NOT NULL
DROP TABLE MHDInternal.Temp_CQUIN23RefAgg_ICB

SELECT
	m.ReportingPeriodEndDate,
	m.UniqMonthID,
	o.STP_Code AS [Organisation Code],
	o.STP_Name AS [Organisation Name],
	CAST(m.Der_ServiceType AS varchar(50)) AS [Service Type],

	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Closed' AND m.Der_ReferralLength >14 AND m.Der_InYearContacts >1 THEN m.UniqServReqID END) AS [Closed referrals open more than 14 days with two or more contacts],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Closed' AND m.Der_ReferralLength >14 AND m.Der_InYearContacts >1 AND m.Der_LastAssessmentDate IS NOT NULL THEN m.UniqServReqID END) AS [Closed referrals open more than 14 days with two or more contacts and a paired score],

	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Open' AND m.Der_InYearContacts >1 THEN m.UniqServReqID END) AS [Open referrals open more than six months with two or more contacts],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Open' AND m.Der_InYearContacts >1 AND m.Der_LastAssessmentDate IS NOT NULL THEN m.UniqServReqID END) AS [Open referrals open more than six months with two or more contacts and a paired score]

INTO MHDInternal.Temp_CQUIN23RefAgg_ICB

FROM MHDInternal.Temp_CQUIN23Master m

LEFT JOIN Reporting_UKHD_ODS.Commissioner_Hierarchies o ON m.OrgIDCCGRes COLLATE DATABASE_DEFAULT = o.Organisation_Code  COLLATE DATABASE_DEFAULT

WHERE m.Der_ServiceType = 'Community' 

GROUP BY m.ReportingPeriodEndDate, m.UniqMonthID, o.STP_Code, o.STP_Name, m.Der_ServiceType

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
Repeat for ICB-level combined CYP & PMH 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO MHDInternal.Temp_CQUIN23RefAgg_ICB

SELECT
	m.ReportingPeriodEndDate,
	m.UniqMonthID,
	o.STP_Code AS [Organisation Code],
	o.STP_Name AS [Organisation Name],
	'CYP and Perinatal' AS [Service Type],

	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Closed' AND m.Der_ReferralLength >14 AND m.Der_InYearContacts >1 THEN m.UniqServReqID END) AS [Closed referrals open more than 14 days with two or more contacts],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Closed' AND m.Der_ReferralLength >14 AND m.Der_InYearContacts >1 AND m.Der_LastAssessmentDate IS NOT NULL THEN m.UniqServReqID END) AS [Closed referrals open more than 14 days with two or more contacts and a paired score],

	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Open' AND m.Der_InYearContacts >1 THEN m.UniqServReqID END) AS [Open referrals open more than six months with two or more contacts],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Open' AND m.Der_InYearContacts >1 AND m.Der_LastAssessmentDate IS NOT NULL THEN m.UniqServReqID END) AS [Open referrals open more than six months with two or more contacts and a paired score]

FROM MHDInternal.Temp_CQUIN23Master m

LEFT JOIN Reporting_UKHD_ODS.Commissioner_Hierarchies o ON m.OrgIDCCGRes COLLATE DATABASE_DEFAULT = o.Organisation_Code  COLLATE DATABASE_DEFAULT

WHERE m.Der_ServiceType IN ('CYP','Perinatal') 

GROUP BY m.ReportingPeriodEndDate, m.UniqMonthID, o.STP_Code, o.STP_Name



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ROLLING THREE MONTH FIGURE FOR CLOSED REFERRAL
MEASURES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Temp_CQUIN23RefFinal_ICB') IS NOT NULL
DROP TABLE MHDInternal.Temp_CQUIN23RefFinal_ICB

SELECT
	r.ReportingPeriodEndDate,
	r.UniqMonthID,
	r.[Organisation Code],
	r.[Organisation Name],
	r.[Service Type],

	SUM(r.[Closed referrals open more than 14 days with two or more contacts]) OVER (PARTITION BY r.[Organisation Code], r.[Service Type]  ORDER BY r.UniqMonthID ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [Closed referrals open more than 14 days with two or more contacts (three month rolling)],
	SUM(r.[Closed referrals open more than 14 days with two or more contacts and a paired score]) OVER (PARTITION BY r.[Organisation Code], r.[Service Type]  ORDER BY r.UniqMonthID ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [Closed referrals open more than 14 days with two or more contacts and a paired score (three month rolling)] 

INTO MHDInternal.Temp_CQUIN23RefFinal_ICB

FROM MHDInternal.Temp_CQUIN23RefAgg_ICB r



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UNPIVOT AND PUT INTO STAGING TABLE 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.Staging_CQUIN23_ICB') IS NOT NULL
DROP TABLE MHDInternal.Staging_CQUIN23_ICB

SELECT  
	ReportingPeriodEndDate,
	UniqMonthID,
	[Organisation Code],
	[Organisation Name],
	[Service Type],
	'Percentages' AS [Dashboard],
	'Closed referrals' AS MeasureName,
	[Closed referrals open more than 14 days with two or more contacts and a paired score (three month rolling)] AS MeasureValue,
	[Closed referrals open more than 14 days with two or more contacts (three month rolling)] AS Denominator

INTO MHDInternal.Staging_CQUIN23_ICB

FROM MHDInternal.Temp_CQUIN23RefFinal_ICB

INSERT INTO MHDInternal.Staging_CQUIN23_ICB

SELECT
	ReportingPeriodEndDate,
	UniqMonthID,
	[Organisation Code],
	[Organisation Name],
	[Service Type],
	'Percentages' AS [Dashboard],
	'Open referrals' AS MeasureName,
	[Open referrals open more than six months with two or more contacts and a paired score] AS MeasureValue,
	[Open referrals open more than six months with two or more contacts] AS Denominator

FROM MHDInternal.Temp_CQUIN23RefAgg_ICB

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
OUTPUT FOR DQ REPORTING 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO MHDInternal.[STAGING_Data_Quality_Master_Table]

SELECT 
	c.ReportingPeriodEndDate,
	NULL AS UniqMonthID,
	'ICB' AS Org_Type,
	NULL AS [Provider code],
	NULL AS [Provider name],
	[Organisation Code] AS [STP code],
	[Organisation Name] AS [STP name],
	Region_Code AS [Region code],
	Region_Name AS [Region name],
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
	,'GP Postcode' AS Name_Source

FROM MHDInternal.Staging_CQUIN23_ICB c

LEFT JOIN (SELECT DISTINCT STP_Code, Region_Code, Region_Name 
					  FROM Reporting_UKHD_ODS.Commissioner_Hierarchies) r 
					    ON [Organisation Code] = r.STP_Code

GROUP BY c.ReportingPeriodEndDate, c.[Organisation Code], c.[Organisation Name], c.[Service Type], Region_Code, Region_Name 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET SNOMED COMPLIANCE - CARE CONTACTS GP POSTCODE ICB DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO MHDInternal.[STAGING_Data_Quality_Master_Table]

SELECT 
	a.ReportingPeriodEndDate
	,NULL AS UniqMonthID
	,'ICB' AS Org_Type
	,NULL AS [Provider code]
	,NULL AS [Provider name]
	,COALESCE(c.STP_Code,'Missing / Invalid') AS [STP code]
	,COALESCE(c.STP_Name,'Missing / Invalid') AS [STP name] 
	,COALESCE(c.Region_Code, 'Missing / Invalid') AS [Region code]
	,COALESCE(c.Region_Name, 'Missing / Invalid') AS [Region name]
	,'N/A' AS Der_CurrentSubmissionWindow
	,'N/A' AS Der_OrgSubmissionStatus
	,'SNoMED CT' AS Dashboard
	,'Coverage' AS Breakdown
	,'Care contacts' AS [Breakdown category]
	,'Contacts with SNoMED CT' AS MeasureName
	,COUNT(DISTINCT i.UniqCareContID) AS MeasureValue
	,'Total contacts' AS DenominatorName
	,COUNT(DISTINCT a.UniqCareContID) AS DenominatorValue
	,'SNoMED CT' AS TargetName
	,70 AS TargetValue
	,'GP Postcode' AS Name_Source

FROM MHDInternal.PreProc_Activity a 

LEFT JOIN MHDInternal.PreProc_Interventions i ON a.UniqCareContID = i.UniqCareContID AND a.RecordNumber = i.RecordNumber

INNER JOIN MHDInternal.PreProc_Referral r ON a.RecordNumber = r.RecordNumber AND a.UniqServReqID = r.UniqServReqID 
	
LEFT JOIN  [Reporting_UKHD_ODS].[Commissioner_Hierarchies] c ON r.Der_SubICBCode = c.Organisation_Code COLLATE DATABASE_DEFAULT

WHERE a.UniqMonthID >= @StartRP AND a.AttendOrDNACode IN ('5','6')

GROUP BY a.ReportingPeriodEndDate ,COALESCE(c.STP_Code,'Missing / Invalid') ,COALESCE(c.Region_Code, 'Missing / Invalid'), COALESCE(c.STP_Name,'Missing / Invalid'),COALESCE(c.Region_Name, 'Missing / Invalid')



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET SNOMED COMPLIANCE - INDIRECT ACTIVITY GP POSTCODE ICB DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO MHDInternal.[STAGING_Data_Quality_Master_Table]

SELECT
	a.ReportingPeriodEndDate
	,NULL AS UniqMonthID
	,'ICB' AS Org_Type
	,NULL AS [Provider code]
	,NULL AS [Provider name]
	,COALESCE(c.STP_Code,'Missing / Invalid') AS [STP code]
	,COALESCE(c.STP_Name,'Missing / Invalid') AS [STP name] 
	,COALESCE(c.Region_Code, 'Missing / Invalid') AS [Region code]
	,COALESCE(c.Region_Name, 'Missing / Invalid') AS [Region name]
	,'N/A' AS Der_CurrentSubmissionWindow
	,'N/A' AS Der_OrgSubmissionStatus
	,'SNoMED CT' AS Dashboard
	,'Coverage' AS Breakdown
	,'Indirect activity' AS [Breakdown category]
	,'Contacts with SNoMED CT' AS MeasureName
	,COUNT(DISTINCT i.Der_InterventionUniqID) AS MeasureValue
	,'Total contacts' AS DenominatorName
	,COUNT(DISTINCT a.Der_ActivityUniqID) AS DenominatorValue
	,'SNoMED CT' AS TargetName
	,70 AS TargetValue
	,'GP Postcode' AS Name_Source

FROM  MHDInternal.PreProc_Activity a  

LEFT JOIN MHDInternal.PreProc_Interventions i ON a.Der_ActivityUniqID = i.Der_InterventionUniqID AND a.RecordNumber = i.RecordNumber AND i.Der_InterventionType = 'Indirect'

INNER JOIN MHDInternal.PreProc_Referral r ON a.RecordNumber = r.RecordNumber AND a.UniqServReqID = r.UniqServReqID 

LEFT JOIN Reporting_UKHD_ODS.Commissioner_Hierarchies c ON r.Der_SubICBCode = c.Organisation_Code COLLATE DATABASE_DEFAULT

WHERE a.Der_ActivityType = 'Indirect' AND a.UniqMonthID >= @StartRP

GROUP BY a.ReportingPeriodEndDate, COALESCE(c.STP_Code,'Missing / Invalid'), COALESCE(c.Region_Code, 'Missing / Invalid'), COALESCE(c.STP_Name,'Missing / Invalid'),COALESCE(c.Region_Name, 'Missing / Invalid')


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DROP TEMPORARY TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DROP TABLE MHDInternal.[TEMP_CDP_Data_Quality_Master_MHSDSOrgs]
DROP TABLE MHDInternal.[TEMP_CDP_Data_Quality_Master_Base]
DROP TABLE MHDInternal.[TEMP_CDP_Data_Quality_Master_OrgStat]
DROP TABLE MHDInternal.[TEMP_CDP_Data_Quality_Master_Submission_History]
