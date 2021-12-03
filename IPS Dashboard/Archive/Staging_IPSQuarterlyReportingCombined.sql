IF OBJECT_ID ('tempdb..#ReferralsMHSDSYTD') IS NOT NULL
DROP TABLE #ReferralsMHSDSYTD

SELECT TOP 1000 
a.Region_Code,
a.Region_Name,
a.STP_Code,
a.STP_Name,
SUM(a.MeasureValue) AS TotalReferred
INTO #ReferralsMHSDSYTD
FROM NHSE_Sandbox_MentalHealth.dbo.Dashboard_IPS_rebuild a
WHERE a.MeasureName = 'NewReferrals' AND ReportingPeriodEnd BETWEEN '2020-04-01' AND '2020-09-30'
GROUP BY a.Region_Code, a.Region_Name, a.STP_Code, a.STP_Name

-----

IF OBJECT_ID ('tempdb..#AccessMHSDSYTD') IS NOT NULL
DROP TABLE #AccessMHSDSYTD

SELECT TOP 1000 
b.Region_Code,
b.Region_Name,
b.STP_Code,
b.STP_Name,
SUM(b.MeasureValue) AS TotalAccessed
INTO #AccessMHSDSYTD
FROM NHSE_Sandbox_MentalHealth.dbo.Dashboard_IPS_rebuild b
WHERE b.MeasureName = 'TotalAccessed' AND ReportingPeriodEnd BETWEEN '2020-04-01' AND '2020-09-30'
GROUP BY b.Region_Code, b.Region_Name, b.STP_Code, b.STP_Name


-----

IF OBJECT_ID ('tempdb..#FYAccessMHSDSYTD') IS NOT NULL
DROP TABLE #FYAccessMHSDSYTD

SELECT TOP 1000 
b.Region_Code,
b.Region_Name,
b.STP_Code,
b.STP_Name,
SUM(b.MeasureValue) AS FYTotalAccessed
INTO #FYAccessMHSDSYTD
FROM NHSE_Sandbox_MentalHealth.dbo.Dashboard_IPS_rebuild b
WHERE b.MeasureName = 'FYTotalAccessed' AND ReportingPeriodEnd BETWEEN '2020-04-01' AND '2020-09-30'
GROUP BY b.Region_Code, b.Region_Name, b.STP_Code, b.STP_Name

-----

IF OBJECT_ID ('tempdb..#ReturnsYTD') IS NOT NULL
DROP TABLE #ReturnsYTD

SELECT 
c.[End RP],
c.STP_Code_ODS,
c.Region_Code,
c.Referrals,
c.Access,
c.[Access Target 2019/20]
INTO #ReturnsYTD
FROM [NHSE_Sandbox_MentalHealth].[dbo].[Staging_IPSQuarterlyReporting] c
WHERE c.[End RP] = '2020-09-30'

-----

DROP TABLE NHSE_Sandbox_MentalHealth.dbo.Staging_IPSQuarterlyReportingCombined

SELECT 
a.Region_Code,
a.Region_Name,
a.STP_Code,
a.STP_Name,
a.TotalReferred AS MHSDSReferrals,
b.TotalAccessed AS MHSDSAccessed,
d.FYTotalAccessed AS MHSDSFYAccessed,
c.Referrals AS ReturnReferrals,
c.Access AS ReturnAccessed,
c.[Access Target 2019/20] AS AccessTarget202021,
c.[End RP]
INTO NHSE_Sandbox_MentalHealth.dbo.Staging_IPSQuarterlyReportingCombined
FROM #ReferralsMHSDSYTD a
LEFT JOIN #AccessMHSDSYTD b ON a.Region_Code = b.Region_Code AND a.STP_Code = b.STP_Code
LEFT JOIN #ReturnsYTD c ON a.STP_Code = c.STP_Code_ODS AND a.Region_Code = c.Region_Code 
LEFT JOIN #FYAccessMHSDSYTD d ON a.Region_Code = d.Region_Code AND a.STP_Code = d.STP_Code
