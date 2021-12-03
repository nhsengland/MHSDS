/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IPS DASHBOARD

CREATED BY CARL MONEY 10/10/2019

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--SET VARIABLES

DECLARE @ENDRP INT
DECLARE @STARTRP INT
DECLARE @FYSTART INT

SET @EndRP = (SELECT UniqMonthID
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_MostRecentFlag = 'p')

SET @STARTRP = 1417 -- Apr 18

SET @FYSTART = (SELECT MAX(UniqMonthID)
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_FYStart = 'Y')

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ALL REFERRALS TO IPS SERVICES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Ref') IS NOT NULL
DROP TABLE #Ref

SELECT
	h.ReportingPeriodEndDate AS ReportingPeriodEnd,
	h.ReportingPeriodStartDate AS ReportingPeriodStart,
	r.UniqMonthID,
	r.Person_ID,
	r.UniqServReqID,
	r.OrgIDProv,
	o.Organisation_Name AS ProvName,
	r.OrgIDCCGRes,
	map.Organisation_Name AS CCGName,
	map.STP_Code,
	map.STP_Name,
	map.Region_Code,
	map.Region_Name,
	r.ReferralRequestReceivedDate,
	r.ServDischDate,
	r.AgeServReferRecDate,
	r.Gender,
	r.SourceOfReferralMH,
	r.EthnicCategory,
	e.EmployStatus,
	e.WeekHoursWorked,
	a.Der_FacetoFaceContactOrder AS AccessFlag,
	a.Contacts
	
INTO #Ref

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Referral] r 

LEFT JOIN 
(SELECT
	e.RecordNumber,
	e.EmployStatus,
	e.WeekHoursWorked

FROM [NHSE_MHSDS].[dbo].[MHS004EmpStatus] e
WHERE e.Der_Use_Submission_Flag = 'Y' AND e.UniqMonthID BETWEEN @STARTRP AND @ENDRP-1

UNION ALL

SELECT
	e.RecordNumber,
	e.EmployStatus,
	e.WeekHoursWorked

FROM [NHSE_MH_PrePublication].[dbo].[V4_MHS004EmpStatus] e
WHERE e.Der_Use_Submission_Flag = 'Y' AND e.UniqMonthID = @ENDRP) e ON r.RecordNumber = e.RecordNumber

INNER JOIN [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] h ON r.UniqMonthID = h.UniqMonthID

LEFT JOIN 
(SELECT
	a.RecordNumber,
	a.UniqServReqID,
	SUM(CASE WHEN a.Der_FacetoFaceContactOrder IS NOT NULL THEN 1 ELSE 0 END) AS Contacts,
	SUM(CASE WHEN a.Der_FacetoFaceContactOrder = 1 THEN 1 ELSE 0 END) AS Der_FacetoFaceContactOrder

FROM [NHSE_Sandbox_MentalHealth].dbo.PreProc_Activity a

GROUP BY a.RecordNumber, a.UniqServReqID) a ON r.RecordNumber = a.RecordNumber AND r.UniqServReqID = a.UniqServReqID

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies o ON r.OrgIDProv = o.Organisation_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies map ON r.OrgIDCCGRes = map.Organisation_Code

WHERE r.ReferralRequestReceivedDate >= '2016-01-01' AND r.UniqMonthID BETWEEN @STARTRP AND @ENDRP AND r.ServTeamTypeRefToMH = 'D05'

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
BUILD MASTER TABLE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Master') IS NOT NULL
DROP TABLE #Master

