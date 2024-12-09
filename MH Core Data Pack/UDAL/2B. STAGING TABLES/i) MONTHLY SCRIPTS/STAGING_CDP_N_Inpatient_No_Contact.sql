/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CODE FOR CORE DATA PACK DASHBOARD *TEMPLATE*

MEASURE NAME:    CDP_N01	MHSDS Inpatient No Contact BME
				CDP_N02	MHSDS Inpatient No Contact White British


BACKGROUND INFO: no provider data, need to run extra months for rolling quarter calc (accounted for in time period)

INPUT:			 
			     MHDInternal.PreProc_Inpatients
				 MHDInternal.PreProc_Activity
				 MHDInternal.PreProc_Header
				 [Internal_Reference].[ComCodeChanges]
			     [Reporting].[Ref_ODS_Commissioner_Hierarchies]
				 [Internal_Reference].[Provider_Successor]
				 [Reporting].[Ref_ODS_Provider_Hierarchies]
				 [MHDInternal].[REFERENCE_CDP_Trajectories]
				 [MHDInternal].[REFERENCE_CDP_Plans]
				 [MHDInternal].[REFERENCE_CDP_Standards]
				 [Internal_Reference].[Date_Full]
				 [UKHD_Data_Dictionary].[Mental_Health_Admitted_Patient_Classification_SCD]

OUTPUT:			 [insert output tables]

WRITTEN BY:		 JADE SYKES    06/2023

UPDATES: 		 KIRSTY WALKER 07/12/2023 Change @RPEnd to remove "where Der_MostRecentFlag = 'Y'" FOR DEC-23 CHANGE TO SINGLE SUBMISSION WINDOW 
								          (THERE USE TO BE A PROVISIONAL DATA WINDOW Y for performance data, P for provisional data BUT NOW WE JUST PULL OUT MAX REPORTING_PERIOD)

>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PRE STEPS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- For metrics which we need to re-run the whole of the current FY each month use this (MHSDS from patient level)

DECLARE @RP_START INT
DECLARE @RP_END INT
DECLARE @RP_STARTDATE DATE
DECLARE @RP_ENDDATE DATE
DECLARE @i INT

SET @RP_ENDDATE = (SELECT MAX([ReportingPeriodEndDate]) FROM MHDInternal.[PreProc_Header])

SET @RP_END = (SELECT UniqMonthID FROM MHDInternal.PreProc_Header WHERE ReportingPeriodEndDate = @RP_ENDDATE)

SET @i = 
CASE WHEN MONTH(@RP_ENDDATE) = 4 THEN -15 -- added 3 to each of these numbers so first month you need is a complete rolling quarter
 WHEN MONTH(@RP_ENDDATE) = 5 THEN -4
 WHEN MONTH(@RP_ENDDATE) = 6 THEN -5
 WHEN MONTH(@RP_ENDDATE) = 7 THEN -6
 WHEN MONTH(@RP_ENDDATE) = 8 THEN -7
 WHEN MONTH(@RP_ENDDATE) = 9 THEN -8
 WHEN MONTH(@RP_ENDDATE) = 10 THEN -9
 WHEN MONTH(@RP_ENDDATE) = 11 THEN -10
 WHEN MONTH(@RP_ENDDATE) = 12 THEN -11
 WHEN MONTH(@RP_ENDDATE) = 1 THEN -12
 WHEN MONTH(@RP_ENDDATE) = 2 THEN -13
 WHEN MONTH(@RP_ENDDATE) = 3 THEN -14
END

SET @RP_STARTDATE = (SELECT DATEFROMPARTS(YEAR((SELECT DATEADD(mm,@i,@RP_ENDDATE))),MONTH((SELECT DATEADD(mm,@i,@RP_ENDDATE))),1) )
SET @RP_START = (SELECT UniqMonthID FROM MHDInternal.PreProc_Header WHERE ReportingPeriodStartDate = @RP_STARTDATE)

PRINT @RP_STARTDATE
PRINT @RP_START
PRINT @RP_ENDDATE
PRINT @RP_END
PRINT @i

--- Delete any rows which already exist in output table for this time period
DELETE FROM MHDInternal.[STAGING_CDP_N_Inpatient_No_Contact]
WHERE [Reporting_Period] BETWEEN @RP_STARTDATE AND @RP_ENDDATE

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 1A: WRANGLE THE RAW DATA INTO THE REQUIRED NUMERATOR, DENOMINATOR AND PERCENTAGE TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- GET ALL ADMISSIONS IN REPORTING PERIOD 	

SELECT	
	i.UniqMonthID
	,i.UniqHospProvSpellNum
	,i.Person_ID
	,r.EthnicCategory
	,CASE WHEN r.EthnicCategory NOT IN ('A','99','-1') THEN 1 ELSE 0 END as NotWhiteBritish 
	,CASE WHEN r.EthnicCategory = 'A' THEN 1 ELSE 0 END as WhiteBritish
	,i.OrgIDProv 
	,r.Der_SubICBCode
	,r.OrgIDCCGRes
	,o.Region_Name
	,CASE WHEN o.Region_Code IN ('REG001','REG002') THEN r.OrgIDCCGRes ELSE r.Der_SubICBCode END AS SubICBCode 
	,i.StartDateHospProvSpell
	,i.StartTimeHospProvSpell 
	,d.Fin_Quarter_Qq_Fin_Year_YYYY_dash_YY AS FY_Quarter
	,DATEADD(MONTH, DATEDIFF(MONTH, 0, i.StartDateHospProvSpell), 0) AS Adm_month
	,ia.HospitalBedTypeMH
	,ISNULL(b.Main_Description_60_Chars,'Missing/Invalid') AS BedType
	,r.AgeServReferRecDate
	,r.UniqServReqID 
	,r.UniqMonthID AS RefMonth
	,r.RecordNumber AS RefRecordNumber 
	,ROW_NUMBER()OVER(PARTITION BY i.UniqHospProvSpellNum ORDER BY r.UniqMonthID DESC, r.RecordNumber DESC) AS RN --- added because joining to refs produces some duplicates 
	
