/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CMH AWT REPORTING

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

DECLARE @RPStartDate DATE

SET @RPStartDate = '2019-04-01' -- Apr 19 

DECLARE @FYStart INT

SET @FYStart = (SELECT MAX(UniqMonthID)
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE Der_FYStart = 'Y')

DECLARE @FYStartDate DATE

SET @FYStartDate = (SELECT MAX(ReportingPeriodEndDate)
FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Header
WHERE Der_FYStart = 'Y')

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LOG START
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'CMH Report Start' AS Step,
	GETDATE() AS [TimeStamp]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDENTIFY REFERRALS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Ref') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Ref

SELECT
	r.ReportingPeriodStartDate,
	r.ReportingPeriodEndDate,
	r.Der_FY,
	r.UniqMonthID,
	r.OrgIDProv,
	r.Person_ID,
	r.OrgIDCCGRes,
	r.RecordNumber,
	r.UniqServReqID,
	r.ReferralRequestReceivedDate,
	r.EthnicCategory,
	r.Gender,
	r.LSOA2011,
	r.AgeServReferRecDate,
	r.AgeRepPeriodEnd,
	r.ServDischDate,
	r.ReferClosReason,
	r.ReferRejectionDate,
	r.ReferRejectReason,
	CASE WHEN r.ServTeamTypeRefToMH = 'C03' THEN 'C10' ELSE r.ServTeamTypeRefToMH END AS Der_ServTeamTypeRefToMH,
	r.UniqCareProfTeamID,
	r.PrimReasonReferralMH

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Ref

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Referral r

WHERE r.AgeServReferRecDate >= 18 -- 18 and over
	AND r.ServTeamTypeRefToMH IN ('A05','A06','A08','A09','A12','A13','A16','C03','C10') -- Core community MH teams
	AND r.UniqMonthID BETWEEN @StartRP AND @EndRP 
	AND (r.LADistrictAuth LIKE 'E%' OR r.LADistrictAuth IS NULL) -- only people resident in England

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DELETE REFERRALS TO INPATIENT SERVICES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DELETE FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Ref WHERE CONCAT(Person_ID,UniqServReqID,Der_FY) IN (SELECT CONCAT(Person_ID,UniqServReqID,Der_FY) FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Inpatients) 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CREATE DERIVATIONS - DIMENSIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Dim') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Dim

SELECT
	r.ReportingPeriodStartDate,
	r.ReportingPeriodEndDate,
	r.Der_FY AS [Financial year],
	r.UniqMonthID,
	r.UniqServReqID,
	r.RecordNumber,
	r.OrgIDProv AS [Provider code],
	p.Organisation_Name AS [Provider name],
	COALESCE(cc.New_Code,r.OrgIDCCGRes, 'Missing / Invalid') AS [CCG code],
	COALESCE(c.Organisation_Name,'Missing / Invalid') AS [CCG name],
	COALESCE(c.STP_Code,'Missing / Invalid') AS [STP code],
	COALESCE(c.STP_Name,'Missing / Invalid') AS [STP name],
	COALESCE(c.Region_Code,'Missing / Invalid') AS [Region code],
	COALESCE(c.Region_Name,'Missing / Invalid') AS [Region name],
	r.Person_ID,
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
	COALESCE(t.Main_Description, 'Missing / invalid') AS [Team type],
	r.UniqCareProfTeamID,
	r.ServDischDate,
	r.ReferRejectionDate,
	r.ReferClosReason,
	r.ReferRejectReason

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Dim

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Ref r

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_DataDic_ZZZ_ReasonForReferralToMentalHealth rr ON r.PrimReasonReferralMH = rr.Main_Code_Text COLLATE DATABASE_DEFAULT AND rr.Effective_To IS NULL AND rr.Valid_To IS NULL

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_DataDic_ZZZ_ServiceOrTeamTypeForMentalHealth t ON r.Der_ServTeamTypeRefToMH = t.Main_Code_Text COLLATE DATABASE_DEFAULT AND t.Effective_To IS NULL AND t.Valid_To IS NULL

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_Other_Deprivation_By_LSOA l ON r.LSOA2011 = l.LSOA_Code AND l.Effective_Snapshot_Date = '2019-12-31'

