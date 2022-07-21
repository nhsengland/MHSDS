/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PTSMI DASHBOARD MHSDS DATA

ASSET: PRE-PROCESSED TABLES

CREATED BY CARL MONEY 10/06/2021

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

----SET VARIABLES

DECLARE @EndRP INT

SET @EndRP	= (SELECT UniqMonthID
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE Der_MostRecentFlag = 'P')

DECLARE @StartRP INT

SET @StartRP = 1429 -- Apr 19 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LOG START
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Update PTSMHP Dashboard Start' AS Step,
	GETDATE() AS [TimeStamp]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ALL INTERVENTIONS OF INTEREST
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_PTSMHP_Act') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_PTSMHP_Act

SELECT 
	i.ReportingPeriodEndDate,
	r.OrgIDProv AS [Provider code],
	p.Organisation_Name AS [Provider name],
	COALESCE(p.Region_Code,'Missing / Invalid') AS [Region code],
	COALESCE(p.Region_Name,'Missing / Invalid') AS [Region name],
	COALESCE(t.Main_Description, 'Missing / invalid') AS [Team type],
	ROW_NUMBER() OVER (PARTITION BY r.Person_ID, r.UniqServReqID, i.Der_SNoMEDProcTerm ORDER BY a.Der_ContactDate ASC, a.Der_ContactTime ASC, a.Der_ActivityUniqID ASC) AS Der_TherapyRN,
	i.Der_SNoMEDProcTerm

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_PTSMHP_Act

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Interventions] i

LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity] a ON i.RecordNumber = a.RecordNumber AND i.UniqServReqID = a.UniqServReqID AND i.UniqCareContID = a.UniqCareContID

LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Referral] r ON a.RecordNumber = r.RecordNumber AND a.UniqServReqID = r.UniqServReqID 

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_DataDic_ZZZ_ServiceOrTeamTypeForMentalHealth t ON r.ServTeamTypeRefToMH = t.Main_Code_Text COLLATE DATABASE_DEFAULT AND t.Effective_To IS NULL AND t.Valid_To IS NULL

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies p ON r.OrgIDProv = p.Organisation_Code

WHERE i.UniqMonthID BETWEEN @StartRP AND @EndRP 
	AND i.Der_SNoMEDProcCode IN 
	('65153003', -- Art therapy (regime/therapy)
	'718026005', -- Cognitive behavioral therapy for psychosis (regime/therapy)
	'1111811000000109', -- Cognitive behavioural therapy for eating disorders (regime/therapy)
	'149451000000104', -- Cognitive behavioural therapy for personality disorder (regime/therapy)
	'390773006', -- Cognitive analytic therapy (regime/therapy)
	'405780009', -- Dialectical behavior therapy (regime/therapy)
	'1323681000000103', -- Eating-disorder-focused focal psychodynamic therapy (regime/therapy)
	'985451000000105', --Family intervention for psychosis (regime/therapy)
	'1108261000000102', -- Interpersonal and social rhythm therapy (regime/therapy)
	'1106951000000105', -- Interpersonal psychotherapy for group (regime/therapy)
	'1111681000000103', -- Mentalisation based treatment (regime/therapy)
	'1323471000000102', -- Maudsley Model of Anorexia Nervosa Treatment for Adults (regime/therapy) (MANTRA)
	'1111691000000101', -- Schema focused therapy (regime/therapy)
	'1111671000000100') -- Transference focused psychotherapy (regime/therapy)
	AND r.AgeServReferRecDate >= 18 -- to exclude under 18s
	AND (i.Der_SNoMEDProcQual != '443390004' OR i.Der_SNoMEDProcQual IS NULL) -- to exclude refused interventions

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
INSERT INTO PTSMI TABLE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DELETE FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_PTSMHP] WHERE [Survey type] = 'MHSDS'

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_PTSMHP]

SELECT
	NULL AS [ID],
	a.ReportingPeriodEndDate AS [Completion time],
	'MHSDS' AS [Survey type],
	a.[Provider code],
	a.[Provider name],
	a.[Region code],
	a.[Region name],
	NULL AS [Postcode],
	NULL AS [Der_RegionONSCode],
	a.[Team type] AS [Team name],
	NULL AS [Professional group],
	a.Der_SNoMEDProcTerm AS [Therapy type],
	'Number of theraputic interventions' AS MeasureName,
	COUNT(a.Der_SNoMEDProcTerm) AS MeasureValue,
	SUM(CASE WHEN a.Der_TherapyRN = 1 THEN 1 ELSE 0 END) AS Counter

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_PTSMHP_Act a

GROUP BY a.ReportingPeriodEndDate, a.[Provider code], a.[Provider name], a.[Region code], a.[Region name], a.[Team type], a.Der_SNoMEDProcTerm 
