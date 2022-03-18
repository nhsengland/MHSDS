USE [NHSE_Sandbox_MentalHealth]
GO
/****** Object:  StoredProcedure [dbo].[Reporting_CQUIN22/23]    Script Date: 18/03/2022 10:33:49 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER PROCEDURE [dbo].[Reporting_CQUIN22/23]
AS

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CQUIN REPORTING

ASSET: PRE-PROCESSED TABLES

CREATED BY CARL MONEY 09/03/2022

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--SET VARIABLES

DECLARE @EndRP INT

SET @EndRP	= (SELECT UniqMonthID
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE Der_MostRecentFlag = 'P')

DECLARE @StartRP INT

SET @StartRP = @EndRP - 14 -- last 14 months

DECLARE @ReportingPeriodEnd DATE

SET @ReportingPeriodEnd = (SELECT ReportingPeriodEndDate
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE Der_MostRecentFlag = 'Y') -- to get the date of the last performance window

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LOG START
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'CQUIN Report Start' AS Step,
	GETDATE() AS [TimeStamp]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ALL CLOSED REFERRALS AND OPEN REFERRALS FOR 
THE LATEST PERIOD
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRef') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRef

SELECT
	r.ReportingPeriodEndDate,
	r.Der_FY,
	r.UniqMonthID,
	CASE WHEN r.OrgIDProv = 'DFC' THEN '1' ELSE r.Person_ID END AS Der_PersonID,
	r.UniqServReqID,
	r.RecordNumber,
	r.OrgIDProv,
	r.ReferralRequestReceivedDate,
	r.ServDischDate,
	DATEDIFF(DD,r.ReferralRequestReceivedDate, r.ServDischDate) AS Der_ReferralLength,
	CASE 
		WHEN r.AgeServReferRecDate < 18 THEN 'CYP'
		WHEN r.ServTeamTypeRefToMH = 'C02' THEN 'Perinatal'
		ELSE 'Community'
	END AS Der_ServiceType,
	CASE WHEN r.ServDischDate IS NOT NULL THEN 'Closed' ELSE 'Open' END AS Der_RefCategory

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRef

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Referral r

WHERE r.UniqMonthID BETWEEN @StartRP AND @EndRP

AND ((r.ServTeamTypeRefToMH IN ('A04','A05','A06','A07','A08','A09','A10','A12','A13','A16','C02','C03','C09','C10') 
	OR r.ServTeamTypeRefToMH IS NULL) -- to include specific adult teams
	
	OR (r.UniqMonthID < 1459 AND r.ServTeamTypeRefToMH IN ('A02','A03')) -- older crisis teams retired in v5. Will remove when 21/22 data no longer needed

	OR ((r.AgeServReferRecDate BETWEEN 0 AND 17) AND r.ServTeamTypeRefToMH NOT IN ('B02','E01','E02','E03','E04','A14'))) -- and everyone under 18 at the time of the referral not accessing LDA or EIP services

AND (r.ServDischDate IS NOT NULL OR DATEDIFF(DD,r.ReferralRequestReceivedDate, r.ReportingPeriodEndDate) >182) -- to include closed referrals or those open at the end of the month with a referral length of at least six months

AND r.ReferRejectionDate IS NULL -- exclude rejected referrals

AND (r.LADistrictAuth LIKE 'E%' OR r.LADistrictAuth IS NULL) -- to limit to those people whose commissioner is an English organisation

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ALL CONTACTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINCont') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINCont

SELECT
	r.UniqMonthID,
	r.Der_PersonID,
	r.UniqServReqID,
	r.RecordNumber,
	r.Der_ServiceType,
	SUM(CASE WHEN a.Der_FY = r.Der_FY AND a.Der_ActivityType = 'DIRECT' AND a.Der_FYContactOrder IS NOT NULL THEN 1 ELSE 0 END) AS Der_ContDirCYP, --counting attended direct activity (excluding SMS or email) for the <18s in the FY
	SUM(CASE WHEN a.Der_FY = r.Der_FY AND a.Der_ActivityType = 'INDIRECT' AND a.Der_FYContactOrder IS NOT NULL THEN 1 ELSE 0 END) AS Der_ContIndCYP, --counting indirect activity (excluding SMS or email) for the <18s in the FY
	MAX(CASE WHEN a.Der_FY = r.Der_FY THEN a.Der_FYDirectContactOrder END) AS Der_ContDir, -- excluding indirect and direct SMS or email activity for >=18s in the FY
	MAX(CASE WHEN a.Der_FY = r.Der_FY THEN a.Der_FYFacetoFaceContactOrder END) AS Der_ContF2F, -- counting face to face contacts only for perinatal services in the FY
	MAX(CASE WHEN a.Der_ContactOrder = 1 THEN a.Der_ContactDate ELSE NULL END) AS Der_FirstContactDate, -- get first contact date for referral 
	MAX(CASE WHEN a.Der_ContactOrder = 2 THEN a.Der_ContactDate ELSE NULL END) AS Der_SecondContactDate  -- get second contact date for referral

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINCont

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRef r

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a ON CASE WHEN a.OrgIDProv = 'DFC' THEN '1' ELSE a.Person_ID END = r.Der_PersonID AND a.UniqServReqID = r.UniqServReqID AND a.UniqMonthID <= r.UniqMonthID

GROUP BY r.Der_FY, r.UniqMonthID, r.Der_PersonID, r.UniqServReqID, r.RecordNumber, r.OrgIDProv, r.Der_ServiceType

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ASSESSMENTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINAss') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINAss

SELECT
	c.UniqServReqID,
	c.RecordNumber,
	c.Der_ServiceType,
	c.Der_FirstContactDate,
	c.Der_SecondContactDate,
	r.CYPMH,
	a.Der_AssToolCompDate, -- the completion date of the assessment
	a.CodedAssToolType,
	a.Der_AssessmentCategory, -- to identify if this is a PROM, PREM or CROM
	a.Der_AssessmentToolName, --the tool name from the MHSDS reference table in the TOS
	a.Der_PreferredTermSNOMED, --the preferred term for the assessment scale
	a.Der_AssOrderAsc -- the ascending order of the assessment

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINAss

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINCont c

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Assessments a ON CASE WHEN a.OrgIDProv = 'DFC' THEN '1' ELSE a.Person_ID END = c.Der_PersonID AND a.UniqServReqID = c.UniqServReqID AND a.UniqMonthID <= c.UniqMonthID -- assessments can't take place in the future

LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[Reference_MHAssessments] r ON a.CodedAssToolType = r.[Active Concept ID (SNOMED CT)]  -- to identify specific CYPMH assessments

WHERE a.Der_ValidScore = 'Y' -- removes records with invalid scores

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET FIRST ASSESSMENTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- CMH / PERINATAL

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINFirstAss') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINFirstAss

SELECT
	a.UniqServReqID,
	a.RecordNumber,
	a.Der_AssessmentCategory,
	a.Der_AssessmentToolName,
	a.CodedAssToolType,
	a.Der_AssToolCompDate AS Der_FirstAssessmentDate

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINFirstAss

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINAss a

WHERE a.Der_AssOrderAsc = 1 AND a.Der_ServiceType <> 'CYP'

-- CYP

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINFirstAss

SELECT
	a.UniqServReqID,
	a.RecordNumber,
	a.Der_AssessmentCategory,
	a.Der_AssessmentToolName,
	a.CodedAssToolType,
	MIN(a.Der_AssToolCompDate) AS Der_FirstAssessmentDate

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINAss a

WHERE a.Der_ServiceType = 'CYP'
AND a.Der_AssToolCompDate >= a.Der_FirstContactDate -- must be on or after the first contact
AND a.CYPMH = 'Y' -- to limit to specific CYPMH assessments

GROUP BY a.UniqServReqID, a.RecordNumber, Der_AssessmentCategory, a.Der_AssessmentToolName, a.CodedAssToolType

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET LAST ASSESSMENTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- CMH / PERINATAL

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINLastAss') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINLastAss

SELECT
	a.UniqServReqID,
	a.RecordNumber,
	a.CodedAssToolType,
	a.Der_AssessmentToolName,
	MAX(a.Der_AssToolCompDate) AS Der_LastAssessmentDate

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINLastAss

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINAss a

WHERE a.Der_AssOrderAsc > 1 AND a.Der_ServiceType <> 'CYP'

GROUP BY a.UniqServReqID, a.RecordNumber, a.Der_AssessmentToolName, a.CodedAssToolType

-- CYP

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINLastAss

SELECT
	a.UniqServReqID,
	a.RecordNumber,
	a.CodedAssToolType,
	a.Der_AssessmentToolName,
	MAX(a.Der_AssToolCompDate) AS Der_LastAssessmentDate

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINAss a

WHERE a.Der_AssToolCompDate >= a.Der_SecondContactDate AND a.Der_AssOrderAsc > 1 
AND a.Der_ServiceType = 'CYP' -- must be on or after the second contact
AND a.CYPMH = 'Y' -- to limit to specific CYPMH assessments

GROUP BY a.UniqServReqID, a.RecordNumber, a.Der_AssessmentToolName, a.CodedAssToolType

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CREATE MASTER TABLE THAT JOINS CONTACTS AND 
ASSESSMENTS TO REFERRALS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINMaster') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINMaster

SELECT
	r.ReportingPeriodEndDate,
	r.UniqMonthID,
	r.Der_PersonID,
	r.UniqServReqID,
	r.RecordNumber,
	r.OrgIDProv,
	r.ReferralRequestReceivedDate,
	r.ServDischDate,
	r.Der_ReferralLength,
	r.Der_ServiceType,
	r.Der_RefCategory,
	CASE
		WHEN r.Der_ServiceType = 'CYP' 
			THEN CASE WHEN c.Der_ContDirCYP > c.Der_ContIndCYP THEN c.Der_ContDirCYP ELSE c.Der_ContIndCYP END -- to count direct and indirect contacts seperately so we don't get in the situation where a person has one indirect and one direct contact
		WHEN r.Der_ServiceType = 'Perinatal' THEN c.Der_ContF2F
		ELSE c.Der_ContDir
	END AS Der_InYearContacts,
	a1.Der_FirstAssessmentDate,
	a1.Der_AssessmentToolName,
	a1.Der_AssessmentCategory,
	a2.Der_LastAssessmentDate

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINMaster

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRef r

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINCont c ON c.RecordNumber = r.RecordNumber AND c.UniqServReqID = r.UniqServReqID

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINFirstAss a1 ON a1.RecordNumber = r.RecordNumber AND a1.UniqServReqID = r.UniqServReqID

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINLastAss a2 ON a2.RecordNumber = r.RecordNumber AND a2.UniqServReqID = r.UniqServReqID AND a1.CodedAssToolType = a2.CodedAssToolType AND a2.Der_LastAssessmentDate > a1.Der_FirstAssessmentDate 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET DISTINCT LIST OF MHSDS SUBMISSION DATES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#MHSDSDates') IS NOT NULL
DROP TABLE #MHSDSDates

SELECT DISTINCT
	m.ReportingPeriodEndDate,
	m.UniqMonthID

INTO #MHSDSDates

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINMaster m

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET DISTINCT LIST OF PROVIDERS AND SERVICES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#MHSDSOrgs') IS NOT NULL
DROP TABLE #MHSDSOrgs

SELECT DISTINCT
	m.OrgIDProv,
	m.Der_ServiceType

INTO #MHSDSOrgs

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINMaster m

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
COMBINE LIST OF DATES AND ORGS TO MAKE SURE ALL
MONTHS ARE REPORTED AGAINST
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#OrgDates') IS NOT NULL
DROP TABLE #OrgDates

SELECT
	d.ReportingPeriodEndDate,
	d.UniqMonthID,
	o.OrgIDProv,
	o.Der_ServiceType

INTO #OrgDates

FROM #MHSDSDates d, #MHSDSOrgs o


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE AT REFERRAL LEVEL
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRefAgg') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRefAgg

SELECT
	o.ReportingPeriodEndDate,
	o.UniqMonthID,
	o.OrgIDProv AS [Organisation Code],
	CAST(o.Der_ServiceType AS varchar(50)) AS [Service Type],

	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Closed' THEN m.UniqServReqID END) AS [Closed Referrals],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Closed' AND m.Der_ReferralLength >14 THEN UniqServReqID END) AS [Closed referrals open more than 14 days],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Closed' AND m.Der_ReferralLength >14 AND m.Der_InYearContacts = 1 THEN m.UniqServReqID END) AS [Closed referrals open more than 14 days with one contact],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Closed' AND m.Der_ReferralLength >14 AND m.Der_InYearContacts >1 THEN m.UniqServReqID END) AS [Closed referrals open more than 14 days with two or more contacts],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Closed' AND m.Der_ReferralLength >14 AND m.Der_InYearContacts >1 AND m.Der_FirstAssessmentDate IS NOT NULL THEN m.UniqServReqID END) AS [Closed referrals open more than 14 days with two or more contacts and one assessment],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Closed' AND m.Der_ReferralLength >14 AND m.Der_InYearContacts >1 AND m.Der_LastAssessmentDate IS NOT NULL THEN m.UniqServReqID END) AS [Closed referrals open more than 14 days with two or more contacts and a paired score],

	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Open' THEN UniqServReqID END) AS [Open referrals open more than six months],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Open' AND m.Der_InYearContacts = 1 THEN m.UniqServReqID END) AS [Open referrals open more than six months with one contact],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Open' AND m.Der_InYearContacts >1 THEN m.UniqServReqID END) AS [Open referrals open more than six months with two or more contacts],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Open' AND m.Der_InYearContacts >1 AND m.Der_FirstAssessmentDate IS NOT NULL THEN m.UniqServReqID END) AS [Open referrals open more than six months with two or more contacts and one assessment],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Open' AND m.Der_InYearContacts >1 AND m.Der_LastAssessmentDate IS NOT NULL THEN m.UniqServReqID END) AS [Open referrals open more than six months with two or more contacts and a paired score]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRefAgg

FROM #OrgDates o

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINMaster m ON m.ReportingPeriodEndDate = o.ReportingPeriodEndDate AND m.OrgIDProv = o.OrgIDProv AND m.Der_ServiceType = o.Der_ServiceType

GROUP BY o.ReportingPeriodEndDate, o.UniqMonthID, o.OrgIDProv, o.Der_ServiceType

-- CREATE A COMBINED CYP AND PERINATAL COHORT HERE

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRefAgg

SELECT
	m.ReportingPeriodEndDate,
	m.UniqMonthID,
	m.[Organisation Code],
	'CYP and Perinatal' AS [Service Type],

	SUM(m.[Closed Referrals]) AS [Closed referrals],
	SUM(m.[Closed referrals open more than 14 days]) AS [Closed referrals open more than 14 days],
	SUM(m.[Closed referrals open more than 14 days with one contact]) AS [Closed referrals open more than 14 days with one contact],
	SUM(m.[Closed referrals open more than 14 days with two or more contacts]) AS [Closed referrals open more than 14 days with two or more contacts],
	SUM(m.[Closed referrals open more than 14 days with two or more contacts and one assessment]) AS [Closed referrals open more than 14 days with two or more contacts and one assessment],
	SUM(m.[Closed referrals open more than 14 days with two or more contacts and a paired score]) AS [Closed referrals open more than 14 days with two or more contacts and a paired score],

	SUM(m.[Open referrals open more than six months]) AS [Open referrals open more than six months],
	SUM(m.[Open referrals open more than six months with one contact]) AS [Open referrals open more than six months with one contact],
	SUM(m.[Open referrals open more than six months with two or more contacts]) AS [Open referrals open more than six months with two or more contacts],
	SUM(m.[Open referrals open more than six months with two or more contacts and one assessment]) AS [Open referrals open more than six months with two or more contacts and one assessment],
	SUM(m.[Open referrals open more than six months with two or more contacts and a paired score]) AS [Open referrals open more than six months with two or more contacts and a paired score]

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRefAgg m

WHERE m.[Service Type] <> 'Community'

GROUP BY m.ReportingPeriodEndDate, m.UniqMonthID, m.[Organisation Code]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ROLLING THREE MONTH FIGURE FOR CLOSED REFERRAL
MEASURES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRefFinal') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRefFinal

SELECT
	r.ReportingPeriodEndDate,
	r.UniqMonthID,
	r.[Organisation Code],
	r.[Service Type],

	SUM(r.[Closed Referrals]) OVER (PARTITION BY r.[Organisation Code], r.[Service Type] ORDER BY r.UniqMonthID ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [Closed referrals (three month rolling)],
	SUM(r.[Closed referrals open more than 14 days]) OVER (PARTITION BY r.[Organisation Code], r.[Service Type]  ORDER BY r.UniqMonthID ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [Closed referrals open more than 14 days (three month rolling)],
	SUM(r.[Closed referrals open more than 14 days with one contact]) OVER (PARTITION BY r.[Organisation Code], r.[Service Type] ORDER BY r.UniqMonthID ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [Closed referrals open more than 14 days with one contact (three month rolling)],
	SUM(r.[Closed referrals open more than 14 days with two or more contacts]) OVER (PARTITION BY r.[Organisation Code], r.[Service Type]  ORDER BY r.UniqMonthID ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [Closed referrals open more than 14 days with two or more contacts (three month rolling)],
	SUM(r.[Closed referrals open more than 14 days with two or more contacts and one assessment]) OVER (PARTITION BY r.[Organisation Code], r.[Service Type] ORDER BY r.UniqMonthID ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [Closed referrals open more than 14 days with two or more contacts and one assessment (three month rolling)],
	SUM(r.[Closed referrals open more than 14 days with two or more contacts and a paired score]) OVER (PARTITION BY r.[Organisation Code], r.[Service Type]  ORDER BY r.UniqMonthID ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [Closed referrals open more than 14 days with two or more contacts and a paired score (three month rolling)]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRefFinal

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRefAgg r

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET PROM REPORTING AND DUPLICATE REFERRALS COUNTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- IDENTIFIY REFERRAL IDENTIFIERS USED MORE THAN ONCE

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINDuplicate') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINDuplicate

SELECT
	d.OrgIDProv,
	COUNT(DISTINCT d.UniqServReqID) AS [Number of distinct referrals],
	COUNT(d.UniqServReqID) - COUNT(DISTINCT d.UniqServReqID) AS [Number of reused referral identifiers]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINDuplicate

FROM
(
SELECT DISTINCT
	r.OrgIDProv, 
	r.UniqServReqID, 
	r.UniqMonthID 

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRef r 

WHERE (r.Der_RefCategory = 'Closed' AND r.UniqMonthID BETWEEN @EndRP - 12 AND @EndRP - 1)
	OR (r.Der_RefCategory = 'Open' AND r.UniqMonthID = @EndRP - 1)) d

GROUP BY d.OrgIDProv 

-- COMBINE WITH PROM REPORTING

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINContext') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINContext

SELECT
	m.OrgIDProv AS [Organisation Code],
	COUNT(DISTINCT CASE WHEN m.Der_ServiceType = 'Community' AND m.Der_InYearContacts >1 AND ((m.Der_RefCategory = 'Closed' AND m.Der_ReferralLength >14) OR m.Der_RefCategory = 'Open') THEN m.UniqServReqID END) AS [Referrals to community services],
	COUNT(DISTINCT CASE WHEN m.Der_ServiceType = 'Community' AND m.Der_InYearContacts >1 AND ((m.Der_RefCategory = 'Closed' AND m.Der_ReferralLength >14) OR m.Der_RefCategory = 'Open') AND m.Der_AssessmentCategory = 'PROM' AND m.Der_LastAssessmentDate IS NOT NULL THEN m.UniqServReqID END) AS [Referrals to community services with two or more PROMs recorded],
	MAX(d.[Number of distinct referrals]) AS [Number of distinct referrals],
	MAX(d.[Number of reused referral identifiers]) AS [Number of reused referral identifiers]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINContext

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINMaster m

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINDuplicate d ON d.OrgIDProv = m.OrgIDProv

WHERE m.UniqMonthID BETWEEN @EndRP - 12 AND @EndRP - 1 -- to looks back over last 12 months, excluding primary data here

GROUP BY m.OrgIDProv 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UNPIVOT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINUnPiv') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINUnPiv

SELECT 
	ReportingPeriodEndDate,
	UniqMonthID,
	[Organisation Code],
	[Service Type],
	CAST('Counts' AS varchar(50)) AS [Dashboard],
	MeasureName,
	MeasureValue,
	NULL AS Denominator

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINUnpiv

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRefAgg

UNPIVOT (MeasureValue FOR MeasureName IN 
	([Closed Referrals], [Closed referrals open more than 14 days], [Closed referrals open more than 14 days with one contact], [Closed referrals open more than 14 days with two or more contacts],[Closed referrals open more than 14 days with two or more contacts and one assessment],[Closed referrals open more than 14 days with two or more contacts and a paired score],
	[Open referrals open more than six months], [Open referrals open more than six months with one contact], [Open referrals open more than six months with two or more contacts], [Open referrals open more than six months with two or more contacts and one assessment], [Open referrals open more than six months with two or more contacts and a paired score])) AS u

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINUnpiv

SELECT 
	ReportingPeriodEndDate,
	UniqMonthID,
	[Organisation Code],
	[Service Type],
	'Counts' AS Dashboard,
	MeasureName,
	MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRefFinal

UNPIVOT (MeasureValue FOR MeasureName IN ([Closed referrals (three month rolling)], [Closed referrals open more than 14 days (three month rolling)], [Closed referrals open more than 14 days with one contact (three month rolling)], [Closed referrals open more than 14 days with two or more contacts (three month rolling)],
	[Closed referrals open more than 14 days with two or more contacts and one assessment (three month rolling)], [Closed referrals open more than 14 days with two or more contacts and a paired score (three month rolling)])) AS u

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINUnpiv

SELECT 
	@ReportingPeriodEnd AS ReportingPeriodEndDate,
	@EndRP - 1 AS UniqMonthID,
	[Organisation Code],
	'Community' AS [Service Type],
	'Context' AS Dashboard,
	MeasureName,
	MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINContext 

UNPIVOT (MeasureValue FOR MeasureName IN ([Referrals to community services], [Referrals to community services with two or more PROMs recorded], [Number of distinct referrals], [Number of reused referral identifiers])) AS u

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINUnpiv

SELECT 
	ReportingPeriodEndDate,
	UniqMonthID,
	[Organisation Code],
	[Service Type],
	'Percentages' AS [Dashboard],
	'Open referrals' AS MeasureName,
	[Open referrals open more than six months with two or more contacts and a paired score] AS MeasureValue,
	[Open referrals open more than six months with two or more contacts] AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRefAgg

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINUnpiv

SELECT 
	ReportingPeriodEndDate,
	UniqMonthID,
	[Organisation Code],
	[Service Type],
	'Percentages' AS [Dashboard],
	'Closed referrals' AS MeasureName,
	[Closed referrals open more than 14 days with two or more contacts and a paired score (three month rolling)] AS MeasureValue,
	[Closed referrals open more than 14 days with two or more contacts (three month rolling)] AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINRefFinal 

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINUnpiv

SELECT 
	@ReportingPeriodEnd AS ReportingPeriodEndDate,
	@EndRP - 1 AS UniqMonthID,
	[Organisation Code],
	'All' AS [Service Type],
	'Percentages - context' AS [Dashboard],
	'Reused referrals' AS MeasureName,
	[Number of reused referral identifiers] AS MeasureValue,
	[Number of distinct referrals] AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINContext 

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINUnpiv

SELECT 
	@ReportingPeriodEnd AS ReportingPeriodEndDate,
	@EndRP - 1 AS UniqMonthID,
	[Organisation Code],
	'Community' AS [Service Type],
	'Percentages - context' AS [Dashboard],
	'Referrals with paired PROM' AS MeasureName,
	[Referrals to community services with two or more PROMs recorded] AS MeasureValue,
	[Referrals to community services] AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINContext 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LINK TO REFERENCE DATA AND CREATE EXTRACT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CQUIN2223]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CQUIN2223]

SELECT
	u.ReportingPeriodEndDate,
	CASE 
		WHEN u.UniqMonthID = @EndRP THEN 'Provisional'
		WHEN u.UniqMonthID = @EndRP - 1 THEN 'Performance'
		ELSE 'Historical'
	END AS [Reporting period description],
	p.Region_Code,
	p.Region_Name AS [Region name],
	u.[Organisation Code],
	p.Organisation_Name AS [Organisation name],
	u.[Service Type],
	u.Dashboard,
	u.MeasureName,
	u.MeasureValue,
	u.Denominator

INTO NHSE_Sandbox_MentalHealth.dbo.Dashboard_CQUIN2223

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINUnpiv u

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies p ON u.[Organisation Code] = p.Organisation_Code

WHERE u.UniqMonthID >= @endRP - 12

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
TIDY UP
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DROP TABLE "Temp_CQUINAss"
DROP TABLE "Temp_CQUINCont"
DROP TABLE "Temp_CQUINContext"
DROP TABLE "Temp_CQUINDuplicate"
DROP TABLE "Temp_CQUINFirstAss"
DROP TABLE "Temp_CQUINLastAss"
DROP TABLE "Temp_CQUINMaster"
DROP TABLE "Temp_CQUINRef"
DROP TABLE "Temp_CQUINRefAgg"
DROP TABLE "Temp_CQUINRefFinal"
DROP TABLE "Temp_CQUINUnpiv"

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LOG END
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'CQUIN Report End' AS Step,
	GETDATE() AS [TimeStamp]
