/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CYP AWT REPORTING

ASSET: PRE-PROCESSED TABLES

CREATED BY CARL MONEY 17/08/2021

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

----SET VARIABLES

DECLARE @EndRP INT

SET @EndRP	= (SELECT UniqMonthID
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE Der_MostRecentFlag = 'P')

DECLARE @ReportingPeriodEnd DATE

SET @ReportingPeriodEnd = (SELECT ReportingPeriodEndDate
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE Der_MostRecentFlag = 'P')

DECLARE @ReportingPeriodStart DATE

SET @ReportingPeriodStart = (SELECT ReportingPeriodStartDate
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE Der_MostRecentFlag = 'P')

DECLARE @FYStart INT

SET @FYStart = (SELECT MAX(UniqMonthID)
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE Der_FYStart = 'Y')

DECLARE @StartRP INT

SET @StartRP = 1429 -- Apr 19 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LOG START
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'CYP Report Start' AS Step,
	GETDATE() AS [TimeStamp]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDENTIFY REFERRALS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Ref') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Ref

SELECT
	r.ReportingPeriodStartDate,
	r.ReportingPeriodEndDate,
	r.Der_FY,
	r.UniqMonthID,
	r.OrgIDProv,
	r.Person_ID,
	CASE WHEN r.OrgIDProv = 'DFC' THEN r.UniqServReqID ELSE r.Person_ID END AS Der_PersonID, -- work around for anonymous services, where new Person_IDs may be allocated
	CASE WHEN r.OrgIDProv = 'DFC' THEN r.OrgIDComm ELSE r.OrgIDCCGRes END AS Der_OrgComm, -- to correctly allocate commissioner to Kooth
	r.RecordNumber,
	r.UniqServReqID,
	r.ReferralRequestReceivedDate,
	r.EthnicCategory,
	r.Gender,
	r.LSOA2011,
	r.LADistrictAuth,
	r.AgeServReferRecDate,
	r.AgeRepPeriodEnd,
	r.ServDischDate,
	r.ReferClosReason,
	r.ReferRejectionDate,
	r.ReferRejectReason,
	r.ServTeamTypeRefToMH,
	LEFT(r.UniqCareProfTeamID,50) AS UniqCareProfTeamID,
	r.PrimReasonReferralMH

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Ref

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Referral r

WHERE r.AgeServReferRecDate BETWEEN 0 AND 17 AND r.UniqMonthID BETWEEN @StartRP AND @EndRP AND (r.LADistrictAuth LIKE 'E%' OR r.LADistrictAuth IS NULL)

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CREATE DERIVATIONS - DIMENSIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Dim') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Dim

SELECT
	r.ReportingPeriodStartDate,
	r.ReportingPeriodEndDate,
	r.Der_FY AS [Financial year],
	r.UniqMonthID,
	r.UniqServReqID,
	r.RecordNumber,
	r.OrgIDProv AS [Provider code],
	p.Organisation_Name AS [Provider name],
	COALESCE(cc.New_Code,r.Der_OrgComm, 'Missing / Invalid') AS [CCG code],
	COALESCE(c.Organisation_Name,'Missing / Invalid') AS [CCG name],
	COALESCE(la.District_Unitary_Authority,'Missing / Invalid') AS [Local Authority code],
	COALESCE(RIGHT(la.[District_Unitary_Authority_Name],CHARINDEX(':',REVERSE(la.[District_Unitary_Authority_Name]))-2),'Missing / Invalid') AS [Local Authority name],
	COALESCE(c.STP_Code,'Missing / Invalid') AS [STP code],
	COALESCE(c.STP_Name,'Missing / Invalid') AS [STP name],
	COALESCE(c.Region_Code,'Missing / Invalid') AS [Region code],
	COALESCE(c.Region_Name,'Missing / Invalid') AS [Region name],
	r.Person_ID,
	r.Der_PersonID,
	CASE 
		WHEN e.Category IS NULL THEN  'Missing / invalid'
		WHEN e.Category = '' THEN 'Missing / invalid'
		ELSE CONCAT(e.[Category],' - ',e.[Main_Description_60_Chars])
	END AS Ethnicity,
	COALESCE(RIGHT(Person_Gender_Desc, LEN(Person_Gender_Desc) - 3), 'Missing / invalid') AS Gender,
	COALESCE(CASE WHEN l.IMD_Decile = '1' THEN '1 - most deprived' WHEN l.IMD_Decile = '10' THEN '10 - least deprived' ELSE CAST(l.IMD_Decile AS Varchar) END, 'Missing / Invalid') AS IMD_Decile,
	r.AgeServReferRecDate,
	r.AgeRepPeriodEnd,
	r.ReferralRequestReceivedDate,
	COALESCE(rr.Main_Description, 'Missing / invalid') AS [Primary reason for referral],
	CASE WHEN r.ServTeamTypeRefToMH = 'F01' THEN 'Mental Health Support Team' ELSE COALESCE(t.Main_Description, 'Missing / invalid') END AS [Team type],
	r.UniqCareProfTeamID,
	r.ServDischDate,
	r.ReferRejectionDate,
	r.ReferClosReason,
	r.ReferRejectReason

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Dim

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Ref r

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_DataDic_ZZZ_ReasonForReferralToMentalHealth rr ON r.PrimReasonReferralMH = rr.Main_Code_Text COLLATE DATABASE_DEFAULT AND rr.Effective_To IS NULL AND rr.Valid_To IS NULL

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_DataDic_ZZZ_ServiceOrTeamTypeForMentalHealth t ON r.ServTeamTypeRefToMH = t.Main_Code_Text COLLATE DATABASE_DEFAULT AND t.Effective_To IS NULL AND t.Valid_To IS NULL

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_Other_Deprivation_By_LSOA l ON r.LSOA2011 = l.LSOA_Code AND l.Effective_Snapshot_Date = '2019-12-31'

