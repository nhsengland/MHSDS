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

IF OBJECT_ID ('tempdb..#Inpats') IS NOT NULL
DROP TABLE #Inpats

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

INTO #Inpats

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Inpatients i

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON i.UniqMonthID = h.UniqMonthID

WHERE i.UniqMonthID BETWEEN @StartRP AND @EndRP AND i.HospitalBedTypeMH IN ('13','25','26')

GROUP BY h.ReportingPeriodStartDate, h.ReportingPeriodEndDate, i.RecordNumber, i.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET REFERRALS TO ED SERVICES BASED ON REASON FOR
REFERRAL, TEAM TYPE OR DIAGNOSIS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Ref') IS NOT NULL
DROP TABLE #Ref

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
	i.Der_OBDs,
	a1.Der_ContactDate AS Der_FirstContactDate,
	a1.Der_ContactDuration AS Der_FirstContactDuration,
	a2.Der_ContactDate AS Der_SecondContactDate,
	a2.Der_ContactDuration AS Der_SecondContactDuration

INTO #Ref

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Referral r

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Header h ON r.UniqMonthID = h.UniqMonthID

LEFT JOIN (
SELECT
	p.Person_ID,
	p.UniqServReqID,
	MIN(p.DiagDate) AS DiagDate
FROM
(SELECT * FROM NHSE_MHSDS.dbo.MHS604PrimDiag p WHERE p.Der_Use_Submission_Flag = 'Y' AND p.UniqMonthID BETWEEN @StartRP AND @EndRP AND p.PrimDiag LIKE 'F50%'
UNION ALL 
SELECT * FROM NHSE_MH_PrePublication.dbo.V4_MHS604PrimDiag p WHERE p.Der_Use_Submission_Flag = 'Y' AND p.UniqMonthID BETWEEN @StartRP AND @EndRP AND p.PrimDiag LIKE 'F50%') p

GROUP BY p.Person_ID, p.UniqServReqID) p ON p.UniqServReqID = r.UniqServReqID AND p.Person_ID = r.Person_ID AND h.ReportingPeriodEndDate >= p.DiagDate

LEFT JOIN #Inpats i ON r.RecordNumber = i.RecordNumber AND r.UniqServReqID = i.UniqServReqID

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a1 ON a1.RecordNumber = r.RecordNumber AND a1.UniqServReqID = r.UniqServReqID AND a1.Der_FacetoFaceContactOrder = 1 

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity a2 ON a2.RecordNumber = r.RecordNumber AND a2.UniqServReqID = r.UniqServReqID AND a2.Der_FacetoFaceContactOrder = 2 

WHERE r.UniqMonthID BETWEEN @StartRP AND @EndRP AND (r.LADistrictAuth LIKE 'E%' OR r.LADistrictAuth IS NULL) AND 
	(r.ServTeamTypeRefToMH IN ('C03','C09','C10') OR r.PrimReasonReferralMH = '12' OR p.DiagDate IS NOT NULL OR i.Der_OBDs IS NOT NULL)

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET FIRST HONOS ITEM 8(G) AND CURRENT VIEW ITEM 20
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Ass') IS NOT NULL
DROP TABLE #Ass

SELECT
	a.RecordNumber,
	a.UniqServReqID,
	MAX(CASE WHEN a.CodedAssToolType = '987441000000102' THEN a.PersScore END) AS Der_CurrentView20Score,
	MAX(CASE WHEN a.CodedAssToolType = '979711000000105' AND h.PersScore = 'G' THEN a.PersScore END) AS Der_HoNOS8EDScore

INTO #Ass

FROM [NHSE_Sandbox_MentalHealth].dbo.PreProc_Assessments a

INNER JOIN #Ref r ON a.RecordNumber = r.RecordNumber AND a.UniqServReqID = r.UniqServReqID

LEFT JOIN (SELECT a.RecordNumber, a.UniqCareActID, a.PersScore FROM [NHSE_Sandbox_MentalHealth].dbo.PreProc_Assessments a WHERE CodedAssToolType = '979831000000108' AND a.PersScore = 'G' 
	AND a.UniqMonthID BETWEEN @StartRP AND @EndRP) h ON a.RecordNumber = h.RecordNumber AND a.Der_AssToolCompDate = a.Der_AssToolCompDate

WHERE a.CodedAssToolType IN ('987441000000102', -- current view item 20
	'979711000000105') -- HoNOS item 8
	AND a.Der_AssOrderAsc = 1

GROUP BY a.RecordNumber, a.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET EDEQ DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#EDEQ') IS NOT NULL
DROP TABLE #EDEQ

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

INTO #EDEQ

FROM [NHSE_Sandbox_MentalHealth].dbo.PreProc_Assessments a

INNER JOIN #Ref r ON a.RecordNumber = r.RecordNumber AND a.UniqServReqID = r.UniqServReqID

WHERE a.CodedAssToolType IN ('959601000000103', '959611000000101', '959621000000107', '959631000000109', '959641000000100', '473345001', '446826001', '473348004', '473346000', '473347009')
AND a.Der_AssOrderAsc IS NOT NULL

GROUP BY a.RecordNumber, a.UniqServReqID 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET SUBSEQUENT ACTIVITY
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Subs') IS NOT NULL
DROP TABLE #Subs

SELECT
	r.ReportingPeriodStartDate,
	r.ReportingPeriodEndDate,
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
	r.DiagDate,
	r.Der_Admissions,
	r.Der_Discharges,
	r.Der_WrdMoves,
	r.Der_DistanceHome,
	r.Der_LOSHosp,
	r.Der_LOSWrd,
	r.Der_OBDs,
	r.Der_FirstContactDate,
	r.Der_FirstContactDuration,
	r.Der_SecondContactDate,
	r.Der_SecondContactDuration,
	ma.Der_InMonthContacts,
	ma.Der_InMonthDNAContacts,
	ma.Der_InMonthCancelledContacts,
	ma.Der_InMonthIndirectContacts,
	ma.Der_InMonthInvalidContacts,
	ca.Der_LastContact,
	ca.Der_LastF2FContact,
	a.Der_HoNOS8EDScore,
	a.Der_CurrentView20Score,
	(SELECT MAX(v) FROM (VALUES (e.Eating14),(e.Global14),(e.Restraint14),(e.Shape14),(e.Weight14)) AS Value(v)) AS EDEQ14to16,
	(SELECT MAX(v) FROM (VALUES (e.Eating),(e.[Global]),(e.Restraint),(e.Shape),(e.[Weight])) AS Value(v)) AS EDEQ

