/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
EATING DISORDER REPORTING

ASSET: PRE-PROCESSED TABLES

CREATED BY CARL MONEY 24/08/2020

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--SET VARIABLES

DECLARE @StartRP INT

SET @StartRP = 1429 --April 2019

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

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET INPATIENT ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Inpats') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Inpats

SELECT
	h.ReportingPeriodStartDate,
	h.ReportingPeriodEndDate,
	i.RecordNumber,
	i.UniqServReqID,
	SUM(CASE WHEN i.StartDateHospProvSpell BETWEEN h.ReportingPeriodStartDate AND h.ReportingPeriodEndDate AND i.Der_firstWardStayRecord = 1 THEN 1 ELSE 0 END) AS Der_Admissions,
	SUM(CASE WHEN i.DischDateHospProvSpell BETWEEN h.ReportingPeriodStartDate AND h.ReportingPeriodEndDate AND Der_LastWardStayRecord = 1 THEN 1 ELSE 0 END) AS Der_Discharges,
	SUM(CASE WHEN i.DischDateHospProvSpell BETWEEN h.ReportingPeriodStartDate AND h.ReportingPeriodEndDate AND Der_LastWardStayRecord = 1 THEN 1 ELSE 0 END) AS Der_WrdMoves,
	SUM(CASE WHEN i.StartDateHospProvSpell BETWEEN h.ReportingPeriodStartDate AND h.ReportingPeriodEndDate AND i.Der_firstWardStayRecord = 1 THEN i.WardLocDistanceHome END) AS Der_DistanceHome,
	SUM(DATEDIFF(dd,CASE WHEN i.StartDateWardStay < h.ReportingPeriodStartDate THEN h.ReportingPeriodStartDate ELSE i.StartDateWardStay END,
		CASE WHEN i.EndDateWardStay > h.ReportingPeriodEndDate OR i.EndDateWardStay IS NULL THEN h.ReportingPeriodEndDate ELSE i.EndDateWardStay END)) AS Der_OBDs,
	SUM(CASE WHEN i.DischDateHospProvSpell BETWEEN h.ReportingPeriodStartDate AND h.ReportingPeriodEndDate AND Der_LastWardStayRecord = 1 
		THEN DATEDIFF(dd,i.StartDateHospProvSpell,i.DischDateHospProvSpell)+1 END) AS Der_LOSHosp,
	SUM(CASE WHEN i.EndDateWardStay BETWEEN h.ReportingPeriodStartDate AND h.ReportingPeriodEndDate	THEN DATEDIFF(dd,i.StartDateWardStay,i.EndDateWardStay)+1 END) AS Der_LOSWrd

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Inpats

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Inpatients i

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON i.UniqMonthID = h.UniqMonthID

WHERE i.UniqMonthID BETWEEN @StartRP AND @EndRP AND i.HospitalBedTypeMH IN ('13','25','26')

GROUP BY h.ReportingPeriodStartDate, h.ReportingPeriodEndDate, i.RecordNumber, i.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET REFERRALS TO ED SERVICES BASED ON REASON FOR
REFERRAL, TEAM TYPE OR DIAGNOSIS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Ref') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Ref

SELECT
	h.ReportingPeriodStartDate,
	h.ReportingPeriodEndDate,
	r.UniqMonthID,
	r.OrgIDProv,
	r.OrgIDCCGRes,
	r.Person_ID,
	r.RecordNumber,
	r.UniqServReqID,
	r.ReferralRequestReceivedDate,
	r.EthnicCategory,
	r.Gender,
	r.LSOA2011,
	r.AgeServReferRecDate,
	r.SourceOfReferralMH,
	r.ServDischDate,
	r.ReferClosReason,
	r.ReferRejectionDate,
	r.ReferRejectReason,
	r.ServTeamTypeRefToMH,
	r.PrimReasonReferralMH,
	p.DiagDate,
	i.Der_Admissions,
	i.Der_Discharges,
	i.Der_WrdMoves,
	i.Der_DistanceHome,
	i.Der_LOSHosp,
	i.Der_LOSWrd,
	i.Der_OBDs

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Ref

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Referral r

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON r.UniqMonthID = h.UniqMonthID