LEFT JOIN NHSE_UKHF.Data_Dictionary.vw_Ethnic_Category_Code_SCD e ON r.EthnicCategory = e.[Main_Code_Text] COLLATE DATABASE_DEFAULT AND e.Is_Latest = 1

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_DataDic_ZZZ_PersonGender g ON r.Gender = g.Person_Gender_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_Other_ComCodeChanges cc ON r.Der_OrgComm = cc.Org_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies p ON r.OrgIDProv = p.Organisation_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies c ON COALESCE(cc.New_Code,r.Der_OrgComm) = c.Organisation_Code

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_DistrictUnitaryAuthority] la ON r.LADistrictAuth = la.District_Unitary_Authority

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LINK TO ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Act') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Act

SELECT
	d.ReportingPeriodEndDate,
	d.UniqMonthID,
	d.[Financial year],
	d.Person_ID,
	d.RecordNumber,
	d.UniqServReqID,
	d.[Provider code],
	d.[Provider name],
	d.[CCG code],
	d.[CCG name],
	d.[Local Authority code],
	d.[Local Authority name],
	d.[STP code],
	d.[STP name],
	d.[Region code],
	d.[Region name],
	d.[Primary reason for referral],
	d.[Team type],
	CASE 
		WHEN a.Der_Contact IS NOT NULL AND a.Der_ActivityType = 'Indirect' THEN 'Indirect'
		WHEN a.Der_Contact IS NOT NULL AND a.ConsMediumUsed = '01' THEN 'Consultation medium - face to face'
		WHEN a.Der_Contact IS NOT NULL AND a.ConsMediumUsed  = '02' THEN 'Consultation medium - telephone'
		WHEN a.Der_Contact IS NOT NULL AND (a.UniqMonthID < 1459 AND a.ConsMediumUsed = '03' OR a.UniqMonthID >= 1459 AND a.ConsMediumUsed = '11') THEN 'Consultation medium - video consult'
		WHEN a.Der_Contact IS NOT NULL AND (a.UniqMonthID < 1459 AND a.ConsMediumUsed IN ('04','98') OR a.UniqMonthID >= 1459 AND a.ConsMediumUsed IN ('05','09', '10', '13')) THEN 'Consultation medium - other'
		WHEN a.Der_Contact IS NOT NULL THEN 'Consultation medium - missing / invalid'
	END AS Der_ConsMediumUsed,
	CASE 
		WHEN a.AttendOrDNACode IN ('7','3') THEN 'Contact attendance - DNA'
		WHEN a.AttendOrDNACode IN ('2','4') THEN 'Contact attendance - cancelled'
		WHEN a.AttendOrDNACode IN ('5','6') THEN 'Contact attendance - attended'
		WHEN a.Der_ActivityType = 'DIRECT' AND a.AttendOrDNACode NOT IN ('2','3','4','5','6','7') THEN 'Contact attendance - missing / invalid'
	END AS Der_AttendDNA,
	CASE
		WHEN a.Der_Contact IS NOT NULL AND a.Der_ContactDuration IS NULL OR a.Der_ContactDuration = 0 THEN 'Contact duration - no time recorded'
		WHEN a.Der_Contact IS NOT NULL AND a.Der_ContactDuration BETWEEN 1 AND 14 THEN 'Contact duration - less than 15 mins'
		WHEN a.Der_Contact IS NOT NULL AND a.Der_ContactDuration BETWEEN 15 AND 29 THEN 'Contact duration - 15 to 30 mins'
		WHEN a.Der_Contact IS NOT NULL AND a.Der_ContactDuration BETWEEN 30 AND 59 THEN 'Contact duration - 30 mins to an hour'
		WHEN a.Der_Contact IS NOT NULL AND a.Der_ContactDuration >59 THEN 'Contact duration - over an hour'
	END AS Der_ContactDurationCat,
	a.Der_Contact

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Act

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Dim d ON a.RecordNumber = d.RecordNumber AND a.UniqServReqID = d.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET CUMULATIVE ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Cumulative') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Cumulative

SELECT
	r.ReportingPeriodEndDate,
	r.RecordNumber,
	r.UniqServReqID,

	-- cumulative activity
	MAX(a.Der_ContactDate) AS Der_LastContact,
	MIN(a.Der_ContactDate) AS Der_FirstContactDate,
	SUM(a.Der_Contact) AS Der_CumulativeContacts,
	MIN(CASE WHEN r.Der_FY = a.Der_FY THEN a.Der_ContactDate END) AS Der_FirstFYContact

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Cumulative

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Ref r

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a ON CASE WHEN a.OrgIDProv = 'DFC' THEN a.UniqServReqID ELSE a.Person_ID END = r.Der_PersonID
	AND r.UniqServReqID = a.UniqServReqID AND a.ReportingPeriodEndDate <= r.ReportingPeriodEndDate 

WHERE a.Der_Contact = 1

GROUP BY r.RecordNumber, r.ReportingPeriodEndDate, r.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

WAITING TIMES SECTION

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ASSESSMENT AND INTERVENTIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Subs') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Subs

	-- care plans to month before latest performance data (no pre processed table here)

SELECT
	f.Person_ID,
	f.UniqServReqID,
	c.RecordNumber,
	CAST('Care Plan' AS varchar(30)) AS Der_EventType,
	CAST(CASE 
		WHEN c.CarePlanTypeMH = '10' THEN 'Mental Health Care Plan'
		WHEN c.CarePlanTypeMH = '11' THEN 'Urgent and Emergency Mental Health Care Plan'
		WHEN c.CarePlanTypeMH = '12' THEN 'Mental Health Crisis Plan'
		WHEN c.CarePlanTypeMH = '13' THEN 'Positive Behaviour Support Plan'
		WHEN c.CarePlanTypeMH = '14' THEN 'Child or Young Persons Mental Health Transition Plan'
	END AS VARCHAR (255)) AS Der_EventDescription,
	cpa.CarePlanContentAgreedDate AS Der_EventDate

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Subs

FROM NHSE_MHSDS.dbo.MHS008CarePlanType c

INNER JOIN NHSE_MHSDS.dbo.MHS009CarePlanAgreement cpa ON cpa.RecordNumber = c.RecordNumber AND cpa.UniqCarePlanID = c.UniqCarePlanID

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_ref f ON c.RecordNumber = f.RecordNumber AND f.ReferralRequestReceivedDate >= COALESCE(c.CarePlanLastUpdateDate,c.CarePlanCreatDate)