INTO #Subs

FROM #Ref r

-- get last contact
LEFT JOIN 
(SELECT
	r.RecordNumber,
	r.UniqServReqID,
	MAX(CASE WHEN c.Der_ContactOrder IS NOT NULL THEN c.Der_ContactDate END) AS Der_LastContact,
	MAX(CASE WHEN c.Der_FacetoFaceContactOrder IS NOT NULL THEN c.Der_ContactDate END) AS Der_LastF2FContact

FROM #Ref r

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity c ON r.Person_ID = c.Person_ID AND r.UniqServReqID = c.UniqServReqID AND c.UniqMonthID <= r.UniqMonthID 

GROUP BY r.RecordNumber, r.UniqServReqID) ca ON r.RecordNumber = ca.RecordNumber AND r.UniqServReqID = ca.UniqServReqID

-- get in month activity
LEFT JOIN 
(SELECT
	r.RecordNumber,
	r.UniqServReqID,
	COUNT(CASE WHEN c.AttendOrDNACode IN ('5','6') THEN c.Der_ActivityUniqID END) AS Der_InMonthContacts,
	COUNT(CASE WHEN c.AttendOrDNACode IN ('7','3') THEN c.Der_ActivityUniqID END) AS Der_InMonthDNAContacts,
	COUNT(CASE WHEN c.AttendOrDNACode IN ('2','4') THEN c.Der_ActivityUniqID END) AS Der_InMonthCancelledContacts,
	COUNT(CASE WHEN c.Der_ActivityType = 'INDIRECT' THEN c.Der_ActivityUniqID END) AS Der_InMonthIndirectContacts,
	COUNT(CASE WHEN c.Der_ActivityType = 'DIRECT' AND c.AttendOrDNACode NOT IN ('2','3','4','5','6','7') THEN c.Der_ActivityUniqID END) AS Der_InMonthInvalidContacts

FROM #Ref r

INNER JOIN NHSE_Sandbox_MentalHealth.dbo.PreProc_Activity c ON r.RecordNumber = c.RecordNumber AND r.UniqServReqID = c.UniqServReqID

GROUP BY r.RecordNumber, r.UniqServReqID) ma ON r.RecordNumber = ma.RecordNumber AND r.UniqServReqID = ma.UniqServReqID

--LINK TO FIRST HoNOS AND CURRENT VIEW

LEFT JOIN #Ass a ON r.RecordNumber = a.RecordNumber AND r.UniqServReqID = a.UniqServReqID 

--LIMK TO EDEQ

LEFT JOIN #EDEQ AS e ON r.RecordNumber = e.RecordNumber AND r.UniqServReqID = e.UniqServReqID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CREATE DERIVATIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Master') IS NOT NULL
DROP TABLE #Master