LEFT JOIN (
SELECT
	p.Person_ID,
	p.UniqServReqID,
	MIN(p.CodedDiagTimestamp) AS DiagDate
FROM
(SELECT p.Person_ID, p.UniqServReqID, p.CodedDiagTimestamp FROM NHSE_MHSDS.dbo.MHS604PrimDiag p INNER JOIN NHSE_MH_PrePublication.test.MHSDS_SubmissionFlags m ON 
	p.NHSEUniqSubmissionID = m.NHSEUniqSubmissionID AND m.Der_IsLatest = 'Y'
	WHERE p.UniqMonthID BETWEEN @StartRP AND @EndRP AND p.PrimDiag LIKE 'F50%'

UNION ALL 

SELECT p.Person_ID, p.UniqServReqID, p.CodedDiagTimestamp FROM NHSE_MH_PrePublication.Test.MHS604PrimDiag p INNER JOIN NHSE_MH_PrePublication.test.MHSDS_SubmissionFlags m ON 
	p.NHSEUniqSubmissionID = m.NHSEUniqSubmissionID AND m.Der_IsLatest = 'Y'
	WHERE p.UniqMonthID BETWEEN @StartRP AND @EndRP AND p.PrimDiag LIKE 'F50%') p

GROUP BY p.Person_ID, p.UniqServReqID) p ON p.UniqServReqID = r.UniqServReqID AND p.Person_ID = r.Person_ID AND h.ReportingPeriodEndDate >= p.DiagDate

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Inpats i ON r.RecordNumber = i.RecordNumber AND r.UniqServReqID = i.UniqServReqID

WHERE r.UniqMonthID BETWEEN @StartRP AND @EndRP AND (r.LADistrictAuth LIKE 'E%' OR r.LADistrictAuth IS NULL) AND 
	(r.ServTeamTypeRefToMH IN ('C03','C09','C10') OR r.PrimReasonReferralMH = '12' OR p.DiagDate IS NOT NULL OR i.Der_OBDs IS NOT NULL)
	
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CREATE DERIVATIONS - DIMENSIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Dim') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Dim

SELECT
	r.ReportingPeriodStartDate,
	r.ReportingPeriodEndDate,
	r.UniqMonthID,
	r.Person_ID,
	r.RecordNumber,
	r.UniqServReqID,
	r.OrgIDProv [Provider code],
	p.Organisation_Name AS [Provider name],
	COALESCE(cc.New_Code,r.OrgIDCCGRes) AS [CCG Code],
	COALESCE(c.Organisation_Name,'Missing / Invalid') AS [CCG Name],
	COALESCE(c.STP_Code,'Missing / Invalid') AS [STP Code],
	COALESCE(c.STP_Name,'Missing / Invalid') AS [STP name],
	COALESCE(c.Region_Code,'Missing / Invalid') AS [Region Code],
	COALESCE(c.Region_Name,'Missing / Invalid') AS [Region name],
	CASE 
		WHEN e.Category IS NULL THEN  'Missing / invalid'
		WHEN e.Category = '' THEN 'Missing / invalid'
		ELSE CONCAT(e.[Category],' - ',e.[Main_Description_60_Chars])
	END AS Ethnicity,
	COALESCE(RIGHT(Person_Gender_Desc, LEN(Person_Gender_Desc) - 3), 'Missing / invalid') AS Gender,
	COALESCE(CASE WHEN l.IMD_Decile = '1' THEN '1 - most deprived' WHEN l.IMD_Decile = '10' THEN '10 - least deprived' ELSE CAST(l.IMD_Decile AS Varchar) END, 'Missing / Invalid') AS IMD_Decile,
	r.AgeServReferRecDate,
	CASE 
		WHEN r.AgeServReferRecDate BETWEEN 0 AND 12 THEN 'Under 12' 
		WHEN r.AgeServReferRecDate BETWEEN 12 AND 17 THEN '12 to 17' 
		WHEN r.AgeServReferRecDate BETWEEN 18 AND 19 THEN '18 to 19' 
		WHEN r.AgeServReferRecDate BETWEEN 20 AND 25 THEN '20 to 25' 
		WHEN r.AgeServReferRecDate BETWEEN 26 AND 64 THEN '26 to 64'
		WHEN r.AgeServReferRecDate BETWEEN 65 AND 84 THEN '65 to 84'
		WHEN r.AgeServReferRecDate >84 THEN '85 and over'
		ELSE 'Missing / Invalid'
	END AS [Age category],
	r.ReferralRequestReceivedDate,
	r.SourceOfReferralMH,
	CASE WHEN r.Der_OBDs IS NULL THEN 'Community' ELSE 'Inpatient' END AS [Referral major category],
	CASE 
		WHEN r.ServTeamTypeRefToMH IN ('C03','C09','C10') THEN 'ED Service' 
		WHEN r.PrimReasonReferralMH = 12 THEN 'Non-ED service but ED reason for referral'
		WHEN r.DiagDate <= r.ReportingPeriodEndDate THEN 'Non-ED service but ED primary diagnosis'
	END AS [Community referral category],
	r.ServDischDate,
	r.ReferClosReason,
	r.ReferRejectionDate,
	r.ReferRejectReason,
	r.ServTeamTypeRefToMH,
	r.PrimReasonReferralMH,
	r.DiagDate,
	r.Der_Admissions,
	r.Der_Discharges,
	r.Der_WrdMoves,
	r.Der_DistanceHome,
	r.Der_LOSHosp,
	r.Der_LOSWrd,
	r.Der_OBDs

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Dim

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Ref r

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_Other_Deprivation_By_LSOA l ON r.LSOA2011 = l.LSOA_Code AND l.Effective_Snapshot_Date = '2019-12-31'

