/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CQUIN REPORTING

CREATED BY CARL MONEY 26/02/19
UPDATED 10/05/19 -	SEE META DATA FILE FOR CHANGES
UPDATED 10/09/19 -	NO CHANGE IN LOGIC BUT SOME FIELD AND DATABASE NAME CHANGES AS A RESULT OF THE NEW EXTRACT
					REMOVAL OF THE ProcSchemeInUse FIELD IN THE SNOMED SECTION
					CHANGES TO THE PSEUDO PERSON ID LOGIC
UPDATED 17/10/19 -	IAPT DATA NOW REPORTED AT PROVIDER LEVEL, RATHER THAN SITE
UPDATED 23/12/19 -	ADDED ADDITIONAL LOGIC AROUND PANIC DISORDER FOR IAPT CQUIN, ADDED A USE SUBMISSION FLAG ON MHSDS 
					(TO IDENTIFY LAST GOOD FILE IN A PARTICULAR MONTH NOW WE RECEIVE PRIMARY DATA) AND ADDED ROLLING
					6 MONTH DATA
UPDATED 31/01/20 -	UPDATED LOGIC AROUND ONWARD REFERRALS. THIS NOW LOOKS AT ONWARD REFERRALS THAT OCCUR DURING THE 
					HOSPITAL SPELL OF INTEREST
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--SET VARIABLES

DECLARE @StartRP INT
DECLARE @EndRP INT
DECLARE @ReportingPeriodEnd DATETIME
DECLARE @ReportingPeriodStart DATETIME
DECLARE @IAPTPeriod_start DATE
DECLARE @IAPTPeriod_end DATE 

SET @StartRP = 1417 --April 2018

SET @EndRP	= (SELECT MAX(UniqMonthID)
			FROM [NHSE_MHSDS].[dbo].[MHS000Header]
			WHERE FileType = 'Refresh')

SET @ReportingPeriodStart = (SELECT MAX(ReportingPeriodStartDate)
FROM [NHSE_MHSDS].[dbo].[MHS000Header]
WHERE UniqMonthID = @StartRP)

SET @ReportingPeriodEnd = (SELECT MAX(ReportingPeriodEndDate)
FROM [NHSE_MHSDS].[dbo].[MHS000Header]
WHERE UniqMonthID = @EndRP)

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DATA QUALITY CQUIN
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
REFERRALS WITH TWO CONTACTS AND AT LEAST ONE 
INTERVENTION RECORDED
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDENTIFY LATEST VERSION OF REFERRALS THAT STARTED AFTER 
1st JAN 2016 AND WERE NOT REJECTED.
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Ref') IS NOT NULL
DROP TABLE #Ref

SELECT DISTINCT
	r.UniqMonthID,
	r.OrgIDProv,	
	r.Person_ID,
	r.UniqServReqID,
	r.RecordNumber

INTO #Ref

FROM [NHSE_MHSDS].[dbo].[MHS101Referral] r 

LEFT JOIN [NHSE_MHSDS].[dbo].[MHS102ServiceTypeReferredTo] s ON r.UniqServReqID = s.UniqServReqID AND r.RecordNumber = s.RecordNumber

INNER JOIN [NHSE_MHSDS].[dbo].[MHS001MPI] m ON r.RecordNumber = m.RecordNumber AND (m.LADistrictAuth LIKE 'E%' OR m.LADistrictAuth IS NULL)

WHERE r.UniqMonthID BETWEEN @StartRP AND @EndRP AND r.Der_Use_Submission_Flag = 'Y' AND r.ReferralRequestReceivedDate >= '2016-01-01' AND s.ReferRejectionDate IS NULL

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ALL ATTENDED CONTACTS (NOT EMAIL OR SMS) AND INDIRECT ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

if OBJECT_ID('tempdb..#Cont') is not null
drop table #Cont

SELECT
	c.UniqMonthID,
	c.OrgIDProv,
	c.Person_ID,
	c.UniqServReqID,
	c.RecordNumber,
	c.UniqCareContID AS 'ContID',
	c.CareContDate AS 'ContDate',
	c.ConsMediumUsed

INTO #Cont

FROM [NHSE_MHSDS].[dbo].[MHS201CareContact] c

WHERE c.UniqMonthID <=@EndRP AND c.Der_Use_Submission_Flag = 'Y' AND c.AttendOrDNACode IN ('5','6') and c.ConsMediumUsed NOT IN ('05','06')

INSERT INTO #Cont

SELECT
	i.UniqMonthID,
	i.OrgIDProv,
	i.Person_ID,
	i.UniqServReqID,
	i.RecordNumber,
	CAST(i.MHS204UniqID AS nvarchar (35)) AS 'ContID',
	i.IndirectActDate AS 'ContDate',
	NULL AS ConsMediumUsed

FROM [NHSE_MHSDS].[dbo].[MHS204IndirectActivity] i

WHERE i.UniqMonthID <=@EndRP AND i.Der_Use_Submission_Flag = 'Y'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LINK CONTACTS AND INDIRECT ACTIVITY TO REFERRAL AND RANK BY REFERRAL
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

if OBJECT_ID('tempdb..#ContSort') is not null
drop table #ContSort

SELECT
	r.UniqMonthID,
	r.OrgIDProv,
	r.Person_ID,
	r.UniqServReqID,
	r.RecordNumber,
	c.ContID,
	c.ContDate,
	ROW_NUMBER () OVER(PARTITION BY c.Person_ID, c.UniqServReqID ORDER BY c.ContDate ASC, c.ContID ASC) AS 'ContRN'

INTO #ContSort

FROM #Cont c

INNER JOIN #Ref r ON r.RecordNumber = c.RecordNumber AND r.UniqServReqID = c.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET SNOMED PROCEDURES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Proc') IS NOT NULL
DROP TABLE #Proc

SELECT
	c.UniqMonthID,
	c.OrgIDProv,
	c.Person_ID,
	c.UniqServReqID,
	cc.CareContDate,
	c.UniqCareContID,
	c.CodeProcAndProcStatus,
	CASE
		WHEN CHARINDEX(':',c.CodeProcAndProcStatus) > 0
		THEN LEFT(c.CodeProcAndProcStatus,CHARINDEX(':',c.CodeProcAndProcStatus)-1)
		ELSE c.CodeProcAndProcStatus
	END AS StrippedSNOMED

INTO #Proc

FROM [NHSE_MHSDS].[dbo].[MHS202CareActivity] c

INNER JOIN [NHSE_MHSDS].[dbo].[MHS201CareContact] cc ON c.Person_ID = cc.Person_ID AND c.UniqServReqID = cc.UniqServReqID AND c.UniqCareContID = cc.UniqCareContID AND cc.Der_Use_Submission_Flag = 'Y'

WHERE c.UniqMonthID <=@EndRP AND c.Der_Use_Submission_Flag = 'Y' AND ISNUMERIC(LEFT(c.CodeProcAndProcStatus, 1)) = 1 AND ISNUMERIC(RIGHT(c.CodeProcAndProcStatus, 1)) = 1

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDENTIFY VALID SNOMED CODES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#ValProc') IS NOT NULL
DROP TABLE #ValProc

SELECT
	p.UniqMonthID,
	p.OrgIDProv,
	p.Person_ID,
	p.UniqServReqID,
	p.CareContDate,
	p.StrippedSNOMED,
	s.Term,
	CASE WHEN s.Effective_To IS NULL OR s.Effective_To > p.CareContDate THEN 'Current' ELSE 'Retired' END AS CodeStatus

INTO #ValProc

FROM #Proc p

INNER JOIN [NHSE_UKHF].[SNOMED].[vw_Descriptions_SCD] s ON 	p.StrippedSNOMED = CAST(s.[Concept_ID] AS VARCHAR) AND s.Type_ID = 900000000000003001 AND s.Is_Latest = 1

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LINK PROCEDURES TO THOSE REFERRALS THAT HAD TWO 
CONTACTS IN THE REPORTING PERIOD
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#ContProc') IS NOT NULL
DROP TABLE #ContProc

SELECT
	c.UniqMonthID,
	c.OrgIDProv,
	c.Person_ID,
	c.UniqServReqID,
	COUNT(CASE WHEN v.CodeStatus = 'Current' THEN v.StrippedSNOMED END) AS CurrentSNOMEDCodes,
	COUNT(CASE WHEN v.CodeStatus = 'Retired' THEN v.StrippedSNOMED END) AS RetiredSNOMEDCodes,
	COUNT(v.StrippedSNOMED) AS AllSNOMEDCodes

INTO #ContProc

FROM #ContSort c

LEFT JOIN #ValProc v ON c.UniqServReqID = v.UniqServReqID AND c.Person_ID = v.Person_ID

WHERE ContRN = 2

GROUP BY c.UniqMonthID, c.OrgIDProv, c.Person_ID, c.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE BY MONTH AND PROVIDER
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#AggInt') IS NOT NULL
DROP TABLE #AggInt

SELECT
	c.UniqMonthID,
	c.OrgIdProv,
	COUNT(c.UniqServReqID) AS ReferralsTwoConts,
	SUM(CASE WHEN c.CurrentSNOMEDCodes >= 1 THEN 1 ELSE 0 END) AS CurrentSNOMEDCodes,
	SUM(CASE WHEN c.RetiredSNOMEDCodes >= 1 THEN 1 ELSE 0 END) AS RetiredSNOMEDCodes,
	SUM(CASE WHEN c.AllSNOMEDCodes >= 1 THEN 1 ELSE 0 END) AS AllSNOMEDCodes

INTO #AggInt

FROM #ContProc c

GROUP BY c.UniqMonthID, c.OrgIdProv

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET DISTINCT CODES SUBMITTED BY MONTH, FOR THE LAST
SIX MONTHS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#ProvInt') IS NOT NULL
DROP TABLE #ProvInt

SELECT
	i.UniqMonthID,
	i.OrgIdProv,
	COUNT(DISTINCT p.StrippedSNOMED) AS UniqSNOMED,
	COUNT(CASE WHEN p.CodeStatus = 'Current' THEN p.StrippedSNOMED END) AS CurrentSNOMEDCodes,
	COUNT(CASE WHEN p.CodeStatus = 'Retired' THEN p.StrippedSNOMED END) AS RetiredSNOMEDCodes


INTO #ProvInt

FROM #AggInt i

LEFT JOIN 
(SELECT DISTINCT
	p.UniqMonthID,
	p.OrgIDProv,
	p.CodeStatus,
	p.StrippedSNOMED

FROM #ValProc p

WHERE UniqMonthID >= @StartRP -5) p ON i.OrgIDProv = p.OrgIDProv AND p.UniqMonthID BETWEEN (i.UniqMonthID - 5) AND i.UniqMonthID

GROUP BY i.UniqMonthID, i.OrgIdProv

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DATA QUALITY MATURITY INDEX (DQMI)
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET DQMI AND EXPERIMENTAL DATA ITEM SCORES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#DQMI') IS NOT NULL
DROP TABLE #DQMI