INNER JOIN NHSE_MH_PrePublication.Test.MHSDS_SubmissionFlags s ON c.NHSEUniqSubmissionID = s.NHSEUniqSubmissionID AND s.Der_IsLatest = 'Y'

	-- care plans for latest performance and provisional data (no pre processed table here)

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Subs

SELECT
	f.Person_ID,
	f.UniqServReqID,
	c.RecordNumber,
	'Care Plan' AS Der_EventType,
	CASE 
		WHEN c.CarePlanTypeMH = '10' THEN 'Mental Health Care Plan'
		WHEN c.CarePlanTypeMH = '11' THEN 'Urgent and Emergency Mental Health Care Plan'
		WHEN c.CarePlanTypeMH = '12' THEN 'Mental Health Crisis Plan'
		WHEN c.CarePlanTypeMH = '13' THEN 'Positive Behaviour Support Plan'
		WHEN c.CarePlanTypeMH = '14' THEN 'Child or Young Persons Mental Health Transition Plan'
	END AS Der_EventDescription,
	cpa.CarePlanContentAgreedDate AS Der_EventDate

FROM NHSE_MH_PrePublication.test.MHS008CarePlanType c

INNER JOIN NHSE_MH_PrePublication.test.MHS009CarePlanAgreement cpa ON cpa.RecordNumber = c.RecordNumber AND cpa.UniqCarePlanID = c.UniqCarePlanID

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_ref f ON c.RecordNumber = f.RecordNumber AND f.ReferralRequestReceivedDate >= COALESCE(c.CarePlanLastUpdateDate,c.CarePlanCreatDate)

INNER JOIN NHSE_MH_PrePublication.Test.MHSDS_SubmissionFlags s ON c.NHSEUniqSubmissionID = s.NHSEUniqSubmissionID AND s.Der_IsLatest = 'Y'

	-- interventions data

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Subs

SELECT
	f.Person_ID,
	f.UniqServReqID,
	i.RecordNumber,
	'SNoMED intervention' AS Der_EventType,
	i.Der_SNoMEDProcTerm AS Der_EventDescription,
	i.Der_ContactDate AS Der_EventDate

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Interventions i 

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Ref f ON i.RecordNumber = f.RecordNumber AND f.UniqServReqID = i.UniqServReqID

WHERE i.Der_SNoMEDProcTerm IS NOT NULL

	-- assessment data

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Subs

SELECT
	f.Person_ID,
	f.UniqServReqID,
	ass.RecordNumber,
	'Assessment - Outcome' AS Der_EventType,
	ass.Der_AssessmentToolName AS Der_EventDescription,
	ass.Der_AssToolCompDate AS Der_EventDate

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Assessments ass

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_ref f ON ass.RecordNumber = f.RecordNumber AND f.UniqServReqID = ass.UniqServReqID

WHERE ass.Der_AssessmentToolName IS NOT NULL

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDENTIFY FIRST OCCURANCE OF EACH EVENT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_SubsRanked') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_SubsRanked

SELECT
	s.Person_ID,
	s.UniqServReqID,
	s.RecordNumber,
	s.Der_EventType,
	s.Der_EventDescription,
	s.Der_EventDate,
	ROW_NUMBER() OVER (PARTITION by s.UniqServReqID, s.Person_ID, s.Der_EventType ORDER BY s.Der_EventDate) AS Der_EventOrder

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_SubsRanked

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Subs s

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LINK FIRST ASSESSMENT, OUTCOME AND INTERVENTION TO REFERRAL
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_SubsRef') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_SubsRef

SELECT DISTINCT
	r.Person_ID,
	r.UniqServReqID,
	so.Der_EventType AS Der_OutEventType,
	so.Der_EventDescription AS Der_OutEventDescription,
	so.Der_EventDate AS Der_OutEventDate,
	st.Der_EventType AS Der_IntEventType,
	st.Der_EventDescription AS Der_IntEventDescription,
	st.Der_EventDate AS Der_IntEventDate,
	sc.Der_EventType AS Der_CPEventType,
	sc.Der_EventDescription AS Der_CPEventDescription,
	sc.Der_EventDate AS Der_CPEventDate

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_SubsRef

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_ref r

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_SubsRanked so ON so.Person_ID = r.Person_ID AND so.UniqServReqID = r.UniqServReqID AND so.Der_EventType = 'Assessment - Outcome' AND so.Der_EventOrder = 1 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_SubsRanked st ON st.Person_ID = r.Person_ID AND st.UniqServReqID = r.UniqServReqID AND st.Der_EventType = 'SNoMED intervention' AND st.Der_EventOrder = 1

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_SubsRanked sc ON sc.Person_ID = r.Person_ID AND sc.UniqServReqID = r.UniqServReqID AND sc.Der_EventType = 'Care Plan' AND sc.Der_EventOrder = 1

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CREATE DERIVATIONS - MEASURES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Master') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Master

