/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CQUIN REPORTING 2023/24

CREATED 9 MARCH 2023 BY TB
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--SET VARIABLES

DECLARE @EndRP INT

SET @EndRP	= (SELECT UniqMonthID
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE Der_MostRecentFlag = 'P')

DECLARE @StartRP INT

--SET @StartRP = @EndRP - 14 -- last 14 months
SET @StartRP = 1465 -- April 2022 as a consistent baseline

DECLARE @ReportingPeriodEnd DATE

SET @ReportingPeriodEnd = (SELECT ReportingPeriodEndDate
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE Der_MostRecentFlag = 'Y') -- to get the date of the last performance window


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ALL CLOSED REFERRALS AND OPEN REFERRALS FOR 
THE LATEST PERIOD
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ref') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ref

SELECT
	r.ReportingPeriodEndDate,
	r.Der_FY,
	r.UniqMonthID,
	CASE WHEN r.OrgIDProv = 'DFC' THEN '1' ELSE r.Person_ID END AS Der_PersonID,
	r.UniqServReqID,
	r.RecordNumber,
	r.OrgIDProv,
	r.OrgIDCCGRes,
	r.ReferralRequestReceivedDate,
	r.ServDischDate,
	DATEDIFF(DD,r.ReferralRequestReceivedDate, r.ServDischDate) AS Der_ReferralLength,
	CASE 
		WHEN r.AgeServReferRecDate < 18 THEN 'CYP'
		WHEN r.ServTeamTypeRefToMH = 'C02' THEN 'Perinatal'
		ELSE 'Community'
	END AS Der_ServiceType,
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate THEN 'Closed' ELSE 'Open' END AS Der_RefCategory

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ref

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Referral r

WHERE r.UniqMonthID BETWEEN @StartRP AND @EndRP

AND ((r.ServTeamTypeRefToMH IN ('A02','A05','A06','A08','A09','A10','A12','A13','A16','C02','C10') 
	OR r.ServTeamTypeRefToMH IS NULL) -- to include specific adult teams
	
	OR (r.UniqMonthID < 1459 AND r.ServTeamTypeRefToMH IN ('A03','A04')) -- older crisis teams retired in v5. Will remove when 21/22 data no longer needed

	OR ((r.AgeServReferRecDate BETWEEN 0 AND 17) AND r.ServTeamTypeRefToMH NOT IN ('B02','E01','E02','E03','E04','A14'))) -- and everyone under 18 at the time of the referral not accessing LDA or EIP services

AND (r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate OR DATEDIFF(DD,r.ReferralRequestReceivedDate, r.ReportingPeriodEndDate) >182) -- to include closed referrals or those open at the end of the month with a referral length of at least six months

AND r.ReferRejectionDate IS NULL -- exclude rejected referrals

AND (r.LADistrictAuth LIKE 'E%' OR r.LADistrictAuth IS NULL) -- to limit to those people whose commissioner is an English organisation

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DELETE REFERRALS TO INPATIENT SERVICES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DELETE FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ref WHERE CONCAT(Der_PersonID,UniqServReqID,Der_FY) IN (SELECT CONCAT(Person_ID,UniqServReqID,Der_FY) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Inpatients) 


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ICB FROM GP PRACTICE 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINGP') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINGP

SELECT
g.RecordNumber,
g.GMPCodeReg

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINGP

FROM NHSE_MHSDS.dbo.MHS002GP g

INNER JOIN NHSE_MH_PrePublication.Test.MHSDS_SubmissionFlags s ON g.NHSEUniqSubmissionID = s.NHSEUniqSubmissionID AND s.Der_IsLatest = 'Y'

WHERE g.EndDateGMPRegistration IS NULL
AND g.UniqMonthID BETWEEN @StartRP AND @EndRP 

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINGP

SELECT
g.RecordNumber,
g.GMPCodeReg

FROM NHSE_MH_PrePublication.test.MHS002GP g