INTO MHDInternal.[TEMP_CDP_N_Inpatient_No_Contact_Admissions_Staging]  	
	
FROM MHDInternal.PreProc_Inpatients i 	

LEFT JOIN MHDInternal.[PreProc_Inpatients] ia ON i.UniqHospProvSpellNum = ia.UniqHospProvSpellNum AND i.Person_ID = ia.Person_ID AND i.UniqServReqID = ia.UniqServReqID  ----- records are partitioned on spell, person and ref : therefore have joined on spell, person and ref	
	AND ia.Der_FirstWardStayRecord = 1 ---- ward stay at admission
	
LEFT JOIN MHDInternal.PreProc_Referral r ON i.RecordNumber = r.RecordNumber AND i.Person_ID = r.Person_ID AND i.UniqServReqID = r.UniqServReqID AND (r.LADistrictAuth LIKE 'E%' OR r.LADistrictAuth IS NULL OR r.LADistrictAuth = '') 	
	
LEFT JOIN [UKHD_Data_Dictionary].[Mental_Health_Admitted_Patient_Classification_SCD] b ON ia.HospitalBedTypeMH = b.Main_Code_Text COLLATE DATABASE_DEFAULT AND Is_Latest = 1	
	
LEFT JOIN [Internal_Reference].[Date_Full] d ON i.StartDateHospProvSpell = d.Full_Date 	

LEFT JOIN [Reporting].[Ref_ODS_Commissioner_Hierarchies] o ON r.Der_SubICBCode = o.Organisation_Code
	
WHERE i.StartDateHospProvSpell BETWEEN @RP_STARTDATE AND @RP_ENDDATE	
AND i.UniqMonthID BETWEEN @RP_START AND @RP_END	
AND ia.HospitalBedTypeMH IN ('10','11','12','200','201','202') --- adult/older acute and PICU admissions only  	
AND i.SourceAdmCodeHospProvSpell NOT IN ('49','53','87') --- excluding people transferred from other MH inpatient settings 	

--- ADD IN SUBICB, ICB, AND REGIONS 

SELECT 
	i.UniqMonthID
	,i.UniqHospProvSpellNum
	,i.Person_ID
	,i.EthnicCategory
	,i.NotWhiteBritish 
	,i.WhiteBritish
	,i.OrgIDProv 
	,o1.Organisation_Name AS Provider_Name
	,ISNULL(o2.Region_Code,'Missing/Invalid') AS Region_Code --- regions taken from CCG rather than provider 
	,ISNULL(o2.Region_Name,'Missing/Invalid') AS Region_Name
	,COALESCE(cc.New_Code,i.SubICBCode,'Missing/Invalid') AS SubICBCode
	,COALESCE(o2.Organisation_Name,'Missing/Invalid') AS [SubICB name]
	,COALESCE(o2.STP_Code,'Missing/Invalid') AS ICB_Code
	,COALESCE(o2.STP_Name,'Missing/Invalid') AS [ICB_name]
	,i.StartDateHospProvSpell
	,i.StartTimeHospProvSpell 
	,i.FY_Quarter
	,i.Adm_month
	,i.HospitalBedTypeMH
	,i.BedType
	,i.AgeServReferRecDate
	,i.UniqServReqID 
	,i.RefMonth
	,i.RefRecordNumber 
	,i.RN

INTO MHDInternal.[TEMP_CDP_N_Inpatient_No_Contact_Admissions]  

FROM MHDInternal.[TEMP_CDP_N_Inpatient_No_Contact_Admissions_Staging] i

LEFT JOIN [Internal_Reference].[Provider_Successor] ps on i.OrgIDProv = ps.Prov_original 
LEFT JOIN [Reporting].[Ref_ODS_Provider_Hierarchies] o1 ON COALESCE(ps.Prov_Successor, i.OrgIDProv) = o1.Organisation_Code 	
	
LEFT JOIN [Internal_Reference].[ComCodeChanges] cc ON i.SubICBCode = cc.Org_Code
LEFT JOIN [Reporting].[Ref_ODS_Commissioner_Hierarchies] o2 ON COALESCE(cc.New_Code,i.SubICBCode) = o2.Organisation_Code	


-- GET PREVIOUS CONTACTS FOR PEOPLE ADMITTED IN THE RP 

SELECT 	
	a.UniqHospProvSpellNum
	,a.OrgIDProv as Adm_OrgIDProv 
	,a.Person_ID
	,a.StartDateHospProvSpell
	,a.StartTimeHospProvSpell 
	,a.BedType
	,c.UniqServReqID 
	,c.Der_ActivityUniqID
	,c.OrgIDProv as Cont_OrgIDProv 
	,c.Der_ActivityType 
	,c.AttendOrDNACode 
	,c.ConsMediumUsed 
	,c.Der_ContactDate 
	,i.UniqHospProvSPellNum As Contact_spell --- to be removed 
	,DATEDIFF(DD, c.Der_ContactDate, a.StartDateHospProvSpell) AS TimeToAdm 
	,ROW_NUMBER() OVER(PARTITION BY a.UniqHospProvSpellNum ORDER BY c.Der_ContactDate DESC) AS RN --- order to get most contact prior referral for each hospital spell 
	
INTO MHDInternal.[TEMP_CDP_N_Inpatient_No_Contact_Prev_Contacts]
	
FROM MHDInternal.PreProc_Activity c 	
	
INNER JOIN MHDInternal.[TEMP_CDP_N_Inpatient_No_Contact_Admissions]   a ON c.Person_ID = a.Person_ID --- same person 	
	AND DATEDIFF(DD, c.Der_ContactDate, a.StartDateHospProvSpell) <= 365 --- contact up to 1yr before admission
	AND DATEDIFF(DD, c.Der_ContactDate, a.StartDateHospProvSpell) > 2 --- exclude contacts in two days before admission 
	AND a.RN = 1 
	
LEFT JOIN MHDInternal.PreProc_Inpatients i ON c.Person_ID = i.Person_ID AND c.UniqServReqID = i.UniqServReqID AND i.Der_HospSpellRecordOrder =1 --- to get contacts as part of hospital spell 	
	AND i.UniqHospProvSpellNum IS NULL --- exclude contacts as part of a hospital spell 
	