SELECT
	r.ReportingPeriodEnd,
	r.ReportingPeriodStart,
	r.UniqMonthID,
	r.Person_ID,
	r.UniqServReqID,
	r.OrgIDProv,
	r.ProvName,
	r.OrgIDCCGRes,
	r.CCGName,
	r.STP_Code,
	r.STP_Name,
	r.Region_Code,
	r.Region_Name,
	CASE WHEN r.ServDischDate IS NULL THEN 1 ELSE 0 END AS Caseload,
	CASE WHEN r.ReferralRequestReceivedDate BETWEEN r.ReportingPeriodStart AND r.ReportingPeriodEnd THEN 1 ELSE 0 END AS NewReferrals,
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStart AND r.ReportingPeriodEnd THEN 1 ELSE 0 END AS ClosedReferrals,
	CASE WHEN r.ServDischDate IS NULL AND r.AgeServReferRecDate BETWEEN 16 AND 35 THEN 1 ELSE 0 END AS Caseload16to35,
	CASE WHEN r.ServDischDate IS NULL AND r.AgeServReferRecDate BETWEEN 36 AND 64 THEN 1 ELSE 0 END AS Caseload36to64,
	CASE WHEN r.ServDischDate IS NULL AND r.Gender = '1' THEN 1 ELSE 0 END AS CaseloadMale,
	CASE WHEN r.ServDischDate IS NULL AND r.SourceOfReferralMH IN ('A1','A2','A3','A4') THEN 1 ELSE 0 END AS ReferredFromPrimaryHealthCare,
	CASE WHEN r.ServDischDate IS NULL AND r.SourceOfReferralMH IN ('B1','B2') THEN 1 ELSE 0 END AS SelfReferral,
	CASE WHEN r.ServDischDate IS NULL AND r.SourceOfReferralMH IN ('I1','I2','P1') THEN 1 ELSE 0 END AS ReferredFromSecondaryMentalHealthCare,
	CASE WHEN r.ServDischDate IS NULL AND r.EthnicCategory = 'A' THEN 1 ELSE 0 END AS CaseloadWhiteBritish,
	CASE WHEN r.ServDischDate IS NULL AND r.EmployStatus = '01' THEN 1 ELSE 0 END AS Employed,
	CASE WHEN r.ServDischDate IS NULL AND r.EmployStatus = '01' AND  r.ReferralRequestReceivedDate BETWEEN r.ReportingPeriodStart AND r.ReportingPeriodEnd THEN 1 ELSE 0 END AS EmployedAtReferral,
	r.AccessFlag,
	r.Contacts,
	CASE WHEN r.UniqMonthID >= @FYSTART THEN r.AccessFlag END AS YTDAccessFlag

INTO #Master

FROM #Ref r

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
LINK ALL ORGS TO ALL PERIODS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Dates') IS NOT NULL
DROP TABLE #Dates

SELECT DISTINCT r.UniqMonthID INTO #Dates FROM #Ref r WHERE r.UniqMonthID >= @FYSTART

IF OBJECT_ID ('tempdb..#Orgs') IS NOT NULL
DROP TABLE #Orgs

SELECT DISTINCT r.OrgIDProv, r.OrgIDCCGRes INTO #Orgs FROM #Ref r WHERE r.UniqMonthID >= @FYSTART

IF OBJECT_ID ('tempdb..#OrgDates') IS NOT NULL
DROP TABLE #OrgDates

SELECT  d.UniqMonthID, o.OrgIDProv, o.OrgIDCCGRes INTO #OrgDates FROM #Orgs o, #Dates d


/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET YTD ACCESS BY PROVIDER/CCG/STP/REGION
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#YTD') IS NOT NULL
DROP TABLE #YTD

SELECT DISTINCT
	m.UniqMonthID,
	'Provider' AS OrgType,
	m.OrgIDProv AS Orgcode,
	SUM(m.YTDAccessFlag) OVER (PARTITION BY m.OrgIDProv ORDER BY m.UniqMonthID) AS YTDAccess,
	SUM(m.NewReferrals) OVER (PARTITION BY m.OrgIDProv ORDER BY m.UniqMonthID) AS YTDNewReferrals

INTO #YTD

FROM #Master m

WHERE m.UniqMonthID >=@FYSTART

UNION ALL

SELECT DISTINCT
	m.UniqMonthID,
	'CCG' AS OrgType,
	m.OrgIDCCGRes AS Orgcode,
	SUM(m.YTDAccessFlag) OVER (PARTITION BY m.OrgIDCCGRes ORDER BY m.UniqMonthID) AS YTDAccess,
	SUM(m.NewReferrals) OVER (PARTITION BY m.OrgIDCCGRes ORDER BY m.UniqMonthID) AS YTDNewReferrals

FROM #Master m

WHERE m.UniqMonthID >=@FYSTART

UNION ALL