INNER JOIN NHSE_MH_PrePublication.Test.MHSDS_SubmissionFlags s ON g.NHSEUniqSubmissionID = s.NHSEUniqSubmissionID AND s.Der_IsLatest = 'Y'

WHERE g.EndDateGMPRegistration IS NULL

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ALL CONTACTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Cont') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Cont

SELECT
	a.UniqMonthID,
	a.Der_FY,
	CASE WHEN a.OrgIDProv = 'DFC' THEN '1' ELSE a.Person_ID END AS Der_PersonID,
	a.UniqServReqID,
	a.RecordNumber,
	a.Der_ActivityType,
	a.Der_ContactDate,
	a.Der_Contact,
	a.Der_DirectContact,
	a.Der_FacetoFaceContact,
	ROW_NUMBER() OVER (PARTITION BY CASE WHEN a.OrgIDProv = 'DFC' THEN '1' ELSE a.Person_ID END, a.UniqServReqID ORDER BY a.Der_ContactDate ASC, a.Der_ContactTime ASC, a.Der_ActivityUniqID ASC) AS ContRN

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Cont

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ref r

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a ON a.RecordNumber = r.RecordNumber AND a.UniqServReqID = r.UniqServReqID

WHERE a.Der_Contact IS NOT NULL -- to remove contacts that were not attended

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE CONTACTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23ContAgg') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23ContAgg

SELECT
	r.UniqMonthID,
	r.Der_PersonID,
	r.UniqServReqID,
	r.RecordNumber,
	r.Der_ServiceType,
	ISNULL(SUM(CASE WHEN a.Der_FY = r.Der_FY AND a.Der_ActivityType = 'DIRECT' THEN a.Der_Contact END),0) AS Der_ContDirCYP, --counting attended direct activity (excluding SMS or email) for the <18s in the FY
	ISNULL(SUM(CASE WHEN a.Der_FY = r.Der_FY AND a.Der_ActivityType = 'INDIRECT' THEN a.Der_Contact ELSE 0 END),0) AS Der_ContIndCYP, --counting indirect activity for the <18s in the FY
	ISNULL(SUM(CASE WHEN a.Der_FY = r.Der_FY THEN a.Der_DirectContact ELSE 0 END),0) AS Der_ContDir, -- excluding indirect and direct SMS or email activity for >=18s in the FY
	ISNULL(SUM(CASE WHEN a.Der_FY = r.Der_FY THEN a.Der_FacetoFaceContact ELSE 0 END),0) AS Der_ContF2F, -- counting face to face contacts only for perinatal services in the FY
	MIN(a.Der_ContactDate) AS Der_FirstContactDate -- get first contact date for referral 
	
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23ContAgg

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ref r

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a ON CASE WHEN a.OrgIDProv = 'DFC' THEN '1' ELSE a.Person_ID END = r.Der_PersonID 
	AND a.UniqServReqID = r.UniqServReqID AND a.UniqMonthID <= r.UniqMonthID
	AND a.Der_Contact = 1 -- to remove contacts that were not attended

GROUP BY r.Der_FY, r.UniqMonthID, r.Der_PersonID, r.UniqServReqID, r.RecordNumber, r.OrgIDProv, r.Der_ServiceType

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ASSESSMENTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ass') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ass

SELECT
	c.UniqServReqID,
	c.RecordNumber,
	c.Der_ServiceType,
	c.Der_FirstContactDate,
	r.CYPMH,
	a.Der_AssToolCompDate, -- the completion date of the assessment
	a.CodedAssToolType,
	a.Der_AssessmentCategory, -- to identify if this is a PROM, PREM or CROM
	a.Der_AssessmentToolName, --the tool name from the MHSDS reference table in the TOS
	a.Der_PreferredTermSNOMED, --the preferred term for the assessment scale
	a.Der_AssOrderAsc -- the ascending order of the assessment

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ass

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23ContAgg c

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Assessments a ON CASE WHEN a.OrgIDProv = 'DFC' THEN '1' ELSE a.Person_ID END = c.Der_PersonID AND a.UniqServReqID = c.UniqServReqID AND a.UniqMonthID <= c.UniqMonthID -- assessments can't take place in the future

LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[Reference_MHAssessments] r ON a.CodedAssToolType = r.[Active Concept ID (SNOMED CT)]  -- to identify specific CYPMH assessments

WHERE a.Der_ValidScore = 'Y' -- removes records with invalid scores


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET FIRST ASSESSMENTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- CMH / PERINATAL

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23FirstAss') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23FirstAss

SELECT
	a.UniqServReqID,
	a.RecordNumber,
	a.Der_AssessmentCategory,
	a.Der_AssessmentToolName,
	a.CodedAssToolType,
	a.Der_AssToolCompDate AS Der_FirstAssessmentDate

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23FirstAss

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ass a

WHERE a.Der_AssOrderAsc = 1 

-- CYP

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23FirstAss

SELECT
	a.UniqServReqID,
	a.RecordNumber,
	a.Der_AssessmentCategory,
	a.Der_AssessmentToolName,
	a.CodedAssToolType,
	MIN(a.Der_AssToolCompDate) AS Der_FirstAssessmentDate

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ass a

WHERE a.Der_ServiceType = 'CYP'
AND a.CYPMH = 'Y' -- to limit to specific CYPMH assessments

GROUP BY a.UniqServReqID, a.RecordNumber, Der_AssessmentCategory, a.Der_AssessmentToolName, a.CodedAssToolType

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET LAST ASSESSMENTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- CMH / PERINATAL

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23LastAss') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23LastAss

SELECT
	a.UniqServReqID,
	a.RecordNumber,
	a.CodedAssToolType,
	a.Der_AssessmentToolName,
	MAX(a.Der_AssToolCompDate) AS Der_LastAssessmentDate

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23LastAss

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ass a

WHERE a.Der_AssOrderAsc > 1 AND a.Der_ServiceType <> 'CYP'

GROUP BY a.UniqServReqID, a.RecordNumber, a.Der_AssessmentToolName, a.CodedAssToolType

-- CYP

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23LastAss

SELECT
	a.UniqServReqID,
	a.RecordNumber,
	a.CodedAssToolType,
	a.Der_AssessmentToolName,
	MAX(a.Der_AssToolCompDate) AS Der_LastAssessmentDate

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ass a

WHERE a.Der_AssOrderAsc > 1 
AND a.Der_ServiceType = 'CYP' -- must be on or after the first contact
AND a.CYPMH = 'Y' -- to limit to specific CYPMH assessments

GROUP BY a.UniqServReqID, a.RecordNumber, a.Der_AssessmentToolName, a.CodedAssToolType

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CREATE MASTER TABLE THAT JOINS CONTACTS AND 
ASSESSMENTS TO REFERRALS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Master') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Master

SELECT
	r.ReportingPeriodEndDate,
	r.UniqMonthID,
	r.Der_PersonID,
	r.UniqServReqID,
	r.RecordNumber,
	r.OrgIDProv,
	ISNULL(gh.GP_CCG_Code, r.OrgIDCCGRes) AS Der_OrgIDCCG, --- CCG from GP or, if missing, from person postcode 
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

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Master

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ref r

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINGP g ON r.RecordNumber = g.RecordNumber 

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_GP_Hierarchies gh ON g.GMPCodeReg = gh.GP_Code

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23ContAgg c ON c.RecordNumber = r.RecordNumber AND c.UniqServReqID = r.UniqServReqID

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23FirstAss a1 ON a1.RecordNumber = r.RecordNumber AND a1.UniqServReqID = r.UniqServReqID

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23LastAss a2 ON a2.RecordNumber = r.RecordNumber AND a2.UniqServReqID = r.UniqServReqID AND a1.CodedAssToolType = a2.CodedAssToolType AND a2.Der_LastAssessmentDate > a1.Der_FirstAssessmentDate 


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

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefAgg') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefAgg

SELECT
	o.ReportingPeriodEndDate,
	o.UniqMonthID,
	o.OrgIDProv AS [Organisation Code],
	CAST(o.Der_ServiceType AS varchar(50)) AS [Service Type],
	--- Any outcome measure 
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
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Open' AND m.Der_InYearContacts >1 AND m.Der_LastAssessmentDate IS NOT NULL THEN m.UniqServReqID END) AS [Open referrals open more than six months with two or more contacts and a paired score],

	-- PROMs only (NEW for 23/24)
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Closed' AND m.Der_ReferralLength >14 AND m.Der_InYearContacts >1 AND m.Der_FirstAssessmentDate IS NOT NULL AND m.Der_AssessmentCategory = 'PROM' THEN m.UniqServReqID END) AS [Closed referrals open more than 14 days with two or more contacts and one PROM],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Closed' AND m.Der_ReferralLength >14 AND m.Der_InYearContacts >1 AND m.Der_LastAssessmentDate IS NOT NULL AND m.Der_AssessmentCategory = 'PROM' THEN m.UniqServReqID END) AS [Closed referrals open more than 14 days with two or more contacts and a paired PROM],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Open' AND m.Der_InYearContacts >1 AND m.Der_FirstAssessmentDate IS NOT NULL AND m.Der_AssessmentCategory = 'PROM' THEN m.UniqServReqID END) AS [Open referrals open more than six months with two or more contacts and one PROM],
	COUNT(DISTINCT CASE WHEN m.Der_RefCategory = 'Open' AND m.Der_InYearContacts >1 AND m.Der_LastAssessmentDate IS NOT NULL AND m.Der_AssessmentCategory = 'PROM' THEN m.UniqServReqID END) AS [Open referrals open more than six months with two or more contacts and a paired PROM]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefAgg

FROM #OrgDates o

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Master m ON m.ReportingPeriodEndDate = o.ReportingPeriodEndDate AND m.OrgIDProv = o.OrgIDProv AND m.Der_ServiceType = o.Der_ServiceType

GROUP BY o.ReportingPeriodEndDate, o.UniqMonthID, o.OrgIDProv, o.Der_ServiceType


-- CREATE A COMBINED CYP AND PERINATAL COHORT HERE

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefAgg

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
	SUM(m.[Closed referrals open more than 14 days with two or more contacts and one PROM]) AS [Closed referrals open more than 14 days with two or more contacts and one PROM],
	SUM(m.[Closed referrals open more than 14 days with two or more contacts and a paired PROM]) AS [Closed referrals open more than 14 days with two or more contacts and a paired PROM],

	SUM(m.[Open referrals open more than six months]) AS [Open referrals open more than six months],
	SUM(m.[Open referrals open more than six months with one contact]) AS [Open referrals open more than six months with one contact],
	SUM(m.[Open referrals open more than six months with two or more contacts]) AS [Open referrals open more than six months with two or more contacts],
	SUM(m.[Open referrals open more than six months with two or more contacts and one assessment]) AS [Open referrals open more than six months with two or more contacts and one assessment],
	SUM(m.[Open referrals open more than six months with two or more contacts and a paired score]) AS [Open referrals open more than six months with two or more contacts and a paired score],
	SUM(m.[Open referrals open more than six months with two or more contacts and one PROM]) AS [Open referrals open more than six months with two or more contacts and one PROM],
	SUM(m.[Open referrals open more than six months with two or more contacts and a paired PROM]) AS [Open referrals open more than six months with two or more contacts and a paired PROM]

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefAgg m

WHERE m.[Service Type] <> 'Community'