SELECT
	d.[Reporting Period To] AS [Reporting Period End],
	d.[Data Provider Code],
	MAX(CASE WHEN d.[Recoded Data Item] = 'ACTIVITY LOCATION TYPE CODE' THEN d.[Data Item Score] END) AS [ACTIVITY LOCATION TYPE CODE Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'ATTENDED OR DID NOT ATTEND' THEN d.[Data Item Score] END) AS [ATTENDED OR DID NOT ATTEND Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'CARE CONTACT TIME (HOUR)' THEN d.[Data Item Score] END) AS [CARE CONTACT TIME (HOUR) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'CARE PLAN TYPE' THEN d.[Data Item Score] END) AS [CARE PLAN TYPE Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH)' THEN d.[Data Item Score] END) AS [CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER)' THEN d.[Data Item Score] END) AS [CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'CONSULTATION MEDIUM USED' THEN d.[Data Item Score] END) AS [CONSULTATION MEDIUM USED Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'DELAYED DISCHARGE ATTRIBUTABLE TO' THEN d.[Data Item Score] END) AS [DELAYED DISCHARGE ATTRIBUTABLE TO Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'DELAYED DISCHARGE REASON' THEN d.[Data Item Score] END) AS [DELAYED DISCHARGE REASON Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'DISCHARGE PLAN CREATION TIME (HOUR)' THEN d.[Data Item Score] END) AS [DISCHARGE PLAN CREATION TIME (HOUR) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'ESTIMATED DISCHARGE DATE' THEN d.[Data Item Score] END) AS [ESTIMATED DISCHARGE DATE Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'ETHNIC CATEGORY' THEN d.[Data Item Score] END) AS [ETHNIC CATEGORY Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'EX-BRITISH ARMED FORCES INDICATOR' THEN d.[Data Item Score] END) AS [EX-BRITISH ARMED FORCES INDICATOR Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION)' THEN d.[Data Item Score] END) AS [GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'HOSPITAL BED TYPE (MENTAL HEALTH)' THEN d.[Data Item Score] END) AS [HOSPITAL BED TYPE (MENTAL HEALTH) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'INDIRECT ACTIVITY TIME (HOUR)' THEN d.[Data Item Score] END) AS [INDIRECT ACTIVITY TIME (HOUR) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE' THEN d.[Data Item Score] END) AS [MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'NHS NUMBER' THEN d.[Data Item Score] END) AS [NHS NUMBER Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'ONWARD REFERRAL TIME (HOUR)' THEN d.[Data Item Score] END) AS [ONWARD REFERRAL TIME (HOUR) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'ORGANISATION IDENTIFIER (CODE OF COMMISSIONER)' THEN d.[Data Item Score] END) AS [ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'ORGANISATION SITE IDENTIFIER (OF TREATMENT)' THEN d.[Data Item Score] END) AS [ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'PERSON BIRTH DATE' THEN d.[Data Item Score] END) AS [PERSON BIRTH DATE Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'PERSON STATED GENDER CODE' THEN d.[Data Item Score] END) AS [PERSON STATED GENDER CODE Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'POSTCODE OF USUAL ADDRESS' THEN d.[Data Item Score] END) AS [POSTCODE OF USUAL ADDRESS Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'PRIMARY DIAGNOSIS DATE' THEN d.[Data Item Score] END) AS [PRIMARY DIAGNOSIS DATE Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016)' THEN d.[Data Item Score] END) AS [PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'PROVISIONAL DIAGNOSIS DATE' THEN d.[Data Item Score] END) AS [PROVISIONAL DIAGNOSIS DATE Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'REFERRAL CLOSURE REASON' THEN d.[Data Item Score] END) AS [REFERRAL CLOSURE REASON Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'REFERRAL REQUEST RECEIVED TIME (HOUR)' THEN d.[Data Item Score] END) AS [REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH)' THEN d.[Data Item Score] END) AS [REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'SECONDARY DIAGNOSIS DATE' THEN d.[Data Item Score] END) AS [SECONDARY DIAGNOSIS DATE Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'SERVICE DISCHARGE TIME (HOUR)' THEN d.[Data Item Score] END) AS [SERVICE DISCHARGE TIME (HOUR) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH)' THEN d.[Data Item Score] END) AS [SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'SOURCE OF REFERRAL' THEN d.[Data Item Score] END) AS [SOURCE OF REFERRAL Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY' THEN d.[Data Item Score] END) AS [SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'TREATMENT FUNCTION CODE (MENTAL HEALTH)' THEN d.[Data Item Score] END) AS [TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'ACTIVITY LOCATION TYPE CODE' THEN d.[National Data Item Average] END) AS [ACTIVITY LOCATION TYPE CODE Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'ATTENDED OR DID NOT ATTEND' THEN d.[National Data Item Average] END) AS [ATTENDED OR DID NOT ATTEND Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'CARE CONTACT TIME (HOUR)' THEN d.[National Data Item Average] END) AS [CARE CONTACT TIME (HOUR) Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'CARE PLAN TYPE' THEN d.[National Data Item Average] END) AS [CARE PLAN TYPE Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH)' THEN d.[National Data Item Average] END) AS [CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER)' THEN d.[National Data Item Average] END) AS [CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'CONSULTATION MEDIUM USED' THEN d.[National Data Item Average] END) AS [CONSULTATION MEDIUM USED Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'DELAYED DISCHARGE ATTRIBUTABLE TO' THEN d.[National Data Item Average] END) AS [DELAYED DISCHARGE ATTRIBUTABLE TO Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'DELAYED DISCHARGE REASON' THEN d.[National Data Item Average] END) AS [DELAYED DISCHARGE REASON Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'DISCHARGE PLAN CREATION TIME (HOUR)' THEN d.[National Data Item Average] END) AS [DISCHARGE PLAN CREATION TIME (HOUR) Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'ESTIMATED DISCHARGE DATE' THEN d.[National Data Item Average] END) AS [ESTIMATED DISCHARGE DATE Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'ETHNIC CATEGORY' THEN d.[National Data Item Average] END) AS [ETHNIC CATEGORY Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'EX-BRITISH ARMED FORCES INDICATOR' THEN d.[National Data Item Average] END) AS [EX-BRITISH ARMED FORCES INDICATOR Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION)' THEN d.[National Data Item Average] END) AS [GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'HOSPITAL BED TYPE (MENTAL HEALTH)' THEN d.[National Data Item Average] END) AS [HOSPITAL BED TYPE (MENTAL HEALTH) Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'INDIRECT ACTIVITY TIME (HOUR)' THEN d.[National Data Item Average] END) AS [INDIRECT ACTIVITY TIME (HOUR) Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE' THEN d.[National Data Item Average] END) AS [MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'NHS NUMBER' THEN d.[National Data Item Average] END) AS [NHS NUMBER Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'ONWARD REFERRAL TIME (HOUR)' THEN d.[National Data Item Average] END) AS [ONWARD REFERRAL TIME (HOUR) Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'ORGANISATION IDENTIFIER (CODE OF COMMISSIONER)' THEN d.[National Data Item Average] END) AS [ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'ORGANISATION SITE IDENTIFIER (OF TREATMENT)' THEN d.[National Data Item Average] END) AS [ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'PERSON BIRTH DATE' THEN d.[National Data Item Average] END) AS [PERSON BIRTH DATE Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'PERSON STATED GENDER CODE' THEN d.[National Data Item Average] END) AS [PERSON STATED GENDER CODE Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'POSTCODE OF USUAL ADDRESS' THEN d.[National Data Item Average] END) AS [POSTCODE OF USUAL ADDRESS Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'PRIMARY DIAGNOSIS DATE' THEN d.[National Data Item Average] END) AS [PRIMARY DIAGNOSIS DATE Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016)' THEN d.[National Data Item Average] END) AS [PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'PROVISIONAL DIAGNOSIS DATE' THEN d.[National Data Item Average] END) AS [PROVISIONAL DIAGNOSIS DATE Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'REFERRAL CLOSURE REASON' THEN d.[National Data Item Average] END) AS [REFERRAL CLOSURE REASON Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'REFERRAL REQUEST RECEIVED TIME (HOUR)' THEN d.[National Data Item Average] END) AS [REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH)' THEN d.[National Data Item Average] END) AS [REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'SECONDARY DIAGNOSIS DATE' THEN d.[National Data Item Average] END) AS [SECONDARY DIAGNOSIS DATE Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'SERVICE DISCHARGE TIME (HOUR)' THEN d.[National Data Item Average] END) AS [SERVICE DISCHARGE TIME (HOUR) Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH)' THEN d.[National Data Item Average] END) AS [SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'SOURCE OF REFERRAL' THEN d.[National Data Item Average] END) AS [SOURCE OF REFERRAL Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY' THEN d.[National Data Item Average] END) AS [SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item National Score],
	MAX(CASE WHEN d.[Recoded Data Item] = 'TREATMENT FUNCTION CODE (MENTAL HEALTH)' THEN d.[National Data Item Average] END) AS [TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item National Score],
	MAX(d.[Dataset Score]) AS Dataset_Score

INTO #DQMI

FROM NHSE_Sandbox_MentalHealth.dbo.Staging_CQUINDQMI d

GROUP BY d.[Reporting Period To], d.[Data Provider Code]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DISCHARGES FOLLOWED UP IN 72 HOURS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDENTIFY MOST RECENT VERSION OF HOSPITAL SPELLS IN 
THE PERIOD
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Hosp') IS NOT NULL
DROP TABLE #Hosp

SELECT
	h.UniqMonthID,
	h.OrgIDProv,
	h.Person_ID,
	h.UniqServReqID,
	h.UniqHospProvSpellNum,
	h.RecordNumber,
	h.StartDateHospProvSpell,
	h.DischDateHospProvSpell,
	h.InactTimeHPS,
	h.DischMethCodeHospProvSpell,
	h.DischDestCodeHospProvSpell,
	ROW_NUMBER () OVER(PARTITION BY h.Person_ID, h.UniqServReqID, h.UniqHospProvSpellNum ORDER BY h.UniqMonthID DESC) AS 'HospRN'

INTO #Hosp

FROM [NHSE_MHSDS].dbo.MHS501HospProvSpell h

INNER JOIN [NHSE_MHSDS].[dbo].[MHS001MPI] m ON h.RecordNumber = m.RecordNumber AND (m.LADistrictAuth LIKE 'E%' OR m.LADistrictAuth IS NULL)

WHERE h.UniqMonthID BETWEEN @StartRP AND @EndRP AND h.Der_Use_Submission_Flag = 'Y'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDENTIFY LATEST BED TYPE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Bed') IS NOT NULL
DROP TABLE #Bed

SELECT
	w.UniqMonthID,
	w.Person_ID,
	w.UniqServReqID,
	w.UniqHospProvSpellNum,
	w.UniqWardStayID,
	w.HospitalBedTypeMH,
	ROW_NUMBER () OVER(PARTITION BY w.Person_ID, w.UniqServReqID, w.UniqHospProvSpellNum ORDER BY w.UniqMonthID DESC, w.InactTimeWS DESC, w.EndDateWardStay DESC, w.MHS502UniqID DESC) AS 'BedRN'

INTO #Bed
		
FROM [NHSE_MHSDS].dbo.MHS502WardStay w

WHERE w.UniqMonthID BETWEEN @StartRP AND @EndRP AND w.Der_Use_Submission_Flag = 'Y'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
COMBINE CONTACTS AND ADMISSIONS FOR FOLLOW UP
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Follow') IS NOT NULL
DROP TABLE #Follow

SELECT
	c.Person_ID,
	c.OrgIdProv,
	c.ContDate

INTO #Follow

FROM #Cont c

WHERE c.ConsMediumUsed IN ('01','02','03','04')

INSERT INTO #Follow

SELECT
	h.Person_ID,
	h.OrgIdProv,
	h.StartDateHospProvSpell AS ContDate

FROM #Hosp h

WHERE h.HospRN = 1

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDENTIFY ONWARD REFERRALS TO ALLOCATE FOLLOW UP
TO OTHER PROVIDERS AND CHECK VALIDITY OF RECEIVING
PROVIDER
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Onward') IS NOT NULL
DROP TABLE #Onward