SELECT DISTINCT
	m.UniqMonthID,
	'STP' AS OrgType,
	m.STP_Code AS Orgcode,
	SUM(m.YTDAccessFlag) OVER (PARTITION BY m.STP_Code ORDER BY m.UniqMonthID) AS YTDAccess,
	SUM(m.NewReferrals) OVER (PARTITION BY m.STP_Code ORDER BY m.UniqMonthID) AS YTDNewReferrals

FROM #Master m

WHERE m.UniqMonthID >=@FYSTART

UNION ALL

SELECT DISTINCT
	m.UniqMonthID,
	'REGION' AS OrgType,
	m.Region_Code AS Orgcode,
	SUM(m.YTDAccessFlag) OVER (PARTITION BY m.Region_Code ORDER BY m.UniqMonthID) AS YTDAccess,
	SUM(m.NewReferrals) OVER (PARTITION BY m.Region_Code ORDER BY m.UniqMonthID) AS YTDNewReferrals

FROM #Master m

WHERE m.UniqMonthID >=@FYSTART

UNION ALL

SELECT DISTINCT
	m.UniqMonthID,
	'ENGLAND' AS OrgType,
	'ENG' AS Orgcode,
	SUM(m.YTDAccessFlag) OVER (ORDER BY m.UniqMonthID) AS YTDAccess,
	SUM(m.NewReferrals) OVER (ORDER BY m.UniqMonthID) AS YTDNewReferrals

FROM #Master m

WHERE m.UniqMonthID >=@FYSTART

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET UNSUPPRESSED DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Unsupp') IS NOT NULL
DROP TABLE #UnSupp

SELECT
	m.ReportingPeriodEnd,
	m.UniqMonthID,
	'PROVIDER' AS 'Organisation Type',
	m.OrgIDProv AS 'Organisation ID',
	m.ProvName AS 'Organisation Name',
	SUM(m.Caseload) AS Caseload,
	SUM(m.NewReferrals) AS NewReferrals,
	SUM(m.ClosedReferrals) AS ClosedReferrals,
	SUM(m.Caseload16to35) AS Caseload16to35,
	SUM(m.Caseload36to64) AS Caseload36to64,
	SUM(m.CaseloadMale) AS CaseloadMale,
	SUM(m.ReferredFromPrimaryHealthCare) AS ReferredFromPrimaryHealthCare,
	SUM(m.SelfReferral) AS SelfReferral,
	SUM(m.ReferredFromSecondaryMentalHealthCare) AS ReferredFromSecondaryMentalHealthCare,
	SUM(m.CaseloadWhiteBritish) AS CaseloadWhiteBritish,
	SUM(m.Employed) AS Employed,
	SUM(m.EmployedAtReferral) AS EmployedAtReferral,
	SUM(m.AccessFlag) AS MonthlyAccess,
	SUM(m.Contacts) AS Contacts

INTO #Unsupp

FROM #Master m

GROUP BY m.ReportingPeriodEnd, m.UniqMonthID, m.OrgIDProv, m.ProvName

UNION ALL

SELECT
	m.ReportingPeriodEnd,
	m.UniqMonthID,
	'CCG' AS 'Organisation Type',
	m.OrgIDCCGRes AS 'Organisation ID',
	m.CCGName AS 'Organisation Name',
	SUM(m.Caseload) AS Caseload,
	SUM(m.NewReferrals) AS NewReferrals,
	SUM(m.ClosedReferrals) AS ClosedReferrals,
	SUM(m.Caseload16to35) AS Caseload16to35,
	SUM(m.Caseload36to64) AS Caseload36to64,
	SUM(m.CaseloadMale) AS CaseloadMale,
	SUM(m.ReferredFromPrimaryHealthCare) AS ReferredFromPrimaryHealthCare,
	SUM(m.SelfReferral) AS SelfReferral,
	SUM(m.ReferredFromSecondaryMentalHealthCare) AS ReferredFromSecondaryMentalHealthCare,
	SUM(m.CaseloadWhiteBritish) AS CaseloadWhiteBritish,
	SUM(m.Employed) AS Employed,
	SUM(m.EmployedAtReferral) AS EmployedAtReferral,
	SUM(m.AccessFlag) AS MonthlyAccess,
	SUM(m.Contacts) AS Contacts

FROM #Master m

GROUP BY m.ReportingPeriodEnd, m.UniqMonthID, m.OrgIDCCGRes, m.CCGName

