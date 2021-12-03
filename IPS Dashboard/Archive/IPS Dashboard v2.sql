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
WHERE Der_MostRecentFlag = 'Y')

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
	map.STP_Code_ODS,
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
	a.Der_FacetoFaceContactOrder AS AccessFlag
	
INTO #Ref

FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Referral] r 

LEFT JOIN [NHSE_MHSDS].[dbo].[MHS004EmpStatus] e ON r.RecordNumber = e.RecordNumber AND e.Der_Use_Submission_Flag = 'Y'

INNER JOIN [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] h ON r.UniqMonthID = h.UniqMonthID

LEFT JOIN [NHSE_Sandbox_MentalHealth].dbo.PreProc_Activity a ON r.Person_ID = a.Person_ID AND r.UniqServReqID = a.UniqServReqID AND r.UniqMonthID = a.UniqMonthID AND a.Der_FacetoFaceContactOrder = 1

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
	r.STP_Code_ODS,
	r.STP_Name,
	r.Region_Code,
	r.Region_Name,
	CASE WHEN r.ReferralRequestReceivedDate BETWEEN r.ReportingPeriodStart AND r.ReportingPeriodEnd THEN 1 ELSE 0 END AS NewRef,
	CASE WHEN r.ServDischDate BETWEEN r.ReportingPeriodStart AND r.ReportingPeriodEnd THEN 1 ELSE 0 END AS ClosedRef,
	CASE WHEN r.AgeServReferRecDate < 18 THEN 1 ELSE 0 END AS 'Under 18',
	CASE WHEN r.AgeServReferRecDate BETWEEN 18 AND 20 THEN 1 ELSE 0 END AS '18 to 20',
	CASE WHEN r.AgeServReferRecDate BETWEEN 21 AND 25 THEN 1 ELSE 0 END AS '21 to 25',
	CASE WHEN r.AgeServReferRecDate BETWEEN 26 AND 30 THEN 1 ELSE 0 END AS '26 to 30',
	CASE WHEN r.AgeServReferRecDate BETWEEN 31 AND 35 THEN 1 ELSE 0 END AS '31 to 35',
	CASE WHEN r.AgeServReferRecDate BETWEEN 36 AND 40 THEN 1 ELSE 0 END AS '36 to 40',
	CASE WHEN r.AgeServReferRecDate BETWEEN 41 AND 45 THEN 1 ELSE 0 END AS '41 to 45',
	CASE WHEN r.AgeServReferRecDate BETWEEN 46 AND 50 THEN 1 ELSE 0 END AS '46 to 50',
	CASE WHEN r.AgeServReferRecDate BETWEEN 51 AND 55 THEN 1 ELSE 0 END AS '51 to 55',
	CASE WHEN r.AgeServReferRecDate BETWEEN 56 AND 60 THEN 1 ELSE 0 END AS '56 to 60',
	CASE WHEN r.AgeServReferRecDate >60 THEN 1 ELSE 0 END AS 'Over 60',
	CASE WHEN r.Gender = '1' THEN 1 ELSE 0 END AS 'Male',
	CASE WHEN r.Gender = '2' THEN 1 ELSE 0 END AS 'Female',
	CASE WHEN r.Gender IS NULL OR r.Gender NOT IN ('1','2')  THEN 1 ELSE 0 END AS 'Other/Invalid',
	CASE WHEN r.SourceOfReferralMH IN ('A1','A2','A3','A4') THEN 1 ELSE 0 END AS 'Primary Health Care',
	CASE WHEN r.SourceOfReferralMH IN ('B1','B2') THEN 1 ELSE 0 END AS 'Self Referral',
	CASE WHEN r.SourceOfReferralMH IN ('C1','C2','C3') THEN 1 ELSE 0 END AS 'Local Authority and Other Public Services',
	CASE WHEN r.SourceOfReferralMH IN ('D1','D2') THEN 1 ELSE 0 END AS 'Employer',
	CASE WHEN r.SourceOfReferralMH IN ('E1','E2','E3','E4','E5','E6') THEN 1 ELSE 0 END AS 'Justice System',
	CASE WHEN r.SourceOfReferralMH IN ('F1','F2','F3') THEN 1 ELSE 0 END AS 'Child Health',
	CASE WHEN r.SourceOfReferralMH IN ('G1','G2','G3','G4') THEN 1 ELSE 0 END AS 'Independent/Voluntary Sector',
	CASE WHEN r.SourceOfReferralMH IN ('H1','H2') THEN 1 ELSE 0 END AS 'Acute Secondary Care',
	CASE WHEN r.SourceOfReferralMH IN ('I1','I2') THEN 1 ELSE 0 END AS 'Other Mental Health NHS Trust',
	CASE WHEN r.SourceOfReferralMH = 'P1' THEN 1 ELSE 0 END AS 'Internal',
	CASE WHEN r.SourceOfReferralMH IS NULL OR 
		r.SourceOfReferralMH NOT IN ('A1','A2','A3','A4','B1','B2','C1','C2','C3','D1','D2','E1','E2','E3','E4','E5','E6','F1','F2','F3','G1','G2','G3','G4','H1','H2','I1','I2','P1') THEN 1 ELSE 0 END AS 'Other/Invalid Referral Source',
	CASE WHEN r.EthnicCategory IN ('A', 'B', 'C') THEN 1 ELSE 0 END AS 'White',
	CASE WHEN r.EthnicCategory IN ('D', 'E', 'F', 'G') THEN 1 ELSE 0 END AS 'Mixed',
	CASE WHEN r.EthnicCategory IN ('H', 'J', 'K', 'L') THEN 1 ELSE 0 END AS 'Asian or Asian British',
	CASE WHEN r.EthnicCategory IN ('M', 'N', 'P') THEN 1 ELSE 0 END AS 'Black or Black British',
	CASE WHEN r.EthnicCategory IN ('R', 'S', 'Z', '99') THEN 1 ELSE 0 END AS 'Other Ethnic Groups' ,
	CASE WHEN r.EthnicCategory IS NULL OR r.EthnicCategory NOT IN ('A', 'B', 'C','D', 'E', 'F', 'G','H', 'J', 'K', 'L','M', 'N', 'P','R', 'S', 'Z', '99') THEN 1 ELSE 0 END AS 'Other/Invalid Ethnicity',
	CASE WHEN r.EmployStatus = '01' THEN 1 ELSE 0 END AS 'Employed',
	CASE WHEN r.EmployStatus = '02' THEN 1 ELSE 0 END AS 'Unemployed and actively seeking work',
	CASE WHEN r.EmployStatus = '03' THEN 1 ELSE 0 END AS 'In Education',
	CASE WHEN r.EmployStatus = '04' THEN 1 ELSE 0 END AS 'Long-term sick or disabled',
	CASE WHEN r.EmployStatus = '05' THEN 1 ELSE 0 END AS 'Looking after the family or home',
	CASE WHEN r.EmployStatus = '06' THEN 1 ELSE 0 END AS 'Not working or actively seeking work',
	CASE WHEN r.EmployStatus = '07' THEN 1 ELSE 0 END AS 'Unpaid voluntary work',
	CASE WHEN r.EmployStatus = '08' THEN 1 ELSE 0 END AS 'Retired',
	CASE WHEN r.EmployStatus = 'ZZ' THEN 1 ELSE 0 END AS 'Employment Status Not Stated',
	CASE WHEN r.EmployStatus IS NULL or r.EmployStatus NOT IN ('01','02','03','04','05','06','07','08','ZZ') THEN 1 ELSE 0 END AS 'Other/Invalid Employment Status',
	CASE WHEN r.WeekHoursWorked = '01' THEN 1 ELSE 0 END AS '30+ Hours',
	CASE WHEN r.WeekHoursWorked = '02' THEN 1 ELSE 0 END AS '16-29 Hours',
	CASE WHEN r.WeekHoursWorked = '03' THEN 1 ELSE 0 END AS '5-15 Hours',
	CASE WHEN r.WeekHoursWorked = '04' THEN 1 ELSE 0 END AS '1-4 Hours',
	CASE WHEN r.WeekHoursWorked = '97' THEN 1 ELSE 0 END AS 'Hours Worked Not Stated',
	CASE WHEN r.WeekHoursWorked = '98' THEN 1 ELSE 0 END AS 'Not Employed',
	CASE WHEN r.WeekHoursWorked = '99' THEN 1 ELSE 0 END AS 'Hours Worked Not Known',
	CASE WHEN r.WeekHoursWorked IS NULL OR r.WeekHoursWorked NOT IN ('01','02','03','04','97','98','99') THEN 1 ELSE 0 END AS 'Other/Invalid Hours Worked',
	r.AccessFlag,
	CASE WHEN r.UniqMonthID >= @FYSTART THEN r.AccessFlag END AS YTDAccessFlag