SELECT
	r.[ReportingPeriodStartDate],
	r.[ReportingPeriodEndDate],
	r.[UniqMonthID],
	r.[Financial year],
	r.[UniqServReqID],
	r.[Provider code],
	r.[Provider name],
	r.[CCG code],
	r.[CCG name],
	r.[Local Authority code],
	r.[Local Authority name],
	r.[STP code],
	r.[STP name],
	r.[Region code],
	r.[Region name],
	r.[Person_ID],
	r.[Ethnicity],
	r.[Gender],
	r.[IMD_Decile],
	r.[AgeServReferRecDate],
	r.[ReferralRequestReceivedDate],
	r.[Primary reason for referral],
	r.[Team type],
	r.[UniqCareProfTeamID],

	---- get caseload measures
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL THEN 1 ELSE 0 END AS [Open referrals],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_LastContact IS NOT NULL THEN 1 ELSE 0 END AS [Caseload],
	CASE WHEN r.ReferralRequestReceivedDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [New referrals],
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [Closed referrals],
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate  AND r.ReferClosReason IN ('02','04') THEN 1 ELSE 0 END AS [Closed referrals - treatment complete / further treatment not appropriate],
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate  AND r.ReferClosReason IN ('01','08') THEN 1 ELSE 0 END AS [Closed referrals - admitted / referred elsewhere],
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate  AND r.ReferClosReason IN ('03','07') THEN 1 ELSE 0 END AS [Closed referrals - person moved / requested discharge],
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate  AND r.ReferClosReason IN ('05','09') THEN 1 ELSE 0 END AS [Closed referrals - DNA / refused to be seen],
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate  AND cu.Der_LastContact IS NOT NULL AND r.ReferClosReason = '08' THEN 1 ELSE 0 END AS [Closed referrals signposted],
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate  AND (r.ReferClosReason NOT IN ('01','02','03','04','05','07','08','09') OR r.ReferClosReason IS NULL) THEN 1 ELSE 0 END AS [Closed referrals - other reason / unknown],
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate  AND cu.Der_CumulativeContacts = 1 THEN 1 ELSE 0 END AS [Closed with one contact],
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate  AND cu.Der_CumulativeContacts > 1 THEN 1 ELSE 0 END AS [Closed with two or more contacts],
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate  AND (cu.Der_CumulativeContacts IS NULL OR cu.Der_CumulativeContacts = 0) THEN 1 ELSE 0 END AS [Closed with no contacts offered / attended],
	CASE WHEN cu.Der_FirstFYContact BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [Contact in financial year], 

	---- get referral length for referrals closed in month, inc categories
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ServDischDate) BETWEEN 0 and 6 THEN 1 ELSE 0 END AS [Referral length - less than one week],
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ServDischDate) BETWEEN 7 and 13 THEN 1 ELSE 0 END AS [Referral length - one to two weeks],
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ServDischDate) BETWEEN 14 and 27 THEN 1 ELSE 0 END AS [Referral length - two to four weeks],
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ServDischDate) BETWEEN 28 and 182	THEN 1 ELSE 0 END AS [Referral length - one to six months],
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ServDischDate) > 182 THEN 1 ELSE 0 END AS [Referral length - six months and over],

	---- get referral not accepted measures, inc duration
	CASE WHEN r.ReferRejectionDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate  THEN 1 ELSE 0 END AS [Referrals not accepted],
	CASE WHEN r.ReferRejectionDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate  AND r.ReferRejectReason = 02 THEN 1 ELSE 0 END AS [Referrals not accepted - alternative service required],
	CASE WHEN r.ReferRejectionDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate  AND r.ReferRejectReason = 01 THEN 1 ELSE 0 END AS [Referrals not accepted - duplicate],
	CASE WHEN r.ReferRejectionDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate  AND r.ReferRejectReason = 03 THEN 1 ELSE 0 END AS [Referrals not accepted - incomplete],
	CASE WHEN r.ReferRejectionDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate  AND (r.ReferRejectReason NOT IN (01,02,03) OR r.ReferRejectReason IS NULL) THEN 1 ELSE 0 END AS [Referrals not accepted - missing / invalid],
	CASE WHEN r.ReferRejectionDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate  THEN DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ReferRejectionDate) END AS [Referrals not accepted length],

	---- get days since last contact measures, inc categories, limited to open referrals at month end
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND DATEDIFF(dd,cu.Der_LastContact,r.ReportingPeriodEndDate) BETWEEN 0 and 6 THEN 1 ELSE 0 END AS [Time since last contact - less than one week],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND DATEDIFF(dd,cu.Der_LastContact,r.ReportingPeriodEndDate) BETWEEN 7 and 13 THEN 1 ELSE 0 END AS [Time since last contact - one to two weeks],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND DATEDIFF(dd,cu.Der_LastContact,r.ReportingPeriodEndDate) BETWEEN 14 and 27 THEN 1 ELSE 0 END AS [Time since last contact - two to four weeks],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND DATEDIFF(dd,cu.Der_LastContact,r.ReportingPeriodEndDate) >27 THEN 1 ELSE 0 END AS [Time since last contact - four weeks or more],
	
	---- get quality of care measures
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate)AND r.ReferRejectionDate IS NULL AND cu.Der_LastContact IS NOT NULL AND s.Der_CPEventDate <= r.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [Referrals with a care plan],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_LastContact IS NOT NULL AND s.Der_IntEventDate <= r.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [Referrals with an intervention],

	---- get waiting times - First contact
	CASE WHEN cu.Der_FirstContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [First contact in period],
	CASE WHEN cu.Der_FirstContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,cu.Der_FirstContactDate) 
		<0 THEN 1 ELSE 0 END AS [Time to first contact - before referral start],	
	CASE WHEN cu.Der_FirstContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,cu.Der_FirstContactDate) 
		BETWEEN 0 and 6 THEN 1 ELSE 0 END AS [Time to first contact - less than one week],
	CASE WHEN cu.Der_FirstContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,cu.Der_FirstContactDate) 
		BETWEEN 7 and 13 THEN 1 ELSE 0 END AS [Time to first contact - one to two weeks],
	CASE WHEN cu.Der_FirstContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,cu.Der_FirstContactDate) 
		BETWEEN 14 and 27 THEN 1 ELSE 0 END AS [Time to first contact - two to four weeks],
	CASE WHEN cu.Der_FirstContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,cu.Der_FirstContactDate) 
		BETWEEN 0 and 27 THEN 1 ELSE 0 END AS [Time to first contact - less than four weeks],
	CASE WHEN cu.Der_FirstContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,cu.Der_FirstContactDate) 
		BETWEEN 28 and 84 THEN 1 ELSE 0 END AS [Time to first contact - four to 12 weeks],
	CASE WHEN cu.Der_FirstContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,cu.Der_FirstContactDate) 
		> 84 THEN 1 ELSE 0 END AS [Time to first contact - 12 weeks and over],

	---- get referrals still waiting
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_FirstContactDate IS NULL THEN 1 ELSE 0 END AS [Referrals still waiting for first contact],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_FirstContactDate IS NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ReportingPeriodEndDate) 
		BETWEEN 0 and 6 THEN 1 ELSE 0 END AS [Referrals still waiting for first contact - less than one week],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_FirstContactDate IS NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ReportingPeriodEndDate) 
		BETWEEN 7 and 13 THEN 1 ELSE 0 END AS [Referrals still waiting for first contact - one to two weeks],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_FirstContactDate IS NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ReportingPeriodEndDate) 
		BETWEEN 14 and 27 THEN 1 ELSE 0 END AS [Referrals still waiting for first contact - two to four weeks],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_FirstContactDate IS NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ReportingPeriodEndDate) 
		BETWEEN 0 and 27 THEN 1 ELSE 0 END AS [Referrals still waiting for first contact - less than four weeks],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_FirstContactDate IS NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ReportingPeriodEndDate) 
		BETWEEN 28 and 84 THEN 1 ELSE 0 END AS [Referrals still waiting for first contact - four to 12 weeks],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND cu.Der_FirstContactDate IS NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ReportingPeriodEndDate) 
		> 84 THEN 1 ELSE 0 END AS [Referrals still waiting for first contact - 12 weeks and over],

	---- get waiting times - additional metrics
	CASE WHEN cu.Der_FirstContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,cu.Der_FirstContactDate) 
		BETWEEN 0 and 27 AND s.Der_OutEventDate <= cu.Der_FirstContactDate THEN 1 ELSE 0 END AS [Seen within four weeks and outcome measure recorded],
	CASE WHEN cu.Der_FirstContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,cu.Der_FirstContactDate) 
		BETWEEN 0 and 27 AND s.Der_OutEventDate <= cu.Der_FirstContactDate THEN s.Der_OutEventDescription END AS [Seen within four weeks - outcome type],
	CASE WHEN cu.Der_FirstContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,cu.Der_FirstContactDate) 
		BETWEEN 0 and 27 AND s.Der_IntEventDate <= cu.Der_FirstContactDate THEN 1 ELSE 0 END AS [Seen within four weeks and intervention recorded],
	CASE WHEN cu.Der_FirstContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,cu.Der_FirstContactDate) 
		BETWEEN 0 and 27 AND s.Der_IntEventDate <= cu.Der_FirstContactDate THEN s.Der_IntEventDescription END AS [Seen within four weeks - intervention type],
	CASE WHEN cu.Der_FirstContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,cu.Der_FirstContactDate) 
		BETWEEN 0 and 27 AND s.Der_CPEventDate <= cu.Der_FirstContactDate THEN 1 ELSE 0 END AS [Seen within four weeks and care plan recorded],
	CASE WHEN cu.Der_FirstContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,cu.Der_FirstContactDate) 
		BETWEEN 0 and 27 AND s.Der_CPEventDate <= cu.Der_FirstContactDate THEN s.Der_CPEventDescription END AS [Seen within four weeks - care plan type],
	CASE WHEN cu.Der_FirstContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,cu.Der_FirstContactDate) BETWEEN 0 and 27 
		AND (s.Der_OutEventDate > cu.Der_FirstContactDate OR s.Der_OutEventDate IS NULL)
		AND (s.Der_IntEventDate > cu.Der_FirstContactDate OR s.Der_IntEventDate IS NULL)
		AND (s.Der_CPEventDate > cu.Der_FirstContactDate OR s.Der_CPEventDate IS NULL)
	THEN 1 ELSE 0 END AS [Seen within four weeks - no additional activity recorded]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Master

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Dim r

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Cumulative cu ON cu.RecordNumber = r.RecordNumber AND cu.UniqServReqID = r.UniqServReqID

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_SubsRef s ON s.Person_ID = r.Person_ID AND s.UniqServReqID = r.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE CORE DASHBOARD
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggMainDash') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggMainDash

SELECT
	m.[ReportingPeriodEndDate],
	m.[Financial year],
	m.[Provider code],
	m.[Provider name],
	m.[CCG code],
	m.[CCG name],
	m.[Local Authority code],
	m.[Local Authority name],
	m.[STP code],
	m.[STP name],
	m.[Region code],
	m.[Region name],
	m.[Primary reason for referral],
	m.[Team type],

	SUM([Caseload]) AS [Caseload],
	SUM([Open referrals]) AS [Open referrals],
	SUM([New referrals]) AS [New referrals],
	SUM([Closed referrals]) AS [Closed referrals],
	SUM([Closed referrals - treatment complete / further treatment not appropriate]) AS [Closed referrals - treatment complete / further treatment not appropriate],
	SUM([Closed referrals - admitted / referred elsewhere]) AS [Closed referrals - admitted / referred elsewhere],
	SUM([Closed referrals - person moved / requested discharge]) AS [Closed referrals - person moved / requested discharge],
	SUM([Closed referrals - DNA / refused to be seen]) AS [Closed referrals - DNA / refused to be seen],
	SUM([Closed referrals - other reason / unknown]) AS [Closed referrals - other reason / unknown],
	SUM([Closed referrals signposted]) AS [Closed referrals signposted],
	SUM([Closed with one contact]) AS [Closed with one contact],
	SUM([Closed with two or more contacts]) AS [Closed with two or more contacts],
	SUM([Closed with no contacts offered / attended]) AS [Closed with no contacts offered / attended],
	
	SUM([Referral length - less than one week]) AS [Referral length - less than one week],
	SUM([Referral length - one to two weeks]) AS [Referral length - one to two weeks],
	SUM([Referral length - two to four weeks]) AS [Referral length - two to four weeks],
	SUM([Referral length - one to six months]) AS [Referral length - one to six months],
	SUM([Referral length - six months and over]) AS [Referral length - six months and over],
	
	SUM([Referrals not accepted]) AS [Referrals not accepted],
	SUM([Referrals not accepted - alternative service required]) AS [Referrals not accepted - alternative service required],
	SUM([Referrals not accepted - duplicate]) AS [Referrals not accepted - duplicate],
	SUM([Referrals not accepted - incomplete]) AS [Referrals not accepted - incomplete],
	SUM([Referrals not accepted - missing / invalid]) AS [Referrals not accepted - missing / invalid],
	SUM([Referrals not accepted length]) AS [Referrals not accepted length],
	
	SUM([Time since last contact - less than one week]) AS [Time since last contact - less than one week],
	SUM([Time since last contact - one to two weeks]) AS [Time since last contact - one to two weeks],
	SUM([Time since last contact - two to four weeks]) AS [Time since last contact - two to four weeks],
	SUM([Time since last contact - four weeks or more]) AS [Time since last contact - four weeks or more],
	
	SUM([Referrals with a care plan]) AS [Referrals with a care plan],
	SUM([Referrals with an intervention]) AS [Referrals with an intervention],

	SUM([Seen within four weeks - no additional activity recorded]) AS [Seen within four weeks - no additional activity recorded],

	-- duplicate these measures for tableau denominators
	SUM([Caseload]) AS [Caseload2],
	SUM([Closed referrals]) AS [Closed referrals2],
	SUM([Open referrals]) AS [Open referrals2]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggMainDash

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Master m