LEFT JOIN NHSE_UKHF.Data_Dictionary.vw_Ethnic_Category_Code_SCD e ON r.EthnicCategory = e.[Main_Code_Text] COLLATE DATABASE_DEFAULT AND e.Is_Latest = 1

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_DataDic_ZZZ_PersonGender g ON r.Gender = g.Person_Gender_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_Other_ComCodeChanges cc ON r.OrgIDCCGRes = cc.Org_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies p ON r.OrgIDProv = p.Organisation_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies c ON COALESCE(cc.New_Code,r.OrgIDCCGRes) = c.Organisation_Code

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LINK TO ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Act') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Act

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
	d.[STP code],
	d.[STP name],
	d.[Region code],
	d.[Region name],
	d.[Primary reason for referral],
	d.[Team type],
	a.Der_ContactDate,
	a.Der_ContactTime,
	a.Der_ActivityUniqID,
	CASE 
		WHEN a.Der_DirectContact = 1 AND a.ConsMediumUsed = '01' THEN 'Consultation medium - face to face'
		WHEN a.Der_DirectContact = 1 AND a.ConsMediumUsed  = '02' THEN 'Consultation medium - telephone'
		WHEN a.Der_DirectContact = 1 AND (a.UniqMonthID < 1459 AND a.ConsMediumUsed = '03' OR a.UniqMonthID >= 1459 AND a.ConsMediumUsed = '11') THEN 'Consultation medium - video consult'
		WHEN a.Der_DirectContact = 1 AND (a.UniqMonthID < 1459 AND a.ConsMediumUsed IN ('04','98') OR a.UniqMonthID >= 1459 AND a.ConsMediumUsed IN ('05','09', '10', '13')) THEN 'Consultation medium - other'
		WHEN a.Der_DirectContact = 1 THEN 'Consultation medium - missing / invalid'
	END AS Der_ConsMediumUsed,
	CASE 
		WHEN a.AttendOrDNACode IN ('7','3') THEN 'Contact attendance - DNA'
		WHEN a.AttendOrDNACode IN ('2','4') THEN 'Contact attendance - cancelled'
		WHEN a.AttendOrDNACode IN ('5','6') THEN 'Contact attendance - attended'
		WHEN a.Der_ActivityType = 'DIRECT' AND a.AttendOrDNACode NOT IN ('2','3','4','5','6','7') THEN 'Contact attendance - missing / invalid'
	END AS Der_AttendDNA,
	CASE
		WHEN a.Der_DirectContact = 1 AND a.Der_ContactDuration IS NULL OR a.Der_ContactDuration = 0 THEN 'Contact duration - no time recorded'
		WHEN a.Der_DirectContact = 1 AND a.Der_ContactDuration BETWEEN 1 AND 14 THEN 'Contact duration - less than 15 mins'
		WHEN a.Der_DirectContact = 1 AND a.Der_ContactDuration BETWEEN 15 AND 29 THEN 'Contact duration - 15 to 30 mins'
		WHEN a.Der_DirectContact = 1 AND a.Der_ContactDuration BETWEEN 30 AND 59 THEN 'Contact duration - 30 mins to an hour'
		WHEN a.Der_DirectContact = 1 AND a.Der_ContactDuration >59 THEN 'Contact duration - over an hour'
	END AS Der_ContactDurationCat,
	a.Der_DirectContact

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Act

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Dim d ON a.RecordNumber = d.RecordNumber AND a.UniqServReqID = d.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
RANK CONTACTS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_ActRank') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_ActRank

SELECT
	a.RecordNumber,
	a.UniqServReqID,
	a.Person_ID,
	a.Der_ContactDate,
	ROW_NUMBER() OVER (PARTITION BY a.Person_ID, a.UniqServReqID ORDER BY a.Der_ContactDate ASC, a.Der_ContactTime ASC, a.Der_ActivityUniqID ASC) AS Der_ContactOrder

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_ActRank

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Act a

WHERE a.Der_DirectContact = 1

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET CUMULATIVE ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Cumulative') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Cumulative

SELECT
	r.ReportingPeriodEndDate,
	r.RecordNumber,
	r.UniqServReqID,

	-- cumulative activity
	MAX(a.Der_ContactDate) AS Der_LastContact,
	SUM(a.Der_DirectContact) AS Der_CumulativeContacts

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Cumulative

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Ref r

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a ON r.Person_ID = a.Person_ID AND r.UniqServReqID = a.UniqServReqID AND a.ReportingPeriodEndDate <= r.ReportingPeriodEndDate 

WHERE a.Der_DirectContact = 1

GROUP BY r.RecordNumber, r.ReportingPeriodEndDate, r.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ASSESSMENT AND INTERVENTIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Subs') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Subs

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

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Subs

FROM NHSE_MHSDS.dbo.MHS008CarePlanType c

INNER JOIN NHSE_MHSDS.dbo.MHS009CarePlanAgreement cpa ON cpa.RecordNumber = c.RecordNumber AND cpa.UniqCarePlanID = c.UniqCarePlanID

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_ref f ON c.RecordNumber = f.RecordNumber AND f.ReferralRequestReceivedDate >= COALESCE(c.CarePlanLastUpdateDate,c.CarePlanCreatDate)

INNER JOIN NHSE_MH_PrePublication.Test.MHSDS_SubmissionFlags s ON c.NHSEUniqSubmissionID = s.NHSEUniqSubmissionID AND s.Der_IsLatest = 'Y'

	-- care plans for latest performance and provisional data (no pre processed table here)

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Subs

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

FROM NHSE_MH_PrePublication.Test.MHS008CarePlanType c

INNER JOIN NHSE_MH_PrePublication.Test.MHS009CarePlanAgreement cpa ON cpa.RecordNumber = c.RecordNumber AND cpa.UniqCarePlanID = c.UniqCarePlanID

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_ref f ON c.RecordNumber = f.RecordNumber AND f.ReferralRequestReceivedDate >= COALESCE(c.CarePlanLastUpdateDate,c.CarePlanCreatDate)

INNER JOIN NHSE_MH_PrePublication.Test.MHSDS_SubmissionFlags s ON c.NHSEUniqSubmissionID = s.NHSEUniqSubmissionID AND s.Der_IsLatest = 'Y'

	-- interventions data

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Subs

SELECT
	f.Person_ID,
	f.UniqServReqID,
	i.RecordNumber,
	CASE 
		WHEN c.Category = 'Assessment' THEN 'Assessment - SNoMED'
		WHEN c.Category = 'Intervention' THEN 'Intervention' 
	END AS Der_EventType,
	i.Der_SNoMEDProcTerm AS Der_EventDescription,
	i.Der_ContactDate AS Der_EventDate

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Interventions i 

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Ref f ON i.RecordNumber = f.RecordNumber AND f.UniqServReqID = i.UniqServReqID