LEFT JOIN NHSE_UKHF.Data_Dictionary.vw_Ethnic_Category_Code_SCD e ON r.EthnicCategory = e.[Main_Code_Text] COLLATE DATABASE_DEFAULT AND e.Is_Latest = 1

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_DataDic_ZZZ_PersonGender g ON r.Gender = g.Person_Gender_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_Other_ComCodeChanges cc ON r.OrgIDCCGRes = cc.Org_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies p ON r.OrgIDProv = p.Organisation_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies c ON COALESCE(cc.New_Code,r.OrgIDCCGRes) = c.Organisation_Code

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LINK TO ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Act') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Act

SELECT
	d.ReportingPeriodEndDate,
	d.UniqMonthID,
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
	d.[Age category],
	d.[Referral major category],
	d.[Community referral category],
	CASE 
		WHEN a.ConsMediumUsed = '01' THEN 'Consultation medium - face to face'
		WHEN a.ConsMediumUsed = '02' THEN 'Consultation medium - telephone'
		WHEN a.UniqMonthID < 1459 AND a.ConsMediumUsed = '03' OR a.UniqMonthID >= 1459 AND a.ConsMediumUsed = '11' THEN 'Consultation medium - video consult'
		WHEN a.ConsMediumUsed IN ('04','98') THEN 'Consultation medium - other'
		ELSE 'Consultation medium - missing / invalid'
	END AS Der_ConsMediumUsed,
	CASE
		WHEN a.Der_ContactDuration IS NULL OR a.Der_ContactDuration = 0 THEN 'Contact duration - no time recorded'
		WHEN a.Der_ContactDuration BETWEEN 1 AND 14 THEN 'Contact duration - less than 15 mins'
		WHEN a.Der_ContactDuration BETWEEN 15 AND 29 THEN 'Contact duration - 15 to 30 mins'
		WHEN a.Der_ContactDuration BETWEEN 30 AND 59 THEN 'Contact duration - 30 mins to an hour'
		WHEN a.Der_ContactDuration >59 THEN 'Contact duration - over an hour'
	END AS Der_ContactDurationCat,
	a.Der_DirectContact

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Act

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Dim d ON a.RecordNumber = d.RecordNumber AND a.UniqServReqID = d.UniqServReqID AND a.Der_DirectContact IS NOT NULL

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET CUMULATIVE ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Cumulative') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Cumulative

SELECT
	r.ReportingPeriodEndDate,
	r.RecordNumber,
	r.UniqServReqID,

	-- cumulative activity
	MAX(a.Der_ContactDate) AS Der_LastContact,
	SUM(a.Der_DirectContact) AS Der_CumulativeContacts

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Cumulative

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Ref r

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a ON r.Person_ID = a.Person_ID AND r.UniqServReqID = a.UniqServReqID AND a.ReportingPeriodEndDate <= r.ReportingPeriodEndDate 

WHERE a.Der_DirectContact IS NOT NULL

GROUP BY r.RecordNumber, r.ReportingPeriodEndDate, r.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET FIRST HONOS ITEM 8(G) AND CURRENT VIEW ITEM 20
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Ass') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Ass

SELECT
	a.RecordNumber,
	a.UniqServReqID,
	MAX(CASE WHEN a.CodedAssToolType = '987441000000102' THEN a.PersScore END) AS Der_CurrentView20Score,
	MAX(CASE WHEN a.CodedAssToolType = '979711000000105' AND h.PersScore = 'G' THEN a.PersScore END) AS Der_HoNOS8EDScore

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Ass