GROUP BY m.[ReportingPeriodEndDate], m.[Financial year], m.[Provider code], m.[Provider name], m.[CCG code],m.[CCG name], m.[Local Authority code],	m.[Local Authority name], m.[STP code], m.[STP name], m.[Region code], m.[Region name], m.[Primary reason for referral], m.[Team type]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggAct') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggAct

SELECT
	a.[ReportingPeriodEndDate],
	a.[Financial year],
	a.[Provider code],
	a.[Provider name],
	a.[CCG code],
	a.[CCG name],
	a.[Local Authority code],
	a.[Local Authority name],
	a.[STP code],
	a.[STP name],
	a.[Region code],
	a.[Region name],
	a.[Primary reason for referral],
	a.[Team type],
	a.[Der_ConsMediumUsed] AS [Consulation medium],
	a.[Der_ContactDurationCat] AS [Contact duration],
	a.[Der_AttendDNA] AS [Contact attendance],

	SUM(a.Der_Contact) AS [Number of contacts],
	COUNT(a.[Provider code]) AS [All contacts]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggAct

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Act a

GROUP BY a.[ReportingPeriodEndDate], a.[Financial year], a.[Provider code], a.[Provider name], a.[CCG code], a.[CCG name], a.[Local Authority code], a.[Local Authority name],a.[STP code], a.[STP name], a.[Region code], a.[Region name],	a.[Primary reason for referral], a.[Team type], a.[Der_ConsMediumUsed],a.[Der_AttendDNA], a.[Der_ContactDurationCat]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE WAITING TIMES - FIRST CONTACT AND STILL WAITERS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggCont') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggCont

SELECT
	m.[ReportingPeriodEndDate],
	m.[Financial year],
	m.[Provider code],
	m.[Provider name],
	m.[CCG code],
	m.[CCG name],
	m.[Local Authority code],
	m.[Local Authority name],
	m.[STP code],
	m.[STP name],
	m.[Region code],
	m.[Region name],
	m.[Primary reason for referral],
	m.[Team type],
	
	SUM(m.[First contact in period]) AS [First contact in period],
	SUM(m.[Time to first contact - before referral start]) AS [Time to first contact - before referral start],	
	SUM(m.[Time to first contact - less than one week]) AS  [Time to first contact - less than one week],
	SUM(m.[Time to first contact - one to two weeks]) AS  [Time to first contact - one to two weeks],
	SUM(m.[Time to first contact - two to four weeks]) AS  [Time to first contact - two to four weeks],
	SUM(m.[Time to first contact - less than four weeks]) AS  [Time to first contact - less than four weeks],
	SUM(m.[Time to first contact - four to 12 weeks]) AS [Time to first contact - four to 12 weeks],
	SUM(m.[Time to first contact - 12 weeks and over]) AS  [Time to first contact - 12 weeks and over],

	SUM(m.[Referrals still waiting for first contact]) AS [Referrals still waiting for first contact],
	SUM(m.[Referrals still waiting for first contact - less than one week]) AS [Referrals still waiting for first contact - less than one week],	
	SUM(m.[Referrals still waiting for first contact - one to two weeks]) AS  [Referrals still waiting for first contact - one to two weeks],
	SUM(m.[Referrals still waiting for first contact - two to four weeks]) AS  [Referrals still waiting for first contact - two to four weeks],
	SUM(m.[Referrals still waiting for first contact - four to 12 weeks]) AS [Referrals still waiting for first contact - four to 12 weeks],
	SUM(m.[Referrals still waiting for first contact - 12 weeks and over]) AS  [Referrals still waiting for first contact - 12 weeks and over]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggCont

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Master m

GROUP BY m.[ReportingPeriodEndDate], m.[Financial year], m.[Provider code], m.[Provider name], m.[CCG code], m.[CCG name], m.[Local Authority code], m.[Local Authority name],m.[STP code], m.[STP name], m.[Region code], m.[Region name], 
	m.[Primary reason for referral], m.[Team type]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE WAITING TIMES - OUTCOMES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggOut') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggOut

SELECT
	m.ReportingPeriodEndDate,
	m.[Financial year],
	m.[Provider code],
	m.[Provider name],
	m.[CCG code],
	m.[CCG name],
	m.[Local Authority code],
	m.[Local Authority name],
	m.[STP code],
	m.[STP name],
	m.[Region code],
	m.[Region name],
	m.[Primary reason for referral],
	m.[Team type],
	m.[Seen within four weeks - outcome type],
	
	SUM(m.[Seen within four weeks and outcome measure recorded]) AS [Seen within four weeks and outcome measure recorded]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggOut

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Financial year], m.[Provider code], m.[Provider name], m.[CCG code], m.[CCG name], m.[Local Authority code], m.[Local Authority name],m.[STP code], m.[STP name], m.[Region code], m.[Region name], 
	m.[Primary reason for referral], m.[Team type], m.[Seen within four weeks - outcome type]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE WAITING TIMES - INTERVENTIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggInt') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggInt

SELECT
	m.ReportingPeriodEndDate,
	m.[Financial year],
	m.[Provider code],
	m.[Provider name],
	m.[CCG code],
	m.[CCG name],
	m.[Local Authority code],
	m.[Local Authority name],
	m.[STP code],
	m.[STP name],
	m.[Region code],
	m.[Region name],
	m.[Primary reason for referral],
	m.[Team type],
	m.[Seen within four weeks - intervention type],
	
	SUM(m.[Seen within four weeks and intervention recorded]) AS [Seen within four weeks and intervention recorded]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggInt

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Financial year], m.[Provider code], m.[Provider name], m.[CCG code], m.[CCG name], m.[Local Authority code], m.[Local Authority name],m.[STP code], m.[STP name], m.[Region code], m.[Region name], 
	m.[Primary reason for referral], m.[Team type], m.[Seen within four weeks - intervention type]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE WAITING TIMES - CARE PLAN
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggCP') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggCP

SELECT
	m.ReportingPeriodEndDate,
	m.[Financial year],
	m.[Provider code],
	m.[Provider name],
	m.[CCG code],
	m.[CCG name],
	m.[Local Authority code],
	m.[Local Authority name],
	m.[STP code],
	m.[STP name],
	m.[Region code],
	m.[Region name],
	m.[Primary reason for referral],
	m.[Team type],
	m.[Seen within four weeks - care plan type],
	
	SUM(m.[Seen within four weeks and care plan recorded]) AS [Seen within four weeks and care plan recorded]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggCP

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Financial year], m.[Provider code], m.[Provider name], m.[CCG code], m.[CCG name], m.[Local Authority code], m.[Local Authority name],m.[STP code], m.[STP name], m.[Region code], m.[Region name], 
	m.[Primary reason for referral], m.[Team type], m.[Seen within four weeks - care plan type]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UNPIVOT AND CREATE ACTIVITY EXTRACT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- CORE DASH

IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CYPWaits]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CYPWaits]

SELECT
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[Local Authority code],
	[Local Authority name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	[Primary reason for referral],
	[Team type],
	'Core Dashboard' AS [Dashboard type],
	CAST(MeasureName AS varchar(100)) AS Breakdown,
	CAST(NULL AS varchar(300)) AS [Breakdown category],
	CAST(NULL AS varchar(300)) AS [Breakdown subcategory],
	MeasureName,
	MeasureValue,
	CASE 
		WHEN MeasureName = 'Caseload' THEN [Open referrals2] 
		WHEN MeasureName IN ('Referrals with a care plan','Referrals with an intervention') THEN Caseload2
	END	AS Denominator

INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CYPWaits]

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggMainDash 

UNPIVOT (MeasureValue FOR MeasureName IN 
	([Caseload],[Open referrals],[New referrals],[Closed referrals],[Closed referrals - treatment complete / further treatment not appropriate],[Closed referrals - admitted / referred elsewhere],
	[Closed referrals - person moved / requested discharge],[Closed referrals - DNA / refused to be seen],[Closed referrals - other reason / unknown],[Closed referrals signposted],
	[Closed with one contact],[Closed with two or more contacts],[Closed with no contacts offered / attended],[Referral length - less than one week],[Referral length - one to two weeks],
	[Referral length - two to four weeks],[Referral length - one to six months],[Referral length - six months and over],[Referrals not accepted],[Referrals not accepted - alternative service required],
	[Referrals not accepted - duplicate],[Referrals not accepted - incomplete],[Referrals not accepted - missing / invalid],[Referrals not accepted length],[Time since last contact - less than one week],
	[Time since last contact - one to two weeks],[Time since last contact - two to four weeks],[Time since last contact - four weeks or more],[Referrals with a care plan],[Referrals with an intervention])) u

-- ACTIVITY DASH

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CYPWaits]

SELECT 
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[Local Authority code],
	[Local Authority name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	[Primary reason for referral],
	[Team type],
	'Activity' AS [Dashboard type],
	[Consulation medium] AS Breakdown,
	[Contact duration] AS [Breakdown category],
	[Contact attendance] AS [Breakdown subcategory],
	'Number of contacts' AS MeasureName,
	[Number of contacts] AS MeasureValue,
	[All contacts] AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggAct

-- WAITING TIMES - STILL WAITING

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CYPWaits]

SELECT 
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[Local Authority code],
	[Local Authority name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	[Primary reason for referral],
	[Team type],
	'Waiting times' AS [Dashboard type],
	'Still waiting' AS Breakdown,
	NULL AS [Breakdown category],
	NULL AS [Breakdown subcategory],
	MeasureName,
	MeasureValue,
	[Referrals still waiting for first contact] AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggCont

UNPIVOT (MeasureValue FOR MeasureName IN 
	([Referrals still waiting for first contact - less than one week],[Referrals still waiting for first contact - one to two weeks],
	[Referrals still waiting for first contact - two to four weeks],[Referrals still waiting for first contact - four to 12 weeks],
	[Referrals still waiting for first contact - 12 weeks and over]))u

WHERE [Referrals still waiting for first contact] >0

-- WAITING TIMES - FIRST CONTACT

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CYPWaits]

SELECT 
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[Local Authority code],
	[Local Authority name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	[Primary reason for referral],
	[Team type],
	'Waiting times' AS [Dashboard type],
	'First contact in period' AS Breakdown,
	NULL AS [Breakdown category],
	NULL AS [Breakdown subcategory],
	MeasureName,
	MeasureValue,
	[First contact in period] AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggCont

UNPIVOT (MeasureValue FOR MeasureName IN 
	([Time to first contact - before referral start], [Time to first contact - less than one week],[Time to first contact - one to two weeks],[Time to first contact - two to four weeks],
	[Time to first contact - less than four weeks],[Time to first contact - four to 12 weeks],[Time to first contact - 12 weeks and over]))u

WHERE [First contact in period] >0

-- WAITING TIMES - OUTCOMES ASSESSMENT

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CYPWaits]