LEFT JOIN [NHSE_Sandbox_MentalHealth].[dbo].[Staging_CMHSNoMED] c ON i.Der_SNoMEDProcCode = c.[Der_SNoMEDProcCode]

WHERE i.Der_SNoMEDProcTerm IS NOT NULL AND i.Der_InterventionType = 'Direct' AND c.Category IN ('Assessment','Intervention')

	-- assessment data

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Subs

SELECT
	f.Person_ID,
	f.UniqServReqID,
	ass.RecordNumber,
	'Assessment - Outcome' AS Der_EventType,
	ass.Der_AssessmentToolName AS Der_EventDescription,
	ass.Der_AssToolCompDate AS Der_EventDate

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Assessments ass

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_ref f ON ass.RecordNumber = f.RecordNumber AND f.UniqServReqID = ass.UniqServReqID

WHERE ass.Der_AssessmentToolName IS NOT NULL

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IDENTIFY FIRST OCCURANCE OF EACH EVENT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_SubsRanked') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_SubsRanked

SELECT
	s.Person_ID,
	s.UniqServReqID,
	s.RecordNumber,
	s.Der_EventType,
	s.Der_EventDescription,
	s.Der_EventDate,
	ROW_NUMBER() OVER (PARTITION by s.UniqServReqID, s.Person_ID, s.Der_EventType ORDER BY s.Der_EventDate) AS Der_EventOrder

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_SubsRanked

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Subs s

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LINK FIRST ASSESSMENT, OUTCOME AND INTERVENTION TO REFERRAL
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_SubsRef') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_SubsRef

SELECT DISTINCT
	r.Person_ID,
	r.UniqServReqID,
	sa.Der_EventType AS Der_AssEventType,
	sa.Der_EventDescription AS Der_AssEventDescription,
	sa.Der_EventDate AS Der_AssEventDate,
	so.Der_EventType AS Der_OutEventType,
	so.Der_EventDescription AS Der_OutEventDescription,
	so.Der_EventDate AS Der_OutEventDate,
	st.Der_EventType AS Der_IntEventType,
	st.Der_EventDescription AS Der_IntEventDescription,
	st.Der_EventDate AS Der_IntEventDate,
	sc.Der_EventType AS Der_CPEventType,
	sc.Der_EventDescription AS Der_CPEventDescription,
	sc.Der_EventDate AS Der_CPEventDate

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_SubsRef

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_ref r

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_SubsRanked sa ON sa.Person_ID = r.Person_ID AND sa.UniqServReqID = r.UniqServReqID AND sa.Der_EventType = 'Assessment - SNoMED' AND sa.Der_EventOrder = 1 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_SubsRanked so ON so.Person_ID = r.Person_ID AND so.UniqServReqID = r.UniqServReqID AND so.Der_EventType = 'Assessment - Outcome' AND so.Der_EventOrder = 1 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_SubsRanked st ON st.Person_ID = r.Person_ID AND st.UniqServReqID = r.UniqServReqID AND st.Der_EventType = 'Intervention' AND st.Der_EventOrder = 1

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_SubsRanked sc ON sc.Person_ID = r.Person_ID AND sc.UniqServReqID = r.UniqServReqID AND sc.Der_EventType = 'Care Plan' AND sc.Der_EventOrder = 1

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CREATE DERIVATIONS - MEASURES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Master') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Master

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

	---- get waiting times - Second contact
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [Second contact in period],
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) 
		<0 THEN 1 ELSE 0 END AS [Time to second contact - before referral start],	
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) 
		BETWEEN 0 and 6 THEN 1 ELSE 0 END AS [Time to second contact - less than one week],
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) 
		BETWEEN 7 and 13 THEN 1 ELSE 0 END AS [Time to second contact - one to two weeks],
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) 
		BETWEEN 14 and 27 THEN 1 ELSE 0 END AS [Time to second contact - two to four weeks],
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) 
		BETWEEN 0 and 27 THEN 1 ELSE 0 END AS [Time to second contact - less than four weeks],
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) 
		BETWEEN 28 and 84 THEN 1 ELSE 0 END AS [Time to second contact - four to 12 weeks],
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) 
		> 84 THEN 1 ELSE 0 END AS [Time to second contact - 12 weeks and over],

	---- get referrals still waiting
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND c.Der_ContactDate IS NULL THEN 1 ELSE 0 END AS [Referrals still waiting for second contact],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND c.Der_ContactDate IS NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ReportingPeriodEndDate) 
		BETWEEN 0 and 6 THEN 1 ELSE 0 END AS [Referrals still waiting for second contact - less than one week],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND c.Der_ContactDate IS NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ReportingPeriodEndDate) 
		BETWEEN 7 and 13 THEN 1 ELSE 0 END AS [Referrals still waiting for second contact - one to two weeks],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND c.Der_ContactDate IS NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ReportingPeriodEndDate) 
		BETWEEN 14 and 27 THEN 1 ELSE 0 END AS [Referrals still waiting for second contact - two to four weeks],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND c.Der_ContactDate IS NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ReportingPeriodEndDate) 
		BETWEEN 0 and 27 THEN 1 ELSE 0 END AS [Referrals still waiting for second contact - less than four weeks],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND c.Der_ContactDate IS NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ReportingPeriodEndDate) 
		BETWEEN 28 and 84 THEN 1 ELSE 0 END AS [Referrals still waiting for second contact - four to 12 weeks],
	CASE WHEN (r.ServDischDate IS NULL OR r.ServDischDate > r.ReportingPeriodEndDate) AND r.ReferRejectionDate IS NULL AND c.Der_ContactDate IS NULL AND DATEDIFF(dd,r.ReferralRequestReceivedDate,r.ReportingPeriodEndDate) 
		> 84 THEN 1 ELSE 0 END AS [Referrals still waiting for second contact - 12 weeks and over],

		---- get waiting times - additional metrics
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) 
		BETWEEN 0 and 27 AND s.Der_OutEventDate <= c.Der_ContactDate THEN 1 ELSE 0 END AS [Seen within four weeks and outcome measure recorded],
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) 
		BETWEEN 0 and 27 AND s.Der_OutEventDate <= c.Der_ContactDate THEN s.Der_OutEventDescription END AS [Seen within four weeks - outcome type],
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) 
		BETWEEN 0 and 27 AND s.Der_IntEventDate <= c.Der_ContactDate THEN 1 ELSE 0 END AS [Seen within four weeks and intervention recorded],
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) 
		BETWEEN 0 and 27 AND s.Der_IntEventDate <= c.Der_ContactDate THEN s.Der_IntEventDescription END AS [Seen within four weeks - intervention type],
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) 
		BETWEEN 0 and 27 AND s.Der_AssEventDate <= c.Der_ContactDate THEN 1 ELSE 0 END AS [Seen within four weeks and assessment recorded],
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) 
		BETWEEN 0 and 27 AND s.Der_AssEventDate <= c.Der_ContactDate THEN s.Der_AssEventDescription END AS [Seen within four weeks - assessment type],
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) 
		BETWEEN 0 and 27 AND s.Der_CPEventDate <= c.Der_ContactDate THEN 1 ELSE 0 END AS [Seen within four weeks and care plan recorded],
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) 
		BETWEEN 0 and 27 AND s.Der_CPEventDate <= c.Der_ContactDate THEN s.Der_CPEventDescription END AS [Seen within four weeks - care plan type],
	CASE WHEN c.Der_ContactDate BETWEEN r.ReportingPeriodStartDate AND r.ReportingPeriodEndDate AND DATEDIFF(dd,r.ReferralRequestReceivedDate,c.Der_ContactDate) BETWEEN 0 and 27 
		AND (s.Der_OutEventDate > c.Der_ContactDate OR s.Der_OutEventDate IS NULL)
		AND (s.Der_IntEventDate > c.Der_ContactDate OR s.Der_IntEventDate IS NULL)
		AND (s.Der_AssEventDate > c.Der_ContactDate OR s.Der_AssEventDate IS NULL)
		AND (s.Der_CPEventDate > c.Der_ContactDate OR s.Der_CPEventDate IS NULL)
	THEN 1 ELSE 0 END AS [Seen within four weeks - no additional activity recorded]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Master

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Dim r

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Cumulative cu ON cu.RecordNumber = r.RecordNumber AND cu.UniqServReqID = r.UniqServReqID

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_SubsRef s ON s.Person_ID = r.Person_ID AND s.UniqServReqID = r.UniqServReqID

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_ActRank c ON c.Person_ID = r.Person_ID AND c.UniqServReqID = r.UniqServReqID AND c.Der_ContactOrder = 2 AND r.ReportingPeriodEndDate >= c.Der_ContactDate

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE CORE DASHBOARD
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggMainDash') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggMainDash

SELECT
	m.[ReportingPeriodEndDate],
	m.[Financial year],
	m.[Provider code],
	m.[Provider name],
	m.[CCG code],
	m.[CCG name],
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

	SUM(CASE WHEN [ReferralRequestReceivedDate] >=@RPStartDate THEN [Seen within four weeks - no additional activity recorded] ELSE 0 END) AS [Seen within four weeks - no additional activity recorded],

	-- duplicate these measures for tableau denominators
	SUM([Caseload]) AS [Caseload2],
	SUM([Open referrals]) AS [Open referrals2]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggMainDash

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Master m

GROUP BY m.[ReportingPeriodEndDate], m.[Financial year], m.[Provider code], m.[Provider name], m.[CCG code],m.[CCG name], m.[STP code], m.[STP name], m.[Region code], m.[Region name], 
	m.[Primary reason for referral], m.[Team type]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggAct') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggAct

SELECT
	a.[ReportingPeriodEndDate],
	a.[Financial year],
	a.[Provider code],
	a.[Provider name],
	a.[CCG code],
	a.[CCG name],
	a.[STP code],
	a.[STP name],
	a.[Region code],
	a.[Region name],
	a.[Primary reason for referral],
	a.[Team type],
	a.[Der_ConsMediumUsed] AS [Consulation medium],
	a.[Der_ContactDurationCat] AS [Contact duration],
	a.[Der_AttendDNA] AS [Contact attendance],

	SUM(a.Der_DirectContact) AS [Number of contacts],
	COUNT(a.[Provider code]) AS [All contacts]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggAct

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Act a