FROM [NHSE_Sandbox_MentalHealth].dbo.PreProc_Assessments a

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Ref r ON a.RecordNumber = r.RecordNumber AND a.UniqServReqID = r.UniqServReqID

LEFT JOIN (SELECT a.RecordNumber, a.UniqCareActID, a.PersScore FROM [NHSE_Sandbox_MentalHealth].dbo.PreProc_Assessments a WHERE CodedAssToolType = '979831000000108' AND a.PersScore = 'G' 
	AND a.UniqMonthID BETWEEN @StartRP AND @EndRP) h ON a.RecordNumber = h.RecordNumber AND a.Der_AssToolCompDate = a.Der_AssToolCompDate

WHERE a.CodedAssToolType IN ('987441000000102', -- current view item 20
	'979711000000105') -- HoNOS item 8
	AND a.Der_AssOrderAsc = 1

GROUP BY a.RecordNumber, a.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET EDEQ DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_ED_EDEQ') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_ED_EDEQ

SELECT
	a.RecordNumber,
	a.UniqServReqID,
	SUM(CASE WHEN a.CodedAssToolType = '959601000000103' THEN 1 ELSE 0 END) AS Eating14,
	SUM(CASE WHEN a.CodedAssToolType = '959611000000101' THEN 1 ELSE 0 END) AS Global14,
	SUM(CASE WHEN a.CodedAssToolType = '959621000000107' THEN 1 ELSE 0 END) AS Restraint14,
	SUM(CASE WHEN a.CodedAssToolType = '959631000000109' THEN 1 ELSE 0 END) AS Shape14,
	SUM(CASE WHEN a.CodedAssToolType = '959641000000100' THEN 1 ELSE 0 END) AS Weight14,
	SUM(CASE WHEN a.CodedAssToolType = '473345001' THEN 1 ELSE 0 END) AS Eating,
	SUM(CASE WHEN a.CodedAssToolType = '446826001' THEN 1 ELSE 0 END) AS 'Global',
	SUM(CASE WHEN a.CodedAssToolType = '473348004' THEN 1 ELSE 0 END) AS Restraint,
	SUM(CASE WHEN a.CodedAssToolType = '473346000' THEN 1 ELSE 0 END) AS Shape,
	SUM(CASE WHEN a.CodedAssToolType = '473347009' THEN 1 ELSE 0 END) AS 'Weight'

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_ED_EDEQ

FROM [NHSE_Sandbox_MentalHealth].dbo.PreProc_Assessments a

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Ref r ON a.RecordNumber = r.RecordNumber AND a.UniqServReqID = r.UniqServReqID

WHERE a.CodedAssToolType IN ('959601000000103', '959611000000101', '959621000000107', '959631000000109', '959641000000100', '473345001', '446826001', '473348004', '473346000', '473347009')
AND a.Der_AssOrderAsc IS NOT NULL

GROUP BY a.RecordNumber, a.UniqServReqID 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CREATE DERIVATIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Master') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Master