SELECT 
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[Local Authority code],
	[Local Authority name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	[Primary reason for referral],
	[Team type],
	'Waiting times' AS [Dashboard type],
	'Outcomes assessment' AS Breakdown,
	[Seen within four weeks - outcome type] AS [Breakdown category],
	NULL AS [Breakdown subcategory],
	MeasureName,
	MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggOut

UNPIVOT (MeasureValue FOR MeasureName IN ([Seen within four weeks and outcome measure recorded]))u

WHERE MeasureValue > 0

-- WAITING TIMES - INTERVENTION

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CYPWaits]

SELECT 
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[Local Authority code],
	[Local Authority name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	[Primary reason for referral],
	[Team type],
	'Waiting times' AS [Dashboard type],
	'Intervention' AS Breakdown,
	[Seen within four weeks - intervention type] AS [Breakdown category],
	NULL AS [Breakdown subcategory],
	MeasureName,
	MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggInt

UNPIVOT (MeasureValue FOR MeasureName IN ([Seen within four weeks and intervention recorded]))u

WHERE MeasureValue > 0

-- WAITING TIMES - CARE PLAN

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CYPWaits]

SELECT 
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[Local Authority code],
	[Local Authority name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	[Primary reason for referral],
	[Team type],
	'Waiting times' AS [Dashboard type],
	'Care plan' AS Breakdown,
	[Seen within four weeks - care plan type] AS [Breakdown category],
	NULL AS [Breakdown subcategory],
	MeasureName,
	MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggCP

UNPIVOT (MeasureValue FOR MeasureName IN ([Seen within four weeks and care plan recorded]))u

WHERE MeasureValue > 0

-- WAITING TIMES - NO ADDITIONAL ACTIVITY

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CYPWaits]

SELECT 
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[Local Authority code],
	[Local Authority name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	[Primary reason for referral],
	[Team type],
	'Waiting times' AS [Dashboard type],
	'No additional activity' AS Breakdown,
	'No additional activity' AS [Breakdown category],
	NULL AS [Breakdown subcategory],	
	MeasureName,
	MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_AggMainDash

UNPIVOT (MeasureValue FOR MeasureName IN ([Seen within four weeks - no additional activity recorded]))u

WHERE MeasureValue > 0

-- MHST CASELOAD

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CYPWaits]

SELECT
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[Local Authority code],
	[Local Authority name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	NULL AS [Primary reason for referral],
	NULL AS [Team type],
	'MHST' AS [Dashboard type],
	m.[Team type] AS Breakdown,
	m.UniqCareProfTeamID AS [Breakdown category],
	NULL AS [Breakdown subcategory],	
	'Referrals with at least one contact' AS MeasureName,
	SUM([Contact in financial year]) AS MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Master m

WHERE m.[Team type] IN ('Mental Health In Education Service', 'Mental Health Support Team')

GROUP BY ReportingPeriodEndDate,[Financial year],[Provider code],[Provider name],[CCG code],[CCG name],[Local Authority code],[Local Authority name],[STP code],[STP name],[Region code],[Region name],m.[Team type],m.UniqCareProfTeamID

-- DEMOGRAPHICS DASH

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CYPWaits]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Financial year],
	NULL AS [Provider code],
	NULL AS [Provider name],
	NULL AS [CCG code],
	NULL AS [CCG name],
	NULL AS [Local Authority code],
	NULL AS [Local Authority name],
	NULL AS [STP code],
	NULL AS [STP name],
	[Region code],
	[Region name],
	NULL AS [Primary reason for referral],
	NULL AS [Team type],
	'Demographics' AS [Dashboard type],
	'Ethnicity' AS Breakdown,
	m.Ethnicity AS [Breakdown category],
	NULL AS [Breakdown subcategory],	
	'Caseload' AS MeasureName,
	SUM(Caseload) AS MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Region code], m.[Region name], m.Ethnicity

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CYPWaits]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Financial year],
	NULL AS [Provider code],
	NULL AS [Provider name],
	NULL AS [CCG code],
	NULL AS [Local Authority code],
	NULL AS [Local Authority name],
	NULL AS [CCG name],
	NULL AS [STP code],
	NULL AS [STP name],
	[Region code],
	[Region name],
	NULL AS [Primary reason for referral],
	NULL AS [Team type],
	'Demographics' AS [Dashboard type],
	'Gender' AS Breakdown,
	m.Gender AS [Breakdown category],
	NULL AS [Breakdown subcategory],	
	'Caseload' AS MeasureName,
	SUM(Caseload) AS MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Region code], m.[Region name], m.Gender

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CYPWaits]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Financial year],
	NULL AS [Provider code],
	NULL AS [Provider name],
	NULL AS [CCG code],
	NULL AS [CCG name],
	NULL AS [Local Authority code],
	NULL AS [Local Authority name],
	NULL AS [STP code],
	NULL AS [STP name],
	[Region code],
	[Region name],
	NULL AS [Primary reason for referral],
	NULL AS [Team type],
	'Demographics' AS [Dashboard type],
	'Age' AS Breakdown,
	m.AgeServReferRecDate AS [Breakdown category],
	NULL AS [Breakdown subcategory],	
	'Caseload' AS MeasureName,
	SUM(Caseload) AS MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Region code], m.[Region name], m.AgeServReferRecDate

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CYPWaits]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Financial year],
	NULL AS [Provider code],
	NULL AS [Provider name],
	NULL AS [CCG code],
	NULL AS [CCG name],
	NULL AS [Local Authority code],
	NULL AS [Local Authority name],
	NULL AS [STP code],
	NULL AS [STP name],
	[Region code],
	[Region name],
	NULL AS [Primary reason for referral],
	NULL AS [Team type],
	'Demographics' AS [Dashboard type],
	'IMD' AS Breakdown,
	m.IMD_Decile AS [Breakdown category],
	NULL AS [Breakdown subcategory],	
	'Caseload' AS MeasureName,
	SUM(Caseload) AS MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CYP_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Region code], m.[Region name], m.IMD_Decile

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DROP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CYP_Act
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CYP_AggAct
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CYP_AggCont
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CYP_AggCP
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CYP_AggInt
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CYP_AggMainDash
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CYP_AggOut
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CYP_Cumulative
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CYP_Dim
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CYP_Master
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CYP_Ref
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CYP_Subs
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CYP_SubsRanked
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CYP_SubsRef