GROUP BY a.[ReportingPeriodEndDate], a.[Financial year], a.[Provider code], a.[Provider name], a.[CCG code], a.[CCG name], a.[STP code], a.[STP name], a.[Region code], a.[Region name],
	a.[Primary reason for referral], a.[Team type], a.[Der_ConsMediumUsed], a.[Der_ContactDurationCat], a.[Der_AttendDNA]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE WAITING TIMES - SECOND CONTACT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggCont') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggCont

SELECT
	m.[ReportingPeriodEndDate],
	m.[Financial year],
	m.[Provider code],
	m.[Provider name],
	m.[CCG code],
	m.[CCG name],
	m.[STP code],
	m.[STP name],
	m.[Region code],
	m.[Region name],
	m.[Primary reason for referral],
	m.[Team type],
	
	SUM(m.[Second contact in period]) AS [Second contact in period],
	SUM(m.[Time to second contact - before referral start]) AS [Time to second contact - before referral start],	
	SUM(m.[Time to second contact - less than one week]) AS  [Time to second contact - less than one week],
	SUM(m.[Time to second contact - one to two weeks]) AS  [Time to second contact - one to two weeks],
	SUM(m.[Time to second contact - two to four weeks]) AS  [Time to second contact - two to four weeks],
	SUM(m.[Time to second contact - less than four weeks]) AS  [Time to second contact - less than four weeks],
	SUM(m.[Time to second contact - four to 12 weeks]) AS [Time to second contact - four to 12 weeks],
	SUM(m.[Time to second contact - 12 weeks and over]) AS  [Time to second contact - 12 weeks and over],

	SUM(m.[Referrals still waiting for second contact]) AS [Referrals still waiting for second contact],
	SUM(m.[Referrals still waiting for second contact - less than one week]) AS [Referrals still waiting for second contact - less than one week],	
	SUM(m.[Referrals still waiting for second contact - one to two weeks]) AS  [Referrals still waiting for second contact - one to two weeks],
	SUM(m.[Referrals still waiting for second contact - two to four weeks]) AS  [Referrals still waiting for second contact - two to four weeks],
	SUM(m.[Referrals still waiting for second contact - four to 12 weeks]) AS [Referrals still waiting for second contact - four to 12 weeks],
	SUM(m.[Referrals still waiting for second contact - 12 weeks and over]) AS  [Referrals still waiting for second contact - 12 weeks and over]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggCont

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Master m

WHERE m.[ReferralRequestReceivedDate] >=@RPStartDate

GROUP BY m.[ReportingPeriodEndDate], m.[Financial year], m.[Provider code], m.[Provider name], m.[CCG code], m.[CCG name], m.[STP code], m.[STP name], m.[Region code], m.[Region name], 
	m.[Primary reason for referral], m.[Team type]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE WAITING TIMES - OUTCOMES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggOut') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggOut

SELECT
	m.ReportingPeriodEndDate,
	m.[Financial year],
	m.[Provider code],
	m.[Provider name],
	m.[CCG code],
	m.[CCG name],
	m.[STP code],
	m.[STP name],
	m.[Region code],
	m.[Region name],
	m.[Primary reason for referral],
	m.[Team type],
	m.[Seen within four weeks - outcome type],
	
	SUM(m.[Seen within four weeks and outcome measure recorded]) AS [Seen within four weeks and outcome measure recorded]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggOut

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Master m

WHERE m.[ReferralRequestReceivedDate] >=@RPStartDate

GROUP BY m.[ReportingPeriodEndDate], m.[Financial year], m.[Provider code], m.[Provider name], m.[CCG code], m.[CCG name], m.[STP code], m.[STP name], m.[Region code], m.[Region name], 
	m.[Primary reason for referral], m.[Team type], m.[Seen within four weeks - outcome type]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE WAITING TIMES - INTERVENTIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggInt') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggInt

SELECT
	m.ReportingPeriodEndDate,
	m.[Financial year],
	m.[Provider code],
	m.[Provider name],
	m.[CCG code],
	m.[CCG name],
	m.[STP code],
	m.[STP name],
	m.[Region code],
	m.[Region name],
	m.[Primary reason for referral],
	m.[Team type],
	m.[Seen within four weeks - intervention type],
	
	SUM(m.[Seen within four weeks and intervention recorded]) AS [Seen within four weeks and intervention recorded]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggInt

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Master m

WHERE m.[ReferralRequestReceivedDate] >=@RPStartDate

GROUP BY m.ReportingPeriodEndDate, m.[Financial year], m.[Provider code], m.[Provider name], m.[CCG code], m.[CCG name], m.[STP code], m.[STP name], m.[Region code], m.[Region name], 
	m.[Primary reason for referral], m.[Team type], m.[Seen within four weeks - intervention type]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE WAITING TIMES - CARE PLAN
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggCP') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggCP

SELECT
	m.ReportingPeriodEndDate,
	m.[Financial year],
	m.[Provider code],
	m.[Provider name],
	m.[CCG code],
	m.[CCG name],
	m.[STP code],
	m.[STP name],
	m.[Region code],
	m.[Region name],
	m.[Primary reason for referral],
	m.[Team type],
	m.[Seen within four weeks - care plan type],
	
	SUM(m.[Seen within four weeks and care plan recorded]) AS [Seen within four weeks and care plan recorded]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggCP

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Master m

WHERE m.[ReferralRequestReceivedDate] >=@RPStartDate

GROUP BY m.ReportingPeriodEndDate, m.[Financial year], m.[Provider code], m.[Provider name], m.[CCG code], m.[CCG name], m.[STP code], m.[STP name], m.[Region code], m.[Region name], 
	m.[Primary reason for referral], m.[Team type], m.[Seen within four weeks - care plan type]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE WAITING TIMES - ASSESSMENT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggAss') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggAss

SELECT
	m.ReportingPeriodEndDate,
	m.[Financial year],
	m.[Provider code],
	m.[Provider name],
	m.[CCG code],
	m.[CCG name],
	m.[STP code],
	m.[STP name],
	m.[Region code],
	m.[Region name],
	m.[Primary reason for referral],
	m.[Team type],
	m.[Seen within four weeks - assessment type],
	
	SUM(m.[Seen within four weeks and assessment recorded]) AS [Seen within four weeks and assessment recorded]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggAss

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Master m

WHERE m.[ReferralRequestReceivedDate] >=@RPStartDate

GROUP BY m.ReportingPeriodEndDate, m.[Financial year], m.[Provider code], m.[Provider name], m.[CCG code], m.[CCG name], m.[STP code], m.[STP name], m.[Region code], m.[Region name], 
	m.[Primary reason for referral], m.[Team type], m.[Seen within four weeks - assessment type]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UNPIVOT AND CREATE EXTRACT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- CORE DASH

IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaits]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaits]

SELECT
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	[Primary reason for referral],
	[Team type],
	'Core Dashboard' AS [Dashboard type],
	CAST(MeasureName AS varchar(50)) AS Breakdown,
	CAST(NULL AS varchar(255)) AS [Breakdown category],
	CAST(NULL AS varchar(300)) AS [Breakdown subcategory],
	MeasureName,
	MeasureValue,
	CASE 
		WHEN MeasureName = 'Caseload' THEN [Open referrals2] 
		WHEN MeasureName IN ('Referrals with a care plan','Referrals with an intervention') THEN Caseload2
	END	AS Denominator

INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaits]

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggMainDash 

UNPIVOT (MeasureValue FOR MeasureName IN 
	([Caseload],[Open referrals],[New referrals],[Closed referrals],[Closed referrals - treatment complete / further treatment not appropriate],[Closed referrals - admitted / referred elsewhere],
	[Closed referrals - person moved / requested discharge],[Closed referrals - DNA / refused to be seen],[Closed referrals - other reason / unknown],[Closed referrals signposted],
	[Closed with one contact],[Closed with two or more contacts],[Closed with no contacts offered / attended],[Referral length - less than one week],[Referral length - one to two weeks],
	[Referral length - two to four weeks],[Referral length - one to six months],[Referral length - six months and over],[Referrals not accepted],[Referrals not accepted - alternative service required],
	[Referrals not accepted - duplicate],[Referrals not accepted - incomplete],[Referrals not accepted - missing / invalid],[Referrals not accepted length],[Time since last contact - less than one week],
	[Time since last contact - one to two weeks],[Time since last contact - two to four weeks],[Time since last contact - four weeks or more],[Referrals with a care plan],[Referrals with an intervention])) u

-- ACTIVITY DASH

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaits]

SELECT 
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
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

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggAct

-- WAITING TIMES - STILL WAITING

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaits]

SELECT 
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
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
	[Referrals still waiting for second contact] AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggCont

UNPIVOT (MeasureValue FOR MeasureName IN 
	([Referrals still waiting for second contact - less than one week],[Referrals still waiting for second contact - one to two weeks],
	[Referrals still waiting for second contact - two to four weeks],[Referrals still waiting for second contact - four to 12 weeks],
	[Referrals still waiting for second contact - 12 weeks and over]))u

WHERE [Referrals still waiting for second contact] >0

-- WAITING TIMES - SECOND CONTACT

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaits]

SELECT 
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	[Primary reason for referral],
	[Team type],
	'Waiting times' AS [Dashboard type],
	'Second contact in period' AS Breakdown,
	NULL AS [Breakdown category],
	NULL AS [Breakdown subcategory],
	MeasureName,
	MeasureValue,
	[Second contact in period] AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggCont

UNPIVOT (MeasureValue FOR MeasureName IN 
	([Time to second contact - before referral start], [Time to second contact - less than one week],[Time to second contact - one to two weeks],[Time to second contact - two to four weeks],
	[Time to second contact - less than four weeks],[Time to second contact - four to 12 weeks],[Time to second contact - 12 weeks and over]))u

WHERE [Second contact in period] >0

-- WAITING TIMES - OUTCOMES ASSESSMENT

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaits]

SELECT 
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
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

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggOut

UNPIVOT (MeasureValue FOR MeasureName IN ([Seen within four weeks and outcome measure recorded]))u

WHERE MeasureValue > 0

-- WAITING TIMES - INTERVENTION

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaits]

SELECT 
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
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

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggInt

UNPIVOT (MeasureValue FOR MeasureName IN ([Seen within four weeks and intervention recorded]))u

WHERE MeasureValue > 0

-- WAITING TIMES - CARE PLAN

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaits]

SELECT 
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
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

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggCP

UNPIVOT (MeasureValue FOR MeasureName IN ([Seen within four weeks and care plan recorded]))u

WHERE MeasureValue > 0

-- WAITING TIMES - ASSESSMENT

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaits]

SELECT 
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	[Primary reason for referral],
	[Team type],
	'Waiting times' AS [Dashboard type],
	'Assessment' AS Breakdown,
	[Seen within four weeks - assessment type] AS [Breakdown category],
	NULL AS [Breakdown subcategory],
	MeasureName,
	MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggAss

UNPIVOT (MeasureValue FOR MeasureName IN ([Seen within four weeks and assessment recorded]))u

WHERE MeasureValue > 0

-- WAITING TIMES - NO ADDITIONAL ACTIVITY

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaits]

SELECT 
	ReportingPeriodEndDate,
	[Financial year],
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
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

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AggMainDash

UNPIVOT (MeasureValue FOR MeasureName IN ([Seen within four weeks - no additional activity recorded]))u

WHERE MeasureValue > 0

-- DEMOGRAPHICS DASH

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaits]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Financial year],
	NULL AS [Provider code],
	NULL AS [Provider name],
	NULL AS [CCG code],
	NULL AS [CCG name],
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

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Region code], m.[Region name], m.Ethnicity

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaits]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Financial year],
	NULL AS [Provider code],
	NULL AS [Provider name],
	NULL AS [CCG code],
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

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Region code], m.[Region name], m.Gender

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaits]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Financial year],
	NULL AS [Provider code],
	NULL AS [Provider name],
	NULL AS [CCG code],
	NULL AS [CCG name],
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

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Region code], m.[Region name], m.AgeServReferRecDate

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaits]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Financial year],
	NULL AS [Provider code],
	NULL AS [Provider name],
	NULL AS [CCG code],
	NULL AS [CCG name],
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

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Region code], m.[Region name], m.IMD_Decile

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>

ACCESS SECTION

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET GP DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMHGP') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMHGP

SELECT
g.RecordNumber,
g.GMPCodeReg

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMHGP

FROM NHSE_MHSDS.dbo.MHS002GP g

INNER JOIN NHSE_MH_PrePublication.Test.MHSDS_SubmissionFlags s ON g.NHSEUniqSubmissionID = s.NHSEUniqSubmissionID AND s.Der_IsLatest = 'Y'

WHERE g.EndDateGMPRegistration IS NULL
AND g.UniqMonthID BETWEEN @StartRP AND @EndRP 

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.TEMP_CMHGP

SELECT
g.RecordNumber,
g.GMPCodeReg

FROM NHSE_MH_PrePublication.test.MHS002GP g

INNER JOIN NHSE_MH_PrePublication.Test.MHSDS_SubmissionFlags s ON g.NHSEUniqSubmissionID = s.NHSEUniqSubmissionID AND s.Der_IsLatest = 'Y'

WHERE g.EndDateGMPRegistration IS NULL

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LINK TO PCN REFERENCE DATA AND LIMIT TO TRANSFORMED PCNs
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AccessRefsPCN') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AccessRefsPCN

SELECT 
	a.UniqMonthID,
	a.UniqServReqID,
	a.Person_ID,
	a.RecordNumber,
	COALESCE(c.Organisation_Code,'Missing / Invalid') AS [CCG code],
	COALESCE(c.Organisation_Name,'Missing / Invalid') AS [CCG name],
	COALESCE(c.STP_Code,'Missing / Invalid') AS [STP code],
	COALESCE(c.STP_Name,'Missing / Invalid') AS [STP name],
	COALESCE(c.Region_Code,'Missing / Invalid') AS [Region code],
	COALESCE(c.Region_Name,'Missing / Invalid') AS [Region name]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AccessRefsPCN

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Dim a

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CMHGP g ON g.RecordNumber = a.RecordNumber 

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_GP_Hierarchies] gh ON g.GMPCodeReg = gh.GP_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies c ON gh.PCN_CCG_Code = c.Organisation_Code COLLATE DATABASE_DEFAULT

INNER JOIN [NHSE_Sandbox_MentalHealth].[dbo].[Staging_CMHTransformedPCNs] p ON p.[PCN Code] = gh.gp_PCN_code COLLATE DATABASE_DEFAULT AND p.[Transformation date] >= DATEADD(m,-11,a.ReportingPeriodStartDate) --this step looks 11 months before the PCN transformed to get a full 12 month access count

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET CONTACTS BY REFERRAL
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AccessRefsCont') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AccessRefsCont

SELECT 
	r.UniqMonthID,
	r.UniqServReqID,
	r.Person_ID,
	r.RecordNumber,
	r.[CCG code],
	r.[CCG name],
	r.[STP code],
	r.[STP name],
	r.[Region code],
	r.[Region name],
	COUNT(a.Der_DirectContact) AS Der_ContactCount

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AccessRefsCont

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AccessRefsPCN r

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_Act a ON a.RecordNumber = r.RecordNumber AND a.UniqServReqID = r.UniqServReqID

WHERE r.UniqMonthID >= @FYStart - 11 -- To only include data for the 12 months before the current year's multiple submission window model

GROUP BY r.UniqMonthID,r.UniqServReqID,r.Person_ID,r.RecordNumber, r.[CCG code],r.[CCG name],r.[STP code],r.[STP name],r.[Region code],r.[Region name]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ROLLING SECOND CONTACT COUNTS BY DUPLICATING 
REFERRAL OVER THE NEXT 12 MONTHS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMHRolling') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMHRolling

SELECT
	r.UniqMonthID + (ROW_NUMBER() OVER(PARTITION BY r.Person_ID, r.UniqServReqID, r.UniqMonthID ORDER BY r.UniqMonthID ASC) -1) AS Der_MonthID,
	r.UniqMonthID,
	r.Person_ID,
	r.UniqServReqID,
	r.[CCG code],
	r.[CCG name],
	r.[STP code],
	r.[STP name],
	r.[Region code],
	r.[Region name],
	r.Der_ContactCount