SELECT
	-- get dimensions
	s.ReportingPeriodStartDate,
	s.ReportingPeriodEndDate,
	s.Person_ID,
	s.RecordNumber,
	s.UniqServReqID,
	s.OrgIDProv,
	p.Organisation_Name AS [Provider name],
	COALESCE(cc.New_Code,s.OrgIDCCGRes) AS CCGCode,
	COALESCE(c.Organisation_Name,'Missing / Invalid') AS [CCG Name],
	COALESCE(c.STP_Code,'Missing / Invalid') AS STP_Code,
	COALESCE(c.STP_Name,'Missing / Invalid') AS [STP name],
	COALESCE(c.Region_Code,'Missing / Invalid') AS Region_Code,
	COALESCE(c.Region_Name,'Missing / Invalid') AS [Region name],
	CASE 
		WHEN e.Category IS NULL THEN  'Missing / invalid'
		WHEN e.Category = '' THEN 'Missing / invalid'
		ELSE CONCAT(e.[Category],' - ',e.[Main_Description_60_Chars])
	END AS Ethnicity,
	COALESCE(RIGHT(Person_Gender_Desc, LEN(Person_Gender_Desc) - 3), 'Missing / invalid') AS Gender,
	COALESCE(CASE WHEN l.IMD_Decile = '1' THEN '1 - most deprived' WHEN l.IMD_Decile = '10' THEN '10 - least deprived' ELSE CAST(l.IMD_Decile AS Varchar) END, 'Missing / Invalid') AS IMD_Decile,
	CASE 
		WHEN s.AgeServReferRecDate BETWEEN 0 AND 12 THEN 'Under 12' 
		WHEN s.AgeServReferRecDate BETWEEN 12 AND 17 THEN '12 to 17' 
		WHEN s.AgeServReferRecDate BETWEEN 18 AND 19 THEN '18 to 19' 
		WHEN s.AgeServReferRecDate BETWEEN 20 AND 25 THEN '20 to 25' 
		WHEN s.AgeServReferRecDate >25 THEN 'Over 25'
		ELSE 'Missing / Invalid'
	END AS [Age category],
	s.ReferralRequestReceivedDate,
	s.SourceOfReferralMH,
	CASE WHEN s.Der_OBDs IS NULL THEN 'Community' ELSE 'Inpatient' END AS [Referral major category],
	CASE 
		WHEN s.ServTeamTypeRefToMH IN ('C03','C09','C10') THEN 'ED Service' 
		WHEN s.PrimReasonReferralMH = 12 THEN 'Non-ED service but ED reason for referral'
		WHEN s.DiagDate <= s.ReportingPeriodEndDate THEN 'Non-ED service but ED primary diagnosis'
	END AS [Community referral category],
	
	--get number of referrals with first contact in month
	CASE WHEN s.Der_FirstContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [First contact],
	
	-- get time to first contact, inc categories
	CASE WHEN s.Der_FirstContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate THEN DATEDIFF(dd,s.ReferralRequestReceivedDate,s.Der_FirstContactDate) END AS [Time to first contact],
		CASE WHEN s.Der_FirstContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.Der_FirstContactDate) BETWEEN 0 and 6 THEN 1 ELSE 0 
		END AS [Time to first contact - less than one week],
	CASE WHEN s.Der_FirstContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.Der_FirstContactDate) BETWEEN 7 and 13 THEN 1 ELSE 0 
		END AS [Time to first contact - one to two weeks],
	CASE WHEN s.Der_FirstContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.Der_FirstContactDate) BETWEEN 14 and 27 THEN 1 ELSE 0 
		END AS [Time to first contact - two to four weeks],
	CASE WHEN s.Der_FirstContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.Der_FirstContactDate) BETWEEN 28 and 182 THEN 1 ELSE 0 
		END AS [Time to first contact - one to six months],
	CASE WHEN s.Der_FirstContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.Der_FirstContactDate) > 182 THEN 1 ELSE 0 
		END AS [Time to first contact - six months and over],

	-- get time to duration of first contact, inc categories
	CASE WHEN s.Der_FirstContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate THEN s.Der_FirstContactDuration END AS [First contact duration],
	CASE WHEN s.Der_FirstContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.Der_FirstContactDuration = 0 OR s.Der_FirstContactDuration IS NULL THEN 1 ELSE 0 
		END AS [First contact duration - no time recorded],
	CASE WHEN s.Der_FirstContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.Der_FirstContactDuration BETWEEN 1 AND 14 THEN 1 ELSE 0 END AS [First contact duration - less than 15 mins],	
	CASE WHEN s.Der_FirstContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.Der_FirstContactDuration BETWEEN 15 AND 29 THEN 1 ELSE 0 END AS [First contact duration - 15 to 30 mins],	
	CASE WHEN s.Der_FirstContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.Der_FirstContactDuration BETWEEN 30 AND 59 THEN 1 ELSE 0 END AS [First contact duration - 30 mins to an hour],	
	CASE WHEN s.Der_FirstContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.Der_FirstContactDuration >59 THEN 1 ELSE 0 END AS [First contact duration - over an hour],	

	--get number of referrals with second contact in month
	CASE WHEN s.Der_secondContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [Second contact],
	
	-- get time to second contact, inc categories
	CASE WHEN s.Der_SecondContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate THEN DATEDIFF(dd,s.ReferralRequestReceivedDate,s.Der_SecondContactDate) END AS [Time to second contact],
		CASE WHEN s.Der_secondContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.Der_SecondContactDate) BETWEEN 0 and 6 THEN 1 ELSE 0 
		END AS [Time to second contact - less than one week],
	CASE WHEN s.Der_SecondContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.Der_SecondContactDate) BETWEEN 7 and 13 THEN 1 ELSE 0 
		END AS [Time to second contact - one to two weeks],
	CASE WHEN s.Der_SecondContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.Der_SecondContactDate) BETWEEN 14 and 27 THEN 1 ELSE 0 
		END AS [Time to second contact - two to four weeks],
	CASE WHEN s.Der_SecondContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.Der_SecondContactDate) BETWEEN 28 and 182 THEN 1 ELSE 0 
		END AS [Time to second contact - one to six months],
	CASE WHEN s.Der_SecondContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.Der_SecondContactDate) > 182 THEN 1 ELSE 0 
		END AS [Time to second contact - six months and over],

	-- get time to duration of second contact, inc categories
	CASE WHEN s.Der_SecondContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate THEN s.Der_secondContactDuration END AS [Second contact duration],
	CASE WHEN s.Der_SecondContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.Der_secondContactDuration = 0 OR s.Der_secondContactDuration IS NULL THEN 1 ELSE 0 
		END AS [Second contact duration - no time recorded],
	CASE WHEN s.Der_SecondContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.Der_secondContactDuration BETWEEN 1 AND 14 THEN 1 ELSE 0 END AS [Second contact duration - less than 15 mins],	
	CASE WHEN s.Der_SecondContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.Der_secondContactDuration BETWEEN 15 AND 29 THEN 1 ELSE 0 END AS [Second contact duration - 15 to 30 mins],	
	CASE WHEN s.Der_SecondContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.Der_secondContactDuration BETWEEN 30 AND 59 THEN 1 ELSE 0 END AS [Second contact duration - 30 mins to an hour],	
	CASE WHEN s.Der_SecondContactDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.Der_secondContactDuration >59 THEN 1 ELSE 0 END AS [Second contact duration - over an hour],	
	
	-- get caseload measures
	CASE WHEN s.ServDischDate IS NULL AND s.ReferRejectionDate IS NULL THEN 1 ELSE 0 END AS [Open referrals],
	CASE WHEN s.ServDischDate IS NULL AND s.ReferRejectionDate IS NULL AND s.Der_LastContact IS NOT NULL THEN 1 ELSE 0 END AS [Caseload],
	CASE WHEN s.ReferralRequestReceivedDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [New referrals],
	CASE WHEN s.ReferRejectionDate IS NULL AND s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [Closed referrals],
	CASE WHEN s.ReferRejectionDate IS NULL AND s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.ReferClosReason IN ('02','04') THEN 1 ELSE 0 END AS [Closed referrals - treatment complete / further treatment not appropriate],
	CASE WHEN s.ReferRejectionDate IS NULL AND s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.ReferClosReason IN ('01','08') THEN 1 ELSE 0 END AS [Closed referrals - admitted / referred elsewhere],
	CASE WHEN s.ReferRejectionDate IS NULL AND s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.ReferClosReason IN ('03','07') THEN 1 ELSE 0 END AS [Closed referrals - person moved / requested discharge],
	CASE WHEN s.ReferRejectionDate IS NULL AND s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.ReferClosReason IN ('05','09') THEN 1 ELSE 0 END AS [Closed referrals - DNA / refused to be seen],
	CASE WHEN s.ReferRejectionDate IS NULL AND s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND (s.ReferClosReason NOT IN ('01','02','03','04','05','07','08','09') OR s.ReferClosReason IS NULL) THEN 1 ELSE 0 END AS [Closed referrals - other reason / unknown],

	-- get referral length for referrals closed in month, inc categories
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate THEN DATEDIFF(dd,s.ReferralRequestReceivedDate,s.ServDischDate) END AS [Referral length],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.ServDischDate) BETWEEN 0 and 6 THEN 1 ELSE 0 
		END AS [Referral length - less than one week],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.ServDischDate) BETWEEN 7 and 13 THEN 1 ELSE 0 
		END AS [Referral length - one to two weeks],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.ServDischDate) BETWEEN 14 and 27 THEN 1 ELSE 0 
		END AS [Referral length - two to four weeks],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.ServDischDate) BETWEEN 28 and 182 THEN 1 ELSE 0 
		END AS [Referral length - one to six months],
	CASE WHEN s.ServDischDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND DATEDIFF(dd,s.ReferralRequestReceivedDate,s.ServDischDate) > 182 THEN 1 ELSE 0 
		END AS [Referral length - six months and over],

	-- get referral not accepted measures, inc duration
	CASE WHEN s.ReferRejectionDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [Referrals not accepted],
	CASE WHEN s.ReferRejectionDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.ReferRejectReason = 02 THEN 1 ELSE 0 END AS [Referrals not accepted - alternative service required],
	CASE WHEN s.ReferRejectionDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.ReferRejectReason = 01 THEN 1 ELSE 0 END AS [Referrals not accepted - duplicate],
	CASE WHEN s.ReferRejectionDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND s.ReferRejectReason = 03 THEN 1 ELSE 0 END AS [Referrals not accepted - incomplete],
	CASE WHEN s.ReferRejectionDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate AND (s.ReferRejectReason NOT IN (01,02,03) OR s.ReferRejectReason IS NULL) THEN 1 ELSE 0 
		END AS [Referrals not accepted - missing / invalid],
	CASE WHEN s.ReferRejectionDate BETWEEN s.ReportingPeriodStartDate AND s.ReportingPeriodEndDate THEN DATEDIFF(dd,s.ReferralRequestReceivedDate,s.ReferRejectionDate) END AS [Referrals not accepted length],

	-- get days since last contact measures, inc categories, limited to open referrals at month end -- remove referral request received date
	CASE WHEN s.ServDischDate IS NULL THEN DATEDIFF(dd,s.Der_LastContact,s.ReportingPeriodEndDate) END AS [Time since last contact],
	CASE WHEN s.ServDischDate IS NULL AND DATEDIFF(dd,s.Der_LastContact,s.ReportingPeriodEndDate) BETWEEN 0 and 6 THEN 1 ELSE 0 END AS [Time since last contact - less than one week],
	CASE WHEN s.ServDischDate IS NULL AND DATEDIFF(dd,s.Der_LastContact,s.ReportingPeriodEndDate) BETWEEN 7 and 13 THEN 1 ELSE 0 END AS [Time since last contact - one to two weeks],
	CASE WHEN s.ServDischDate IS NULL AND DATEDIFF(dd,s.Der_LastContact,s.ReportingPeriodEndDate) BETWEEN 14 and 27 THEN 1 ELSE 0 END AS [Time since last contact - two to four weeks],
	CASE WHEN s.ServDischDate IS NULL AND DATEDIFF(dd,s.Der_LastContact,s.ReportingPeriodEndDate) >27 THEN 1 ELSE 0 END AS [Time since last contact - four weeks or more],
	
	-- get days since last F2F contact measures, inc categories, limited to open referrals at month end -- remove referral request received date
	CASE WHEN s.ServDischDate IS NULL THEN DATEDIFF(dd,s.Der_LastContact,s.ReportingPeriodEndDate) END AS [Time since last face to face contact],
	CASE WHEN s.ServDischDate IS NULL AND DATEDIFF(dd,s.Der_LastContact,s.ReportingPeriodEndDate) BETWEEN 0 and 6 THEN 1 ELSE 0 
		END AS [Time since last face to face contact - less than one week],
	CASE WHEN s.ServDischDate IS NULL AND DATEDIFF(dd,s.Der_LastContact,s.ReportingPeriodEndDate) BETWEEN 7 and 13 THEN 1 ELSE 0 
		END AS [Time since last face to face contact - one to two weeks],
	CASE WHEN s.ServDischDate IS NULL AND DATEDIFF(dd,s.Der_LastContact,s.ReportingPeriodEndDate) BETWEEN 14 and 27 THEN 1 ELSE 0 
		END AS [Time since last face to face contact - two to four weeks],
	CASE WHEN s.ServDischDate IS NULL AND DATEDIFF(dd,s.Der_LastContact,s.ReportingPeriodEndDate) >27 THEN 1 ELSE 0 
		END AS [Time since last face to face contact - four weeks or more],

	-- get misc other measures (inpatient, in month activity, outcomes)
	s.Der_InMonthContacts AS [Attended contacts],
	s.Der_InMonthDNAContacts AS [DNA'd contacts],
	s.Der_InMonthCancelledContacts AS [Cancelled contacts],
	s.Der_InMonthIndirectContacts AS [Indirect contacts],
	s.Der_InMonthInvalidContacts AS [Unknown / Invalid attendance code],
	s.Der_Admissions AS [Admissions],
	s.Der_Discharges AS [Discharges],
	s.Der_WrdMoves AS [Finished ward stays],
	s.Der_DistanceHome AS [Distance to home],
	s.Der_LOSHosp AS [Length of stay - hospital spell],
	s.Der_LOSWrd AS [Length of stay - ward stay],
	s.Der_OBDs AS [Occupied bed days],
	CAST(LEFT(s.Der_HoNOS8EDScore,1) AS int) AS [Initial HoNOS eating issues scale score],
	CAST(LEFT(s.Der_CurrentView20Score,1) AS int) AS [Initial current view eating issues scale score],
	s.EDEQ14to16 AS [EDEQ - Adolescent],
	s.EDEQ AS [EDEQ]
 
INTO #Master

FROM #Subs s

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_Deprivation_By_LSOA] l ON s.LSOA2011 = l.LSOA_Code AND l.Effective_Snapshot_Date = '2019-12-31'

