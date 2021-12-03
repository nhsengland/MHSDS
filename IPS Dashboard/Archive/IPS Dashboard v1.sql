/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
IPS ROUTINE REPORTING

CREATED BY CARL MONEY 16/07/18
UPDATE BY T-BIZNESS 21/12/18
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--SET VARIABLES

DECLARE @ENDRP INT
DECLARE @STARTRP INT

SET @ENDRP	= (SELECT MAX(UniqMonthID)
FROM [NHSE_MHSDS].[dbo].[MHS000Header]
WHERE FileType = 'Refresh')

SET @STARTRP = 1417 -- Apr 18

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ALL REFERRALS TO IPS SERVICES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Ref') IS NOT NULL
DROP TABLE #Ref

SELECT
	h.ReportingPeriodEndDate AS ReportingPeriodEnd,
	h.ReportingPeriodStartDate AS ReportingPeriodStart,
	r.Person_ID,
	r.UniqServReqID,
	r.OrgIDProv,
	o.Organisation_Name AS ProvName,
	m.OrgIDCCGRes,
	map.Organisation_Name AS CCGName,
	map.STP_Code_ODS,
	map.STP_Name,
	d.Fin_Year_Start,
	ROW_NUMBER () OVER (PARTITION BY r.Person_ID, r.UniqServReqID, d.Fin_Year_Start ORDER BY h.ReportingPeriodEndDate ASC) AS CumulativeCount
	
INTO #Ref

FROM  [NHSE_MHSDS].[dbo].[MHS101Referral] r 

INNER JOIN [NHSE_MHSDS].[dbo].[MHS000Header] h ON h.NHSEUniqSubmissionID = r.NHSEUniqSubmissionID

INNER JOIN [NHSE_MHSDS].[dbo].[MHS102ServiceTypeReferredTo] s ON r.UniqServReqID = s.UniqServReqID AND r.RecordNumber = s.RecordNumber AND s.ReferRejectionDate IS NULL AND s.ServTeamTypeRefToMH = 'D05'

LEFT JOIN [NHSE_MHSDS].[dbo].[MHS001MPI] m ON r.RecordNumber = m.RecordNumber

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Provider_Hierarchies o ON r.OrgIDProv = o.Organisation_Code

LEFT JOIN NHSE_Reference.dbo.tbl_Ref_ODS_Commissioner_Hierarchies map ON m.OrgIDCCGRes = map.Organisation_Code

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_Dates_Full] d ON h.ReportingPeriodEndDate = d.Full_Date

WHERE r.ReferralRequestReceivedDate >= '2016-01-01' AND r.UniqMonthID BETWEEN @STARTRP AND @ENDRP

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET FIRST INSTANCE OF A REFERRAL IN EACH FINANCIAL
YEAR
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#RefYTD') IS NOT NULL
DROP TABLE #RefYTD

SELECT
	r.ReportingPeriodEnd,
	r.Person_ID,
	r.UniqServReqID,
	r.OrgIDProv,
	r.ProvName,
	r.OrgIDCCGRes,
	r.CCGName,
	r.STP_Code_ODS,
	r.STP_Name,
	r.Fin_Year_Start,
	COUNT(r.UniqServReqID) OVER(PARTITION BY r.Fin_Year_Start, r.OrgIDProv ORDER BY r.ReportingPeriodEnd) RunningTotal

INTO #RefYTD

FROM #Ref r

WHERE CumulativeCount = 1

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
BUILD MASTER TABLE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('tempdb..#Master') IS NOT NULL
DROP TABLE #Master

SELECT 
	r.Fin_Year_Start AS 'Financial Year',	
	r.ReportingPeriodEnd,
	'Provider' AS 'Organisation Type',
	r.OrgIDProv AS 'Organisation Code', 
	r.ProvName AS 'Organisation Name', 
	COUNT(DISTINCT r.UniqServReqID) AS 'Referrals Submitted',
	MAX(r2.RunningTotal) AS 'Cumulative Referrals'

INTO #Master

FROM #Ref r 

INNER JOIN #RefYTD r2 ON r.OrgIDProv = r2.OrgIDProv AND r.ReportingPeriodEnd = r2.ReportingPeriodEnd

GROUP BY r.Fin_Year_Start,	r.ReportingPeriodEnd, r.OrgIDProv, r.ProvName 

UNION ALL

SELECT 
	r.Fin_Year_Start AS 'Financial Year',	
	r.ReportingPeriodEnd,
	'CCG' AS 'Organisation Type',
	r.OrgIDCCGRes AS 'Organisation Code', 
	r.CCGName AS 'Organisation Name', 
	COUNT(DISTINCT r.UniqServReqID) AS 'Referrals Submitted',
	MAX(r2.RunningTotal) AS 'Cumulative Referrals'

FROM #Ref r 

INNER JOIN #RefYTD r2 ON r.OrgIDCCGRes = r2.OrgIDCCGRes AND r.ReportingPeriodEnd = r2.ReportingPeriodEnd

GROUP BY r.Fin_Year_Start,	r.ReportingPeriodEnd, r.OrgIDCCGRes, r.CCGName 

UNION ALL

SELECT 
	r.Fin_Year_Start AS 'Financial Year',	
	r.ReportingPeriodEnd,
	'STP' AS 'Organisation Type',
	r.STP_Code_ODS AS 'Organisation Code', 
	r.STP_Name AS 'Organisation Name', 
	COUNT(DISTINCT r.UniqServReqID) AS 'Referrals Submitted',
	MAX(r2.RunningTotal) AS 'Cumulative Referrals'

FROM #Ref r 

INNER JOIN #RefYTD r2 ON r.STP_Code_ODS = r2.STP_Code_ODS AND r.ReportingPeriodEnd = r2.ReportingPeriodEnd

GROUP BY r.Fin_Year_Start,	r.ReportingPeriodEnd, r.STP_Code_ODS, r.STP_Name 

UNION ALL

SELECT 
	r.Fin_Year_Start AS 'Financial Year',	
	r.ReportingPeriodEnd,
	'ENGLAND' AS 'Organisation Type',
	'ENG' AS 'Organisation Code', 
	'ENGLAND' AS 'Organisation Name', 
	COUNT(DISTINCT r.UniqServReqID) AS 'Referrals Submitted',
	MAX(r2.RunningTotal) AS 'Cumulative Referrals'

FROM #Ref r 

INNER JOIN 
(SELECT
	r.ReportingPeriodEnd,
	SUM(r.RunningTotal) AS RunningTotal
FROM 
	(SELECT DISTINCT
		ReportingPeriodEnd,
		OrgIDProv,
		RunningTotal	
	FROM #RefYTD) r
GROUP BY r.ReportingPeriodEnd) r2 ON r.ReportingPeriodEnd = r2.ReportingPeriodEnd

GROUP BY r.Fin_Year_Start,	r.ReportingPeriodEnd

SELECT * 
--INTO nhse_sandbox_mentalHealth.dbo.Dashboard_IPS
FROM #Master 

WHERE [Organisation Name] IS NOT NULL