SELECT
	-- get dimensions
	s.ReportingPeriodStartDate,
	s.ReportingPeriodEndDate,
	s.UniqMonthID,
	s.Person_ID,
	s.RecordNumber,
	s.UniqServReqID,
	s.[Provider code],
	s.[Provider name],
	s.[CCG Code],
	s.[CCG Name],
	s.[STP Code],
	s.[STP name],
	s.[Region Code],
	s.[Region name],
	s.Ethnicity,
	s.Gender,
	s.IMD_Decile,
	s.AgeServReferRecDate,
	s.[Age category],
	s.SourceOfReferralMH,
	s.[Referral major category],
	s.[Community referral category],
	
	---- get caseload measures
	CASE WHEN (s.ServDischDate IS NULL OR s.ServDischDate > s.ReportingPeriodEndDate) AND s.ReferRejectionDate IS NULL THEN 1 ELSE 0 END AS [Open referrals],
	CASE WHEN (s.ServDischDate IS NULL OR s.ServDischDate > s.ReportingPeriodEndDate) AND s.ReferRejectionDate IS NULL AND cu.Der_LastContact IS NOT NULL THEN 1 ELSE 0 END AS [Caseload],
	CASE WHEN s.ReferralRequestReceivedDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [New referrals],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [Closed referrals],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate  AND s.ReferClosReason IN ('02','04') THEN 1 ELSE 0 END AS [Closed referrals - treatment complete / further treatment not appropriate],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate  AND s.ReferClosReason IN ('01','08') THEN 1 ELSE 0 END AS [Closed referrals - admitted / referred elsewhere],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate  AND s.ReferClosReason IN ('03','07') THEN 1 ELSE 0 END AS [Closed referrals - person moved / requested discharge],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate  AND s.ReferClosReason IN ('05','09') THEN 1 ELSE 0 END AS [Closed referrals - DNA / refused to be seen],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate  AND cu.Der_LastContact IS NOT NULL AND s.ReferClosReason = '08' THEN 1 ELSE 0 END AS [Closed referrals signposted],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate  AND (s.ReferClosReason NOT IN ('01','02','03','04','05','07','08','09') OR s.ReferClosReason IS NULL) THEN 1 ELSE 0 END AS [Closed referrals - other reason / unknown],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate  AND cu.Der_CumulativeContacts = 1 THEN 1 ELSE 0 END AS [Closed with one contact],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate  AND cu.Der_CumulativeContacts > 1 THEN 1 ELSE 0 END AS [Closed with two or more contacts],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate  AND (cu.Der_CumulativeContacts IS NULL OR cu.Der_CumulativeContacts = 0) THEN 1 ELSE 0 END AS [Closed with no contacts offered / attended],

	---- get referral length for referrals closed in month, inc categories
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.ServDischDate) BETWEEN 0 and 6 THEN 1 ELSE 0 END AS [Referral length - less than one week],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.ServDischDate) BETWEEN 7 and 13 THEN 1 ELSE 0 END AS [Referral length - one to two weeks],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.ServDischDate) BETWEEN 14 and 27 THEN 1 ELSE 0 END AS [Referral length - two to four weeks],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.ServDischDate) BETWEEN 28 and 182	THEN 1 ELSE 0 END AS [Referral length - one to six months],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.ServDischDate) BETWEEN 183 and 365 THEN 1 ELSE 0 END AS [Referral length - six to 12 months],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.ServDischDate) > 365 THEN 1 ELSE 0 END AS [Referral length - over 12 months],

	---- get referral not accepted measures, inc duration
	CASE WHEN s.ReferRejectionDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate  THEN 1 ELSE 0 END AS [Referrals not accepted],
	CASE WHEN s.ReferRejectionDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate  AND s.ReferRejectReason = 02 THEN 1 ELSE 0 END AS [Referrals not accepted - alternative service required],
	CASE WHEN s.ReferRejectionDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate  AND s.ReferRejectReason = 01 THEN 1 ELSE 0 END AS [Referrals not accepted - duplicate],
	CASE WHEN s.ReferRejectionDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate  AND s.ReferRejectReason = 03 THEN 1 ELSE 0 END AS [Referrals not accepted - incomplete],
	CASE WHEN s.ReferRejectionDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate  AND (s.ReferRejectReason NOT IN (01,02,03) OR s.ReferRejectReason IS NULL) THEN 1 ELSE 0 END AS [Referrals not accepted - missing / invalid],
	CASE WHEN s.ReferRejectionDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate  THEN DATEDIFF(dd,s.ReferralRequestReceivedDate,s.ReferRejectionDate) END AS [Referrals not accepted length],

	---- get days since last contact measures, inc categories, limited to open referrals at month end
	CASE WHEN (s.ServDischDate IS NULL OR s.ServDischDate > s.ReportingPeriodEndDate) AND DATEDIFF(dd,cu.Der_LastContact,s.ReportingPeriodEndDate) BETWEEN 0 and 6 THEN 1 ELSE 0 END AS [Time since last contact - less than one week],
	CASE WHEN (s.ServDischDate IS NULL OR s.ServDischDate > s.ReportingPeriodEndDate) AND DATEDIFF(dd,cu.Der_LastContact,s.ReportingPeriodEndDate) BETWEEN 7 and 13 THEN 1 ELSE 0 END AS [Time since last contact - one to two weeks],
	CASE WHEN (s.ServDischDate IS NULL OR s.ServDischDate > s.ReportingPeriodEndDate) AND DATEDIFF(dd,cu.Der_LastContact,s.ReportingPeriodEndDate) BETWEEN 14 and 27 THEN 1 ELSE 0 END AS [Time since last contact - two to four weeks],
	CASE WHEN (s.ServDischDate IS NULL OR s.ServDischDate > s.ReportingPeriodEndDate) AND DATEDIFF(dd,cu.Der_LastContact,s.ReportingPeriodEndDate) >27 THEN 1 ELSE 0 END AS [Time since last contact - four weeks or more],
	
	-- get misc other measures (inpatient, in month activity, outcomes)
	s.Der_Admissions AS [Admissions],
	s.Der_Discharges AS [Discharges],
	s.Der_WrdMoves AS [Finished ward stays],
	s.Der_DistanceHome AS [Distance to home],
	s.Der_LOSHosp AS [Length of stay - hospital spell],
	s.Der_LOSWrd AS [Length of stay - ward stay],
	s.Der_OBDs AS [Occupied bed days],
	CAST(LEFT(a.Der_HoNOS8EDScore,1) AS int) AS [Initial HoNOS eating issues scale score],
	CAST(LEFT(a.Der_CurrentView20Score,1) AS int) AS [Initial current view eating issues scale score],
	(SELECT MAX(v) FROM (VALUES (e.Eating14),(e.Global14),(e.Restraint14),(e.Shape14),(e.Weight14)) AS Value(v)) AS [EDEQ - Adolescent],
	(SELECT MAX(v) FROM (VALUES (e.Eating),(e.[Global]),(e.Restraint),(e.Shape),(e.[Weight])) AS Value(v)) AS [EDEQ]
 