LEFT JOIN [NHSE_UKHF].[Data_Dictionary].[vw_Ethnic_Category_Code_SCD] e ON s.EthnicCategory = e.[Main_Code_Text] COLLATE DATABASE_DEFAULT AND e.Is_Latest = 1

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_DataDic_ZZZ_PersonGender] g ON s.Gender = g.Person_Gender_Code

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.tbl_Ref_Other_ComCodeChanges cc ON s.OrgIDCCGRes = cc.Org_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies p ON s.OrgIDProv = p.Organisation_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies c ON COALESCE(cc.New_Code,s.OrgIDCCGRes) = c.Organisation_Code

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#AggMainDash') IS NOT NULL
DROP TABLE #AggMainDash

SELECT
	m.ReportingPeriodEndDate,
	m.OrgIDProv,
	m.[Provider name],
	m.CCGCode,
	m.[CCG Name],
	m.STP_Code,
	m.[STP name],
	m.Region_Code,
	m.[Region name],
	m.[Age category],
	m.[Referral major category] AS [Major Category],
	m.[Community referral category] AS [Category],
	
	SUM([First contact]) AS [First contact],
	SUM([Time to first contact]) AS [Time to first contact],
	SUM([Time to first contact - less than one week]) AS [Time to first contact - less than one week],
	SUM([Time to first contact - one to two weeks]) AS [Time to first contact - one to two weeks],
	SUM([Time to first contact - two to four weeks]) AS [Time to first contact - two to four weeks],
	SUM([Time to first contact - one to six months]) AS [Time to first contact - one to six months],
	SUM([Time to first contact - six months and over]) AS [Time to first contact - six months and over],

	SUM([First contact duration]) AS [First contact duration],
	SUM([First contact duration - no time recorded]) AS [First contact duration - no time recorded],
	SUM([First contact duration - less than 15 mins]) AS [First contact duration - less than 15 mins],	
	SUM([First contact duration - 15 to 30 mins]) AS [First contact duration - 15 to 30 mins],	
	SUM([First contact duration - 30 mins to an hour]) AS [First contact duration - 30 mins to an hour],	
	SUM([First contact duration - over an hour]) AS [First contact duration - over an hour],	

	SUM([Second contact]) AS [Second contact],
	SUM([Time to second contact]) AS [Time to second contact],
	SUM([Time to second contact - less than one week]) AS [Time to second contact - less than one week],
	SUM([Time to second contact - one to two weeks]) AS [Time to second contact - one to two weeks],
	SUM([Time to second contact - two to four weeks]) AS [Time to second contact - two to four weeks],
	SUM([Time to second contact - one to six months]) AS [Time to second contact - one to six months],
	SUM([Time to second contact - six months and over]) AS [Time to second contact - six months and over],

	SUM([Second contact duration]) AS [Second contact duration],
	SUM([Second contact duration - no time recorded]) AS [Second contact duration - no time recorded],
	SUM([Second contact duration - less than 15 mins]) AS [Second contact duration - less than 15 mins],	
	SUM([Second contact duration - 15 to 30 mins]) AS [Second contact duration - 15 to 30 mins],	
	SUM([Second contact duration - 30 mins to an hour]) AS [Second contact duration - 30 mins to an hour],	
	SUM([Second contact duration - over an hour]) AS [Second contact duration - over an hour],	
	
	SUM([Open referrals]) AS [Open referrals],
	SUM(Caseload) AS [Caseload],
	SUM([New referrals]) AS [New referrals],
	SUM([Closed referrals]) AS [Closed referrals],
	SUM([Closed referrals - treatment complete / further treatment not appropriate]) AS [Closed referrals - treatment complete / further treatment not appropriate],
	SUM([Closed referrals - admitted / referred elsewhere]) AS [Closed referrals - admitted / referred elsewhere],
	SUM([Closed referrals - person moved / requested discharge]) AS [Closed referrals - person moved / requested discharge],
	SUM([Closed referrals - DNA / refused to be seen]) AS [Closed referrals - DNA / refused to be seen],
	SUM([Closed referrals - other reason / unknown]) AS [Closed referrals - other reason / unknown],
	
	SUM([Referral length]) AS [Referral length],
	SUM([Referral length - less than one week]) AS [Referral length - less than one week],
	SUM([Referral length - one to two weeks]) AS [Referral length - one to two weeks],
	SUM([Referral length - two to four weeks]) AS [Referral length - two to four weeks],
	SUM([Referral length - one to six months]) AS [Referral length - one to six months],
	SUM([Referral length - six months and over]) AS [Referral length - six months and over],

	SUM([Referrals not accepted]) AS [Referrals not accepted],
	SUM([Referrals not accepted - duplicate]) AS [Referrals not accepted - duplicate],
	SUM([Referrals not accepted - alternative service required]) AS [Referrals not accepted - alternative service required],
	SUM([Referrals not accepted - incomplete]) AS [Referrals not accepted - incomplete],
	SUM([Referrals not accepted - missing / invalid]) AS [Referrals not accepted - missing / invalid],
	SUM([Referrals not accepted length]) AS [Referrals not accepted length],

	SUM([Time since last contact]) AS [Time since last contact],
	SUM([Time since last contact - less than one week]) AS [Time since last contact - less than one week],
	SUM([Time since last contact - one to two weeks]) AS [Time since last contact - one to two weeks],
	SUM([Time since last contact - two to four weeks]) AS [Time since last contact - two to four weeks],
	SUM([Time since last contact - four weeks or more]) AS [Time since last contact - four weeks or more],

	SUM([Time since last face to face contact]) AS [Time since last face to face contact],
	SUM([Time since last face to face contact - less than one week]) AS [Time since last face to face contact - less than one week],
	SUM([Time since last face to face contact - one to two weeks]) AS [Time since last face to face contact - one to two weeks],
	SUM([Time since last face to face contact - two to four weeks]) AS [Time since last face to face contact - two to four weeks],
	SUM([Time since last face to face contact - four weeks or more]) AS [Time since last face to face contact - four weeks or more],

	SUM([Attended contacts]) AS [Attended contacts],
	SUM([DNA'd contacts]) AS [DNA'd contacts],
	SUM([Cancelled contacts]) AS [Cancelled contacts],
	SUM([Indirect contacts]) AS [Indirect contacts],
	SUM([Unknown / Invalid attendance code]) AS [Unknown / Invalid attendance code],
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
	SUM([First contact]) AS [First contact2],
	SUM([Second contact]) AS [Second contact2],
	SUM([Closed referrals]) AS [Closed referrals2],
	SUM([Referrals not accepted]) AS [Referrals not accepted2],
	SUM([Admissions]) AS [Admissions2],
	SUM([Discharges]) AS [Discharges2],
	SUM([Finished ward stays]) AS [Finished ward stays2],
	SUM([Caseload]) AS [Caseload2],
	COUNT([Initial HoNOS eating issues scale score]) AS [Initial HoNOS eating issues scale score2],
	COUNT([Initial current view eating issues scale score]) AS [Initial current view eating issues scale score2]

INTO #AggMainDash

FROM #Master m

GROUP BY m.ReportingPeriodStartDate, m.ReportingPeriodEndDate, m.OrgIDProv, m.[Provider name], m.CCGCode, m.[CCG Name], m.STP_Code, m.[STP name], m.Region_Code, m.[Region name], m.[Age category], m.[Referral major category], 
	m.[Community referral category]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UNPIVOT AND CREATE EXTRACT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

SELECT
	ReportingPeriodEndDate,
	OrgIDProv,
	[Provider name],
	CCGCode,
	[CCG Name],
	STP_Code,
	[STP name],
	Region_Code,
	[Region name],
	[Age category],
	CAST('Activity' AS varchar(255)) AS Breakdown,
	CAST([Major Category] AS varchar(255)) AS [Major Category],
	CAST(Category AS varchar(255)) AS Category,
	CAST(MeasureName AS varchar(255)) AS MeasureName,
	MeasureValue,
	CASE
		WHEN [MeasureName] IN ('Time to first contact','First contact duration')  THEN [First contact2]
		WHEN [MeasureName] IN ('Time to second contact','Second contact duration')  THEN [Second contact2]
		WHEN [MeasureName] = 'Referral length' THEN [Closed referrals2]
		WHEN [MeasureName] IN ('Time since last contact','Time since last face to face contact')  THEN [Caseload2]
		WHEN [MeasureName] = 'Referrals not accepted length' THEN [Referrals not accepted2]
		WHEN [MeasureName] = 'Distance to home' THEN [Admissions2]
		WHEN [MeasureName] = 'Length of stay - hospital spell' THEN [Discharges2]
		WHEN [MeasureName] = 'Length of stay - ward stay' THEN [Finished ward stays2]
		WHEN [MeasureName] = 'Initial HoNOS eating issues scale score' THEN [Initial HoNOS eating issues scale score2]
		WHEN [MeasureName] = 'Initial current view eating issues scale score' THEN [Initial current view eating issues scale score2]
	END AS Denominator,
	CASE 
		WHEN [MeasureName] = 'Distance to home' THEN [MAX Distance to home]
		WHEN [MeasureName] = 'Initial HoNOS eating issues scale score' THEN [MAX Initial HoNOS eating issues scale score]
		WHEN [MeasureName] = 'Initial current view eating issues scale score' THEN [MAX Initial current view eating issues scale score]
	END AS [MAXValue]

INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

FROM #AggMainDash 

UNPIVOT (MeasureValue FOR MeasureName IN 
	([First contact],[Time to first contact],[Time to first contact - less than one week],[Time to first contact - one to two weeks],[Time to first contact - two to four weeks],[Time to first contact - one to six months],
	[Time to first contact - six months and over],[First contact duration],[First contact duration - no time recorded],[First contact duration - less than 15 mins],[First contact duration - 15 to 30 mins],
	[First contact duration - 30 mins to an hour],[First contact duration - over an hour],[Second contact],[Time to second contact],[Time to second contact - less than one week],[Time to second contact - one to two weeks],
	[Time to second contact - two to four weeks],[Time to second contact - one to six months],[Time to second contact - six months and over],[Second contact duration],[Second contact duration - no time recorded],
	[Second contact duration - less than 15 mins],[Second contact duration - 15 to 30 mins],[Second contact duration - 30 mins to an hour],[Second contact duration - over an hour],[Caseload],[New referrals],[Closed referrals],[Open referrals],
	[Closed referrals - treatment complete / further treatment not appropriate],[Closed referrals - admitted / referred elsewhere],[Closed referrals - person moved / requested discharge],
	[Closed referrals - DNA / refused to be seen],[Closed referrals - other reason / unknown],[Referral length],[Referral length - less than one week],[Referral length - one to two weeks],[Referral length - two to four weeks],
	[Referral length - one to six months],[Referral length - six months and over],[Referrals not accepted],[Referrals not accepted - duplicate],[Referrals not accepted - alternative service required],
	[Referrals not accepted - incomplete],[Referrals not accepted - missing / invalid],[Referrals not accepted length],[Time since last contact],[Time since last contact - less than one week],
	[Time since last contact - one to two weeks],[Time since last contact - two to four weeks],[Time since last contact - four weeks or more],[Time since last face to face contact],
	[Time since last face to face contact - less than one week],[Time since last face to face contact - one to two weeks],[Time since last face to face contact - two to four weeks],
	[Time since last face to face contact - four weeks or more],[Attended contacts],[DNA'd contacts],[Cancelled contacts],[Indirect contacts],[Unknown / Invalid attendance code],[Admissions],[Discharges],
	[Finished ward stays],[Distance to home],[Length of stay - hospital spell],[Length of stay - ward stay],[Occupied bed days],[Initial HoNOS eating issues scale score],[Initial current view eating issues scale score],
	[EDEQ - Adolescent],[EDEQ])) u

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

SELECT
	m.ReportingPeriodEndDate,
	m.OrgIDProv,
	m.[Provider name],
	m.CCGCode,
	m.[CCG Name],
	m.STP_Code,
	m.[STP name],
	m.Region_Code,
	m.[Region name],
	[Age category],
	'Interventions' AS [Breakdown],
	'SNoMED-CT' AS [Major Category],
	i.Der_SNoMEDProcTerm  AS [Category],
	'Number of interventions recorded' AS MeasureName,
	COUNT(i.[Der_InterventionUniqID]) AS MeasureValue,
	NULL AS Denominator,
	NULL AS MAXValue

FROM NHSE_Sandbox_MentalHealth.dbo.PreProc_Interventions i

INNER JOIN #Master m ON i.RecordNumber = m.RecordNumber AND i.UniqServReqID = m.UniqServReqID

WHERE i.Der_SNoMEDProcTerm IS NOT NULL

GROUP BY m.ReportingPeriodEndDate, m.OrgIDProv,	m.[Provider name], m.CCGCode, m.[CCG Name], m.STP_Code,	m.[STP name], m.Region_Code, m.[Region name], [Age category], i.Der_SNoMEDProcTerm

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

SELECT
	m.ReportingPeriodEndDate,
	m.OrgIDProv,
	m.[Provider name],
	m.CCGCode,
	m.[CCG Name],
	m.STP_Code,
	m.[STP name],
	m.Region_Code,
	m.[Region name],
	[Age category],
	'Ref source' AS [Breakdown],
	COALESCE(r.Category, 'Missing / invalid') AS [Major Category],
	COALESCE(r.Main_Description, 'Missing / invalid') AS [Category],
	'Caseload by referral source' AS MeasureName,
	SUM([New referrals]) AS MeasureValue,
	NULL AS Denominator,
	NULL AS MAXValue

FROM #Master m

LEFT JOIN [NHSE_UKHF].[Data_Dictionary].[vw_Source_Of_Referral_For_Mental_Health_SCD] r ON m.SourceOfReferralMH = r.Main_Code_Text COLLATE DATABASE_DEFAULT 
	AND (r.Effective_To IS NULL OR r.Effective_To >= '2019-04-01') AND (r.Valid_To IS NULL OR r.Valid_To >= '2019-04-01') AND Is_Latest = 1

WHERE m.[Referral major category] = 'Community'

GROUP BY m.ReportingPeriodEndDate, m.OrgIDProv,	m.[Provider name], m.CCGCode, m.[CCG Name], m.STP_Code,	m.[STP name], m.Region_Code, m.[Region name], [Age category], r.Category, r.Main_Description

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

SELECT
	m.ReportingPeriodEndDate,
	NULL AS OrgIDProv,
	NULL AS [Provider name],
	NULL AS CCGCode,
	NULL AS [CCG Name],
	NULL AS STP_Code,
	NULL AS [STP name],
	m.Region_Code,
	m.[Region name],
	[Age category],
	'Demographics' AS [Breakdown],
	'Ethnicity' AS [Major Category],
	m.ethnicity AS [Category],
	'Caseload' AS MeasureName,
	SUM(Caseload) AS MeasureValue,
	NULL AS Denominator,
	NULL AS MAXValue

FROM #Master m

GROUP BY m.ReportingPeriodEndDate, m.Region_Code, m.[Region name], [Age category], m.ethnicity

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

SELECT
	m.ReportingPeriodEndDate,
	NULL AS OrgIDProv,
	NULL AS [Provider name],
	NULL AS CCGCode,
	NULL AS [CCG Name],
	NULL AS STP_Code,
	NULL AS [STP name],
	m.Region_Code,
	m.[Region name],
	m.[Age category],
	'Demographics' AS [Breakdown],
	'Age Category' AS [Major Category],
	m.[Age category] AS [Category],
	'Caseload' AS MeasureName,
	SUM(Caseload) AS MeasureValue,
	NULL AS Denominator,
	NULL AS MAXValue

FROM #Master m

GROUP BY m.ReportingPeriodEndDate, m.Region_Code, m.[Region name], [Age category]

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

SELECT
	m.ReportingPeriodEndDate,
	NULL AS OrgIDProv,
	NULL AS [Provider name],
	NULL AS CCGCode,
	NULL AS [CCG Name],
	NULL AS STP_Code,
	NULL AS [STP name],
	m.Region_Code,
	m.[Region name],
	m.[Age category],
	'Demographics' AS [Breakdown],
	'Gender' AS [Major Category],
	m.Gender AS [Category],
	'Caseload' AS MeasureName,
	SUM(Caseload) AS MeasureValue,
	NULL AS Denominator,
	NULL AS MAXValue

FROM #Master m

GROUP BY m.ReportingPeriodEndDate, m.Region_Code, m.[Region name], [Age category], Gender

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisorders]

SELECT
	m.ReportingPeriodEndDate,
	NULL AS OrgIDProv,
	NULL AS [Provider name],
	NULL AS CCGCode,
	NULL AS [CCG Name],
	NULL AS STP_Code,
	NULL AS [STP name],
	m.Region_Code,
	m.[Region name],
	m.[Age category],
	'Demographics' AS [Breakdown],
	'Deprivation' AS [Major Category],
	m.IMD_Decile AS [Category],
	'Caseload' AS MeasureName,
	SUM(Caseload) AS MeasureValue,
	NULL AS Denominator,
	NULL AS MAXValue

FROM #Master m

GROUP BY m.ReportingPeriodEndDate, m.Region_Code, m.[Region name], [Age category], IMD_Decile

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET AWT DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#AWTTemp') IS NOT NULL
DROP TABLE #AWTTemp

SELECT
	s.REPORTING_PERIOD_END AS ReportingPeriodEnd,
	'MHSDS' AS DataSource,
	CASE WHEN s.BREAKDOWN = 'Provider' THEN s.BREAKDOWN ELSE 'CCG' END AS OrgType,
	COALESCE(cc.New_Code,s.PRIMARY_LEVEL) AS [Organisation code],
	SUM(CASE WHEN s.MEASURE_ID = 'ED86' THEN s.MEASURE_VALUE END) AS [Urgent referrals entering treatment],
	SUM(CASE WHEN s.MEASURE_ID = 'ED86a' THEN s.MEASURE_VALUE END) AS [Urgent referrals entering treatment within one week],
	SUM(CASE WHEN s.MEASURE_ID = 'ED87' THEN s.MEASURE_VALUE END) AS [Routine referrals entering treatment],
	SUM(CASE WHEN s.MEASURE_ID IN ('ED87a','ED87b') THEN s.MEASURE_VALUE END) AS [Routine referrals entering treatment within four weeks]

INTO #AWTTemp

FROM [NHSE_Sandbox_MentalHealth].[dbo].[Staging_CYPED] s

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.tbl_Ref_Other_ComCodeChanges cc ON s.PRIMARY_LEVEL = cc.Org_Code

WHERE BREAKDOWN IN ('Provider', 'CCG - GP Practice or Residence') AND MEASURE_ID IN ('ED86', 'ED86a','ED87','ED87a','ED87b') AND s.PRIMARY_LEVEL IS NOT NULL

GROUP BY s.REPORTING_PERIOD_END, s.BREAKDOWN, COALESCE(cc.New_Code,s.PRIMARY_LEVEL)

INSERT INTO #AWTTemp

SELECT
	s.Effective_Snapshot_Date AS ReportingPeriodEnd,
	'SDCS' AS DataSource,
	'Provider' AS OrgType,
	s.Organisation_Code AS [Organisation code],
	SUM(CASE WHEN s.Urgent_Routine = 'Urgent' THEN s.No_Of_Patients END ) AS [Urgent referrals entering treatment],
	SUM(CASE WHEN s.Urgent_Routine = 'Urgent' AND s.Weeks_Since_Referral = '>0-1 week' THEN No_Of_Patients END) AS [Urgent referrals entering treatment within one week],
	SUM(CASE WHEN s.Urgent_Routine = 'Routine' THEN s.No_Of_Patients END ) AS [Routine referrals entering treatment],
	SUM(CASE WHEN s.Urgent_Routine = 'Routine' AND s.Weeks_Since_Referral IN ('>0-1 week', '>1-4 weeks') THEN No_Of_Patients END) AS [Routine referrals entering treatment within four weeks]

FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Prov1] s