WHERE 	
(c.[Der_ActivityType] = 'DIRECT' AND c.AttendOrDNACode IN ('5','6') AND c.ConsMediumUsed NOT IN ('05','06')) 	
OR c.[Der_ActivityType] = 'INDIRECT'	

-- GET SubICB ADMISSIONS, AND ADMISSIONS FOR PEOPLE KNOWN TO SERVICES	

SELECT 
	a.Adm_month AS ReportingPeriodStartDate
	,a.FY_Quarter
	,a.Region_Code
	,a.Region_Name
	,a.OrgIDProv
	,a.Provider_Name
	,a.SubICBCode
	,a.[SubICB name]
	,a.ICB_Code
	,a.[ICB_Name]
	,CASE 
		WHEN a.WhiteBritish = 1 THEN 'White British' 
		WHEN a.NotWhiteBritish = 1 THEN 'Non-white British' 
		ELSE 'Missing/invalid' 
	END as 'Ethnicity' 
	,COUNT(*) AS Admissions  
	,SUM(CASE WHEN p.UniqHospProvSpellNum IS NULL THEN 1 ELSE 0 END) as NoContact

INTO MHDInternal.[TEMP_CDP_N_Inpatient_Agg]

FROM MHDInternal.[TEMP_CDP_N_Inpatient_No_Contact_Admissions]   a

LEFT JOIN MHDInternal.[TEMP_CDP_N_Inpatient_No_Contact_Prev_Contacts] p ON a.UniqHospProvSpellNum = p.UniqHospProvSpellNum AND p.RN = 1 

WHERE a.RN = 1 

GROUP BY a.Adm_month,a.FY_Quarter, a.Region_Code, a.Region_Name, a.OrgIDProv, a.Provider_Name, a.SubICBCode, a.[SubICB name], a.ICB_Code, a.[ICB_Name], 
CASE 
		WHEN a.WhiteBritish = 1 THEN 'White British' 
		WHEN a.NotWhiteBritish = 1 THEN 'Non-white British' 
		ELSE 'Missing/invalid' 
	END

-- GET SubICB ADMISSIONS, AND ADMISSIONS FOR PEOPLE KNOWN TO SERVICES	

SELECT 
	'England' AS Org_Type 
	,'ENG' AS Org_Code
	,'England' AS Org_Name
	,'NA' AS ICB_Code
	,'NA' AS ICB_Name
	,'NA' AS Region_Code
	,'NA' AS Region_Name
	,ReportingPeriodStartDate
	--,SUM(Admissions) AS Admissions
	--,SUM(NoContact) AS Nocontact
	,SUM(CASE WHEN Ethnicity = 'White British' THEN Admissions ELSE 0 END) as WhiteBritish_Admissions
	,SUM(CASE WHEN Ethnicity = 'White British' THEN NoContact ELSE 0 END) as WhiteBritish_NoContact
	,SUM(CASE WHEN Ethnicity = 'Non-white British' THEN Admissions ELSE 0 END) as NonWhite_Admissions
	,SUM(CASE WHEN Ethnicity = 'Non-white British' THEN NoContact ELSE 0 END) as NonWhite_NoContact

INTO MHDInternal.[TEMP_CDP_N_Inpatient_Output]

FROM MHDInternal.[TEMP_CDP_N_Inpatient_Agg]  

GROUP BY ReportingPeriodStartDate 

UNION ALL 

SELECT 
	'Region' AS Org_Type 
	,Region_Code AS Org_Code
	,Region_Name AS Org_Name
	,'NA' AS ICB_Code
	,'NA' AS ICB_Name
	,Region_Code
	,Region_Name
	,ReportingPeriodStartDate
	--,SUM(Admissions) AS Admissions
	--,SUM(NoContact) AS Nocontact
	,SUM(CASE WHEN Ethnicity = 'White British' THEN Admissions ELSE 0 END) as WhiteBritish_Admissions
	,SUM(CASE WHEN Ethnicity = 'White British' THEN NoContact ELSE 0 END) as WhiteBritish_NoContact
	,SUM(CASE WHEN Ethnicity = 'Non-white British' THEN Admissions ELSE 0 END) as NonWhite_Admissions
	,SUM(CASE WHEN Ethnicity = 'Non-white British' THEN NoContact ELSE 0 END) as NonWhite_NoContact

FROM MHDInternal.[TEMP_CDP_N_Inpatient_Agg]  

GROUP BY Region_Code, Region_Name, ReportingPeriodStartDate 

UNION ALL 

SELECT 
	'ICB' AS Org_Type 
	,ICB_Code AS Org_Code
	,[ICB_Name] AS Org_Name
	,[ICB_Code] 
	,[ICB_Name] 
	,Region_Code 
	,Region_Name 
	,ReportingPeriodStartDate
	--,SUM(Admissions) AS Admissions
	--,SUM(NoContact) AS Nocontact
	,SUM(CASE WHEN Ethnicity = 'White British' THEN Admissions ELSE 0 END) as WhiteBritish_Admissions
	,SUM(CASE WHEN Ethnicity = 'White British' THEN NoContact ELSE 0 END) as WhiteBritish_NoContact
	,SUM(CASE WHEN Ethnicity = 'Non-white British' THEN Admissions ELSE 0 END) as NonWhite_Admissions
	,SUM(CASE WHEN Ethnicity = 'Non-white British' THEN NoContact ELSE 0 END) as NonWhite_NoContact

FROM MHDInternal.[TEMP_CDP_N_Inpatient_Agg] 

GROUP BY [ICB_Code], [ICB_Name], Region_Code, Region_Name, ReportingPeriodStartDate 

UNION ALL 