INTO NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Master

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Dim s

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Cumulative cu ON cu.RecordNumber = s.RecordNumber AND cu.UniqServReqID = s.UniqServReqID

--LINK TO FIRST HoNOS AND CURRENT VIEW

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Ass a ON s.RecordNumber = a.RecordNumber AND s.UniqServReqID = a.UniqServReqID 

--LIMK TO EDEQ

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.Temp_ED_EDEQ AS e ON s.RecordNumber = e.RecordNumber AND s.UniqServReqID = e.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_ED_AggMainDash') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_ED_AggMainDash

SELECT
	m.ReportingPeriodEndDate,
	m.[Provider code],
	m.[Provider name],
	m.[CCG Code],
	m.[CCG Name],
	m.[STP Code],
	m.[STP name],
	m.[Region Code],
	m.[Region name],
	m.[Age category],
	m.[Referral major category] AS [Major Category],
	m.[Community referral category] AS [Category],
	
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
	SUM([Referral length - six to 12 months]) AS [Referral length - six to 12 months],
	SUM([Referral length - over 12 months]) AS [Referral length - over 12 months],
	
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

	SUM([Admissions]) AS [Admissions],
	SUM([Discharges]) AS [Discharges],
	SUM([Finished ward stays]) AS [Finished ward stays],
	SUM([Distance to home]) AS [Distance to home],
	MAX([Distance to home]) AS [MAX Distance to home],
	SUM([Length of stay - hospital spell]) AS [Length of stay - hospital spell],
	SUM([Length of stay - ward stay]) AS [Length of stay - ward stay],
	SUM([Occupied bed days]) AS [Occupied bed days],
	SUM([Initial HoNOS eating issues scale score]) AS [Initial HoNOS eating issues scale score],
	MAX([Initial HoNOS eating issues scale score]) AS [MAX Initial HoNOS eating issues scale score],
	SUM([Initial current view eating issues scale score]) AS [Initial current view eating issues scale score],
	MAX([Initial current view eating issues scale score]) AS [MAX Initial current view eating issues scale score],
	SUM([EDEQ - Adolescent]) AS [EDEQ - Adolescent],
	SUM([EDEQ]) AS [EDEQ],
	
	 --duplicated to make calculations in tableau easier
	SUM([Closed referrals]) AS [Closed referrals2],
	SUM([Referrals not accepted]) AS [Referrals not accepted2],
	SUM([Admissions]) AS [Admissions2],
	SUM([Discharges]) AS [Discharges2],
	SUM([Finished ward stays]) AS [Finished ward stays2],
	SUM([Caseload]) AS [Caseload2],
	COUNT([Initial HoNOS eating issues scale score]) AS [Initial HoNOS eating issues scale score2],
	COUNT([Initial current view eating issues scale score]) AS [Initial current view eating issues scale score2]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_ED_AggMainDash

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Provider code], m.[Provider name], m.[CCG Code], m.[CCG Name], m.[STP Code], m.[STP name], m.[Region Code], m.[Region name], m.[Age category], m.[Referral major category], m.[Community referral category]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('NHSE_Sandbox_MentalHealth.dbo.Temp_ED_AggAct') IS NOT NULL
DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Temp_ED_AggAct