GROUP BY s.Effective_Snapshot_Date, s.Organisation_Code

INSERT INTO #AWTTemp

SELECT
	s.Effective_Snapshot_Date AS ReportingPeriodEnd,
	'SDCS' AS DataSource,
	'CCG' AS OrgType,
	COALESCE(cc.New_Code COLLATE DATABASE_DEFAULT,s.Organisation_Code COLLATE DATABASE_DEFAULT) AS [Organisation code],
	SUM(CASE WHEN s.Urgent_Routine = 'Urgent' THEN s.No_Of_Patients END ) AS [Urgent referrals entering treatment],
	SUM(CASE WHEN s.Urgent_Routine = 'Urgent' AND s.Weeks_Since_Referral = '>0-1 week' THEN No_Of_Patients END) AS [Urgent referrals entering treatment within one week],
	SUM(CASE WHEN s.Urgent_Routine = 'Routine' THEN s.No_Of_Patients END ) AS [Routine referrals entering treatment],
	SUM(CASE WHEN s.Urgent_Routine = 'Routine' AND s.Weeks_Since_Referral IN ('>0-1 week', '>1-4 weeks') THEN No_Of_Patients END) AS [Routine referrals entering treatment within four weeks]

FROM [NHSE_UKHF].[Mental_Health].[vw_CYP_With_Eating_Disorder_Waiting_Times_Comm1] s