INTO #Master

FROM #Ref r

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET YTD ACCESS BY PROVIDER/CCG/STP/REGION
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#YTD') IS NOT NULL
DROP TABLE #YTD

SELECT DISTINCT
	m.UniqMonthID,
	'Provider' AS OrgType,
	m.OrgIDProv AS Orgcode,
	SUM(m.YTDAccessFlag) OVER (PARTITION BY m.OrgIDProv ORDER BY m.UniqMonthID) AS YTDAccess

INTO #YTD

FROM #Master m

WHERE m.UniqMonthID >=1429

UNION ALL

SELECT DISTINCT
	m.UniqMonthID,
	'CCG' AS OrgType,
	m.OrgIDCCGRes AS Orgcode,
	SUM(m.YTDAccessFlag) OVER (PARTITION BY m.OrgIDCCGRes ORDER BY m.UniqMonthID) AS YTDAccess
FROM #Master m

WHERE m.UniqMonthID >=1429

UNION ALL

SELECT DISTINCT
	m.UniqMonthID,
	'STP' AS OrgType,
	m.STP_Code_ODS AS Orgcode,
	SUM(m.YTDAccessFlag) OVER (PARTITION BY m.STP_Code_ODS ORDER BY m.UniqMonthID) AS YTDAccess
FROM #Master m

WHERE m.UniqMonthID >=1429

UNION ALL

SELECT DISTINCT
	m.UniqMonthID,
	'REGION' AS OrgType,
	m.Region_Code AS Orgcode,
	SUM(m.YTDAccessFlag) OVER (PARTITION BY m.Region_Code ORDER BY m.UniqMonthID) AS YTDAccess
FROM #Master m

WHERE m.UniqMonthID >=1429

UNION ALL