SELECT 
	'SubICB' AS Org_Type 
	,SubICBCode AS Org_Code
	,[SubICB name] AS Org_Name
	,[ICB_Code] 
	,[ICB_Name] 
	,Region_Code 
	,Region_Name 
	,ReportingPeriodStartDate
	--,SUM(Admissions) AS Admissions
	--,SUM(NoContact) AS Nocontact
	,SUM(CASE WHEN Ethnicity = 'White British' THEN Admissions ELSE 0 END) as WhiteBritish_Admissions
	,SUM(CASE WHEN Ethnicity = 'White British' THEN NoContact ELSE 0 END) as WhiteBritish_NoContact
	,SUM(CASE WHEN Ethnicity = 'Non-white British' THEN Admissions ELSE 0 END) as NonWhite_Admissions
	,SUM(CASE WHEN Ethnicity = 'Non-white British' THEN NoContact ELSE 0 END) as NonWhite_NoContact

FROM MHDInternal.[TEMP_CDP_N_Inpatient_Agg] 

GROUP BY SubICBCode, [SubICB name], [ICB_Code], [ICB_Name], Region_Code, Region_Name, ReportingPeriodStartDate 

--CREATE ROLLING QUARTERLY COUNTS 

SELECT
	Org_Type
	,Org_Code
	,[Org_Name]
	,ICB_Code
	,ICB_Name
	,Region_Code
	,Region_Name
	,ReportingPeriodStartDate AS [Reporting_Period]
	--,SUM(SUM(Admissions)) OVER (PARTITION BY Org_Type, Org_Code, OrgName ORDER BY ReportingPeriodStartDate ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS Admissions 
	--,SUM(SUM(Nocontact)) OVER (PARTITION BY Org_Type, Org_Code, OrgName ORDER BY ReportingPeriodStartDate ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS Nocontact 
	,SUM(SUM(WhiteBritish_Admissions)) OVER (PARTITION BY Org_Type, Org_Code, Org_Name ORDER BY ReportingPeriodStartDate ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [MHSDS Inpatient No Contact White British Denominator]
	,SUM(SUM(WhiteBritish_NoContact)) OVER (PARTITION BY Org_Type, Org_Code, Org_Name ORDER BY ReportingPeriodStartDate ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [MHSDS Inpatient No Contact White British Numerator]
	,SUM(SUM(NonWhite_Admissions)) OVER (PARTITION BY Org_Type, Org_Code, Org_Name ORDER BY ReportingPeriodStartDate ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [MHSDS Inpatient No Contact BME Denominator] 
	,SUM(SUM(NonWhite_NoContact)) OVER (PARTITION BY Org_Type, Org_Code, Org_Name ORDER BY ReportingPeriodStartDate ROWS BETWEEN 2 PRECEDING AND CURRENT ROW) AS [MHSDS Inpatient No Contact BME Numerator]

INTO MHDInternal.[TEMP_CDP_N_Inpatient_RAW]

FROM MHDInternal.[TEMP_CDP_N_Inpatient_Output] 

GROUP BY Org_Type, Org_Code, Org_Name,ICB_Code
	,ICB_Name
	,Region_Code
	,Region_Name, ReportingPeriodStartDate

-- Cast all as float ready for unpivot and pull only complete data points

SELECT [Reporting_Period]
,[Org_Type]
,[Org_Code]
,[Org_Name]
,[ICB_Code]
,[ICB_Name]
,[Region_Code]
,[Region_Name]
,CAST([MHSDS Inpatient No Contact White British Denominator] AS FLOAT) AS [MHSDS Inpatient No Contact White British Denominator]
,CAST([MHSDS Inpatient No Contact White British Numerator] AS FLOAT) AS [MHSDS Inpatient No Contact White British Numerator] 
,CAST([MHSDS Inpatient No Contact BME Denominator] AS FLOAT) AS [MHSDS Inpatient No Contact BME Denominator]
,CAST([MHSDS Inpatient No Contact BME Numerator] AS FLOAT) AS [MHSDS Inpatient No Contact BME Numerator] 

INTO MHDInternal.[TEMP_CDP_N_Inpatient_RAW_2]
FROM MHDInternal.[TEMP_CDP_N_Inpatient_RAW]
WHERE [Reporting_Period] BETWEEN DATEADD(mm,3,@RP_STARTDATE) AND @RP_ENDDATE

--unpivot to new structure

SELECT [Reporting_Period]
,[Measure_Name_Type]
,[Org_Type]
,[Org_Code]
,[Org_Name]
,[ICB_Code]
,[ICB_Name]
,[Region_Code]
,[Region_Name]
,[Measure_Value]
INTO MHDInternal.[TEMP_CDP_N_Inpatient_RAW_3]
FROM   
   (SELECT *
   FROM MHDInternal.[TEMP_CDP_N_Inpatient_RAW_2]) p  
UNPIVOT  
   ( [Measure_Value] FOR [Measure_Name_Type] IN   
      (
[MHSDS Inpatient No Contact White British Denominator]
,[MHSDS Inpatient No Contact White British Numerator]
,[MHSDS Inpatient No Contact BME Denominator]
,[MHSDS Inpatient No Contact BME Numerator]
)  
)AS unpvt;  

-- Split out measure name and measure type

SELECT [Reporting_Period]
,CASE WHEN [Measure_Name_Type] LIKE '%BME%' THEN 'CDP_N01'
WHEN [Measure_Name_Type] LIKE '%White%' THEN 'CDP_N02' END AS CDP_Measure_ID
,CASE WHEN [Measure_Name_Type] LIKE '%BME%' THEN 'MHSDS Inpatient No Contact BME'
WHEN [Measure_Name_Type] LIKE '%White%' THEN 'MHSDS Inpatient No Contact White British' END AS CDP_Measure_Name
,[Org_Type]
,[Org_Code]
,[Org_Name]
,[ICB_Code]
,[ICB_Name]
,[Region_Code]
,[Region_Name]
,CASE WHEN [Measure_Name_Type] LIKE '%Numerator%' THEN 'Numerator'
WHEN [Measure_Name_Type] LIKE '%Denominator%' THEN 'Denominator' END AS Measure_Type
,[Measure_Value]
INTO MHDInternal.[TEMP_CDP_N_Inpatient_MASTER]
FROM MHDInternal.[TEMP_CDP_N_Inpatient_RAW_3] f

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 2: REALLOCATIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Get Data for orgs in time periods which need reallocatings & put rest of data aside

-- Reallocations Data

--GET LIST OF UNIQUE REALLOCATIONS FOR ORGS minus bassetlaw
IF OBJECT_ID ('MHDInternal.[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw]') IS NOT NULL
DROP TABLE MHDInternal.[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw]

SELECT DISTINCT [From] COLLATE database_default as Orgs
  INTO MHDInternal.[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw]
  FROM MHDInternal.[REFERENCE_CDP_Boundary_Population_Changes]
 WHERE Bassetlaw_Indicator = 0

UNION

SELECT DISTINCT [Add] COLLATE database_default as Orgs
  FROM MHDInternal.[REFERENCE_CDP_Boundary_Population_Changes]
 WHERE Bassetlaw_Indicator = 0

-- Use this for if Bassetlaw_Indicator = 0 (bassetlaw has moved to new location)
SELECT * 
  INTO MHDInternal.[TEMP_CDP_N_Inpatient_Reallocations]
  FROM MHDInternal.[TEMP_CDP_N_Inpatient_MASTER]

 WHERE Org_Code IN (SELECT Orgs FROM MHDInternal.[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw])
   AND Reporting_Period <'2022-07-01'

--No change data

-- Use this for if Bassetlaw_Indicator = 0 (bassetlaw has moved to new location) 
SELECT * 
  INTO MHDInternal.[TEMP_CDP_N_Inpatient_No_Change]
  FROM MHDInternal.[TEMP_CDP_N_Inpatient_MASTER]
 WHERE Reporting_Period >='2022-07-01' 
    OR (Org_Code NOT IN (SELECT Orgs FROM MHDInternal.[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw])
   AND Reporting_Period <'2022-07-01' )

-- Calculate activity movement for donor orgs
SELECT 
	   r.Reporting_Period,
	   r.CDP_Measure_ID,
	   r.CDP_Measure_Name,
	   r.Org_Type,
	   r.Org_Code,
	   r.Measure_Type,
	   r.Measure_Value * Change as Measure_Value_Change,
	   [Add]

  INTO MHDInternal.[TEMP_CDP_N_Inpatient_Reallocations_Changes_From]
  FROM MHDInternal.[TEMP_CDP_N_Inpatient_Reallocations] r

INNER JOIN MHDInternal.[REFERENCE_CDP_Boundary_Population_Changes] c ON r.Org_Code = c.[From]
 WHERE Bassetlaw_Indicator = 1	--change depending on Bassetlaw mappings (0 or 1)

-- Sum activity movement for orgs gaining (need to sum for Midlands Y60 which recieves from 2 orgs)
SELECT 
	   r.Reporting_Period,
	   r.CDP_Measure_ID,
	   r.CDP_Measure_Name,
	   r.Org_Type,
	   [Add] as Org_Code,
	   r.Measure_Type,
	   SUM(Measure_Value_Change) as Measure_Value_Change

  INTO MHDInternal.[TEMP_CDP_N_Inpatient_Changes_Add]
  FROM MHDInternal.[TEMP_CDP_N_Inpatient_Reallocations_Changes_From] r

GROUP BY 
r.Reporting_Period,
r.CDP_Measure_ID,
r.CDP_Measure_Name,
r.Org_Type,
[Add],
r.Measure_Type

--Calculate new figures
-- From
SELECT 
	   r.Reporting_Period,
	   r.CDP_Measure_ID,
	   r.CDP_Measure_Name,
	   r.Org_Type,
	   r.Org_Code,
	   r.Org_Name,
	   r.ICB_Code,
	   r.ICB_Name,
	   r.Region_Code,
	   r.Region_Name,
	   r.Measure_Type,
	   r.Measure_Value - Measure_Value_Change as Measure_Value

  INTO MHDInternal.[TEMP_CDP_N_Inpatient_Reallocations_Final]
  FROM MHDInternal.[TEMP_CDP_N_Inpatient_Reallocations] r

INNER JOIN MHDInternal.[TEMP_CDP_N_Inpatient_Reallocations_Changes_From] c 
        ON r.Org_Code = c.Org_Code 
       AND r.Reporting_Period = c.Reporting_Period 
	   AND r.Measure_Type = c.Measure_Type 
	   AND r.CDP_Measure_Name = c.CDP_Measure_Name

UNION

--Add
SELECT 
	   r.Reporting_Period,
	   r.CDP_Measure_ID,
	   r.CDP_Measure_Name,
	   r.Org_Type,
	   r.Org_Code,
	   r.Org_Name,
	   r.ICB_Code,
	   r.ICB_Name,
	   r.Region_Code,
	   r.Region_Name,
	   r.Measure_Type,
	   r.Measure_Value + Measure_Value_Change as Measure_Value

  FROM MHDInternal.[TEMP_CDP_N_Inpatient_Reallocations] r

INNER JOIN MHDInternal.[TEMP_CDP_N_Inpatient_Changes_Add] c 
        ON r.Org_Code = c.Org_Code 
	   AND r.Reporting_Period = c.Reporting_Period 
	   AND r.Measure_Type = c.Measure_Type 
	   AND r.CDP_Measure_Name = c.CDP_Measure_Name

--Collate reallocations with no change data to create new 'master' table
SELECT * 
  INTO MHDInternal.[TEMP_CDP_N_Inpatient_Master_2]
  FROM MHDInternal.[TEMP_CDP_N_Inpatient_Reallocations_Final]

UNION

SELECT * 
  FROM MHDInternal.[TEMP_CDP_N_Inpatient_No_Change]

-- Calculate any percentages needed in the data
--Example script for this

SELECT 
	   a.Reporting_Period,
	   a.CDP_Measure_ID,
	   a.CDP_Measure_Name,
	   a.Org_Type,
	   a.Org_Code,
	   a.Org_Name,
	   a.ICB_Code,
	   a.ICB_Name,
	   a.Region_Code,
	   a.Region_Name,
	   CASE WHEN a.CDP_Measure_ID IN ('CDP_M07','CDP_M08') THEN 'Rate' 
			ELSE 'Percentage' 
	   END as Measure_Type, -- change metric names etc
	   ((CASE WHEN a.Measure_Value < 5 THEN NULL 
			 ELSE CAST(a.Measure_Value as FLOAT) 
			 END) 
		/
	   (CASE WHEN b.Measure_Value < 5 THEN NULL 
			 ELSE NULLIF(CAST(b.Measure_Value as FLOAT),0)
			 END) 
	    )*100  as Measure_Value

  INTO MHDInternal.[TEMP_CDP_N_Inpatient_Percentage_Calcs]
  FROM (SELECT * 
		  FROM MHDInternal.[TEMP_CDP_N_Inpatient_Master_2] 
		 WHERE Measure_Type = 'Numerator') a
INNER JOIN 
	   (SELECT * 
	      FROM MHDInternal.[TEMP_CDP_N_Inpatient_Master_2] 
		 WHERE Measure_Type = 'Denominator') b  
		    ON a.Reporting_Period = b.Reporting_Period 
		   AND a.Org_Code = b.Org_Code 
		   AND a.CDP_Measure_ID = b.CDP_Measure_ID
		   AND a.Org_Type = b.Org_Type

-- Collate Percentage calcs with rest of data
SELECT * 

  INTO MHDInternal.[TEMP_CDP_N_Inpatient_Final] 
  FROM MHDInternal.[TEMP_CDP_N_Inpatient_Master_2]

UNION

SELECT * 
  FROM MHDInternal.[TEMP_CDP_N_Inpatient_Percentage_Calcs]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
ADD IN MISSING SubICBs & ICBs
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Get list of SubICBs and ICBs
SELECT DISTINCT 
'SubICB' AS Org_Type
,Organisation_Code AS [Org_Code]
,[Organisation_Name] AS Org_Name
,STP_Code AS [ICB_Code]
,STP_Name AS [ICB_Name]
,Region_Code
,Region_Name
INTO MHDInternal.[TEMP_CDP_N_Inpatient_Org_List]
FROM [Reporting].[Ref_ODS_Commissioner_Hierarchies] WHERE Effective_To IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'

UNION

SELECT DISTINCT 
'ICB' AS Org_Type
,STP_Code AS [Org_Code]
,STP_Name AS Org_Name
,STP_Code AS [ICB_Code]
,STP_Name AS [ICB_Name]
,Region_Code
,Region_Name
FROM [Reporting].[Ref_ODS_Commissioner_Hierarchies] WHERE Effective_To IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'

-- Get list of all orgs and indicator combinations
SELECT * 
INTO MHDInternal.[TEMP_CDP_N_Inpatient_Org_List_Dates]
FROM MHDInternal.[TEMP_CDP_N_Inpatient_Org_List]
CROSS JOIN (SELECT DISTINCT [Reporting_Period], [CDP_Measure_ID],[CDP_Measure_Name],[Measure_Type] FROM MHDInternal.[TEMP_CDP_N_Inpatient_Final]      )_


-- Find list of only missing rows
SELECT 
d.Reporting_Period,
	   d.CDP_Measure_ID,
	   d.CDP_Measure_Name,
	   d.Org_Type,
	   d.Org_Code,
	   d.Org_Name,
	   d.ICB_Code,
	   d.ICB_Name,
	   d.Region_Code,
	   d.Region_Name,
	   d.Measure_Type,
	   NULL AS Measure_Value

	   INTO MHDInternal.[TEMP_CDP_N_Inpatient_Missing_Orgs]

	   FROM MHDInternal.[TEMP_CDP_N_Inpatient_Org_List_Dates] d

LEFT JOIN MHDInternal.[TEMP_CDP_N_Inpatient_Final]   e ON d.CDP_Measure_ID = e.CDP_Measure_ID  AND d.[Org_Type] = e.[Org_Type] AND d.CDP_Measure_ID = e.CDP_Measure_ID AND  d.[Reporting_Period] = e.[Reporting_Period] AND d.[Org_Code] = e.[Org_Code] AND d.[Measure_Type] = e.[Measure_Type] AND d.[Org_Type] = e.[Org_Type]
WHERE e.Org_Code IS NULL

-- Add into data
INSERT INTO MHDInternal.[TEMP_CDP_N_Inpatient_Final] 
SELECT * FROM MHDInternal.[TEMP_CDP_N_Inpatient_Missing_Orgs]




/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 3: ROUNDING & SUPRESSION (WHERE REQUIRED), ADDING TARGETS, % ACHIEVED
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

SELECT DISTINCT
	   f.Reporting_Period,
	   f.CDP_Measure_ID,
	   f.CDP_Measure_Name,
	   f.Org_Type,
	   f.Org_Code,
	   f.Org_Name,
	   f.ICB_Code,
	   f.ICB_Name,
	   f.Region_Code,
	   f.Region_Name,
	   f.Measure_Type,
	   -- This set-up uses 'standard' rounding and supression rules
	   CASE WHEN f.Measure_Type IN('Percentage') AND f.Org_Type = 'England' 
			THEN CAST(ROUND(Measure_Value,1) as FLOAT)/100 -- If rate and eng round to 1dp
		    WHEN f.Measure_Type IN('Percentage') AND f.Org_Type <> 'England' 
			THEN CAST(ROUND(Measure_Value,0) as FLOAT)/100 -- If rate and not Eng then round to 0dp
            WHEN f.Measure_Type IN('Rate') AND f.Org_Type = 'England' 
			THEN CAST(ROUND(Measure_Value,1) as FLOAT)
            WHEN f.Measure_Type IN('Rate') AND f.Org_Type <> 'England' 
			THEN CAST(ROUND(Measure_Value,0) as FLOAT)
			WHEN Measure_Value < 5 
			THEN NULL -- supressed values shown as NULL
			WHEN f.Org_Type = 'England' 
			THEN Measure_Value -- Counts for Eng no rounding
			ELSE CAST(ROUND(Measure_Value/5.0,0)*5 as FLOAT) 
	   END as Measure_Value,
	   s.[Standard],
	   l.[LTP_Trajectory_Rounded] AS [LTP_Trajectory],
	   CASE WHEN f.Measure_Type NOT IN ('Rate','Percentage','Numerator','Denominator') 
			THEN ROUND(CAST(Measure_Value as FLOAT)/NULLIF(CAST(l.LTP_Trajectory as FLOAT),0),2) 
			ELSE NULL 
	   END as LTP_Trajectory_Percentage_Achieved,
	   p.[Plan_Rounded] AS [Plan],
	   CASE WHEN f.Measure_Type NOT IN ('Rate','Percentage','Numerator','Denominator') 
			THEN ROUND(CAST(Measure_Value as FLOAT)/NULLIF(CAST(p.[Plan] as FLOAT),0),2) 
			ELSE NULL 
	   END as Plan_Percentage_Achieved,
	   s.Standard_STR,
	   l.LTP_Trajectory_STR,
	   p.Plan_STR

  INTO MHDInternal.[TEMP_CDP_N_Inpatient_Final_2] 
  FROM MHDInternal.[TEMP_CDP_N_Inpatient_Final]  f

LEFT JOIN MHDInternal.[Reference_CDP_LTP_Trajectories] l 
    ON f.Reporting_Period = l.Reporting_Period 
   AND f.Org_Code = l.Org_Code 
   AND f.CDP_Measure_ID = l.CDP_Measure_ID
   AND f.Measure_Type = l.Measure_Type

LEFT JOIN MHDInternal.[REFERENCE_CDP_Plans] p 
    ON f.Reporting_Period = p.Reporting_Period 
   AND f.Org_Code = p.Org_Code 
   AND f.CDP_Measure_ID = p.CDP_Measure_ID 
   AND f.Measure_Type = p.Measure_Type

LEFT JOIN MHDInternal.[REFERENCE_CDP_Standards] s 
    ON f.Reporting_Period = s.Reporting_Period 
   AND f.CDP_Measure_ID = s.CDP_Measure_ID 
   AND f.Measure_Type = s.Measure_Type



/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 4: ADD 'STR' VALUES & ISLATEST & LAST MODIFIED
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Set Is_Latest in current table as 0
UPDATE MHDInternal.STAGING_CDP_N_Inpatient_No_Contact
   SET Is_Latest = 0

--Determine latest month of data for is_Latest
SELECT MAX(Reporting_Period) as Reporting_Period 
  INTO MHDInternal.[TEMP_CDP_N_Inpatient_Is_Latest] 
  FROM MHDInternal.[TEMP_CDP_N_Inpatient_Final_2] 


INSERT INTO MHDInternal.[STAGING_CDP_N_Inpatient_No_Contact]
SELECT
	   EOMONTH(f.Reporting_Period) AS Reporting_Period, -- convert to reporting period end date
	   CASE WHEN i.Reporting_Period IS NOT NULL 
			THEN 1 
			ELSE 0 
	   END as Is_Latest,
	   f.CDP_Measure_ID,
	   f.CDP_Measure_Name,
	   f.Org_Type,
	   f.Org_Code,
	   f.Org_Name,
	   f.ICB_Code,
	   f.ICB_Name,
	   f.Region_Code,
	   f.Region_Name,
	   f.Measure_Type,
	   f.Measure_Value,
	   [Standard],
	   LTP_Trajectory,
	   LTP_Trajectory_Percentage_Achieved,
	   [Plan],
	   Plan_Percentage_Achieved,
		CASE WHEN e.[Org_Code] IS NOT NULL THEN '-' -- If this row was added in as a missing org then show '-'
			WHEN f.[Measure_Value] IS NULL THEN '*' 
			WHEN f.Measure_Type IN('Percentage') THEN CAST(f.[Measure_Value]*100 AS VARCHAR)+'%' 
			ELSE FORMAT(f.[Measure_Value],N'N0') END AS [Measure_Value_STR],
	   Standard_STR,
	   LTP_Trajectory_STR,
	   CAST(LTP_Trajectory_Percentage_Achieved*100 as varchar)+'%' as LTP_Trajectory_Percentage_Achieved_STR,
	   Plan_STR,
	   CAST(Plan_Percentage_Achieved*100 as varchar)+'%' as Plan_Percentage_Achieved_STR,
	   GETDATE() as Last_Modified

   FROM MHDInternal.[TEMP_CDP_N_Inpatient_Final_2]  f

LEFT JOIN MHDInternal.[TEMP_CDP_N_Inpatient_Is_Latest]  i ON f.Reporting_Period = i.Reporting_Period
LEFT JOIN MHDInternal.[TEMP_CDP_N_Inpatient_Missing_Orgs] e ON f.CDP_Measure_ID = e.CDP_Measure_ID AND f.[Reporting_Period] = e.[Reporting_Period] AND f.[Measure_Type] = e.[Measure_Type] AND f.[Org_Code] = e.[Org_Code] AND f.[Org_Type] = e.[Org_Type]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 5: QA - REMOVE UNSUPPORTED ORGS, CHECK FOR DUPLICATE ROWS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DELETE FROM MHDInternal.[STAGING_CDP_N_Inpatient_No_Contact]
 WHERE Region_Code LIKE 'REG%' 
	OR Org_Code IS NULL 
	OR (Org_Type = 'SubICB' 
   AND Org_Code NOT IN (SELECT DISTINCT Organisation_Code FROM [Reporting].[Ref_ODS_Commissioner_Hierarchies] WHERE Effective_To IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))
    OR (Org_Type = 'ICB' AND Org_Code NOT IN (SELECT DISTINCT STP_Code FROM [Reporting].[Ref_ODS_Commissioner_Hierarchies] WHERE [Effective_To] IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP')) 
	OR (Org_Type = 'Region' AND Org_Code NOT IN (SELECT DISTINCT Region_Code FROM [Reporting].[Ref_ODS_Commissioner_Hierarchies] WHERE [Effective_To] IS NULL AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))

-- Check for duplicate rows, this should return a blank table if none
SELECT DISTINCT 
	   a.Reporting_Period,
	   a.CDP_Measure_ID,
	   a.CDP_Measure_Name,
	   a.Measure_Type,
	   a.Org_Type,
	   a.Org_Code
  FROM
	   (SELECT 
			   Reporting_Period,
			   CDP_Measure_ID,
			   CDP_Measure_Name,
			   Measure_Type,
			   Org_Type,
			   Org_Code,
			   count(1) cnt
		 FROM MHDInternal.[STAGING_CDP_N_Inpatient_No_Contact]
         GROUP BY 
		 Reporting_Period,
		 CDP_Measure_ID,
		 CDP_Measure_Name,
		 Measure_Type,
		 Org_Type,
		 Org_Code
         HAVING count(1) > 1) a

-- Check for differences between new month and previous month data (nb this will look high for the YTD measures when April data comes in)

SELECT Latest_Reporting_Period, 
	   Previous_Reporting_Period, 
	   CDP_Measure_ID, 
	   CDP_Measure_Name, 
	   Measure_Type,
	   Org_Type,
	   Org_Code, 
	   Org_Name, 
	   Previous_Measure_Value_STR,
	   Latest_Measure_Value_STR,
	 --  Numerical_Change,
	 CASE WHEN Previous_Measure_Value_STR <> '-' AND Previous_Measure_Value_STR <> '*' AND (Latest_Measure_Value_STR = '-' OR Latest_Measure_Value_STR IS NULL) THEN '2 Data Missing - Latest'
	 WHEN Latest_Measure_Value_STR <> '-' AND Latest_Measure_Value_STR <> '*' AND (Previous_Measure_Value_STR = '-' OR Previous_Measure_Value_STR IS NULL) THEN '7 Data Missing - Previous'
		WHEN Previous_Measure_Value_STR = '*' AND Latest_Measure_Value_STR = '*' THEN '9 Supression - Both'
		WHEN Previous_Measure_Value_STR = '-' AND Latest_Measure_Value_STR = '-' THEN '8 Data Missing - Both'
		WHEN ((Measure_Type NOT IN ('Percentage','Rate') AND (Latest_Measure_Value < 100 OR Previous_Measure_Value < 100)) OR Previous_Measure_Value_STR = '*' OR Latest_Measure_Value_STR = '*')
		AND (Percentage_Change >= 0.5 OR Percentage_Change IS NULL) THEN '4 High Variation - Volatile Numbers'
		WHEN Percentage_Change >= 0.5 THEN '1 High Variation'
		WHEN Percentage_Change <= 0.1 THEN '5 Low Variation'
		WHEN ((Measure_Type NOT IN ('Percentage','Rate') AND (Latest_Measure_Value < 100 OR Previous_Measure_Value < 100)) OR Previous_Measure_Value_STR = '*' OR Latest_Measure_Value_STR = '*')
		AND (Percentage_Change < 0.5 OR Percentage_Change IS NULL) THEN '6 Moderate Variation - Volatile Numbers'
		WHEN Percentage_Change < 0.5 THEN '3 Moderate Variation'
		ELSE NULL END AS 'QA_Flag',
	   FORMAT(Percentage_Change,'P1') AS Percentage_Change


	   FROM (
SELECT 
	   latest.Reporting_Period AS Latest_Reporting_Period, 
	   previous.Reporting_Period AS Previous_Reporting_Period, 
	   latest.CDP_Measure_ID, 
	   latest.CDP_Measure_Name, 
	   latest.Measure_Type,
	   latest.Org_Type,
	   latest.Org_Code, 
	   latest.Org_Name, 
	   latest.Measure_Value as Latest_Measure_Value,
	   previous.Measure_Value as Previous_Measure_Value, 
	   ABS(latest.Measure_Value - previous.Measure_Value) as Numerical_Change,
	   previous.Measure_Value_STR AS Previous_Measure_Value_STR,
	   latest.Measure_Value_STR AS Latest_Measure_Value_STR,
	   CASE WHEN latest.Measure_Type = 'Percentage' 
			THEN ROUND(ABS(latest.Measure_Value - previous.Measure_Value),3)
			WHEN latest.Measure_Type <> 'Percentage' AND ABS(latest.Measure_Value - previous.Measure_Value) = 0 THEN 0
			ELSE -- percentage point change if comparing percentages
			ROUND(NULLIF(ABS(latest.Measure_Value - previous.Measure_Value),0)/NULLIF(latest.Measure_Value,0),1)
	   END as Percentage_Change

  FROM MHDInternal.[STAGING_CDP_N_Inpatient_No_Contact] latest

  LEFT JOIN MHDInternal.[REFERENCE_CDP_METADATA] meta 
	   ON latest.CDP_Measure_ID = meta.CDP_Measure_ID 

  LEFT JOIN MHDInternal.[STAGING_CDP_N_Inpatient_No_Contact] previous
	  ON latest.CDP_Measure_ID = previous.CDP_Measure_ID 
		  AND CASE WHEN meta.Update_Frequency = 'Monthly' THEN EOMONTH(DATEADD(mm, -1, latest.Reporting_Period ))
		  WHEN meta.Update_Frequency = 'Quarterly' THEN EOMONTH(DATEADD(mm, -3, latest.Reporting_Period )) 
		  WHEN meta.Update_Frequency = 'Annually' THEN EOMONTH(DATEADD(mm, -12, latest.Reporting_Period )) 
		  END = previous.Reporting_Period
		  AND latest.Measure_Type = previous.Measure_Type
		  AND latest.Org_Code = previous.Org_Code 
		  AND latest.Org_Type = previous.Org_Type

WHERE latest.Is_Latest = 1 )_

ORDER BY QA_Flag, CDP_Measure_Name, Org_Name, Org_Type, Percentage_Change DESC

--check table has updated okay
SELECT MAX(Reporting_Period)
  FROM MHDInternal.[STAGING_CDP_N_Inpatient_No_Contact]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 6: DROP TEMP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

	DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_No_Contact_Admissions_Staging]  
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_No_Contact_Admissions]  
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_No_Contact_Prev_Contacts]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_Agg]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_Output]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_RAW]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_RAW_2]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_RAW_3]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_MASTER]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_Reallocations]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_No_Change]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_Reallocations_Changes_From]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_Changes_Add]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_Reallocations_Final]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_Master_2]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_Percentage_Calcs]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_Final] 
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_Org_List]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_Org_List_Dates]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_Missing_Orgs]
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_Final_2] 
DROP TABLE MHDInternal.[TEMP_CDP_N_Inpatient_Is_Latest] 