LEFT JOIN NHSE_Sandbox_MentalHealth.dbo.tbl_Ref_Other_ComCodeChanges cc ON s.Organisation_Code = cc.Org_Code COLLATE DATABASE_DEFAULT

GROUP BY s.Effective_Snapshot_Date, COALESCE(cc.New_Code COLLATE DATABASE_DEFAULT,s.Organisation_Code COLLATE DATABASE_DEFAULT)

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET OUTPUT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisordersAWT]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisordersAWT]

-- provider

SELECT
	a.ReportingPeriodEnd,
	a.DataSource,
	a.OrgType,
	a.[Organisation code],
	p.Organisation_Name AS [Organisation name],
	[Urgent referrals entering treatment],
	[Urgent referrals entering treatment within one week],
	[Routine referrals entering treatment],
	[Routine referrals entering treatment within four weeks]

INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisordersAWT]
	   
FROM #AWTTemp a

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies p ON a.[Organisation code] = p.Organisation_Code

WHERE OrgType = 'Provider'

-- CCG

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisordersAWT]

SELECT
	a.ReportingPeriodEnd,
	a.DataSource,
	a.OrgType,
	a.[Organisation code],
	COALESCE(c.Organisation_Name,'Missing / Invalid') AS [Organisation name],
	[Urgent referrals entering treatment],
	[Urgent referrals entering treatment within one week],
	[Routine referrals entering treatment],
	[Routine referrals entering treatment within four weeks]
	   