SELECT DISTINCT
	m.UniqMonthID,
	'ENGLAND' AS OrgType,
	'ENG' AS Orgcode,
	SUM(m.YTDAccessFlag) OVER (ORDER BY m.UniqMonthID) AS YTDAccess
FROM #Master m

WHERE m.UniqMonthID >=1429

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
	COUNT(m.UniqServReqID) AS Referrals,
	SUM(m.NewRef) AS NewReferrals,
	SUM(m.ClosedRef) AS ClosedReferrals,
	SUM(m.[Under 18]) AS 'Referrals for People Under 18',
	SUM(m.[18 to 20]) AS 'Referrals for People 18 to 20',
	SUM(m.[21 to 25]) AS 'Referrals for People 21 to 25',
	SUM(m.[26 to 30]) AS 'Referrals for People 26 to 30',
	SUM(m.[31 to 35]) AS 'Referrals for People 31 to 35',
	SUM(m.[36 to 40]) AS 'Referrals for People 36 to 40',
	SUM(m.[41 to 45]) AS 'Referrals for People 41 to 45',
	SUM(m.[46 to 50]) AS 'Referrals for People 46 to 50',
	SUM(m.[51 to 55]) AS 'Referrals for People 51 to 55',
	SUM(m.[56 to 60]) AS 'Referrals for People 56 to 60',
	SUM(m.[Over 60]) AS 'Referrals for People Over 60',
	SUM(m.[Male]) AS 'Referrals for Males',
	SUM(m.[Female]) AS 'Referrals for Females',
	SUM(m.[Other/Invalid]) AS 'Referrals with an Other/Invalid Gender',
	SUM(m.[Primary Health Care]) AS 'Referrals from Primary Health Care',
	SUM(m.[Self Referral]) AS 'Self Referrals',
	SUM(m.[Local Authority and Other Public Services]) AS 'Referrals from Local Authority and Other Public Services',
	SUM(m.[Employer]) AS 'Employer Referrals',
	SUM(m.[Justice System]) AS 'Referrals from Justice System',
	SUM(m.[Child Health]) AS 'Referrals from Child Health',
	SUM(m.[Independent/Voluntary Sector]) AS 'Referrals from Independent/Voluntary Sector',
	SUM(m.[Acute Secondary Care]) AS 'Referrals from Acute Secondary Care',
	SUM(m.[Other Mental Health NHS Trust]) AS 'Referrals from Other Mental Health NHS Trust',
	SUM(m.[Internal]) AS 'Internal Referrals',
	SUM(m.[Other/Invalid Referral Source]) AS 'Referrals from Other/Invalid Referral Source',
	SUM(m.[White]) AS 'Referrals for White Ethnicities',
	SUM(m.[Mixed]) AS 'Referrals for Mixed Ethnicities',
	SUM(m.[Asian or Asian British]) AS 'Referrals for Asian or Asian British Ethnicities',
	SUM(m.[Black or Black British]) AS 'Referrals for Black or Black British Ethnicities',
	SUM(m.[Other Ethnic Groups]) AS 'Referrals for Other Ethnic Groups',
	SUM(m.[Other/Invalid Ethnicity]) AS 'Referrals for Other/Invalid Ethnicities',
	SUM(m.[Employed]) AS 'Employed',
	SUM(m.[Unemployed and actively seeking work]) AS 'Unemployed and actively seeking work',
	SUM(m.[In Education]) AS 'In Education',
	SUM(m.[Long-term sick or disabled]) AS 'Long-term sick or disabled',
	SUM(m.[Looking after the family or home]) AS 'Looking after the family or home',
	SUM(m.[Not working or actively seeking work]) AS 'Not working or actively seeking work',
	SUM(m.[Unpaid voluntary work]) AS 'Unpaid voluntary work',
	SUM(m.[Retired]) AS 'Retired',
	SUM(m.[Employment Status Not Stated]) AS 'Employment Status Not Stated',
	SUM(m.[Other/Invalid Employment Status]) AS 'Other/Invalid Employment Status',
	SUM(m.[30+ Hours]) AS '30+ Hours Work',
	SUM(m.[16-29 Hours]) AS '16-29 Hours Work',
	SUM(m.[5-15 Hours]) AS '5-15 Hours Work',
	SUM(m.[1-4 Hours]) AS '1-4 Hours Work',
	SUM(m.[Hours Worked Not Stated]) AS 'Hours Worked Not Stated',
	SUM(m.[Not Employed]) AS 'Not Employed',
	SUM(m.[Hours Worked Not Known]) AS 'Hours Worked Not Known',
	SUM(m.[Other/Invalid Hours Worked]) AS 'Other/Invalid Hours Worked',
	SUM(m.AccessFlag) AS 'Monthly Access'

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
	COUNT(m.UniqServReqID) AS Referrals,
	SUM(m.NewRef) AS NewReferrals,
	SUM(m.ClosedRef) AS ClosedReferrals,
	SUM(m.[Under 18]) AS 'Referrals for People Under 18',
	SUM(m.[18 to 20]) AS 'Referrals for People 18 to 20',
	SUM(m.[21 to 25]) AS 'Referrals for People 21 to 25',
	SUM(m.[26 to 30]) AS 'Referrals for People 26 to 30',
	SUM(m.[31 to 35]) AS 'Referrals for People 31 to 35',
	SUM(m.[36 to 40]) AS 'Referrals for People 36 to 40',
	SUM(m.[41 to 45]) AS 'Referrals for People 41 to 45',
	SUM(m.[46 to 50]) AS 'Referrals for People 46 to 50',
	SUM(m.[51 to 55]) AS 'Referrals for People 51 to 55',
	SUM(m.[56 to 60]) AS 'Referrals for People 56 to 60',
	SUM(m.[Over 60]) AS 'Referrals for People Over 60',
	SUM(m.[Male]) AS 'Referrals for Males',
	SUM(m.[Female]) AS 'Referrals for Females',
	SUM(m.[Other/Invalid]) AS 'Referrals with an Other/Invalid Gender',
	SUM(m.[Primary Health Care]) AS 'Referrals from Primary Health Care',
	SUM(m.[Self Referral]) AS 'Self Referrals',
	SUM(m.[Local Authority and Other Public Services]) AS 'Referrals from Local Authority and Other Public Services',
	SUM(m.[Employer]) AS 'Employer Referrals',
	SUM(m.[Justice System]) AS 'Referrals from Justice System',
	SUM(m.[Child Health]) AS 'Referrals from Child Health',
	SUM(m.[Independent/Voluntary Sector]) AS 'Referrals from Independent/Voluntary Sector',
	SUM(m.[Acute Secondary Care]) AS 'Referrals from Acute Secondary Care',
	SUM(m.[Other Mental Health NHS Trust]) AS 'Referrals from Other Mental Health NHS Trust',
	SUM(m.[Internal]) AS 'Internal Referrals',
	SUM(m.[Other/Invalid Referral Source]) AS 'Referrals from Other/Invalid Referral Source',
	SUM(m.[White]) AS 'Referrals for White Ethnicities',
	SUM(m.[Mixed]) AS 'Referrals for Mixed Ethnicities',
	SUM(m.[Asian or Asian British]) AS 'Referrals for Asian or Asian British Ethnicities',
	SUM(m.[Black or Black British]) AS 'Referrals for Black or Black British Ethnicities',
	SUM(m.[Other Ethnic Groups]) AS 'Referrals for Other Ethnic Groups',
	SUM(m.[Other/Invalid Ethnicity]) AS 'Referrals for Other/Invalid Ethnicities',
	SUM(m.[Employed]) AS 'Employed',
	SUM(m.[Unemployed and actively seeking work]) AS 'Unemployed and actively seeking work',
	SUM(m.[In Education]) AS 'In Education',
	SUM(m.[Long-term sick or disabled]) AS 'Long-term sick or disabled',
	SUM(m.[Looking after the family or home]) AS 'Looking after the family or home',
	SUM(m.[Not working or actively seeking work]) AS 'Not working or actively seeking work',
	SUM(m.[Unpaid voluntary work]) AS 'Unpaid voluntary work',
	SUM(m.[Retired]) AS 'Retired',
	SUM(m.[Employment Status Not Stated]) AS 'Employment Status Not Stated',
	SUM(m.[Other/Invalid Employment Status]) AS 'Other/Invalid Employment Status',
	SUM(m.[30+ Hours]) AS '30+ Hours Work',
	SUM(m.[16-29 Hours]) AS '16-29 Hours Work',
	SUM(m.[5-15 Hours]) AS '5-15 Hours Work',
	SUM(m.[1-4 Hours]) AS '1-4 Hours Work',
	SUM(m.[Hours Worked Not Stated]) AS 'Hours Worked Not Stated',
	SUM(m.[Not Employed]) AS 'Not Employed',
	SUM(m.[Hours Worked Not Known]) AS 'Hours Worked Not Known',
	SUM(m.[Other/Invalid Hours Worked]) AS 'Other/Invalid Hours Worked',
	SUM(m.AccessFlag) AS 'Monthly Access'