SELECT
	a.[ReportingPeriodEndDate],
	a.[Provider code],
	a.[Provider name],
	a.[CCG code],
	a.[CCG name],
	a.[STP code],
	a.[STP name],
	a.[Region code],
	a.[Region name],
	a.[Age category],
	a.[Der_ConsMediumUsed] AS [Consulation medium],
	a.[Der_ContactDurationCat] AS [Contact duration],
	a.[Referral major category] AS [Major Category],
	a.[Community referral category] AS [Category],

	SUM(a.Der_DirectContact) AS [Number of contacts]

INTO NHSE_Sandbox_MentalHealth.dbo.Temp_ED_AggAct

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Act a

GROUP BY a.[ReportingPeriodEndDate], a.[Provider code], a.[Provider name], a.[CCG code], a.[CCG name], a.[STP code], a.[STP name], a.[Region code], a.[Region name],
	a.[Referral major category], a.[Age category], a.[Community referral category], a.[Der_ConsMediumUsed], a.[Der_ContactDurationCat]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UNPIVOT AND CREATE ACTIVITY EXTRACT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- CORE DASH

IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

SELECT
	ReportingPeriodEndDate,
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	[Age category],
	CAST([Major Category] AS varchar(255)) AS [Major Category],
	CAST([Category] AS varchar(255)) AS [Category],
	'Core Dashboard' AS [Dashboard type],
	CAST(NULL AS varchar(255)) AS Breakdown,
	CAST(NULL AS varchar(255)) AS [Breakdown category],
	MeasureName,
	MeasureValue,
	CASE 
		WHEN [MeasureName] = 'Referral length' THEN [Closed referrals2]
		WHEN [MeasureName] = 'Distance to home' THEN [Admissions2]
		WHEN [MeasureName] = 'Length of stay - hospital spell' THEN [Discharges2]
		WHEN [MeasureName] = 'Length of stay - ward stay' THEN [Finished ward stays2]
		WHEN [MeasureName] = 'Initial HoNOS eating issues scale score' THEN [Initial HoNOS eating issues scale score2]
		WHEN [MeasureName] = 'Initial current view eating issues scale score' THEN [Initial current view eating issues scale score2]
	END	AS Denominator

INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_ED_AggMainDash 

UNPIVOT (MeasureValue FOR MeasureName IN 
	([Caseload],[Open referrals],[New referrals],[Closed referrals],[Closed referrals - treatment complete / further treatment not appropriate],[Closed referrals - admitted / referred elsewhere],
	[Closed referrals - person moved / requested discharge],[Closed referrals - DNA / refused to be seen],[Closed referrals - other reason / unknown],[Closed referrals signposted],
	[Closed with one contact],[Closed with two or more contacts],[Closed with no contacts offered / attended],[Referral length - less than one week],[Referral length - one to two weeks],
	[Referral length - two to four weeks],[Referral length - one to six months],[Referral length - six to 12 months],[Referral length - over 12 months],[Referrals not accepted],[Referrals not accepted - alternative service required],
	[Referrals not accepted - duplicate],[Referrals not accepted - incomplete],[Referrals not accepted - missing / invalid],[Referrals not accepted length],[Time since last contact - less than one week],
	[Time since last contact - one to two weeks],[Time since last contact - two to four weeks],[Time since last contact - four weeks or more],[Admissions],[Discharges],[Finished ward stays],[Distance to home],
	[MAX Distance to home],[Length of stay - hospital spell],[Length of stay - ward stay],[Occupied bed days],[Initial HoNOS eating issues scale score],[MAX Initial HoNOS eating issues scale score],[Initial current view eating issues scale score],
	[MAX Initial current view eating issues scale score],[EDEQ - Adolescent],[EDEQ])) u

-- ACTIVITY DASH

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

SELECT 
	ReportingPeriodEndDate,
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	[Age category],
	[Major Category],
	[Category],
	'Activity' AS [Dashboard type],
	[Consulation medium] AS Breakdown,
	[Contact duration] AS [Breakdown category],
	'Number of contacts' AS MeasureName,
	[Number of contacts] AS MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_ED_AggAct