UNION ALL

SELECT
	m.ReportingPeriodEnd,
	m.UniqMonthID,
	'STP' AS 'Organisation Type',
	m.STP_Code AS 'Organisation ID',
	m.STP_Name AS 'Organisation Name',
	SUM(m.Caseload) AS Caseload,
	SUM(m.NewReferrals) AS NewReferrals,
	SUM(m.ClosedReferrals) AS ClosedReferrals,
	SUM(m.Caseload16to35) AS Caseload16to35,
	SUM(m.Caseload36to64) AS Caseload36to64,
	SUM(m.CaseloadMale) AS CaseloadMale,
	SUM(m.ReferredFromPrimaryHealthCare) AS ReferredFromPrimaryHealthCare,
	SUM(m.SelfReferral) AS SelfReferral,
	SUM(m.ReferredFromSecondaryMentalHealthCare) AS ReferredFromSecondaryMentalHealthCare,
	SUM(m.CaseloadWhiteBritish) AS CaseloadWhiteBritish,
	SUM(m.Employed) AS Employed,
	SUM(m.EmployedAtReferral) AS EmployedAtReferral,
	SUM(m.AccessFlag) AS MonthlyAccess,
	SUM(m.Contacts) AS Contacts

FROM #Master m

GROUP BY m.ReportingPeriodEnd, m.UniqMonthID, m.STP_Code, m.STP_Name

UNION ALL

SELECT
	m.ReportingPeriodEnd,
	m.UniqMonthID,
	'REGION' AS 'Organisation Type',
	m.Region_Code AS 'Organisation ID',
	m.Region_Name AS 'Organisation Name',
	SUM(m.Caseload) AS Caseload,
	SUM(m.NewReferrals) AS NewReferrals,
	SUM(m.ClosedReferrals) AS ClosedReferrals,
	SUM(m.Caseload16to35) AS Caseload16to35,
	SUM(m.Caseload36to64) AS Caseload36to64,
	SUM(m.CaseloadMale) AS CaseloadMale,
	SUM(m.ReferredFromPrimaryHealthCare) AS ReferredFromPrimaryHealthCare,
	SUM(m.SelfReferral) AS SelfReferral,
	SUM(m.ReferredFromSecondaryMentalHealthCare) AS ReferredFromSecondaryMentalHealthCare,
	SUM(m.CaseloadWhiteBritish) AS CaseloadWhiteBritish,
	SUM(m.Employed) AS Employed,
	SUM(m.EmployedAtReferral) AS EmployedAtReferral,
	SUM(m.AccessFlag) AS MonthlyAccess,
	SUM(m.Contacts) AS Contacts

FROM #Master m

GROUP BY m.ReportingPeriodEnd, m.UniqMonthID, m.Region_Code, m.Region_Name

UNION ALL

SELECT
	m.ReportingPeriodEnd,
	m.UniqMonthID,
	'ENGLAND' AS 'Organisation Type',
	'ENG' AS 'Organisation ID',
	'ENGLAND' AS 'Organisation Name',
	SUM(m.Caseload) AS Caseload,
	SUM(m.NewReferrals) AS NewReferrals,
	SUM(m.ClosedReferrals) AS ClosedReferrals,
	SUM(m.Caseload16to35) AS Caseload16to35,
	SUM(m.Caseload36to64) AS Caseload36to64,
	SUM(m.CaseloadMale) AS CaseloadMale,
	SUM(m.ReferredFromPrimaryHealthCare) AS ReferredFromPrimaryHealthCare,
	SUM(m.SelfReferral) AS SelfReferral,
	SUM(m.ReferredFromSecondaryMentalHealthCare) AS ReferredFromSecondaryMentalHealthCare,
	SUM(m.CaseloadWhiteBritish) AS CaseloadWhiteBritish,
	SUM(m.Employed) AS Employed,
	SUM(m.EmployedAtReferral) AS EmployedAtReferral,
	SUM(m.AccessFlag) AS MonthlyAccess,
	SUM(m.Contacts) AS Contacts

FROM #Master m

GROUP BY m.ReportingPeriodEnd, m.UniqMonthID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET QUARTERLY RETURN DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Return') IS NOT NULL
DROP TABLE #Return