FROM #Master m

GROUP BY m.ReportingPeriodEnd, m.UniqMonthID, m.OrgIDCCGRes, m.CCGName

UNION ALL

SELECT
	m.ReportingPeriodEnd,
	m.UniqMonthID,
	'STP' AS 'Organisation Type',
	m.STP_Code_ODS AS 'Organisation ID',
	m.STP_Name AS 'Organisation Name',
	COUNT(m.UniqServReqID) AS Referrals,
	SUM(m.NewRef) AS NewReferrals,
	SUM(m.ClosedRef) AS ClosedReferrals,
	SUM(m.[Under 18]) AS 'Referrals for People Under 18',
	SUM(m.[18 to 20]) AS 'Referrals for People 18 to 20',
	SUM(m.[21 to 25]) AS 'Referrals for People 21 to 25',
	SUM(m.[26 to 30]) AS 'Referrals for People 26 to 30',
	SUM(m.[31 to 35]) AS 'Referrals for People 31 to 35',
	SUM(m.[36 to 40]) AS 'Referrals for People 36 to 40',
	SUM(m.[41 to 45]) AS 'Referrals for People 41 to 45',
	SUM(m.[46 to 50]) AS 'Referrals for People 46 to 50',
	SUM(m.[51 to 55]) AS 'Referrals for People 51 to 55',
	SUM(m.[56 to 60]) AS 'Referrals for People 56 to 60',
	SUM(m.[Over 60]) AS 'Referrals for People Over 60',
	SUM(m.[Male]) AS 'Referrals for Males',
	SUM(m.[Female]) AS 'Referrals for Females',
	SUM(m.[Other/Invalid]) AS 'Referrals with an Other/Invalid Gender',
	SUM(m.[Primary Health Care]) AS 'Referrals from Primary Health Care',
	SUM(m.[Self Referral]) AS 'Self Referrals',
	SUM(m.[Local Authority and Other Public Services]) AS 'Referrals from Local Authority and Other Public Services',
	SUM(m.[Employer]) AS 'Employer Referrals',
	SUM(m.[Justice System]) AS 'Referrals from Justice System',
	SUM(m.[Child Health]) AS 'Referrals from Child Health',
	SUM(m.[Independent/Voluntary Sector]) AS 'Referrals from Independent/Voluntary Sector',
	SUM(m.[Acute Secondary Care]) AS 'Referrals from Acute Secondary Care',
	SUM(m.[Other Mental Health NHS Trust]) AS 'Referrals from Other Mental Health NHS Trust',
	SUM(m.[Internal]) AS 'Internal Referrals',
	SUM(m.[Other/Invalid Referral Source]) AS 'Referrals from Other/Invalid Referral Source',
	SUM(m.[White]) AS 'Referrals for White Ethnicities',
	SUM(m.[Mixed]) AS 'Referrals for Mixed Ethnicities',
	SUM(m.[Asian or Asian British]) AS 'Referrals for Asian or Asian British Ethnicities',
	SUM(m.[Black or Black British]) AS 'Referrals for Black or Black British Ethnicities',
	SUM(m.[Other Ethnic Groups]) AS 'Referrals for Other Ethnic Groups',
	SUM(m.[Other/Invalid Ethnicity]) AS 'Referrals for Other/Invalid Ethnicities',
	SUM(m.[Employed]) AS 'Employed',
	SUM(m.[Unemployed and actively seeking work]) AS 'Unemployed and actively seeking work',
	SUM(m.[In Education]) AS 'In Education',
	SUM(m.[Long-term sick or disabled]) AS 'Long-term sick or disabled',
	SUM(m.[Looking after the family or home]) AS 'Looking after the family or home',
	SUM(m.[Not working or actively seeking work]) AS 'Not working or actively seeking work',
	SUM(m.[Unpaid voluntary work]) AS 'Unpaid voluntary work',
	SUM(m.[Retired]) AS 'Retired',
	SUM(m.[Employment Status Not Stated]) AS 'Employment Status Not Stated',
	SUM(m.[Other/Invalid Employment Status]) AS 'Other/Invalid Employment Status',
	SUM(m.[30+ Hours]) AS '30+ Hours Work',
	SUM(m.[16-29 Hours]) AS '16-29 Hours Work',
	SUM(m.[5-15 Hours]) AS '5-15 Hours Work',
	SUM(m.[1-4 Hours]) AS '1-4 Hours Work',
	SUM(m.[Hours Worked Not Stated]) AS 'Hours Worked Not Stated',
	SUM(m.[Not Employed]) AS 'Not Employed',
	SUM(m.[Hours Worked Not Known]) AS 'Hours Worked Not Known',
	SUM(m.[Other/Invalid Hours Worked]) AS 'Other/Invalid Hours Worked',
	SUM(m.AccessFlag) AS 'Monthly Access'