SELECT DISTINCT
	o.Person_ID,
	o.UniqServReqID,
	o.OnwardReferDate,
	o.OrgIdProv,
	CASE 
		WHEN map.OrgIDProvider IS NULL THEN NULL
		WHEN LEFT(o.OrgIDReceiving,1) = '8' THEN o.OrgIDReceiving 
		ELSE LEFT(o.OrgIDReceiving,3) 
	END AS OrgIDReceiving

INTO #Onward

FROM [NHSE_MHSDS].[dbo].[MHS105OnwardReferral] o

LEFT JOIN 
(SELECT DISTINCT
	h.OrgIDProvider

FROM [NHSE_MHSDS].[dbo].[MHS000Header] h

WHERE h.UniqMonthID BETWEEN @StartRP AND @EndRP) map ON CASE WHEN LEFT(o.OrgIDReceiving,1) = '8' THEN o.OrgIDReceiving ELSE LEFT(o.OrgIDReceiving,3) END = map.OrgIDProvider

WHERE CASE WHEN LEFT(o.OrgIDReceiving,1) = '8' THEN OrgIDProv ELSE LEFT(o.OrgIDReceiving,3) END <> o.OrgIdProv AND o.Der_Use_Submission_Flag = 'Y'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDENTIFY DISCHARGES, BED TYPES AND ORG RESPONSIBLE 
FOR FOLLOW UP
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Disch') IS NOT NULL
DROP TABLE #Disch