GROUP BY m.ReportingPeriodEndDate, m.UniqMonthID, m.[Organisation Code]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ROLLING THREE MONTH FIGURE FOR CLOSED REFERRAL
MEASURES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefFinal') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefFinal

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
	SUM(r.[Closed referrals open more than 14 days with two or more contacts and a paired score]) OVER (PARTITION BY r.[Organisation Code], r.[Service Type]  ORDER BY r.UniqMonthID ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [Closed referrals open more than 14 days with two or more contacts and a paired score (three month rolling)], 
	SUM(r.[Closed referrals open more than 14 days with two or more contacts and one PROM]) OVER (PARTITION BY r.[Organisation Code], r.[Service Type]  ORDER BY r.UniqMonthID ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [Closed referrals open more than 14 days with two or more contacts and one PROM (three month rolling)],
	SUM(r.[Closed referrals open more than 14 days with two or more contacts and a paired PROM]) OVER (PARTITION BY r.[Organisation Code], r.[Service Type]  ORDER BY r.UniqMonthID ASC ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [Closed referrals open more than 14 days with two or more contacts and a paired PROM (three month rolling)]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefFinal

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefAgg r

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE AT ASSESSMENT LEVEL
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23AssAgg') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23AssAgg

SELECT
	m.ReportingPeriodEndDate,
	m.UniqMonthID,
	m.OrgIDProv,
	m.Der_ServiceType,
	m.Der_AssessmentCategory,
	m.Der_AssessmentToolName,
	SUM(CASE WHEN m.Der_LastAssessmentDate IS NOT NULL THEN 1 ELSE 0 END) AS [Number of paired scores]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23AssAgg

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Master m

GROUP BY m.ReportingPeriodEndDate, m.UniqMonthID, m.OrgIDProv, m.Der_ServiceType, m.Der_AssessmentCategory, m.Der_AssessmentToolName


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UNPIVOT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23UnPiv') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23UnPiv

SELECT 
	ReportingPeriodEndDate,
	UniqMonthID,
	[Organisation Code],
	[Service Type],
	CAST('Counts' AS varchar(25)) AS [Dashboard],
	CAST('Counts' AS varchar(25)) AS MeasureGroup,
	MeasureName,
	MeasureValue,
	NULL AS Denominator

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Unpiv

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefAgg

UNPIVOT (MeasureValue FOR MeasureName IN 
	([Closed Referrals], [Closed referrals open more than 14 days], [Closed referrals open more than 14 days with one contact], [Closed referrals open more than 14 days with two or more contacts],[Closed referrals open more than 14 days with two or more contacts and one assessment],[Closed referrals open more than 14 days with two or more contacts and a paired score], [Closed referrals open more than 14 days with two or more contacts and one PROM], [Closed referrals open more than 14 days with two or more contacts and a paired PROM],
	[Open referrals open more than six months], [Open referrals open more than six months with one contact], [Open referrals open more than six months with two or more contacts], [Open referrals open more than six months with two or more contacts and one assessment], [Open referrals open more than six months with two or more contacts and a paired score],[Open referrals open more than six months with two or more contacts and one PROM],[Open referrals open more than six months with two or more contacts and a paired PROM] )) AS u

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Unpiv

SELECT 
	ReportingPeriodEndDate,
	UniqMonthID,
	[Organisation Code],
	[Service Type],
	'Counts' AS Dashboard,
	'Counts' AS MeasureGroup,
	MeasureName,
	MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefFinal

UNPIVOT (MeasureValue FOR MeasureName IN ([Closed referrals (three month rolling)], [Closed referrals open more than 14 days (three month rolling)], [Closed referrals open more than 14 days with one contact (three month rolling)], [Closed referrals open more than 14 days with two or more contacts (three month rolling)],
	[Closed referrals open more than 14 days with two or more contacts and one assessment (three month rolling)], [Closed referrals open more than 14 days with two or more contacts and a paired score (three month rolling)],[Closed referrals open more than 14 days with two or more contacts and one PROM (three month rolling)],[Closed referrals open more than 14 days with two or more contacts and a paired PROM (three month rolling)] )) AS u

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Unpiv

SELECT 
	ReportingPeriodEndDate,
	UniqMonthID,
	[Organisation Code],
	[Service Type],
	'Percentages' AS [Dashboard],
	'All OMs' AS MeasureGroup,
	'Open referrals' AS MeasureName,
	[Open referrals open more than six months with two or more contacts and a paired score] AS MeasureValue,
	[Open referrals open more than six months with two or more contacts] AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefAgg

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Unpiv

SELECT 
	ReportingPeriodEndDate,
	UniqMonthID,
	[Organisation Code],
	[Service Type],
	'Percentages' AS [Dashboard],
	'All OMs' AS MeasureGroup,
	'Closed referrals' AS MeasureName,
	[Closed referrals open more than 14 days with two or more contacts and a paired score (three month rolling)] AS MeasureValue,
	[Closed referrals open more than 14 days with two or more contacts (three month rolling)] AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefFinal 

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Unpiv

SELECT 
	ReportingPeriodEndDate,
	UniqMonthID,
	[Organisation Code],
	[Service Type],
	'Percentages' AS [Dashboard],
	'PROMs' AS MeasureGroup,
	'Open referrals' AS MeasureName,
	[Open referrals open more than six months with two or more contacts and a paired PROM] AS MeasureValue,
	[Open referrals open more than six months with two or more contacts] AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefAgg

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Unpiv

SELECT 
	ReportingPeriodEndDate,
	UniqMonthID,
	[Organisation Code],
	[Service Type],
	'Percentages' AS [Dashboard],
	'PROMs' AS MeasureGroup,
	'Closed referrals' AS MeasureName,
	[Closed referrals open more than 14 days with two or more contacts and a paired PROM (three month rolling)] AS MeasureValue,
	[Closed referrals open more than 14 days with two or more contacts (three month rolling)] AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefFinal 

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Unpiv

SELECT
	ReportingPeriodEndDate,
	UniqMonthID,
	OrgIDProv AS [Organisation Code],
	Der_ServiceType AS [Service Type],
	'Assessments' AS [Dashboard],
	Der_AssessmentCategory AS MeasureGroup,
	Der_AssessmentToolName AS MeasureName,
	[Number of paired scores] AS MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23AssAgg



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LINK TO REFERENCE DATA AND CREATE EXTRACT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/


DECLARE @EndRP INT

SET @EndRP	= (SELECT UniqMonthID
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE Der_MostRecentFlag = 'P')

DECLARE @StartRP INT

--SET @StartRP = @EndRP - 14 -- last 14 months
SET @StartRP = 1465 -- April 2022 as a consistent baseline

IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CQUIN2324]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CQUIN2324]

SELECT
	u.ReportingPeriodEndDate,
	CASE 
		WHEN u.UniqMonthID = @EndRP THEN 'Provisional'
		WHEN u.UniqMonthID = @EndRP - 1 THEN 'Performance'
		ELSE 'Historical'
	END AS [Reporting period description],
	CASE 
		WHEN u.[Organisation Code] LIKE 'R%' OR u.[Organisation Code] LIKE 'T%' THEN 'NHS'
		ELSE 'IS'
	END AS [Organisation type],
	p.Region_Code,
	p.Region_Name AS [Region name],
	u.[Organisation Code],
	p.Organisation_Name AS [Organisation name],
	u.[Service Type],
	u.Dashboard,
	u.MeasureName,
	u.MeasureGroup,
	u.MeasureValue,
	u.Denominator

INTO NHSE_Sandbox_MentalHealth.dbo.Dashboard_CQUIN2324

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Unpiv u

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies p ON u.[Organisation Code] = p.Organisation_Code

WHERE u.UniqMonthID >= @StartRP

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DROP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ass
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Cont
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23FirstAss
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23LastAss
--DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINMaster
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Ref
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefAgg
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23RefFinal
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23AssAgg
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUIN23Unpiv
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CQUINGP