FROM #Master m

GROUP BY m.ReportingPeriodEnd, m.UniqMonthID, m.STP_Code_ODS, m.STP_Name

UNION ALL

SELECT
	m.ReportingPeriodEnd,
	m.UniqMonthID,
	'REGION' AS 'Organisation Type',
	m.Region_Code AS 'Organisation ID',
	m.Region_Name AS 'Organisation Name',
	COUNT(m.UniqServReqID) AS Referrals,
	SUM(m.NewRef) AS NewReferrals,
	SUM(m.ClosedRef) AS ClosedReferrals,
	SUM(m.[Under 18]) AS 'Referrals for People Under 18',
	SUM(m.[18 to 20]) AS 'Referrals for People 18 to 20',
	SUM(m.[21 to 25]) AS 'Referrals for People 21 to 25',
	SUM(m.[26 to 30]) AS 'Referrals for People 26 to 30',
	SUM(m.[31 to 35]) AS 'Referrals for People 31 to 35',
	SUM(m.[36 to 40]) AS 'Referrals for People 36 to 40',
	SUM(m.[41 to 45]) AS 'Referrals for People 41 to 45',
	SUM(m.[46 to 50]) AS 'Referrals for People 46 to 50',
	SUM(m.[51 to 55]) AS 'Referrals for People 51 to 55',
	SUM(m.[56 to 60]) AS 'Referrals for People 56 to 60',
	SUM(m.[Over 60]) AS 'Referrals for People Over 60',
	SUM(m.[Male]) AS 'Referrals for Males',
	SUM(m.[Female]) AS 'Referrals for Females',
	SUM(m.[Other/Invalid]) AS 'Referrals with an Other/Invalid Gender',
	SUM(m.[Primary Health Care]) AS 'Referrals from Primary Health Care',
	SUM(m.[Self Referral]) AS 'Self Referrals',
	SUM(m.[Local Authority and Other Public Services]) AS 'Referrals from Local Authority and Other Public Services',
	SUM(m.[Employer]) AS 'Employer Referrals',
	SUM(m.[Justice System]) AS 'Referrals from Justice System',
	SUM(m.[Child Health]) AS 'Referrals from Child Health',
	SUM(m.[Independent/Voluntary Sector]) AS 'Referrals from Independent/Voluntary Sector',
	SUM(m.[Acute Secondary Care]) AS 'Referrals from Acute Secondary Care',
	SUM(m.[Other Mental Health NHS Trust]) AS 'Referrals from Other Mental Health NHS Trust',
	SUM(m.[Internal]) AS 'Internal Referrals',
	SUM(m.[Other/Invalid Referral Source]) AS 'Referrals from Other/Invalid Referral Source',
	SUM(m.[White]) AS 'Referrals for White Ethnicities',
	SUM(m.[Mixed]) AS 'Referrals for Mixed Ethnicities',
	SUM(m.[Asian or Asian British]) AS 'Referrals for Asian or Asian British Ethnicities',
	SUM(m.[Black or Black British]) AS 'Referrals for Black or Black British Ethnicities',
	SUM(m.[Other Ethnic Groups]) AS 'Referrals for Other Ethnic Groups',
	SUM(m.[Other/Invalid Ethnicity]) AS 'Referrals for Other/Invalid Ethnicities',
	SUM(m.[Employed]) AS 'Employed',
	SUM(m.[Unemployed and actively seeking work]) AS 'Unemployed and actively seeking work',
	SUM(m.[In Education]) AS 'In Education',
	SUM(m.[Long-term sick or disabled]) AS 'Long-term sick or disabled',
	SUM(m.[Looking after the family or home]) AS 'Looking after the family or home',
	SUM(m.[Not working or actively seeking work]) AS 'Not working or actively seeking work',
	SUM(m.[Unpaid voluntary work]) AS 'Unpaid voluntary work',
	SUM(m.[Retired]) AS 'Retired',
	SUM(m.[Employment Status Not Stated]) AS 'Employment Status Not Stated',
	SUM(m.[Other/Invalid Employment Status]) AS 'Other/Invalid Employment Status',
	SUM(m.[30+ Hours]) AS '30+ Hours Work',
	SUM(m.[16-29 Hours]) AS '16-29 Hours Work',
	SUM(m.[5-15 Hours]) AS '5-15 Hours Work',
	SUM(m.[1-4 Hours]) AS '1-4 Hours Work',
	SUM(m.[Hours Worked Not Stated]) AS 'Hours Worked Not Stated',
	SUM(m.[Not Employed]) AS 'Not Employed',
	SUM(m.[Hours Worked Not Known]) AS 'Hours Worked Not Known',
	SUM(m.[Other/Invalid Hours Worked]) AS 'Other/Invalid Hours Worked',
	SUM(m.AccessFlag) AS 'Monthly Access'