SELECT DISTINCT
	h.UniqMonthID,
	h.OrgIDProv,
	COALESCE(o.OrgIDReceiving,h.OrgIDProv) AS ResponsibleProv,
	h.Person_ID,
	h.UniqServReqID,
	h.UniqHospProvSpellNum,
	h.RecordNumber,
	h.DischDateHospProvSpell,
	h.StartDateHospProvSpell,
	CASE WHEN h.DischDateHospProvSpell >= @ReportingPeriodStart THEN 1 ELSE 0 END AS DischFlag,
	CASE WHEN h.InactTimeHPS <@ReportingPeriodEnd THEN 1 ELSE 0 END AS InactiveFlag,
	CASE 
		WHEN DischMethCodeHospProvSpell NOT IN ('4','5') AND DischDestCodeHospProvSpell NOT IN ('30','37','38','48','49','50','53','79','84','87') 
			AND DischDateHospProvSpell < DATEADD(DD, -3, @ReportingPeriodEnd) THEN 1 ELSE 0 
	END AS ElgibleDischFlag,
	CASE WHEN b.HospitalBedTypeMH IN ('10', '11', '12', '16', '17', '18') THEN 1 ELSE 0 END AS AcuteBed,
	CASE WHEN b.HospitalBedTypeMH IN ('13', '14', '15', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30', '31', '32', '33', '34') THEN 1 ELSE 0 END AS OtherBed,
	CASE WHEN b.HospitalBedTypeMH NOT IN ('10', '11', '12', '16', '17', '18', '13', '14', '15', '19', '20', '21', '22', '23', '24', '25', '26', '27', '28', '29', '30', '31', '32', '33', '34') THEN 1 ELSE 0 
	END AS InvalidBed,
	CASE WHEN b.HospitalBedTypeMH IS NULL THEN 1 ELSE 0 END AS MissingBed,
	CASE WHEN DATEDIFF(DD, h.DischDateHospProvSpell , m.PersDeathDate) <= 3  THEN 1 ELSE 0 END AS DiedBeforeFollowUp,
	CASE WHEN DischDestCodeHospProvSpell IN ('37', '38') THEN 1 ELSE 0 END AS PrisonCourtDischarge

INTO #Disch

FROM #Hosp h

LEFT JOIN #Onward o ON h.Person_ID = o.Person_ID AND h.UniqServReqID = o.UniqServReqID AND OnwardReferDate BETWEEN h.StartDateHospProvSpell AND h.DischDateHospProvSpell

LEFT JOIN #Bed b ON b.Person_ID = h.Person_ID AND b.UniqServReqID = h.UniqServReqID AND b.UniqHospProvSpellNum = h.UniqHospProvSpellNum AND b.BedRN = 1

LEFT JOIN [NHSE_MHSDS].dbo.MHS001MPI m ON m.Person_ID = h.Person_ID AND m.OrgIDProv = COALESCE(o.OrgIDReceiving,h.OrgIDProv) AND m.PersDeathDate IS NOT NULL 
	AND (m.UniqMonthID = h.UniqMonthID OR m.UniqMonthID = h.UniqMonthID+1) AND m.Der_Use_Submission_Flag = 'Y'

WHERE h.HospRN = 1

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDENTIFY THOSE DISCHARGES WITH FOLLOW-UP
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Fup') IS NOT NULL
DROP TABLE #Fup

SELECT
	d.UniqMonthID,
	d.OrgIDProv,
	CASE WHEN d.ElgibleDischFlag = 1 AND AcuteBed = 1 THEN d.ResponsibleProv ELSE d.OrgIDProv END AS ResponsibleProv,
	d.Person_ID,
	d.UniqServReqID,
	d.UniqHospProvSpellNum,
	d.RecordNumber,
	d.DischDateHospProvSpell,
	d.DischFlag,
	d.InactiveFlag,
	d.ElgibleDischFlag,
	d.AcuteBed,
	d.OtherBed,
	d.InvalidBed,
	d.MissingBed,
	d.DiedBeforeFollowUp,
	d.PrisonCourtDischarge,
	CASE WHEN DATEDIFF(DD, d.DischDateHospProvSpell , c.FirstCont) <= 3  THEN 1 ELSE 0 END AS FollowedUp3Days,
	CASE WHEN c.FirstCont IS NULL THEN 1 ELSE 0 END AS NoFollowUp

INTO #Fup

FROM #Disch d

LEFT JOIN
(SELECT
	h.Person_ID,
	h.UniqServReqID,
	h.UniqHospProvSpellNum,
	MIN(c.ContDate) AS FirstCont

FROM #Disch h

INNER JOIN 

(SELECT
	c.Person_ID,
	c.OrgIdProv,
	c.ContDate

FROM #Follow c) c ON c.Person_ID = h.Person_ID AND c.ContDate > h.DischDateHospProvSpell AND c.OrgIdProv = h.ResponsibleProv

GROUP BY h.Person_ID,	h.UniqServReqID, h.UniqHospProvSpellNum) c ON d.Person_ID = c.Person_ID AND	d.UniqServReqID = c.UniqServReqID AND d.UniqHospProvSpellNum = c.UniqHospProvSpellNum

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE BY MONTH AND PROVIDER
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#AggFUp') IS NOT NULL
DROP TABLE #AggFup

SELECT
	f.UniqMonthID,
	f.ResponsibleProv AS OrgIDProv,
	SUM(f.DischFlag) AS DischFlag,
	SUM(f.InactiveFlag) AS InactiveFlag,
	SUM(f.ElgibleDischFlag) AS ElgibleDischFlag,
	SUM(CASE WHEN f.ElgibleDischFlag = 1 THEN f.AcuteBed ELSE 0 END) AS AcuteDisch,
	SUM(CASE WHEN f.ElgibleDischFlag = 1 AND f.ResponsibleProv <> f.OrgIDProv THEN f.AcuteBed ELSE 0 END) AS AcuteDischRec,
	MIN(o.AcuteBed) AS AcuteDischSent,
	SUM(CASE WHEN f.ElgibleDischFlag = 1 THEN f.OtherBed ELSE 0 END) AS OtherDisch,
	SUM(CASE WHEN f.ElgibleDischFlag = 1 THEN f.InvalidBed ELSE 0 END) AS InvalidDisch,
	SUM(CASE WHEN f.ElgibleDischFlag = 1 THEN f.MissingBed ELSE 0 END) AS MissingDisch,
	SUM(CASE WHEN f.ElgibleDischFlag = 1 AND f.AcuteBed = 1 THEN f.FollowedUp3Days ELSE 0 END) AS FollowedUp3Days,
	SUM(CASE WHEN f.ElgibleDischFlag = 1 AND f.AcuteBed = 1 THEN f.NoFollowUp ELSE 0 END) AS NoFollowUp,
	SUM(CASE WHEN f.ElgibleDischFlag = 1 AND f.AcuteBed = 1 THEN f.DiedBeforeFollowUp ELSE 0 END) AS DiedBeforeFollowUp,
	SUM(CASE WHEN f.AcuteBed = 1 THEN f.PrisonCourtDischarge ELSE 0 END) AS PrisonCourtDischarge

INTO #AggFup

FROM #FUp f

LEFT JOIN
(SELECT
	f.UniqMonthID,
	f.OrgIDProv,
	SUM(f.AcuteBed) AS AcuteBed
FROM #FUp f

WHERE f.OrgIDProv <> f.ResponsibleProv AND f.ElgibleDischFlag = 1 AND f.AcuteBed = 1

GROUP BY f.UniqMonthID, f.OrgIDProv) o ON o.UniqMonthID = f.UniqMonthID AND o.OrgIDProv = f.ResponsibleProv

GROUP BY f.UniqMonthID, f.ResponsibleProv

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IAPT CQUIN
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET BASE TABLE AND SET DIAGNOSIS FLAGS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#MONTHLY_IAPT_CQUIN') IS NOT NULL 
DROP TABLE #MONTHLY_IAPT_CQUIN

SELECT
	h.MONTH_ID,
	r.IC_PATHWAY_ID,
	CASE WHEN LEFT(r.ORGCODEPROVIDER,1) IN ('R','T') THEN LEFT(r.ORGCODEPROVIDER,3) ELSE r.ORGCODEPROVIDER END AS ORGCODEPROVIDER,
	CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN h.START_DATE AND h.END_DATE THEN 'Y' ELSE NULL END AS FinishedTreatment,
	r.IC_PROVDIAG,
	r.IC_ADSM,
	r.IC_LAST_PANIC_DISORDER,
	r.IAPT_PERSON_ID, 
	CASE	
		WHEN r.IC_PROVDIAG LIKE 'F3[2-3]%' THEN 'Depression' 
		WHEN r.IC_PROVDIAG LIKE 'F4[0-3]%' THEN 'Anxiety and stress related disorders (Total)'
		WHEN r.IC_PROVDIAG LIKE 'F%' AND r.IC_PROVDIAG NOT LIKE 'F3[2-3]%' AND R.IC_PROVDIAG NOT LIKE 'F4[0-3]%' THEN 'Other Mental Health problems'
		WHEN r.IC_PROVDIAG IS NULL THEN NULL
		WHEN r.IC_PROVDIAG = '-1' THEN 'Unspecified'
		WHEN r.IC_PROVDIAG = '-3' THEN 'Invalid Data Supplied'
		ELSE 'Other Recorded Problems' 
	END AS IC_PROBDESC_PRIMARY, 
	CASE
		WHEN r.IC_PROVDIAG = 'F400' THEN 'Agoraphobia' 
		WHEN r.IC_PROVDIAG = 'F401' THEN 'Social phobias'
		WHEN r.IC_PROVDIAG = 'F402' THEN 'Specific (isolated) phobias'
		WHEN r.IC_PROVDIAG = 'F410' THEN 'Panic disorder [episodic paroxysmal anxiety]'
		WHEN r.IC_PROVDIAG = 'F411' THEN 'Generalized anxiety disorder'
		WHEN r.IC_PROVDIAG = 'F412' THEN 'Mixed anxiety and depressive disorder'
		WHEN r.IC_PROVDIAG LIKE 'F42%' THEN 'Obsessive-compulsive disorder'
		WHEN r.IC_PROVDIAG = 'F431' THEN 'Post-traumatic stress disorder'
		WHEN r.IC_PROVDIAG LIKE 'F4[0-3]%' AND r.IC_PROVDIAG NOT IN ('F400','F401','F402','F410','F411','F412','F431') AND r.IC_PROVDIAG NOT LIKE 'F42%'  
			THEN 'Other anxiety or stress related disorder'
		ELSE 'Hypochondriacal disorder'
	END AS IC_PROBDESC_SECONDARY

INTO #MONTHLY_IAPT_CQUIN 

FROM [NHSE_Sandbox_Policy].dbo.[Referral_v15] r

INNER JOIN NHSE_IAPT.dbo.[Person_v15] p	ON r.IAPT_RECORD_NUMBER = p.IAPT_RECORD_NUMBER

INNER JOIN NHSE_IAPT.dbo.[Header_v15] h	ON p.HEADER_ID = h.HEADER_ID

WHERE h.MONTH_ID BETWEEN @StartRP AND @EndRP AND (p.LAD_UA LIKE 'E%' OR p.LAD_UA IS NULL) AND  r.[IC_USE_PATHWAY_FLAG] = 'Y'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE BY PROVIDER AND MONTH
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#IAPT_Agg') IS NOT NULL 
DROP TABLE #IAPT_Agg

SELECT
	m.MONTH_ID,
	m.OrgCodeProvider AS OrgIDProvider, 
	COUNT(DISTINCT CASE WHEN FinishedTreatment = 'Y' AND ((IC_PROBDESC_SECONDARY = 'Obsessive-compulsive disorder' AND IC_ADSM = 'OCD') 
		OR (IC_PROBDESC_SECONDARY = 'Social phobias' AND IC_ADSM = 'SOCIAL_PHOBIA_INVENTORY') OR (IC_PROVDIAG = 'F452' AND IC_ADSM = 'ANXIETY_INVENTORY')
		OR (IC_PROBDESC_SECONDARY = 'Agoraphobia' AND IC_ADSM = 'AGORA_MOB_ALONE') OR (IC_PROBDESC_SECONDARY = 'Post-traumatic stress disorder' AND IC_ADSM = 'PTSD')
		OR (IC_PROBDESC_SECONDARY = 'Panic disorder [episodic paroxysmal anxiety]' AND IC_ADSM = 'PDSS')) THEN IC_PATHWAY_ID ELSE NULL END) 
	AS PairScores,
	COUNT(DISTINCT CASE WHEN FinishedTreatment = 'Y' AND (IC_PROBDESC_SECONDARY = 'Agoraphobia' OR IC_PROBDESC_SECONDARY = 'Obsessive-compulsive disorder'
		OR IC_PROBDESC_SECONDARY = 'Panic disorder [episodic paroxysmal anxiety]' OR IC_PROBDESC_SECONDARY = 'Post-traumatic stress disorder' OR IC_PROBDESC_SECONDARY = 'Social phobias'
		OR IC_PROVDIAG = 'F452') THEN IC_PATHWAY_ID ELSE NULL END) 
	AS FinishedCourseTreatment

INTO #IAPT_Agg

FROM #MONTHLY_IAPT_CQUIN m

GROUP BY m.MONTH_ID, m.OrgCodeProvider

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CREATE MASTER TABLE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET LIST OF PROVIDERS, BY MONTH AND DATA SET
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Provs') IS NOT NULL
DROP TABLE #Provs

SELECT DISTINCT
	h.OrgIDProvider,
	'MHSDS' AS DataSet

INTO #Provs

FROM [NHSE_MHSDS].[dbo].[MHS000Header] h

WHERE h.UniqMonthID BETWEEN @StartRP AND @EndRP

INSERT INTO #Provs

SELECT DISTINCT
	CASE WHEN LEFT(h.ORGCODEPROVIDER,1) IN ('R','T') THEN LEFT(h.ORGCODEPROVIDER,3) ELSE h.ORGCODEPROVIDER END AS OrgIDProvider,
	'IAPT' AS DataSet

FROM NHSE_IAPT.dbo.[Header_v15] h

WHERE h.MONTH_ID BETWEEN @StartRP AND @EndRP

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDENTIFY PROVIDERS WHO SUBMIT TO ONE OR BOTH DATA
SETS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#DistProvs') IS NOT NULL
DROP TABLE #DistProvs

SELECT
	p.OrgIDProvider,
	CASE WHEN c.Dataset > 1 THEN 'Both' ELSE p.DataSet END AS DataSet

INTO #Distprovs

FROM #Provs p

LEFT JOIN
(SELECT
	p.OrgIDProvider,
	COUNT(*) AS DataSet
FROM #Provs p

GROUP BY p.OrgIDProvider) c ON c.OrgIDProvider = p.OrgIDProvider

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ASSIGN PROVIDERS WHO MADE AT LEAST ONE SUBMISSION 
TO EACH MONTH
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#ProvMonth') IS NOT NULL
DROP TABLE #ProvMonth

SELECT DISTINCT
	h.UniqMonthID,
	h.ReportingPeriodStartDate,
	h.ReportingPeriodEndDate,
	d.OrgIDProvider,
	d.DataSet

INTO #ProvMonth

FROM [NHSE_MHSDS].dbo.MHS000Header h, #Distprovs d

WHERE h.UniqMonthID BETWEEN @StartRP AND @EndRP

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
BUILD MASTER TABLE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Master') IS NOT NULL
DROP TABLE #Master

SELECT DISTINCT
	d.UniqMonthID,
	d.ReportingPeriodStartDate,
	d.ReportingPeriodEndDate,
	d.OrgIDProvider,
	d.DataSet,
	a.ReferralsTwoConts,
	a.CurrentSNOMEDCodes,
	a.RetiredSNOMEDCodes,
	a.AllSNOMEDCodes,
	p.CurrentSNOMEDCodes AS UniqCurrentSNOMED,
	p.RetiredSNOMEDCodes AS UniqRetiredSNOMED,
	p.UniqSNOMED,
	f.DischFlag,
	f.InactiveFlag,
	f.ElgibleDischFlag,
	f.AcuteDisch,
	f.AcuteDischRec,
	f.AcuteDischSent,
	f.OtherDisch,
	f.InvalidDisch,
	f.MissingDisch,
	f.FollowedUp3Days,
	f.NoFollowUp,
	f.DiedBeforeFollowUp,
	f.PrisonCourtDischarge,
	i.FinishedCourseTreatment,
	i.PairScores,
	dq.[ACTIVITY LOCATION TYPE CODE Data Item Score],
	dq.[ATTENDED OR DID NOT ATTEND Data Item Score],
	dq.[CARE CONTACT TIME (HOUR) Data Item Score],
	dq.[CARE PLAN TYPE Data Item Score],
	dq.[CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item Score],
	dq.[CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item Score],
	dq.[CONSULTATION MEDIUM USED Data Item Score],
	dq.[DELAYED DISCHARGE ATTRIBUTABLE TO Data Item Score],
	dq.[DELAYED DISCHARGE REASON Data Item Score],
	dq.[DISCHARGE PLAN CREATION TIME (HOUR) Data Item Score],
	dq.[ESTIMATED DISCHARGE DATE Data Item Score],
	dq.[ETHNIC CATEGORY Data Item Score],
	dq.[EX-BRITISH ARMED FORCES INDICATOR Data Item Score],
	dq.[GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item Score],
	dq.[HOSPITAL BED TYPE (MENTAL HEALTH) Data Item Score],
	dq.[INDIRECT ACTIVITY TIME (HOUR) Data Item Score],
	dq.[MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item Score],
	dq.[NHS NUMBER Data Item Score],
	dq.[ONWARD REFERRAL TIME (HOUR) Data Item Score],
	dq.[ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item Score],
	dq.[ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item Score],
	dq.[PERSON BIRTH DATE Data Item Score],
	dq.[PERSON STATED GENDER CODE Data Item Score],
	dq.[POSTCODE OF USUAL ADDRESS Data Item Score],
	dq.[PRIMARY DIAGNOSIS DATE Data Item Score],
	dq.[PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item Score],
	dq.[PROVISIONAL DIAGNOSIS DATE Data Item Score],
	dq.[REFERRAL CLOSURE REASON Data Item Score],
	dq.[REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item Score],
	dq.[REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item Score],
	dq.[SECONDARY DIAGNOSIS DATE Data Item Score],
	dq.[SERVICE DISCHARGE TIME (HOUR) Data Item Score],
	dq.[SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item Score],
	dq.[SOURCE OF REFERRAL Data Item Score],
	dq.[SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item Score],
	dq.[TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item Score],
	dq.[ACTIVITY LOCATION TYPE CODE Data Item National Score],
	dq.[ATTENDED OR DID NOT ATTEND Data Item National Score],
	dq.[CARE CONTACT TIME (HOUR) Data Item National Score],
	dq.[CARE PLAN TYPE Data Item National Score],
	dq.[CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item National Score],
	dq.[CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item National Score],
	dq.[CONSULTATION MEDIUM USED Data Item National Score],
	dq.[DELAYED DISCHARGE ATTRIBUTABLE TO Data Item National Score],
	dq.[DELAYED DISCHARGE REASON Data Item National Score],
	dq.[DISCHARGE PLAN CREATION TIME (HOUR) Data Item National Score],
	dq.[ESTIMATED DISCHARGE DATE Data Item National Score],
	dq.[ETHNIC CATEGORY Data Item National Score],
	dq.[EX-BRITISH ARMED FORCES INDICATOR Data Item National Score],
	dq.[GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item National Score],
	dq.[HOSPITAL BED TYPE (MENTAL HEALTH) Data Item National Score],
	dq.[INDIRECT ACTIVITY TIME (HOUR) Data Item National Score],
	dq.[MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item National Score],
	dq.[NHS NUMBER Data Item National Score],
	dq.[ONWARD REFERRAL TIME (HOUR) Data Item National Score],
	dq.[ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item National Score],
	dq.[ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item National Score],
	dq.[PERSON BIRTH DATE Data Item National Score],
	dq.[PERSON STATED GENDER CODE Data Item National Score],
	dq.[POSTCODE OF USUAL ADDRESS Data Item National Score],
	dq.[PRIMARY DIAGNOSIS DATE Data Item National Score],
	dq.[PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item National Score],
	dq.[PROVISIONAL DIAGNOSIS DATE Data Item National Score],
	dq.[REFERRAL CLOSURE REASON Data Item National Score],
	dq.[REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item National Score],
	dq.[REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item National Score],
	dq.[SECONDARY DIAGNOSIS DATE Data Item National Score],
	dq.[SERVICE DISCHARGE TIME (HOUR) Data Item National Score],
	dq.[SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item National Score],
	dq.[SOURCE OF REFERRAL Data Item National Score],
	dq.[SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item National Score],
	dq.[TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item National Score],
	dq.Dataset_Score

INTO #Master

FROM #ProvMonth d

LEFT JOIN #AggInt a ON a.UniqMonthID = d.UniqMonthID AND a.OrgIdProv = d.OrgIDProvider

LEFT JOIN #ProvInt p ON p.UniqMonthID = d.UniqMonthID AND p.OrgIdProv = d.OrgIDProvider

LEFT JOIN #AggFup f ON f.UniqMonthID = d.UniqMonthID AND f.OrgIdProv = d.OrgIDProvider

LEFT JOIN #IAPT_Agg i ON i.MONTH_ID = d.UniqMonthID AND i.OrgIDProvider = d.OrgIDProvider

LEFT JOIN #DQMI dq ON d.ReportingPeriodEndDate = dq.[Reporting Period End] AND d.OrgIDProvider = dq.[Data Provider Code]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
OUTPUT TABLE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ROLLING THREE MONTHS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#UnSupp') IS NOT NULL
DROP TABLE #UnSupp

SELECT 
	m.UniqMonthID,
	DATEADD(mm,-2,m.ReportingPeriodStartDate) AS ReportingPeriodStartDate,
	m.ReportingPeriodEndDate,
	'Rolling Three Months' AS PeriodType,
	m.OrgIDProvider,
	m.DataSet,
	SUM(m.ReferralsTwoConts) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ReferralsTwoConts,
	SUM(m.CurrentSNOMEDCodes) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS CurrentSNOMEDCodes,
	SUM(m.RetiredSNOMEDCodes) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS RetiredSNOMEDCodes,
	SUM(m.AllSNOMEDCodes) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS AllSNOMEDCodes,
	MAX(m.CurrentSNOMEDCodes) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS UniqCurrentSNOMED,
	MAX(m.RetiredSNOMEDCodes) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS UniqRetiredSNOMED,
	MAX(m.UniqSNOMED) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS UniqSNOMED,
	SUM(m.DischFlag) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS DischFlag,
	SUM(m.InactiveFlag) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS InactiveFlag,
	SUM(m.ElgibleDischFlag) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS ElgibleDischFlag,
	SUM(m.AcuteDisch) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS AcuteDisch,
	SUM(m.AcuteDischRec) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS AcuteDischRec,
	SUM(m.AcuteDischSent) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS AcuteDischSent,
	SUM(m.OtherDisch) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS OtherDisch,
	SUM(m.InvalidDisch) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS InvalidDisch,
	SUM(m.MissingDisch) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS MissingDisch,
	SUM(m.FollowedUp3Days) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS FollowedUp3Days,
	SUM(m.NoFollowUp) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS NoFollowUp,
	SUM(m.DiedBeforeFollowUp) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS DiedBeforeFollowUp,
	SUM(m.PrisonCourtDischarge) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS PrisonCourtDischarge,
	SUM(m.FinishedCourseTreatment) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS FinishedCourseTreatment,
	SUM(m.PairScores) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS PairScores,
	AVG(m.[ACTIVITY LOCATION TYPE CODE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [ACTIVITY LOCATION TYPE CODE Data Item Score],
	AVG(m.[ATTENDED OR DID NOT ATTEND Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [ATTENDED OR DID NOT ATTEND Data Item Score],
	AVG(m.[CARE CONTACT TIME (HOUR) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [CARE CONTACT TIME (HOUR) Data Item Score],
	AVG(m.[CARE PLAN TYPE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [CARE PLAN TYPE Data Item Score],
	AVG(m.[CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item Score],
	AVG(m.[CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item Score],
	AVG(m.[CONSULTATION MEDIUM USED Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [CONSULTATION MEDIUM USED Data Item Score],
	AVG(m.[DELAYED DISCHARGE ATTRIBUTABLE TO Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [DELAYED DISCHARGE ATTRIBUTABLE TO Data Item Score],
	AVG(m.[DELAYED DISCHARGE REASON Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [DELAYED DISCHARGE REASON Data Item Score],
	AVG(m.[DISCHARGE PLAN CREATION TIME (HOUR) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [DISCHARGE PLAN CREATION TIME (HOUR) Data Item Score],
	AVG(m.[ESTIMATED DISCHARGE DATE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [ESTIMATED DISCHARGE DATE Data Item Score],
	AVG(m.[ETHNIC CATEGORY Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [ETHNIC CATEGORY Data Item Score],
	AVG(m.[EX-BRITISH ARMED FORCES INDICATOR Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [EX-BRITISH ARMED FORCES INDICATOR Data Item Score],
	AVG(m.[GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item Score],
	AVG(m.[HOSPITAL BED TYPE (MENTAL HEALTH) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [HOSPITAL BED TYPE (MENTAL HEALTH) Data Item Score],
	AVG(m.[INDIRECT ACTIVITY TIME (HOUR) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [INDIRECT ACTIVITY TIME (HOUR) Data Item Score],
	AVG(m.[MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item Score],
	AVG(m.[NHS NUMBER Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [NHS NUMBER Data Item Score],
	AVG(m.[ONWARD REFERRAL TIME (HOUR) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [ONWARD REFERRAL TIME (HOUR) Data Item Score],
	AVG(m.[ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item Score],
	AVG(m.[ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item Score],
	AVG(m.[PERSON BIRTH DATE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [PERSON BIRTH DATE Data Item Score],
	AVG(m.[PERSON STATED GENDER CODE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [PERSON STATED GENDER CODE Data Item Score],
	AVG(m.[POSTCODE OF USUAL ADDRESS Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [POSTCODE OF USUAL ADDRESS Data Item Score],
	AVG(m.[PRIMARY DIAGNOSIS DATE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [PRIMARY DIAGNOSIS DATE Data Item Score],
	AVG(m.[PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item Score],
	AVG(m.[PROVISIONAL DIAGNOSIS DATE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [PROVISIONAL DIAGNOSIS DATE Data Item Score],
	AVG(m.[REFERRAL CLOSURE REASON Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [REFERRAL CLOSURE REASON Data Item Score],
	AVG(m.[REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item Score],
	AVG(m.[REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item Score],
	AVG(m.[SECONDARY DIAGNOSIS DATE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [SECONDARY DIAGNOSIS DATE Data Item Score],
	AVG(m.[SERVICE DISCHARGE TIME (HOUR) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [SERVICE DISCHARGE TIME (HOUR) Data Item Score],
	AVG(m.[SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item Score],
	AVG(m.[SOURCE OF REFERRAL Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [SOURCE OF REFERRAL Data Item Score],
	AVG(m.[SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item Score],
	AVG(m.[TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item Score],
	AVG(m.[ACTIVITY LOCATION TYPE CODE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [ACTIVITY LOCATION TYPE CODE Data Item National Score],
	AVG(m.[ATTENDED OR DID NOT ATTEND Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [ATTENDED OR DID NOT ATTEND Data Item National Score],
	AVG(m.[CARE CONTACT TIME (HOUR) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [CARE CONTACT TIME (HOUR) Data Item National Score],
	AVG(m.[CARE PLAN TYPE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [CARE PLAN TYPE Data Item National Score],
	AVG(m.[CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item National Score],
	AVG(m.[CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item National Score],
	AVG(m.[CONSULTATION MEDIUM USED Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [CONSULTATION MEDIUM USED Data Item National Score],
	AVG(m.[DELAYED DISCHARGE ATTRIBUTABLE TO Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [DELAYED DISCHARGE ATTRIBUTABLE TO Data Item National Score],
	AVG(m.[DELAYED DISCHARGE REASON Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [DELAYED DISCHARGE REASON Data Item National Score],
	AVG(m.[DISCHARGE PLAN CREATION TIME (HOUR) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [DISCHARGE PLAN CREATION TIME (HOUR) Data Item National Score],
	AVG(m.[ESTIMATED DISCHARGE DATE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [ESTIMATED DISCHARGE DATE Data Item National Score],
	AVG(m.[ETHNIC CATEGORY Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [ETHNIC CATEGORY Data Item National Score],
	AVG(m.[EX-BRITISH ARMED FORCES INDICATOR Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [EX-BRITISH ARMED FORCES INDICATOR Data Item National Score],
	AVG(m.[GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item National Score],
	AVG(m.[HOSPITAL BED TYPE (MENTAL HEALTH) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [HOSPITAL BED TYPE (MENTAL HEALTH) Data Item National Score],
	AVG(m.[INDIRECT ACTIVITY TIME (HOUR) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [INDIRECT ACTIVITY TIME (HOUR) Data Item National Score],
	AVG(m.[MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item National Score],
	AVG(m.[NHS NUMBER Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [NHS NUMBER Data Item National Score],
	AVG(m.[ONWARD REFERRAL TIME (HOUR) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [ONWARD REFERRAL TIME (HOUR) Data Item National Score],
	AVG(m.[ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item National Score],
	AVG(m.[ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item National Score],
	AVG(m.[PERSON BIRTH DATE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [PERSON BIRTH DATE Data Item National Score],
	AVG(m.[PERSON STATED GENDER CODE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [PERSON STATED GENDER CODE Data Item National Score],
	AVG(m.[POSTCODE OF USUAL ADDRESS Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [POSTCODE OF USUAL ADDRESS Data Item National Score],
	AVG(m.[PRIMARY DIAGNOSIS DATE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [PRIMARY DIAGNOSIS DATE Data Item National Score],
	AVG(m.[PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item National Score],
	AVG(m.[PROVISIONAL DIAGNOSIS DATE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [PROVISIONAL DIAGNOSIS DATE Data Item National Score],
	AVG(m.[REFERRAL CLOSURE REASON Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [REFERRAL CLOSURE REASON Data Item National Score],
	AVG(m.[REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item National Score],
	AVG(m.[REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item National Score],
	AVG(m.[SECONDARY DIAGNOSIS DATE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [SECONDARY DIAGNOSIS DATE Data Item National Score],
	AVG(m.[SERVICE DISCHARGE TIME (HOUR) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [SERVICE DISCHARGE TIME (HOUR) Data Item National Score],
	AVG(m.[SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item National Score],
	AVG(m.[SOURCE OF REFERRAL Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [SOURCE OF REFERRAL Data Item National Score],
	AVG(m.[SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item National Score],
	AVG(m.[TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item National Score],
	AVG(m.Dataset_Score) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS Dataset_Score

INTO #UnSupp

FROM #Master m

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ROLLING SIX MONTHS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO #UnSupp

SELECT
	m.UniqMonthID,
	DATEADD(mm,-5,m.ReportingPeriodStartDate) AS ReportingPeriodStartDate,
	m.ReportingPeriodEndDate,
	'Rolling Six Months' AS PeriodType,
	m.OrgIDProvider,
	m.DataSet,
	SUM(m.ReferralsTwoConts) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS ReferralsTwoConts,
	SUM(m.CurrentSNOMEDCodes) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS CurrentSNOMEDCodes,
	SUM(m.RetiredSNOMEDCodes) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS RetiredSNOMEDCodes,
	SUM(m.AllSNOMEDCodes) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS AllSNOMEDCodes,
	MAX(m.CurrentSNOMEDCodes) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS UniqCurrentSNOMED,
	MAX(m.RetiredSNOMEDCodes) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS UniqRetiredSNOMED,
	MAX(m.UniqSNOMED) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS UniqSNOMED,
	SUM(m.DischFlag) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS DischFlag,
	SUM(m.InactiveFlag) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS InactiveFlag,
	SUM(m.ElgibleDischFlag) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS ElgibleDischFlag,
	SUM(m.AcuteDisch) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS AcuteDisch,
	SUM(m.AcuteDischRec) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS AcuteDischRec,
	SUM(m.AcuteDischSent) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS AcuteDischSent,
	SUM(m.OtherDisch) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS OtherDisch,
	SUM(m.InvalidDisch) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS InvalidDisch,
	SUM(m.MissingDisch) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS MissingDisch,
	SUM(m.FollowedUp3Days) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS FollowedUp3Days,
	SUM(m.NoFollowUp) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS NoFollowUp,
	SUM(m.DiedBeforeFollowUp) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS DiedBeforeFollowUp,
	SUM(m.PrisonCourtDischarge) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS PrisonCourtDischarge,
	SUM(m.FinishedCourseTreatment) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS FinishedCourseTreatment,
	SUM(m.PairScores) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS PairScores,
	AVG(m.[ACTIVITY LOCATION TYPE CODE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [ACTIVITY LOCATION TYPE CODE Data Item Score],
	AVG(m.[ATTENDED OR DID NOT ATTEND Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [ATTENDED OR DID NOT ATTEND Data Item Score],
	AVG(m.[CARE CONTACT TIME (HOUR) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [CARE CONTACT TIME (HOUR) Data Item Score],
	AVG(m.[CARE PLAN TYPE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [CARE PLAN TYPE Data Item Score],
	AVG(m.[CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item Score],
	AVG(m.[CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item Score],
	AVG(m.[CONSULTATION MEDIUM USED Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [CONSULTATION MEDIUM USED Data Item Score],
	AVG(m.[DELAYED DISCHARGE ATTRIBUTABLE TO Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [DELAYED DISCHARGE ATTRIBUTABLE TO Data Item Score],
	AVG(m.[DELAYED DISCHARGE REASON Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [DELAYED DISCHARGE REASON Data Item Score],
	AVG(m.[DISCHARGE PLAN CREATION TIME (HOUR) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [DISCHARGE PLAN CREATION TIME (HOUR) Data Item Score],
	AVG(m.[ESTIMATED DISCHARGE DATE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [ESTIMATED DISCHARGE DATE Data Item Score],
	AVG(m.[ETHNIC CATEGORY Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [ETHNIC CATEGORY Data Item Score],
	AVG(m.[EX-BRITISH ARMED FORCES INDICATOR Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [EX-BRITISH ARMED FORCES INDICATOR Data Item Score],
	AVG(m.[GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item Score],
	AVG(m.[HOSPITAL BED TYPE (MENTAL HEALTH) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [HOSPITAL BED TYPE (MENTAL HEALTH) Data Item Score],
	AVG(m.[INDIRECT ACTIVITY TIME (HOUR) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [INDIRECT ACTIVITY TIME (HOUR) Data Item Score],
	AVG(m.[MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item Score],
	AVG(m.[NHS NUMBER Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [NHS NUMBER Data Item Score],
	AVG(m.[ONWARD REFERRAL TIME (HOUR) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [ONWARD REFERRAL TIME (HOUR) Data Item Score],
	AVG(m.[ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item Score],
	AVG(m.[ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item Score],
	AVG(m.[PERSON BIRTH DATE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [PERSON BIRTH DATE Data Item Score],
	AVG(m.[PERSON STATED GENDER CODE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [PERSON STATED GENDER CODE Data Item Score],
	AVG(m.[POSTCODE OF USUAL ADDRESS Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [POSTCODE OF USUAL ADDRESS Data Item Score],
	AVG(m.[PRIMARY DIAGNOSIS DATE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [PRIMARY DIAGNOSIS DATE Data Item Score],
	AVG(m.[PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item Score],
	AVG(m.[PROVISIONAL DIAGNOSIS DATE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [PROVISIONAL DIAGNOSIS DATE Data Item Score],
	AVG(m.[REFERRAL CLOSURE REASON Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [REFERRAL CLOSURE REASON Data Item Score],
	AVG(m.[REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item Score],
	AVG(m.[REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item Score],
	AVG(m.[SECONDARY DIAGNOSIS DATE Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [SECONDARY DIAGNOSIS DATE Data Item Score],
	AVG(m.[SERVICE DISCHARGE TIME (HOUR) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [SERVICE DISCHARGE TIME (HOUR) Data Item Score],
	AVG(m.[SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item Score],
	AVG(m.[SOURCE OF REFERRAL Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [SOURCE OF REFERRAL Data Item Score],
	AVG(m.[SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item Score],
	AVG(m.[TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item Score],
	AVG(m.[ACTIVITY LOCATION TYPE CODE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [ACTIVITY LOCATION TYPE CODE Data Item National Score],
	AVG(m.[ATTENDED OR DID NOT ATTEND Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [ATTENDED OR DID NOT ATTEND Data Item National Score],
	AVG(m.[CARE CONTACT TIME (HOUR) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [CARE CONTACT TIME (HOUR) Data Item National Score],
	AVG(m.[CARE PLAN TYPE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [CARE PLAN TYPE Data Item National Score],
	AVG(m.[CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item National Score],
	AVG(m.[CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item National Score],
	AVG(m.[CONSULTATION MEDIUM USED Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [CONSULTATION MEDIUM USED Data Item National Score],
	AVG(m.[DELAYED DISCHARGE ATTRIBUTABLE TO Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [DELAYED DISCHARGE ATTRIBUTABLE TO Data Item National Score],
	AVG(m.[DELAYED DISCHARGE REASON Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [DELAYED DISCHARGE REASON Data Item National Score],
	AVG(m.[DISCHARGE PLAN CREATION TIME (HOUR) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [DISCHARGE PLAN CREATION TIME (HOUR) Data Item National Score],
	AVG(m.[ESTIMATED DISCHARGE DATE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [ESTIMATED DISCHARGE DATE Data Item National Score],
	AVG(m.[ETHNIC CATEGORY Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [ETHNIC CATEGORY Data Item National Score],
	AVG(m.[EX-BRITISH ARMED FORCES INDICATOR Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [EX-BRITISH ARMED FORCES INDICATOR Data Item National Score],
	AVG(m.[GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item National Score],
	AVG(m.[HOSPITAL BED TYPE (MENTAL HEALTH) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [HOSPITAL BED TYPE (MENTAL HEALTH) Data Item National Score],
	AVG(m.[INDIRECT ACTIVITY TIME (HOUR) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [INDIRECT ACTIVITY TIME (HOUR) Data Item National Score],
	AVG(m.[MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item National Score],
	AVG(m.[NHS NUMBER Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [NHS NUMBER Data Item National Score],
	AVG(m.[ONWARD REFERRAL TIME (HOUR) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [ONWARD REFERRAL TIME (HOUR) Data Item National Score],
	AVG(m.[ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item National Score],
	AVG(m.[ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item National Score],
	AVG(m.[PERSON BIRTH DATE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [PERSON BIRTH DATE Data Item National Score],
	AVG(m.[PERSON STATED GENDER CODE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [PERSON STATED GENDER CODE Data Item National Score],
	AVG(m.[POSTCODE OF USUAL ADDRESS Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [POSTCODE OF USUAL ADDRESS Data Item National Score],
	AVG(m.[PRIMARY DIAGNOSIS DATE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [PRIMARY DIAGNOSIS DATE Data Item National Score],
	AVG(m.[PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item National Score],
	AVG(m.[PROVISIONAL DIAGNOSIS DATE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [PROVISIONAL DIAGNOSIS DATE Data Item National Score],
	AVG(m.[REFERRAL CLOSURE REASON Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [REFERRAL CLOSURE REASON Data Item National Score],
	AVG(m.[REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item National Score],
	AVG(m.[REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item National Score],
	AVG(m.[SECONDARY DIAGNOSIS DATE Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [SECONDARY DIAGNOSIS DATE Data Item National Score],
	AVG(m.[SERVICE DISCHARGE TIME (HOUR) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [SERVICE DISCHARGE TIME (HOUR) Data Item National Score],
	AVG(m.[SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item National Score],
	AVG(m.[SOURCE OF REFERRAL Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [SOURCE OF REFERRAL Data Item National Score],
	AVG(m.[SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item National Score],
	AVG(m.[TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item National Score]) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS [TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item National Score],
	AVG(m.Dataset_Score) OVER (PARTITION BY m.OrgIDProvider ORDER BY m.UniqMonthID ROWS BETWEEN 5 PRECEDING AND CURRENT ROW) AS Dataset_Score

FROM #Master m

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET MONTHLY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO #UnSupp

SELECT
	m.UniqMonthID,
	m.ReportingPeriodStartDate,
	m.ReportingPeriodEndDate,
	'Monthly' AS PeriodType,
	m.OrgIDProvider,
	m.DataSet,
	m.ReferralsTwoConts,
	m.CurrentSNOMEDCodes,
	m.RetiredSNOMEDCodes,
	m.AllSNOMEDCodes,
	m.UniqCurrentSNOMED,
	m.UniqRetiredSNOMED,
	m.UniqSNOMED,
	m.DischFlag,
	m.InactiveFlag,
	m.ElgibleDischFlag,
	m.AcuteDisch,
	m.AcuteDischRec,
	m.AcuteDischSent,
	m.OtherDisch,
	m.InvalidDisch,
	m.MissingDisch,
	m.FollowedUp3Days,
	m.NoFollowUp,
	m.DiedBeforeFollowUp,
	m.PrisonCourtDischarge,
	m.FinishedCourseTreatment,
	m.PairScores,
	m.[ACTIVITY LOCATION TYPE CODE Data Item Score],
	m.[ATTENDED OR DID NOT ATTEND Data Item Score],
	m.[CARE CONTACT TIME (HOUR) Data Item Score],
	m.[CARE PLAN TYPE Data Item Score],
	m.[CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item Score],
	m.[CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item Score],
	m.[CONSULTATION MEDIUM USED Data Item Score],
	m.[DELAYED DISCHARGE ATTRIBUTABLE TO Data Item Score],
	m.[DELAYED DISCHARGE REASON Data Item Score],
	m.[DISCHARGE PLAN CREATION TIME (HOUR) Data Item Score],
	m.[ESTIMATED DISCHARGE DATE Data Item Score],
	m.[ETHNIC CATEGORY Data Item Score],
	m.[EX-BRITISH ARMED FORCES INDICATOR Data Item Score],
	m.[GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item Score],
	m.[HOSPITAL BED TYPE (MENTAL HEALTH) Data Item Score],
	m.[INDIRECT ACTIVITY TIME (HOUR) Data Item Score],
	m.[MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item Score],
	m.[NHS NUMBER Data Item Score],
	m.[ONWARD REFERRAL TIME (HOUR) Data Item Score],
	m.[ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item Score],
	m.[ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item Score],
	m.[PERSON BIRTH DATE Data Item Score],
	m.[PERSON STATED GENDER CODE Data Item Score],
	m.[POSTCODE OF USUAL ADDRESS Data Item Score],
	m.[PRIMARY DIAGNOSIS DATE Data Item Score],
	m.[PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item Score],
	m.[PROVISIONAL DIAGNOSIS DATE Data Item Score],
	m.[REFERRAL CLOSURE REASON Data Item Score],
	m.[REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item Score],
	m.[REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item Score],
	m.[SECONDARY DIAGNOSIS DATE Data Item Score],
	m.[SERVICE DISCHARGE TIME (HOUR) Data Item Score],
	m.[SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item Score],
	m.[SOURCE OF REFERRAL Data Item Score],
	m.[SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item Score],
	m.[TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item Score],
	m.[ACTIVITY LOCATION TYPE CODE Data Item National Score],
	m.[ATTENDED OR DID NOT ATTEND Data Item National Score],
	m.[CARE CONTACT TIME (HOUR) Data Item National Score],
	m.[CARE PLAN TYPE Data Item National Score],
	m.[CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item National Score],
	m.[CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item National Score],
	m.[CONSULTATION MEDIUM USED Data Item National Score],
	m.[DELAYED DISCHARGE ATTRIBUTABLE TO Data Item National Score],
	m.[DELAYED DISCHARGE REASON Data Item National Score],
	m.[DISCHARGE PLAN CREATION TIME (HOUR) Data Item National Score],
	m.[ESTIMATED DISCHARGE DATE Data Item National Score],
	m.[ETHNIC CATEGORY Data Item National Score],
	m.[EX-BRITISH ARMED FORCES INDICATOR Data Item National Score],
	m.[GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item National Score],
	m.[HOSPITAL BED TYPE (MENTAL HEALTH) Data Item National Score],
	m.[INDIRECT ACTIVITY TIME (HOUR) Data Item National Score],
	m.[MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item National Score],
	m.[NHS NUMBER Data Item National Score],
	m.[ONWARD REFERRAL TIME (HOUR) Data Item National Score],
	m.[ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item National Score],
	m.[ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item National Score],
	m.[PERSON BIRTH DATE Data Item National Score],
	m.[PERSON STATED GENDER CODE Data Item National Score],
	m.[POSTCODE OF USUAL ADDRESS Data Item National Score],
	m.[PRIMARY DIAGNOSIS DATE Data Item National Score],
	m.[PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item National Score],
	m.[PROVISIONAL DIAGNOSIS DATE Data Item National Score],
	m.[REFERRAL CLOSURE REASON Data Item National Score],
	m.[REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item National Score],
	m.[REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item National Score],
	m.[SECONDARY DIAGNOSIS DATE Data Item National Score],
	m.[SERVICE DISCHARGE TIME (HOUR) Data Item National Score],
	m.[SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item National Score],
	m.[SOURCE OF REFERRAL Data Item National Score],
	m.[SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item National Score],
	m.[TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item National Score],
	m.Dataset_Score

FROM #Master m

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
SUPPRESS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Supp') IS NOT NULL
DROP TABLE #Supp

SELECT
	u.UniqMonthID,
	u.ReportingPeriodStartDate,
	u.ReportingPeriodEndDate,
	u.PeriodType,
	u.OrgIDProvider,
	b.Organisation_Name AS [Organisation Name],
	u.DataSet,
	CASE WHEN u.ReferralsTwoConts < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.ReferralsTwoConts/5.0,0)*5 AS VARCHAR),'*') END AS [Referrals with two contacts],
	CASE WHEN u.AllSNOMEDCodes < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.AllSNOMEDCodes/5.0,0)*5 AS VARCHAR),'*') END AS [Referrals with two contacts with SNOMED intervention],
	CASE WHEN u.CurrentSNOMEDCodes < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.CurrentSNOMEDCodes/5.0,0)*5 AS VARCHAR),'*') END AS [Referrals with two contacts with a current SNOMED intervention],
	CASE WHEN u.RetiredSNOMEDCodes < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.RetiredSNOMEDCodes/5.0,0)*5 AS VARCHAR),'*') END AS [Referrals with two contacts with a retired SNOMED intervention],
	CASE WHEN u.ReferralsTwoConts < 5 THEN '*' ELSE CAST(ROUND(u.AllSNOMEDCodes*100.0/u.ReferralsTwoConts,1) AS VARCHAR) END AS [Per cent with SNOMED intervention],
	u.UniqSNOMED AS [Distinct SNOMED codes submitted in last six months],
	u.UniqCurrentSNOMED AS [Distinct current SNOMED codes submitted in last six months],
	u.UniqRetiredSNOMED AS [Distinct invalid SNOMED codes submitted in last six months],
	CASE WHEN u.DischFlag < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.DischFlag/5.0,0)*5 AS VARCHAR),'*') END AS [Total discharges],
	CASE WHEN u.InactiveFlag < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.InactiveFlag/5.0,0)*5 AS VARCHAR),'*') END AS [Inactive hospital spells],
	CASE WHEN u.ElgibleDischFlag < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.ElgibleDischFlag/5.0,0)*5 AS VARCHAR),'*') END AS [Eligible discharges],
	CASE WHEN u.AcuteDisch < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.AcuteDisch/5.0,0)*5 AS VARCHAR),'*') END AS [Eligible discharges from adult acute beds],
	CASE WHEN u.AcuteDischRec < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.AcuteDischRec/5.0,0)*5 AS VARCHAR),'*') END AS [Eligible discharges from adult acute beds received from another provider for follow up],
	CASE WHEN u.AcuteDischSent < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.AcuteDischSent/5.0,0)*5 AS VARCHAR),'*') END AS [Eligible discharges from adult acute beds sent to another provider for follow up],
	CASE WHEN u.OtherDisch < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.OtherDisch/5.0,0)*5 AS VARCHAR),'*') END AS [Eligible discharges from other bed types],
	CASE WHEN u.InvalidDisch < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.InvalidDisch/5.0,0)*5 AS VARCHAR),'*') END AS [Eligible discharges from invalid bed types],
	CASE WHEN u.MissingDisch < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.MissingDisch/5.0,0)*5 AS VARCHAR),'*') END AS [Eligible discharges with no bed type recorded],
	CASE WHEN u.FollowedUp3Days < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.FollowedUp3Days/5.0,0)*5 AS VARCHAR),'*') END AS [Eligible discharges from adult acute beds followed up within three days],
	CASE WHEN u.FollowedUp3Days < 5 THEN '*' ELSE CAST(ROUND(u.FollowedUp3Days*100.0/u.AcuteDisch,1) AS VARCHAR) END AS [Per cent followed up],
	CASE WHEN u.NoFollowUp < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.NoFollowUp/5.0,0)*5 AS VARCHAR),'*') END AS [Eligible discharges from adult acute beds with no contact],
	CASE WHEN u.DiedBeforeFollowUp < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.DiedBeforeFollowUp/5.0,0)*5 AS VARCHAR),'*') END AS [Eligible discharges where the person died before follow-up],
	CASE WHEN u.PrisonCourtDischarge < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.PrisonCourtDischarge/5.0,0)*5 AS VARCHAR),'*') END AS [Discharges to prison or court that have been excluded],
	CASE WHEN u.FinishedCourseTreatment < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.FinishedCourseTreatment/5.0,0)*5 AS VARCHAR),'*') END AS [Referrals that finished the course of treatment],
	CASE WHEN u.PairScores < 5 THEN '*' ELSE ISNULL(CAST(ROUND(u.PairScores/5.0,0)*5 AS VARCHAR),'*') END AS [Referrals that finished the course of treatment with a paired ADSM],
	CASE WHEN u.FinishedCourseTreatment < 5 THEN '*' ELSE CAST(ROUND(u.PairScores*100.0/u.FinishedCourseTreatment,1) AS VARCHAR) END AS [Per cent of referrals that finished the course of treatment with a paired ADSM],
	u.[ACTIVITY LOCATION TYPE CODE Data Item Score],
	u.[ATTENDED OR DID NOT ATTEND Data Item Score],
	u.[CARE CONTACT TIME (HOUR) Data Item Score],
	u.[CARE PLAN TYPE Data Item Score],
	u.[CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item Score],
	u.[CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item Score],
	u.[CONSULTATION MEDIUM USED Data Item Score],
	u.[DELAYED DISCHARGE ATTRIBUTABLE TO Data Item Score],
	u.[DELAYED DISCHARGE REASON Data Item Score],
	u.[DISCHARGE PLAN CREATION TIME (HOUR) Data Item Score],
	u.[ESTIMATED DISCHARGE DATE Data Item Score],
	u.[ETHNIC CATEGORY Data Item Score],
	u.[EX-BRITISH ARMED FORCES INDICATOR Data Item Score],
	u.[GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item Score],
	u.[HOSPITAL BED TYPE (MENTAL HEALTH) Data Item Score],
	u.[INDIRECT ACTIVITY TIME (HOUR) Data Item Score],
	u.[MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item Score],
	u.[NHS NUMBER Data Item Score],
	u.[ONWARD REFERRAL TIME (HOUR) Data Item Score],
	u.[ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item Score],
	u.[ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item Score],
	u.[PERSON BIRTH DATE Data Item Score],
	u.[PERSON STATED GENDER CODE Data Item Score],
	u.[POSTCODE OF USUAL ADDRESS Data Item Score],
	u.[PRIMARY DIAGNOSIS DATE Data Item Score],
	u.[PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item Score],
	u.[PROVISIONAL DIAGNOSIS DATE Data Item Score],
	u.[REFERRAL CLOSURE REASON Data Item Score],
	u.[REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item Score],
	u.[REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item Score],
	u.[SECONDARY DIAGNOSIS DATE Data Item Score],
	u.[SERVICE DISCHARGE TIME (HOUR) Data Item Score],
	u.[SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item Score],
	u.[SOURCE OF REFERRAL Data Item Score],
	u.[SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item Score],
	u.[TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item Score],
	u.[ACTIVITY LOCATION TYPE CODE Data Item National Score],
	u.[ATTENDED OR DID NOT ATTEND Data Item National Score],
	u.[CARE CONTACT TIME (HOUR) Data Item National Score],
	u.[CARE PLAN TYPE Data Item National Score],
	u.[CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item National Score],
	u.[CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item National Score],
	u.[CONSULTATION MEDIUM USED Data Item National Score],
	u.[DELAYED DISCHARGE ATTRIBUTABLE TO Data Item National Score],
	u.[DELAYED DISCHARGE REASON Data Item National Score],
	u.[DISCHARGE PLAN CREATION TIME (HOUR) Data Item National Score],
	u.[ESTIMATED DISCHARGE DATE Data Item National Score],
	u.[ETHNIC CATEGORY Data Item National Score],
	u.[EX-BRITISH ARMED FORCES INDICATOR Data Item National Score],
	u.[GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item National Score],
	u.[HOSPITAL BED TYPE (MENTAL HEALTH) Data Item National Score],
	u.[INDIRECT ACTIVITY TIME (HOUR) Data Item National Score],
	u.[MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item National Score],
	u.[NHS NUMBER Data Item National Score],
	u.[ONWARD REFERRAL TIME (HOUR) Data Item National Score],
	u.[ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item National Score],
	u.[ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item National Score],
	u.[PERSON BIRTH DATE Data Item National Score],
	u.[PERSON STATED GENDER CODE Data Item National Score],
	u.[POSTCODE OF USUAL ADDRESS Data Item National Score],
	u.[PRIMARY DIAGNOSIS DATE Data Item National Score],
	u.[PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item National Score],
	u.[PROVISIONAL DIAGNOSIS DATE Data Item National Score],
	u.[REFERRAL CLOSURE REASON Data Item National Score],
	u.[REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item National Score],
	u.[REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item National Score],
	u.[SECONDARY DIAGNOSIS DATE Data Item National Score],
	u.[SERVICE DISCHARGE TIME (HOUR) Data Item National Score],
	u.[SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item National Score],
	u.[SOURCE OF REFERRAL Data Item National Score],
	u.[SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item National Score],
	u.[TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item National Score],
	u.Dataset_Score
	
INTO #Supp  

FROM #UnSupp u

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies b ON u.OrgIDProvider = b.Organisation_Code

WHERE Organisation_Name IS NOT NULL

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET OUTPUT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Dashboard_CQUIN1920') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Dashboard_CQUIN1920

SELECT
	s.UniqMonthID,
	s.ReportingPeriodStartDate,
	s.ReportingPeriodEndDate,
	s.PeriodType,
	s.OrgIDProvider,
	s.[Organisation Name],
	s.DataSet,
	s.[Referrals with two contacts],
	s.[Referrals with two contacts with a current SNOMED intervention],
	s.[Referrals with two contacts with a retired SNOMED intervention],
	s.[Referrals with two contacts with SNOMED intervention],
	s.[Per cent with SNOMED intervention],
	s.[Distinct SNOMED codes submitted in last six months],
	s.[Total discharges],
	s.[Inactive hospital spells],
	s.[Eligible discharges],
	s.[Eligible discharges from adult acute beds],
	s.[Eligible discharges from adult acute beds received from another provider for follow up],
	s.[Eligible discharges from adult acute beds sent to another provider for follow up],
	s.[Eligible discharges from other bed types],
	s.[Eligible discharges from invalid bed types],
	s.[Eligible discharges with no bed type recorded],
	s.[Eligible discharges from adult acute beds followed up within three days],
	s.[Per cent followed up],
	s.[Eligible discharges from adult acute beds with no contact],
	s.[Eligible discharges where the person died before follow-up],
	s.[Discharges to prison or court that have been excluded],
	s.[Referrals that finished the course of treatment],
	s.[Referrals that finished the course of treatment with a paired ADSM],
	s.[Per cent of referrals that finished the course of treatment with a paired ADSM],
	n.[Referrals with two contacts (England)],
	n.[Referrals with two contacts with a current SNOMED intervention (England)],
	n.[Referrals with two contacts with a retired SNOMED intervention (England)],
	n.[Referrals with two contacts with SNOMED intervention (England)],
	n.[Per cent with SNOMED intervention (England)],
	n.[Total discharges (England)],
	n.[Inactive hospital spells (England)],
	n.[Eligible discharges (England)],
	n.[Eligible discharges from adult acute beds (England)],
	n.[Eligible discharges from adult acute beds received from another provider for follow up (England)],
	n.[Eligible discharges from adult acute beds sent to another provider for follow up (England)],
	n.[Eligible discharges from other bed types (England)],
	n.[Eligible discharges from invalid bed types (England)],
	n.[Eligible discharges with no bed type recorded (England)],
	n.[Eligible discharges from adult acute beds followed up within three days (England)],
	n.[Per cent followed up within three days (England)],
	n.[Eligible discharges from adult acute beds with no contact (England)],
	n.[Eligible discharges where the person died before follow-up (England)],
	n.[Discharges to prison or court that have been excluded (England)],
	n.[Referrals that finished the course of treatment (England)],
	n.[Referrals that finished the course of treatment with a paired ADSM (England)],
	n.[Per cent of referrals that finished the course of treatment with a paired ADSM  (England)],
	s.[ACTIVITY LOCATION TYPE CODE Data Item Score],
	s.[ATTENDED OR DID NOT ATTEND Data Item Score],
	s.[CARE CONTACT TIME (HOUR) Data Item Score],
	s.[CARE PLAN TYPE Data Item Score],
	s.[CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item Score],
	s.[CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item Score],
	s.[CONSULTATION MEDIUM USED Data Item Score],
	s.[DELAYED DISCHARGE ATTRIBUTABLE TO Data Item Score],
	s.[DELAYED DISCHARGE REASON Data Item Score],
	s.[DISCHARGE PLAN CREATION TIME (HOUR) Data Item Score],
	s.[ESTIMATED DISCHARGE DATE Data Item Score],
	s.[ETHNIC CATEGORY Data Item Score],
	s.[EX-BRITISH ARMED FORCES INDICATOR Data Item Score],
	s.[GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item Score],
	s.[HOSPITAL BED TYPE (MENTAL HEALTH) Data Item Score],
	s.[INDIRECT ACTIVITY TIME (HOUR) Data Item Score],
	s.[MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item Score],
	s.[NHS NUMBER Data Item Score],
	s.[ONWARD REFERRAL TIME (HOUR) Data Item Score],
	s.[ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item Score],
	s.[ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item Score],
	s.[PERSON BIRTH DATE Data Item Score],
	s.[PERSON STATED GENDER CODE Data Item Score],
	s.[POSTCODE OF USUAL ADDRESS Data Item Score],
	s.[PRIMARY DIAGNOSIS DATE Data Item Score],
	s.[PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item Score],
	s.[PROVISIONAL DIAGNOSIS DATE Data Item Score],
	s.[REFERRAL CLOSURE REASON Data Item Score],
	s.[REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item Score],
	s.[REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item Score],
	s.[SECONDARY DIAGNOSIS DATE Data Item Score],
	s.[SERVICE DISCHARGE TIME (HOUR) Data Item Score],
	s.[SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item Score],
	s.[SOURCE OF REFERRAL Data Item Score],
	s.[SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item Score],
	s.[TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item Score],
	s.[ACTIVITY LOCATION TYPE CODE Data Item National Score],
	s.[ATTENDED OR DID NOT ATTEND Data Item National Score],
	s.[CARE CONTACT TIME (HOUR) Data Item National Score],
	s.[CARE PLAN TYPE Data Item National Score],
	s.[CARE PROFESSIONAL SERVICE OR TEAM TYPE ASSOCIATION (MENTAL HEALTH) Data Item National Score],
	s.[CLINICAL RESPONSE PRIORITY TYPE (EATING DISORDER) Data Item National Score],
	s.[CONSULTATION MEDIUM USED Data Item National Score],
	s.[DELAYED DISCHARGE ATTRIBUTABLE TO Data Item National Score],
	s.[DELAYED DISCHARGE REASON Data Item National Score],
	s.[DISCHARGE PLAN CREATION TIME (HOUR) Data Item National Score],
	s.[ESTIMATED DISCHARGE DATE Data Item National Score],
	s.[ETHNIC CATEGORY Data Item National Score],
	s.[EX-BRITISH ARMED FORCES INDICATOR Data Item National Score],
	s.[GENERAL MEDICAL PRACTICE CODE (PATIENT REGISTRATION) Data Item National Score],
	s.[HOSPITAL BED TYPE (MENTAL HEALTH) Data Item National Score],
	s.[INDIRECT ACTIVITY TIME (HOUR) Data Item National Score],
	s.[MENTAL HEALTH ACT LEGAL STATUS CLASSIFICATION CODE Data Item National Score],
	s.[NHS NUMBER Data Item National Score],
	s.[ONWARD REFERRAL TIME (HOUR) Data Item National Score],
	s.[ORGANISATION IDENTIFIER (CODE OF COMMISSIONER) Data Item National Score],
	s.[ORGANISATION SITE IDENTIFIER (OF TREATMENT) Data Item National Score],
	s.[PERSON BIRTH DATE Data Item National Score],
	s.[PERSON STATED GENDER CODE Data Item National Score],
	s.[POSTCODE OF USUAL ADDRESS Data Item National Score],
	s.[PRIMARY DIAGNOSIS DATE Data Item National Score],
	s.[PRIMARY REASON FOR REFERRAL (MENTAL HEALTH) (REFERRAL RECEIVED ON OR AFTER 1ST JAN 2016) Data Item National Score],
	s.[PROVISIONAL DIAGNOSIS DATE Data Item National Score],
	s.[REFERRAL CLOSURE REASON Data Item National Score],
	s.[REFERRAL REQUEST RECEIVED TIME (HOUR) Data Item National Score],
	s.[REFERRED OUT OF AREA REASON (ADULT ACUTE MENTAL HEALTH) Data Item National Score],
	s.[SECONDARY DIAGNOSIS DATE Data Item National Score],
	s.[SERVICE DISCHARGE TIME (HOUR) Data Item National Score],
	s.[SERVICE OR TEAM TYPE REFERRED TO (MENTAL HEALTH) Data Item National Score],
	s.[SOURCE OF REFERRAL Data Item National Score],
	s.[SPECIALISED MENTAL HEALTH SERVICE CODE - WARD STAY Data Item National Score],
	s.[TREATMENT FUNCTION CODE (MENTAL HEALTH) Data Item National Score],
	s.Dataset_Score

INTO NHSE_Sandbox_MentalHealth.dbo.Dashboard_CQUIN1920

FROM #Supp s

LEFT JOIN 
(SELECT
	u.ReportingPeriodEndDate,
	u.PeriodType,
	SUM(ISNULL(u.ReferralsTwoConts,0)) AS [Referrals with two contacts (England)],
	SUM(ISNULL(u.AllSNOMEDCodes,0)) AS [Referrals with two contacts with SNOMED intervention (England)],
	SUM(ISNULL(u.CurrentSNOMEDCodes,0)) AS [Referrals with two contacts with a current SNOMED intervention (England)],
	SUM(ISNULL(u.RetiredSNOMEDCodes,0)) AS [Referrals with two contacts with a retired SNOMED intervention (England)],
	ROUND(SUM(u.AllSNOMEDCodes*100.0)/NULLIF(SUM(u.ReferralsTwoConts),0),1) AS [Per cent with SNOMED intervention (England)],
	MAX(u.UniqSNOMED) AS [Distinct SNOMED codes submitted in last six months (England)],
	MAX(u.UniqCurrentSNOMED) AS [Distinct current SNOMED codes submitted in last six months (England)],
	MAX(u.UniqRetiredSNOMED) AS [Distinct invalid SNOMED codes submitted in last six months (England)],
	SUM(ISNULL(u.DischFlag,0)) AS [Total discharges (England)],
	SUM(ISNULL(u.InactiveFlag,0)) AS [Inactive hospital spells (England)],
	SUM(ISNULL(u.ElgibleDischFlag,0)) AS [Eligible discharges (England)],
	SUM(ISNULL(u.AcuteDisch,0)) AS [Eligible discharges from adult acute beds (England)],
	SUM(ISNULL(u.AcuteDischRec,0)) AS [Eligible discharges from adult acute beds received from another provider for follow up (England)],
	SUM(ISNULL(u.AcuteDischSent,0)) AS [Eligible discharges from adult acute beds sent to another provider for follow up (England)],
	SUM(ISNULL(u.OtherDisch,0)) AS [Eligible discharges from other bed types (England)],
	SUM(ISNULL(u.InvalidDisch,0)) AS [Eligible discharges from invalid bed types (England)],
	SUM(ISNULL(u.MissingDisch,0)) AS [Eligible discharges with no bed type recorded (England)],
	SUM(ISNULL(u.FollowedUp3Days,0)) AS [Eligible discharges from adult acute beds followed up within three days (England)],
	ROUND(SUM(u.FollowedUp3Days*100.0)/NULLIF(SUM(u.AcuteDisch),0),1) AS [Per cent followed up within three days (England)],
	SUM(ISNULL(u.NoFollowUp,0)) AS [Eligible discharges from adult acute beds with no contact (England)],
	SUM(ISNULL(u.DiedBeforeFollowUp,0)) AS [Eligible discharges where the person died before follow-up (England)],
	SUM(ISNULL(u.PrisonCourtDischarge,0)) AS [Discharges to prison or court that have been excluded (England)],
	SUM(ISNULL(u.FinishedCourseTreatment,0)) AS [Referrals that finished the course of treatment (England)],
	SUM(ISNULL(u.PairScores,0)) AS [Referrals that finished the course of treatment with a paired ADSM (England)],
	ROUND(SUM(u.PairScores*100.0)/NULLIF(SUM(u.FinishedCourseTreatment),0),1) AS [Per cent of referrals that finished the course of treatment with a paired ADSM  (England)]

FROM #UnSupp u

WHERE OrgIDProvider LIKE 'R%' OR OrgIDProvider LIKE 'T%'

GROUP BY u.ReportingPeriodEndDate, u.PeriodType) n ON n.ReportingPeriodEndDate = s.ReportingPeriodEndDate AND n.PeriodType = s.PeriodType

SELECT * FROM NHSE_Sandbox_MentalHealth.dbo.Dashboard_CQUIN1920 ORDER BY 5,1