INTO NHSE_Sandbox_MentalHealth.dbo.temp_CMHRolling

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AccessRefsCont r

CROSS JOIN MASTER..spt_values AS n WHERE n.type = 'p' AND n.number BETWEEN r.UniqMonthID AND r.UniqMonthID + 11

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE ACTIVITY OVER PREVIOUS 12 MONTHS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAct') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAct

SELECT
	r.Der_MonthID,
	r.UniqMonthID,
	r.Person_ID,
	r.UniqServReqID,
	r.[CCG code],
	r.[CCG name],
	r.[STP code],
	r.[STP name],
	r.[Region code],
	r.[Region name],
	SUM(r.Der_ContactCount) OVER (PARTITION BY r.Person_ID, r.UniqServReqID, r.Der_MonthID ORDER BY r.UniqMonthID ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS Der_12MonthConts

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAct

FROM NHSE_Sandbox_MentalHealth.dbo.temp_CMHRolling r

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
COUNT EACH PERSON ONCE AT ORG LEVEL
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAgg') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAgg

SELECT CAST('England' AS varchar(50)) AS OrgCode, CAST('England' AS varchar(250)) AS OrgName, CAST('England' AS varchar(50)) AS OrgType, r.Der_MonthID AS UniqMonthID, COUNT(DISTINCT r.Person_ID) AS Access INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAgg FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAct r 
	WHERE r.Der_MonthID >= @FYStart AND r.Der_12MonthConts > 1 GROUP BY r.Der_MonthID

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAgg

SELECT r.[CCG code] AS OrgCode, r.[CCG name] AS OrgName, 'CCG' AS OrgType, r.Der_MonthID AS UniqMonthID, COUNT(DISTINCT r.Person_ID) AS Access FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAct r 
	WHERE r.Der_MonthID >= @FYStart AND r.Der_12MonthConts > 1 GROUP BY r.Der_MonthID, r.[CCG code], r.[CCG name]

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAgg

SELECT r.[STP code] AS OrgCode, r.[STP name] AS OrgName, 'STP' AS OrgType, r.Der_MonthID AS UniqMonthID, COUNT(DISTINCT r.Person_ID) AS Access FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAct r 
	WHERE r.Der_MonthID >= @FYStart AND r.Der_12MonthConts > 1 GROUP BY r.Der_MonthID, r.[STP code], r.[STP name]

INSERT INTO NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAgg

SELECT r.[Region code] AS OrgCode, r.[Region name] AS OrgName,'Region' AS OrgType, r.Der_MonthID AS UniqMonthID, COUNT(DISTINCT r.Person_ID) AS Access FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAct r 
	WHERE r.Der_MonthID >= @FYStart AND r.Der_12MonthConts > 1 GROUP BY r.Der_MonthID, r.[Region code], r.[Region name]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CREATE ACCESS EXTRACT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--DELETE DATA FROM THIS FINANCIAL YEAR

DELETE FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaitsAccess] WHERE ReportingPeriodEndDate >= @FYStartDate AND [Der_AccessType] = 'Second - PCN Rolling'

----CCG

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaitsAccess]

SELECT
	b.Orgtype AS [Organisation type],
	h.ReportingPeriodEndDate,
	b.OrgCode [Organisation code],
	b.OrgName [Organisation name],
	'Second - PCN Rolling' AS Der_AccessType,
	b.Access AS [CMH access]

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAgg b

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON b.UniqMonthID = h.UniqMonthID

WHERE b.OrgType = 'CCG'

----STP

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaitsAccess]

SELECT
	b.Orgtype AS [Organisation type],
	h.ReportingPeriodEndDate,
	b.OrgCode [Organisation code],
	b.OrgName [Organisation name],
	'Second - PCN Rolling' AS Der_AccessType,
	b.Access AS [CMH access]

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAgg b

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON b.UniqMonthID = h.UniqMonthID

WHERE b.OrgType = 'STP'

----Region

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaitsAccess]

SELECT
	b.Orgtype AS [Organisation type],
	h.ReportingPeriodEndDate,
	b.OrgCode [Organisation code],
	b.OrgName [Organisation name],
	'Second - PCN Rolling' AS Der_AccessType,
	b.Access AS [CMH access]

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAgg b

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON b.UniqMonthID = h.UniqMonthID

WHERE b.OrgType = 'Region'

----England

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_CMHWaitsAccess]

SELECT
	b.Orgtype AS [Organisation type],
	h.ReportingPeriodEndDate,
	b.OrgCode [Organisation code],
	b.OrgName [Organisation name],
	'Second - PCN Rolling' AS Der_AccessType,
	b.Access AS [CMH access]

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAgg b

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON b.UniqMonthID = h.UniqMonthID

WHERE b.OrgCode = 'England'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DROP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/
--waiting times
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CMH_Act
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CMH_AggAct
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CMH_AggCont
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CMH_AggCP
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CMH_AggInt
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CMH_AggMainDash
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CMH_AggOut
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CMH_Cumulative
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CMH_Dim
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CMH_Master
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CMH_Ref
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CMH_Subs
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CMH_SubsRanked
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_CMH_SubsRef
--access
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMHGP
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AccessRefsPCN
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_AccessRefsCont
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.temp_CMHRolling
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAct
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_CMH_RollingAgg