FROM #AWTTemp a

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies c ON a.[Organisation code] = c.Organisation_Code

WHERE OrgType = 'CCG'

-- STP

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisordersAWT]

SELECT
	a.ReportingPeriodEnd,
	a.DataSource,
	'STP' AS OrgType,
	c.STP_Code AS [Organisation code],
	COALESCE(c.STP_Name,'Missing / Invalid') AS [Organisation name],
	SUM([Urgent referrals entering treatment]) AS [Urgent referrals entering treatment],
	SUM([Urgent referrals entering treatment within one week]) AS [Urgent referrals entering treatment within one week],
	SUM([Routine referrals entering treatment]) AS [Routine referrals entering treatment],
	SUM([Routine referrals entering treatment within four weeks]) AS [Routine referrals entering treatment within four weeks]
	   
FROM #AWTTemp a

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies c ON a.[Organisation code] = c.Organisation_Code

WHERE OrgType = 'CCG'

GROUP BY a.ReportingPeriodEnd, a.DataSource, c.STP_Code, c.STP_Name

-- Region

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisordersAWT]

SELECT
	a.ReportingPeriodEnd,
	a.DataSource,
	'Region' AS OrgType,
	c.Region_Code AS [Organisation code],
	COALESCE(c.Region_Name,'Missing / Invalid') AS [Organisation name],
	SUM([Urgent referrals entering treatment]) AS [Urgent referrals entering treatment],
	SUM([Urgent referrals entering treatment within one week]) AS [Urgent referrals entering treatment within one week],
	SUM([Routine referrals entering treatment]) AS [Routine referrals entering treatment],
	SUM([Routine referrals entering treatment within four weeks]) AS [Routine referrals entering treatment within four weeks]
	   
FROM #AWTTemp a

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies c ON a.[Organisation code] = c.Organisation_Code

WHERE OrgType = 'CCG'

GROUP BY a.ReportingPeriodEnd, a.DataSource, c.Region_Code, c.Region_Name

-- England

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_EatingDisordersAWT]

SELECT
	a.ReportingPeriodEnd,
	a.DataSource,
	'England' AS OrgType,
	'ENG' AS [Organisation code],
	'England' AS [Organisation name],
	SUM([Urgent referrals entering treatment]) AS [Urgent referrals entering treatment],
	SUM([Urgent referrals entering treatment within one week]) AS [Urgent referrals entering treatment within one week],
	SUM([Routine referrals entering treatment]) AS [Routine referrals entering treatment],
	SUM([Routine referrals entering treatment within four weeks]) AS [Routine referrals entering treatment within four weeks]
	   
FROM #AWTTemp a

WHERE OrgType = 'Provider'

GROUP BY a.ReportingPeriodEnd, a.DataSource