FROM #Master m

GROUP BY m.ReportingPeriodEnd, m.UniqMonthID, m.Region_Code, m.Region_Name

UNION ALL

SELECT
	m.ReportingPeriodEnd,
	m.UniqMonthID,
	'ENGLAND' AS 'Organisation Type',
	'ENG' AS 'Organisation ID',
	'ENGLAND' AS 'Organisation Name',
	COUNT(m.UniqServReqID) AS Referrals,
	SUM(m.NewRef) AS NewReferrals,
	SUM(m.ClosedRef) AS ClosedReferrals,
	SUM(m.[Under 18]) AS 'Referrals for People Under 18',
	SUM(m.[18 to 20]) AS 'Referrals for People 18 to 20',
	SUM(m.[21 to 25]) AS 'Referrals for People 21 to 25',
	SUM(m.[26 to 30]) AS 'Referrals for People 26 to 30',
	SUM(m.[31 to 35]) AS 'Referrals for People 31 to 35',
	SUM(m.[36 to 40]) AS 'Referrals for People 36 to 40',
	SUM(m.[41 to 45]) AS 'Referrals for People 41 to 45',
	SUM(m.[46 to 50]) AS 'Referrals for People 46 to 50',
	SUM(m.[51 to 55]) AS 'Referrals for People 51 to 55',
	SUM(m.[56 to 60]) AS 'Referrals for People 56 to 60',
	SUM(m.[Over 60]) AS 'Referrals for People Over 60',
	SUM(m.[Male]) AS 'Referrals for Males',
	SUM(m.[Female]) AS 'Referrals for Females',
	SUM(m.[Other/Invalid]) AS 'Referrals with an Other/Invalid Gender',
	SUM(m.[Primary Health Care]) AS 'Referrals from Primary Health Care',
	SUM(m.[Self Referral]) AS 'Self Referrals',
	SUM(m.[Local Authority and Other Public Services]) AS 'Referrals from Local Authority and Other Public Services',
	SUM(m.[Employer]) AS 'Employer Referrals',
	SUM(m.[Justice System]) AS 'Referrals from Justice System',
	SUM(m.[Child Health]) AS 'Referrals from Child Health',
	SUM(m.[Independent/Voluntary Sector]) AS 'Referrals from Independent/Voluntary Sector',
	SUM(m.[Acute Secondary Care]) AS 'Referrals from Acute Secondary Care',
	SUM(m.[Other Mental Health NHS Trust]) AS 'Referrals from Other Mental Health NHS Trust',
	SUM(m.[Internal]) AS 'Internal Referrals',
	SUM(m.[Other/Invalid Referral Source]) AS 'Referrals from Other/Invalid Referral Source',
	SUM(m.[White]) AS 'Referrals for White Ethnicities',
	SUM(m.[Mixed]) AS 'Referrals for Mixed Ethnicities',
	SUM(m.[Asian or Asian British]) AS 'Referrals for Asian or Asian British Ethnicities',
	SUM(m.[Black or Black British]) AS 'Referrals for Black or Black British Ethnicities',
	SUM(m.[Other Ethnic Groups]) AS 'Referrals for Other Ethnic Groups',
	SUM(m.[Other/Invalid Ethnicity]) AS 'Referrals for Other/Invalid Ethnicities',
	SUM(m.[Employed]) AS 'Employed',
	SUM(m.[Unemployed and actively seeking work]) AS 'Unemployed and actively seeking work',
	SUM(m.[In Education]) AS 'In Education',
	SUM(m.[Long-term sick or disabled]) AS 'Long-term sick or disabled',
	SUM(m.[Looking after the family or home]) AS 'Looking after the family or home',
	SUM(m.[Not working or actively seeking work]) AS 'Not working or actively seeking work',
	SUM(m.[Unpaid voluntary work]) AS 'Unpaid voluntary work',
	SUM(m.[Retired]) AS 'Retired',
	SUM(m.[Employment Status Not Stated]) AS 'Employment Status Not Stated',
	SUM(m.[Other/Invalid Employment Status]) AS 'Other/Invalid Employment Status',
	SUM(m.[30+ Hours]) AS '30+ Hours Work',
	SUM(m.[16-29 Hours]) AS '16-29 Hours Work',
	SUM(m.[5-15 Hours]) AS '5-15 Hours Work',
	SUM(m.[1-4 Hours]) AS '1-4 Hours Work',
	SUM(m.[Hours Worked Not Stated]) AS 'Hours Worked Not Stated',
	SUM(m.[Not Employed]) AS 'Not Employed',
	SUM(m.[Hours Worked Not Known]) AS 'Hours Worked Not Known',
	SUM(m.[Other/Invalid Hours Worked]) AS 'Other/Invalid Hours Worked',
	SUM(m.AccessFlag) AS 'Monthly Access'

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
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[NewReferrals] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[NewReferrals] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[NewReferrals]/5.0,0)*5 AS VARCHAR),'*') END AS 'NewReferrals',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[ClosedReferrals] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[ClosedReferrals] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[ClosedReferrals]/5.0,0)*5 AS VARCHAR),'*') END AS 'ClosedReferrals',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for People Under 18] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for People Under 18] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for People Under 18]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for People Under 18',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for People 18 to 20] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for People 18 to 20] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for People 18 to 20]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for People 18 to 20',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for People 21 to 25] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for People 21 to 25] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for People 21 to 25]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for People 21 to 25',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for People 26 to 30] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for People 26 to 30] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for People 26 to 30]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for People 26 to 30',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for People 31 to 35] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for People 31 to 35] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for People 31 to 35]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for People 31 to 35',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for People 36 to 40] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for People 36 to 40] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for People 36 to 40]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for People 36 to 40',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for People 41 to 45] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for People 41 to 45] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for People 41 to 45]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for People 41 to 45',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for People 46 to 50] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for People 46 to 50] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for People 46 to 50]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for People 46 to 50',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for People 51 to 55] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for People 51 to 55] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for People 51 to 55]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for People 51 to 55',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for People 56 to 60] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for People 56 to 60] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for People 56 to 60]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for People 56 to 60',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for People Over 60] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for People Over 60] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for People Over 60]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for People Over 60',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for Males] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for Males] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for Males]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for Males',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for Females] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for Females] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for Females]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for Females',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals with an Other/Invalid Gender] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals with an Other/Invalid Gender] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals with an Other/Invalid Gender]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals with an Other/Invalid Gender',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals from Primary Health Care] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals from Primary Health Care] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals from Primary Health Care]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals from Primary Health Care',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Self Referrals] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Self Referrals] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Self Referrals]/5.0,0)*5 AS VARCHAR),'*') END AS 'Self Referrals',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals from Local Authority and Other Public Services] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals from Local Authority and Other Public Services] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals from Local Authority and Other Public Services]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals from Local Authority and Other Public Services',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Employer Referrals] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Employer Referrals] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Employer Referrals]/5.0,0)*5 AS VARCHAR),'*') END AS 'Employer Referrals',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals from Justice System] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals from Justice System] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals from Justice System]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals from Justice System',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals from Child Health] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals from Child Health] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals from Child Health]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals from Child Health',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals from Independent/Voluntary Sector] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals from Independent/Voluntary Sector] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals from Independent/Voluntary Sector]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals from Independent/Voluntary Sector',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals from Acute Secondary Care] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals from Acute Secondary Care] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals from Acute Secondary Care]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals from Acute Secondary Care',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals from Other Mental Health NHS Trust] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals from Other Mental Health NHS Trust] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals from Other Mental Health NHS Trust]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals from Other Mental Health NHS Trust',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Internal Referrals] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Internal Referrals] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Internal Referrals]/5.0,0)*5 AS VARCHAR),'*') END AS 'Internal Referrals',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals from Other/Invalid Referral Source] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals from Other/Invalid Referral Source] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals from Other/Invalid Referral Source]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals from Other/Invalid Referral Source',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for White Ethnicities] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for White Ethnicities] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for White Ethnicities]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for White Ethnicities',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for Mixed Ethnicities] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for Mixed Ethnicities] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for Mixed Ethnicities]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for Mixed Ethnicities',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for Asian or Asian British Ethnicities] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for Asian or Asian British Ethnicities] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for Asian or Asian British Ethnicities]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for Asian or Asian British Ethnicities',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for Black or Black British Ethnicities] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for Black or Black British Ethnicities] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for Black or Black British Ethnicities]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for Black or Black British Ethnicities',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for Other Ethnic Groups] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for Other Ethnic Groups] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for Other Ethnic Groups]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for Other Ethnic Groups',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Referrals for Other/Invalid Ethnicities] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Referrals for Other/Invalid Ethnicities] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Referrals for Other/Invalid Ethnicities]/5.0,0)*5 AS VARCHAR),'*') END AS 'Referrals for Other/Invalid Ethnicities',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Employed] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Employed] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Employed]/5.0,0)*5 AS VARCHAR),'*') END AS 'Employed',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Unemployed and actively seeking work] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Unemployed and actively seeking work] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Unemployed and actively seeking work]/5.0,0)*5 AS VARCHAR),'*') END AS 'Unemployed and actively seeking work',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[In Education] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[In Education] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[In Education]/5.0,0)*5 AS VARCHAR),'*') END AS 'In Education',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Long-term sick or disabled] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Long-term sick or disabled] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Long-term sick or disabled]/5.0,0)*5 AS VARCHAR),'*') END AS 'Long-term sick or disabled',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Looking after the family or home] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Looking after the family or home] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Looking after the family or home]/5.0,0)*5 AS VARCHAR),'*') END AS 'Looking after the family or home',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Not working or actively seeking work] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Not working or actively seeking work] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Not working or actively seeking work]/5.0,0)*5 AS VARCHAR),'*') END AS 'Not working or actively seeking work',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Unpaid voluntary work] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Unpaid voluntary work] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Unpaid voluntary work]/5.0,0)*5 AS VARCHAR),'*') END AS 'Unpaid voluntary work',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Retired] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Retired] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Retired]/5.0,0)*5 AS VARCHAR),'*') END AS 'Retired',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Employment Status Not Stated] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Employment Status Not Stated] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Employment Status Not Stated]/5.0,0)*5 AS VARCHAR),'*') END AS 'Employment Status Not Stated',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Other/Invalid Employment Status] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Other/Invalid Employment Status] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Other/Invalid Employment Status]/5.0,0)*5 AS VARCHAR),'*') END AS 'Other/Invalid Employment Status',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[30+ Hours Work] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[30+ Hours Work] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[30+ Hours Work]/5.0,0)*5 AS VARCHAR),'*') END AS '30+ Hours Work',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[16-29 Hours Work] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[16-29 Hours Work] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[16-29 Hours Work]/5.0,0)*5 AS VARCHAR),'*') END AS '16-29 Hours Work',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[5-15 Hours Work] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[5-15 Hours Work] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[5-15 Hours Work]/5.0,0)*5 AS VARCHAR),'*') END AS '5-15 Hours Work',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[1-4 Hours Work] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[1-4 Hours Work] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[1-4 Hours Work]/5.0,0)*5 AS VARCHAR),'*') END AS '1-4 Hours Work',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Hours Worked Not Stated] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Hours Worked Not Stated] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Hours Worked Not Stated]/5.0,0)*5 AS VARCHAR),'*') END AS 'Hours Worked Not Stated',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Not Employed] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Not Employed] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Not Employed]/5.0,0)*5 AS VARCHAR),'*') END AS 'Not Employed',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Hours Worked Not Known] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Hours Worked Not Known] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Hours Worked Not Known]/5.0,0)*5 AS VARCHAR),'*') END AS 'Hours Worked Not Known',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Other/Invalid Hours Worked] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Other/Invalid Hours Worked] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Other/Invalid Hours Worked]/5.0,0)*5 AS VARCHAR),'*') END AS 'Other/Invalid Hours Worked',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (u.[Monthly Access] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND u.[Monthly Access] <5 THEN '*' ELSE ISNULL(CAST(ROUND(u.[Monthly Access]/5.0,0)*5 AS VARCHAR),'*') END AS 'Monthly Access',
	CASE WHEN u.[Organisation Type] = 'England' THEN CAST (y.[YTDAccess] AS VARCHAR) WHEN u.[Organisation Type] <> 'England' AND y.[YTDAccess] <5 THEN '*' ELSE ISNULL(CAST(ROUND(y.[YTDAccess]/5.0,0)*5 AS VARCHAR),'*') END AS 'YTD Access',
	r.[Access] AS 'Quarterly Return Access Count',
	r.[Access Target 2019/20],
	r.[Referrals] AS 'Quarterly Return Referral Count'

INTO [NHSE_Sandbox_MentalHealth].[dbo].[Dashboard_IPS]

FROM #Unsupp u

LEFT JOIN #YTD y ON u.UniqMonthID = y.UniqMonthID AND u.[Organisation ID] = y.Orgcode

LEFT JOIN #Return r ON u.ReportingPeriodEnd = r.[End RP] AND u.[Organisation ID] = r.Orgcode

WHERE u.[Organisation Name] IS NOT NULL AND u.[Organisation Name] <> 'NHS_England'

ORDER BY 3,4,2