SELECT
	s.[End RP],
	'STP' AS OrgType,
	s.STP_Code_ODS AS OrgCode,
	s.[Access],
	s.[Access Target 2019/20],
	s.[Referrals]

INTO #Return

FROM [NHSE_Sandbox_MentalHealth].[dbo].[Staging_IPSQuarterlyReporting] s

UNION ALL

SELECT
	s.[End RP],
	'Region' AS OrgType,
	s.[Region_Code] AS OrgCode,
	SUM(s.[Access]) AS Access,
	SUM(s.[Access Target 2019/20]) AS 'Access Target 2019/20',
	SUM(s.[Referrals]) AS Referrals

FROM [NHSE_Sandbox_MentalHealth].[dbo].[Staging_IPSQuarterlyReporting] s

GROUP BY s.[End RP], s.[Region_Code]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
SUPPRESS AND ADD YTD DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('[NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_IPS]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_IPS]

SELECT
	u.[ReportingPeriodEnd],
	u.[Organisation Type],
	u.[Organisation ID],
	u.[Organisation Name],
	CASE 
		WHEN u.[Organisation Type] = 'England' THEN CAST (u.Caseload AS VARCHAR) 
		WHEN u.[Organisation Type] <> 'England' AND u.Caseload <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.Caseload/5.0,0)*5 AS VARCHAR),'*') 
	END AS 'Caseload',
	CASE 
		WHEN u.[Organisation Type] = 'England' THEN CAST (u.[NewReferrals] AS VARCHAR) 
		WHEN u.[Organisation Type] <> 'England' AND u.[NewReferrals] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[NewReferrals]/5.0,0)*5 AS VARCHAR),'*') 
	END AS 'New Referrals Recieved',
	CASE 
		WHEN u.[Organisation Type] = 'England' THEN CAST (u.[ClosedReferrals] AS VARCHAR)
		WHEN u.[Organisation Type] <> 'England' AND u.[ClosedReferrals] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[ClosedReferrals]/5.0,0)*5 AS VARCHAR),'*') 
	END AS 'Referrals Closed',
	CASE 
		WHEN u.[Organisation Type] = 'England' THEN CAST(ROUND(u.Caseload16to35*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)
		WHEN u.[Organisation Type] <> 'England' AND u.Caseload16to35 <5 THEN '*' ELSE CAST(ROUND(u.Caseload16to35*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)
	END AS 'Caseload 16 to 35',
	CASE 
		WHEN u.[Organisation Type] = 'England' THEN CAST(ROUND(u.Caseload36to64*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)
		WHEN u.[Organisation Type] <> 'England' AND u.Caseload36to64 <5 THEN '*' ELSE CAST(ROUND(u.Caseload36to64*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)	
	END AS 'Caseload 36 to 64',
	CASE 
		WHEN u.[Organisation Type] = 'England' THEN CAST(ROUND(u.CaseloadMale*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)
		WHEN u.[Organisation Type] <> 'England' AND u.CaseloadMale <5 THEN '*' ELSE CAST(ROUND(u.CaseloadMale*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)	
	END AS 'Caseload Male',
	CASE 
		WHEN u.[Organisation Type] = 'England' THEN CAST(ROUND(u.ReferredFromPrimaryHealthCare*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)
		WHEN u.[Organisation Type] <> 'England' AND u.ReferredFromPrimaryHealthCare <5 THEN '*' ELSE CAST(ROUND(u.ReferredFromPrimaryHealthCare*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)	
	END AS 'Referred From Primary Health Care',
	CASE 
		WHEN u.[Organisation Type] = 'England' THEN CAST(ROUND(u.SelfReferral*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)
		WHEN u.[Organisation Type] <> 'England' AND u.SelfReferral <5 THEN '*' ELSE CAST(ROUND(u.SelfReferral*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)	
	END AS 'Self Referrals',
	CASE 
		WHEN u.[Organisation Type] = 'England' THEN CAST(ROUND(u.ReferredFromSecondaryMentalHealthCare*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)
		WHEN u.[Organisation Type] <> 'England' AND u.ReferredFromSecondaryMentalHealthCare <5 THEN '*' ELSE 
			CAST(ROUND(u.ReferredFromSecondaryMentalHealthCare*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)	
	END AS 'Referred From Secondary Mental Health Care',
	CASE 
		WHEN u.[Organisation Type] = 'England' THEN CAST(ROUND((NULLIF(u.Caseload,0)- (u.ReferredFromPrimaryHealthCare + u.SelfReferral + u.ReferredFromSecondaryMentalHealthCare))*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR) 
		WHEN u.[Organisation Type] <> 'England' AND (u.ReferredFromPrimaryHealthCare + u.SelfReferral + u.ReferredFromSecondaryMentalHealthCare) <5 THEN '*' 
			ELSE CAST(ROUND((u.Caseload - (u.ReferredFromPrimaryHealthCare + u.SelfReferral + u.ReferredFromSecondaryMentalHealthCare))*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR) 
	END AS 'Referred From Other Sources',
	CASE 
		WHEN u.[Organisation Type] = 'England' THEN CAST(ROUND((u.Caseload-u.CaseloadWhiteBritish)*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)
		WHEN u.[Organisation Type] <> 'England' AND (u.Caseload-u.CaseloadWhiteBritish) <5 THEN '*' ELSE CAST(ROUND((u.Caseload-u.CaseloadWhiteBritish)*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)	
	END AS 'Caseload Not White British',
	CASE 
		WHEN u.[Organisation Type] = 'England' THEN CAST(ROUND(u.Employed*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)
		WHEN u.[Organisation Type] <> 'England' AND u.Employed <5 THEN '*' ELSE CAST(ROUND(u.Employed*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)	
	END AS 'Employed',
	CASE 
		WHEN u.[Organisation Type] = 'England' THEN CAST(ROUND(u.EmployedAtReferral*100.0/u.Caseload,1) AS VARCHAR)
		WHEN u.[Organisation Type] <> 'England' AND u.EmployedAtReferral <5 THEN '*' ELSE CAST(ROUND(u.EmployedAtReferral*100.0/NULLIF(u.Caseload,0),1) AS VARCHAR)	
	END AS 'Employed At Referral',
	CASE 
		WHEN u.[Organisation Type] = 'England' THEN CAST (u.[MonthlyAccess] AS VARCHAR) 
		WHEN u.[Organisation Type] <> 'England' AND u.[MonthlyAccess] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[MonthlyAccess]/5.0,0)*5 AS VARCHAR),'*') 
	END AS 'Monthly Access',
	CASE 
		WHEN u.[Organisation Type] = 'England' THEN CAST (u.Contacts AS VARCHAR) 
		WHEN u.[Organisation Type] <> 'England' AND u.Contacts <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.Contacts/5.0,0)*5 AS VARCHAR),'*') 
	END AS 'Activity',
	CASE
		WHEN u.[Organisation Type] = 'England' THEN CAST (y.[YTDAccess] AS VARCHAR) 
		WHEN u.[Organisation Type] <> 'England' AND y.[YTDAccess] <5 THEN '*' ELSE ISNULL(CAST(ROUND(y.[YTDAccess]/5.0,0)*5 AS VARCHAR),'*') 
	END AS 'MHSDS Access Count',
	CASE
		WHEN u.[Organisation Type] = 'England' THEN CAST (y.YTDNewReferrals AS VARCHAR) 
		WHEN u.[Organisation Type] <> 'England' AND y.YTDNewReferrals <5 THEN '*' ELSE ISNULL(CAST(ROUND(y.YTDNewReferrals/5.0,0)*5 AS VARCHAR),'*') 
	END AS 'MHSDS New Referral Count',
	ISNULL(r.[Access],0) AS 'Quarterly Return Access Count',
	ISNULL(r.[Access Target 2019/20],0) AS 'Access Target',
	ISNULL(r.[Referrals],0) AS 'Quarterly Return New Referral Count'
	
INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_IPS]

FROM #Unsupp u

LEFT JOIN #YTD y ON u.UniqMonthID = y.UniqMonthID AND u.[Organisation ID] = y.Orgcode

LEFT JOIN #Return r ON u.ReportingPeriodEnd = r.[End RP] AND u.[Organisation ID] = r.Orgcode

WHERE u.[Organisation Name] IS NOT NULL AND u.[Organisation Name] <> 'NHS_England'

SELECT * FROM [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_IPS]

where [Organisation Name] = 'ENGLAND'

ORDER BY 2,3,1