-- DEMOGRAPHICS DASH

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Provider code],
	NULL AS [Provider name],
	NULL AS [CCG code],
	NULL AS [CCG name],
	NULL AS [STP code],
	NULL AS [STP name],
	[Region code],
	[Region name],
	'N/A' AS [Age category],
	'N/A' AS [Major Category],
	'N/A' AS [Category],
	'Demographics' AS [Dashboard type],
	'Ethnicity' AS Breakdown,
	m.Ethnicity AS [Breakdown category],
	'Caseload' AS MeasureName,
	SUM(Caseload) AS MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Region code], m.[Region name], m.Ethnicity

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Provider code],
	NULL AS [Provider name],
	NULL AS [CCG code],
	NULL AS [CCG name],
	NULL AS [STP code],
	NULL AS [STP name],
	[Region code],
	[Region name],
	'N/A' AS [Age category],
	'N/A' AS [Major Category],
	'N/A' AS [Category],
	'Demographics' AS [Dashboard type],
	'Gender' AS Breakdown,
	m.Gender AS [Breakdown category],
	'Caseload' AS MeasureName,
	SUM(Caseload) AS MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Region code], m.[Region name], m.Gender

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Provider code],
	NULL AS [Provider name],
	NULL AS [CCG code],
	NULL AS [CCG name],
	NULL AS [STP code],
	NULL AS [STP name],
	[Region code],
	[Region name],
	'N/A' AS [Age category],
	'N/A' AS [Major Category],
	'N/A' AS [Category],
	'Demographics' AS [Dashboard type],
	'Age' AS Breakdown,
	m.AgeServReferRecDate AS [Breakdown category],
	'Caseload' AS MeasureName,
	SUM(Caseload) AS MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Region code], m.[Region name], m.AgeServReferRecDate

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

SELECT
	ReportingPeriodEndDate,
	NULL AS [Provider code],
	NULL AS [Provider name],
	NULL AS [CCG code],
	NULL AS [CCG name],
	NULL AS [STP code],
	NULL AS [STP name],
	[Region code],
	[Region name],
	'N/A' AS [Age category],
	'N/A' AS [Major Category],
	'N/A' AS [Category],
	'Demographics' AS [Dashboard type],
	'IMD' AS Breakdown,
	m.IMD_Decile AS [Breakdown category],
	'Caseload' AS MeasureName,
	SUM(Caseload) AS MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Master m

GROUP BY m.ReportingPeriodEndDate, m.[Region code], m.[Region name], m.IMD_Decile

-- REFERRAL SOURCE

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

SELECT
	ReportingPeriodEndDate,
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	[Age category],
	[Community referral category] AS [Major Category],
	[Age category] AS [Category],
	'Ref source' AS [Dashboard type],
	COALESCE(r.Category, 'Missing / invalid') AS Breakdown,
	COALESCE(r.Main_Description, 'Missing / invalid') AS [Breakdown category],
	'Caseload by referral source' AS MeasureName,
	SUM([New referrals]) AS MeasureValue,
	NULL AS Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Temp_ED_Master m

LEFT JOIN [NHSE_UKHF].[Data_Dictionary].[vw_Source_Of_Referral_For_Mental_Health_SCD] r ON m.SourceOfReferralMH = r.Main_Code_Text COLLATE DATABASE_DEFAULT 
	AND (r.Effective_To IS NULL OR r.Effective_To >= '2019-04-01') AND (r.Valid_To IS NULL OR r.Valid_To >= '2019-04-01') AND Is_Latest = 1

WHERE m.[Referral major category] = 'Community'

GROUP BY ReportingPeriodEndDate, [Provider code], [Provider name], [CCG code], [CCG name], [STP code], [STP name], [Region code], [Region name], [Age category], [Community referral category], COALESCE(r.Category, 'Missing / invalid'), COALESCE(r.Main_Description, 'Missing / invalid')

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ADULT WAITING TIMES DATA

** IMPORTANT **

THIS IS TAKEN FROM THE CMH DASHBOARD FOR CONSISTENCY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

SELECT 
	ReportingPeriodEndDate,
	[Provider code],
	[Provider name],
	[CCG code],
	[CCG name],
	[STP code],
	[STP name],
	[Region code],
	[Region name],
	'N/A' AS [Age category],
	[Primary reason for referral] AS [Major Category],
	[Team type] AS [Category],
	[Dashboard type],
	Breakdown,
	[Breakdown category],
	MeasureName,
	MeasureValue,
	Denominator

FROM NHSE_Sandbox_MentalHealth.dbo.Dashboard_CMHWaits

WHERE [Dashboard type] = 'Waiting times' AND [Team type] = 'Community Eating Disorder Service'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
DROP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_ED_AggMainDash
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_ED_Ass
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_ED_EDEQ
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_ED_Inpats
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_ED_Master
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].Temp_ED_Ref
