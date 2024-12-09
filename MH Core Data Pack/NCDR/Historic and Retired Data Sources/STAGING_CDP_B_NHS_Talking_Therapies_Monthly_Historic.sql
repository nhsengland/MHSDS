/***************************
CODE FOR CORE DATA PACK DASHBOARD

MEASURE NAME(s): CDP_B01: NHS Talking Therapies 18 Week Waits
			     CDP_B02: NHS Talking Therapies 6 Week Waits
				 CDP_B03: NHS Talking Therapies 1st-2nd Treatment >90 days
				 CDP_B04: NHS Talking Therapies Access
				 CDP_B05: NHS Talking Therapies Recovery

MEASURE DESCRIPTION(s):
				 CDP_B01: Proportion of referrals that finished a course of treatment in the reporting period that waited 126 days or less for first treatment expressed as a percentage
			     CDP_B02: Proportion of referrals that finished a course of treatment in the reporting period that waited 42 days or less for first treatment expressed as a percentage
				 CDP_B03: The proportion of people who waited over 90 days between first and second treatment appointment (where the second treatment appointment occurred within the month) in the reporting period. 
						  The primary purpose of this indicator is to measure the number of people who have waited more than 90 days between first and second appointments.  
						  There should be no in treatment pathway waits (where the person has an early appointment but is then put on an ‘internal’ waiting list before a full course of treatment starts). 
						  There should be appropriate measures taken to reduce the numbers of people who have waited over 90 days for a second appointment. 
				 CDP_B04: The number of people who enter NHS funded treatment with IAPT Services in the reporting period (FirstTreatment)
				 CDP_B05: The proportion of people who have attended at least two treatment contacts and are moving to recovery (defined as those who at initial assessment achieved "caseness” and at final session did not) in the reporting period. 
						  Column name in the IAPT quarterly report: Recovery Rate.
				 
BACKGROUND INFO: Data for September 20 onwards will be sourced in a seperate script as data will come from IAPT v2 tables
	 
INPUT:			 [NHSE_Sandbox_Policy].[dbo].[Referral_v15]
				 [NHSE_IAPT].[Person_v15] 
				 [NHSE_IAPT].[Header_v15] 
				 [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges]
				 [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]
				 [NHSE_Reference].[dbo].[tbl_Ref_Other_Provider_Successor] 
				 [NHSE_Reference].[dbo].[tbl_Ref_ODS_Provider_Hierarchies]
				 [NHSE_Reference].[dbo].[tbl_Ref_ODS_ProviderSite]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Boundary_Population_Changes]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans]
				 [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Standards]

TEMP TABLES:	 SEE DROPPED TABLES AT END OF THE SCRIPT.

OUTPUT:			 [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_B_NHS_Talking_Therapies_Monthly_Historic]

WRITTEN BY:		 JADE SYKES 20/07/2023

UPDATES:		 KIRSTY WALKER 20/10/2023 updated formatting of script, added [NHSE_Reference].[dbo].[tbl_Ref_ODS_ProviderSite] to provider lookup
				 JADE SYKES 30/10/2023 added new planning metrics (will become main script once signed off):
				 CDP_B06: NHS Talking Therapies Reliable Recovery
				 CDP_B06: Proportion of referrals with a discharge date in the period that finished a course of treatment and showed reliable recovery (service user moved to recovery and shown reliable improvement). 
						  Denominator is count of referrals finishing in the period minus those finishing a course of treatment who were not at caseness at initial assessment.
				 CDP_B07: NHS Talking Therapies Reliable Improvement
				 CDP_B07: Proportion of referrals with a discharge date in the period that finished a course of treatment that showed reliable improvement expressed as a percentage

***************************/

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PRE-STEPS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/
	
USE [NHSE_IAPT]

DECLARE @Period_start DATE
DECLARE @Period_end DATE

SET @Period_Start = '2020-08-01'
SET @Period_End = '2020-08-31'

PRINT @Period_start
PRINT @Period_end

-- Delete any rows which already exist in output table for this time period
DELETE FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_B_NHS_Talking_Therapies_Monthly_Historic]
WHERE Reporting_Period BETWEEN @Period_Start AND @Period_End

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 1: CREATE MASTER TABLE
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

SELECT 
	   h.END_DATE AS Reporting_Period,
	   'England' AS Org_Type,
	   'ENG' AS 'Org_Code',
	   'England' AS 'Org_Name',
	   'NA' AS ICB_Code,
	   'NA' AS ICB_Name,
	   'NA' AS Region_Code,
	   'NA' AS Region_Name,
		-- NHS Talking Therapies Access
		COUNT(DISTINCT CASE WHEN r.IC_DATE_FIRST_THERAPEUTIC_SESSION BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B04 Count',
		-- NHS Talking Therapies Recovery
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND  [IC_RECOVERY_FLAG] = 'Y' 
							THEN  r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B05 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL END)
		- 
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND [IC_NOT_CASENESS_FLAG]= 'Y' 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B05 Denominator',
		-- NHS Talking Therapies 6 Week Waits
		COUNT(DISTINCT CASE WHEN r.ENDDATE BETWEEN @Period_Start AND @Period_End AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND DATEDIFF(dd,REFRECDATE,IC_DATE_FIRST_THERAPEUTIC_SESSION)<=42 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B02 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B02 Denominator',
		-- NHS Talking Therapies 18 Week Waits
		COUNT(DISTINCT CASE WHEN r.ENDDATE BETWEEN @Period_Start AND @Period_End AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2  AND DATEDIFF(dd,REFRECDATE,IC_DATE_FIRST_THERAPEUTIC_SESSION)<=126 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B01 Numerator',
		COUNT(DISTINCT CASE WHEN ENDDATE IS NOT NULL AND IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B01 Denominator',
		-- NHS Talking Therapies 1st-2nd Treatment >90 days
		COUNT(DISTINCT CASE WHEN R.[IC_DATE_SECOND_THERAPEUTIC_SESSION] BETWEEN @Period_Start AND @Period_End AND DATEDIFF(DD,IC_DATE_FIRST_THERAPEUTIC_SESSION,[IC_DATE_SECOND_THERAPEUTIC_SESSION]) >90 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B03 Numerator',
		COUNT(DISTINCT CASE WHEN [IC_DATE_SECOND_THERAPEUTIC_SESSION] BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B03 Denominator',
				-- NHS Talking Therapies Reliable Recovery
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND  [IC_RELIABLE_RECOVERY_FLAG] = 'Y' 
							THEN  r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B06 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL END)
		- 
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND [IC_NOT_CASENESS_FLAG]= 'Y' 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B06 Denominator',
						-- NHS Talking Therapies Reliable Improvement
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND  [IC_RELIABLE_IMPROV_FLAG] = 'Y' 
							THEN  r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B07 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL END) AS 'CDP_B07 Denominator'

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Master]

  FROM [NHSE_Sandbox_Policy].[dbo].[Referral_v15] r

INNER JOIN [Person_v15] p ON r.IAPT_RECORD_NUMBER = p.IAPT_RECORD_NUMBER

INNER JOIN [Header_v15] h ON p.HEADER_ID = h.HEADER_ID

WHERE h.START_DATE BETWEEN DATEADD(MONTH, 0, @Period_Start) AND @Period_Start
  AND IC_USE_PATHWAY_FLAG = 'Y'

GROUP BY 
h.END_DATE

 UNION

-- Region

SELECT 
	   h.END_DATE AS Reporting_Period,
	   'Region' AS Org_Type,
	   Region_Code AS Org_Code,
	   Region_Name AS Org_Name,
	   'NA' AS ICB_Code,
	   'NA' AS ICB_Name,
	   Region_Code AS Region_Code,
	   Region_Name AS Region_Name,
	   -- NHS Talking Therapies Access
	    COUNT(DISTINCT CASE WHEN r.IC_DATE_FIRST_THERAPEUTIC_SESSION  BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B04 Count',
		-- NHS Talking Therapies Recovery
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND  [IC_RECOVERY_FLAG] = 'Y' 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B05 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL END)
		- 
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND [IC_NOT_CASENESS_FLAG]= 'Y' 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B05 Denominator',
		-- NHS Talking Therapies 6 Week Waits
		COUNT(DISTINCT CASE WHEN r.ENDDATE BETWEEN @Period_Start AND @Period_End AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND DATEDIFF(dd,REFRECDATE,IC_DATE_FIRST_THERAPEUTIC_SESSION)<=42 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B02 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B02 Denominator',
		-- NHS Talking Therapies 18 Week Waits
		COUNT(DISTINCT CASE WHEN r.ENDDATE BETWEEN @Period_Start AND @Period_End AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2  AND DATEDIFF(dd,REFRECDATE,IC_DATE_FIRST_THERAPEUTIC_SESSION)<=126 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B01 Numerator',
		COUNT(DISTINCT CASE WHEN ENDDATE IS NOT NULL AND IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B01 Denominator',
		-- NHS Talking Therapies 1st-2nd Treatment >90 days
		COUNT(DISTINCT CASE WHEN R.[IC_DATE_SECOND_THERAPEUTIC_SESSION] BETWEEN @Period_Start AND @Period_End AND DATEDIFF(DD,IC_DATE_FIRST_THERAPEUTIC_SESSION,[IC_DATE_SECOND_THERAPEUTIC_SESSION]) >90 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B03 Numerator',
		COUNT(DISTINCT CASE WHEN [IC_DATE_SECOND_THERAPEUTIC_SESSION] BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B03 Denominator',
				-- NHS Talking Therapies Reliable Recovery
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND  [IC_RELIABLE_RECOVERY_FLAG] = 'Y' 
							THEN  r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B06 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL END)
		- 
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND [IC_NOT_CASENESS_FLAG]= 'Y' 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B06 Denominator',
						-- NHS Talking Therapies Reliable Improvement
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND  [IC_RELIABLE_IMPROV_FLAG] = 'Y' 
							THEN  r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B07 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL END) AS 'CDP_B07 Denominator'

  FROM [NHSE_Sandbox_Policy].[dbo].[Referral_v15] r

INNER JOIN [Person_v15] p ON r.IAPT_RECORD_NUMBER = p.IAPT_RECORD_NUMBER

INNER JOIN [Header_v15] h ON p.HEADER_ID = h.HEADER_ID

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON r.IC_CCG = cc.Org_Code 
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] ch ON COALESCE(cc.New_Code, r.IC_CCG) = ch.Organisation_Code 

WHERE h.START_DATE BETWEEN DATEADD(MONTH, 0, @Period_Start) AND @Period_Start
  AND IC_USE_PATHWAY_FLAG = 'Y'

GROUP BY 
h.END_DATE, 
Region_Code,  
Region_Name 

 UNION

-- ICB

SELECT 
	   h.END_DATE AS Reporting_Period,
	   'ICB' AS Org_Type,
	   STP_Code AS 'Org_Code',
	   STP_Name AS 'Org_Name',
	   STP_Code AS ICB_Code,
	   STP_Name AS ICB_Name,
	   Region_Code AS Region_Code,
	   Region_Name AS Region_Name,
		-- NHS Talking Therapies Access
		COUNT(DISTINCT CASE WHEN r.IC_DATE_FIRST_THERAPEUTIC_SESSION  BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B04 Count',
		-- NHS Talking Therapies Recovery
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND [IC_RECOVERY_FLAG] = 'Y' 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B05 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL END)
		- 
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND [IC_NOT_CASENESS_FLAG]= 'Y' 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B05 Denominator',
		-- NHS Talking Therapies 6 Week Waits
		COUNT(DISTINCT CASE WHEN r.ENDDATE BETWEEN @Period_Start AND @Period_End AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND DATEDIFF(dd,REFRECDATE,IC_DATE_FIRST_THERAPEUTIC_SESSION)<=42 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B02 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B02 Denominator',
		-- NHS Talking Therapies 18 Week Waits
		COUNT(DISTINCT CASE WHEN r.ENDDATE BETWEEN @Period_Start AND @Period_End AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2  AND DATEDIFF(dd,REFRECDATE,IC_DATE_FIRST_THERAPEUTIC_SESSION)<=126 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B01 Numerator',
		COUNT(DISTINCT CASE WHEN ENDDATE IS NOT NULL AND IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B01 Denominator',
		-- NHS Talking Therapies 1st-2nd Treatment >90 days
		COUNT(DISTINCT CASE WHEN R.[IC_DATE_SECOND_THERAPEUTIC_SESSION] BETWEEN @Period_Start AND @Period_End AND DATEDIFF(DD,IC_DATE_FIRST_THERAPEUTIC_SESSION,[IC_DATE_SECOND_THERAPEUTIC_SESSION]) >90 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B03 Numerator',
		COUNT(DISTINCT CASE WHEN [IC_DATE_SECOND_THERAPEUTIC_SESSION] BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B03 Denominator',
				-- NHS Talking Therapies Reliable Recovery
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND  [IC_RELIABLE_RECOVERY_FLAG] = 'Y' 
							THEN  r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B06 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL END)
		- 
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND [IC_NOT_CASENESS_FLAG]= 'Y' 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B06 Denominator',
						-- NHS Talking Therapies Reliable Improvement
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND  [IC_RELIABLE_IMPROV_FLAG] = 'Y' 
							THEN  r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B07 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL END) AS 'CDP_B07 Denominator'

  FROM [NHSE_Sandbox_Policy].[dbo].[Referral_v15] r

INNER JOIN [Person_v15] p ON r.IAPT_RECORD_NUMBER = p.IAPT_RECORD_NUMBER
INNER JOIN [Header_v15] h ON p.HEADER_ID = h.HEADER_ID

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON r.IC_CCG = cc.Org_Code 
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] ch ON COALESCE(cc.New_Code, r.IC_CCG) = ch.Organisation_Code 

WHERE h.START_DATE BETWEEN DATEADD(MONTH, 0, @Period_Start) AND @Period_Start
  AND IC_USE_PATHWAY_FLAG = 'Y'

GROUP BY 
h.END_DATE, 
Region_Code,  
Region_Name, 
STP_Code, 
STP_Name

 UNION

-- SubICB

SELECT 
	   h.END_DATE AS Reporting_Period,
	   'SubICB' AS Org_Type,
	   COALESCE(cc.New_Code, r.IC_CCG,'Missing / Invalid' COLLATE database_default) AS 'Org_Code',
	   Organisation_Name AS Org_Name,
	   STP_Code AS ICB_Code,
	   STP_Name AS ICB_Name,
	   Region_Code AS Region_Code,
	   Region_Name AS Region_Name,
		-- NHS Talking Therapies Access
		COUNT(DISTINCT CASE WHEN r.IC_DATE_FIRST_THERAPEUTIC_SESSION  BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B04 Count',
		-- NHS Talking Therapies Recovery
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND [IC_RECOVERY_FLAG] = 'Y' 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B05 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL END)
		- 
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND [IC_NOT_CASENESS_FLAG]= 'Y' 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B05 Denominator',
		-- NHS Talking Therapies 6 Week Waits
		COUNT(DISTINCT CASE WHEN r.ENDDATE BETWEEN @Period_Start AND @Period_End AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND DATEDIFF(dd,REFRECDATE,IC_DATE_FIRST_THERAPEUTIC_SESSION)<=42 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B02 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B02 Denominator',
		-- NHS Talking Therapies 18 Week Waits
		COUNT(DISTINCT CASE WHEN r.ENDDATE BETWEEN @Period_Start AND @Period_End AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2  AND DATEDIFF(dd,REFRECDATE,IC_DATE_FIRST_THERAPEUTIC_SESSION)<=126 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B01 Numerator',
		COUNT(DISTINCT CASE WHEN ENDDATE IS NOT NULL AND IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B01 Denominator',
		-- NHS Talking Therapies 1st-2nd Treatment >90 days
		COUNT(DISTINCT CASE WHEN R.[IC_DATE_SECOND_THERAPEUTIC_SESSION] BETWEEN @Period_Start AND @Period_End AND DATEDIFF(DD,IC_DATE_FIRST_THERAPEUTIC_SESSION,[IC_DATE_SECOND_THERAPEUTIC_SESSION]) >90 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B03 Numerator',
		COUNT(DISTINCT CASE WHEN [IC_DATE_SECOND_THERAPEUTIC_SESSION] BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B03 Denominator',
				-- NHS Talking Therapies Reliable Recovery
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND  [IC_RELIABLE_RECOVERY_FLAG] = 'Y' 
							THEN  r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B06 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL END)
		- 
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND [IC_NOT_CASENESS_FLAG]= 'Y' 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B06 Denominator',
						-- NHS Talking Therapies Reliable Improvement
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND  [IC_RELIABLE_IMPROV_FLAG] = 'Y' 
							THEN  r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B07 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL END) AS 'CDP_B07 Denominator'

  FROM [NHSE_Sandbox_Policy].[dbo].[Referral_v15] r

INNER JOIN [Person_v15] p ON r.IAPT_RECORD_NUMBER = p.IAPT_RECORD_NUMBER

INNER JOIN [Header_v15] h ON p.HEADER_ID = h.HEADER_ID

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_ComCodeChanges] cc ON r.IC_CCG = cc.Org_Code 
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] ch ON COALESCE(cc.New_Code, r.IC_CCG) = ch.Organisation_Code 

WHERE h.START_DATE BETWEEN DATEADD(MONTH, 0, @Period_Start) AND @Period_Start
  AND IC_USE_PATHWAY_FLAG = 'Y'

GROUP BY 
h.END_DATE, 
COALESCE(cc.New_Code, r.IC_CCG,'Missing / Invalid' COLLATE database_default),
Organisation_Name, 
STP_Code, STP_Name, 
Region_Code, 
Region_Name

UNION
-- Provider

SELECT 
	   h.END_DATE AS Reporting_Period,
	   'Provider' AS Org_Type,
	   COALESCE(ps.Prov_Successor, r.OrgCodeProvider, 'Missing / Invalid' COLLATE database_default) AS 'Org_Code',
	   COALESCE(ph.Organisation_Name, pu.ODS_ProvSite_OrgName) AS 'Org_Name',
	   COALESCE(ph.STP_Code, puh.STP_Code) AS ICB_Code,
	   COALESCE(ph.STP_Name, puh.STP_Name) AS ICB_Name,
	   COALESCE(ph.Region_Code, puh.Region_Code) AS Region_Code,
	   COALESCE(ph.Region_Name, puh.Region_Name) AS Region_Name,
		-- NHS Talking Therapies Access
		COUNT(DISTINCT CASE WHEN r.IC_DATE_FIRST_THERAPEUTIC_SESSION BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B04 Count',
		-- NHS Talking Therapies Recovery
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND [IC_RECOVERY_FLAG] = 'Y' 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B05 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL END)
		- 
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND [IC_NOT_CASENESS_FLAG]= 'Y' 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B05 Denominator',
		-- NHS Talking Therapies 6 Week Waits
		COUNT(DISTINCT CASE WHEN r.ENDDATE BETWEEN @Period_Start AND @Period_End AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND DATEDIFF(dd,REFRECDATE,IC_DATE_FIRST_THERAPEUTIC_SESSION)<=42 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B02 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B02 Denominator',
		-- NHS Talking Therapies 18 Week Waits
		COUNT(DISTINCT CASE WHEN r.ENDDATE BETWEEN @Period_Start AND @Period_End AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2  AND DATEDIFF(dd,REFRECDATE,IC_DATE_FIRST_THERAPEUTIC_SESSION)<=126 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B01 Numerator',
		COUNT(DISTINCT CASE WHEN ENDDATE IS NOT NULL AND IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B01 Denominator',
		-- NHS Talking Therapies 1st-2nd Treatment >90 days
		COUNT(DISTINCT CASE WHEN R.[IC_DATE_SECOND_THERAPEUTIC_SESSION] BETWEEN @Period_Start AND @Period_End AND DATEDIFF(DD,IC_DATE_FIRST_THERAPEUTIC_SESSION,[IC_DATE_SECOND_THERAPEUTIC_SESSION]) >90 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B03 Numerator',
		COUNT(DISTINCT CASE WHEN [IC_DATE_SECOND_THERAPEUTIC_SESSION] BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B03 Denominator',
				-- NHS Talking Therapies Reliable Recovery
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND  [IC_RELIABLE_RECOVERY_FLAG] = 'Y' 
							THEN  r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B06 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL END)
		- 
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND [IC_NOT_CASENESS_FLAG]= 'Y' 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B06 Denominator',
						-- NHS Talking Therapies Reliable Improvement
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End AND  [IC_RELIABLE_IMPROV_FLAG] = 'Y' 
							THEN  r.IC_PATHWAY_ID 
							ELSE NULL 
		END) AS 'CDP_B07 Numerator',
		COUNT(DISTINCT CASE WHEN r.ENDDATE IS NOT NULL AND r.IC_COUNT_TREATMENT_APPOINTMENTS >= 2 AND r.ENDDATE BETWEEN @Period_Start AND @Period_End 
							THEN r.IC_PATHWAY_ID 
							ELSE NULL END) AS 'CDP_B07 Denominator'

  FROM [NHSE_Sandbox_Policy].[dbo].[Referral_v15] r

INNER JOIN [Person_v15] p ON r.IAPT_RECORD_NUMBER = p.IAPT_RECORD_NUMBER

INNER JOIN [Header_v15] h ON p.HEADER_ID = h.HEADER_ID

LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_Other_Provider_Successor] ps on r.[OrgCodeProvider] = ps.Prov_original 
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_Provider_Hierarchies] ph ON COALESCE(ps.Prov_Successor, r.[OrgCodeProvider]) = ph.Organisation_Code 
-- It was noticed 16/10/23 that there were 2 organisations without org_name, icb_code, icb_name, region_code and region_name. 
-- These were site ID's RDYLK and TAF90, the first join below returns the org name. The second join returns the hierarchies based on the parent provider code (i.e. RDY, TAF)
LEFT JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_ProviderSite] pu ON COALESCE(ps.Prov_Successor, r.OrgCodeProvider) = pu.Provider_Site_Code --to get org_name
LEFT JOIN (SELECT DISTINCT Provider_Site_Code, STP_Code, STP_Name, Region_Code, Region_Name
					  FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Provider_Hierarchies] phh
					  INNER JOIN [NHSE_Reference].[dbo].[tbl_Ref_ODS_ProviderSite] puu ON phh.Organisation_Code = puu.Provider_Code) puh ON COALESCE(ps.Prov_Successor, r.OrgCodeProvider) = puh.Provider_Site_Code

WHERE h.START_DATE BETWEEN DATEADD(MONTH, 0, @Period_Start) AND @Period_Start
  AND IC_USE_PATHWAY_FLAG = 'Y'

GROUP BY 
h.END_DATE,
COALESCE(ps.Prov_Successor, r.OrgCodeProvider, 'Missing / Invalid' COLLATE database_default),
COALESCE(ph.Organisation_Name, pu.ODS_ProvSite_OrgName),
COALESCE(ph.STP_Code, puh.STP_Code),
COALESCE(ph.STP_Name, puh.STP_Name),
COALESCE(ph.Region_Code, puh.Region_Code),
COALESCE(ph.Region_Name, puh.Region_Name)

-- cast as floats so all the same for the unpivot

SELECT Reporting_Period,
	   Org_Type,
	   Org_Code,
	   Org_Name,
	   ICB_Code,
	   ICB_Name,
	   Region_Code,
	   Region_Name,
	   CAST([CDP_B04 Count] AS FLOAT) AS [CDP_B04 Count],
	   CAST([CDP_B05 Numerator] AS FLOAT) AS [CDP_B05 Numerator],
	   CAST([CDP_B05 Denominator] AS FLOAT) AS [CDP_B05 Denominator] ,
	   CAST([CDP_B02 Numerator] AS FLOAT) AS [CDP_B02 Numerator],
	   CAST([CDP_B02 Denominator] AS FLOAT) AS [CDP_B02 Denominator],
	   CAST([CDP_B01 Numerator] AS FLOAT) AS [CDP_B01 Numerator],
	   CAST([CDP_B01 Denominator] AS FLOAT) AS [CDP_B01 Denominator],
	   CAST([CDP_B03 Numerator] AS FLOAT) AS [CDP_B03 Numerator],
	   CAST([CDP_B03 Denominator] AS FLOAT) AS [CDP_B03 Denominator],
	   CAST([CDP_B06 Numerator] AS FLOAT) AS [CDP_B06 Numerator],
	   CAST([CDP_B06 Denominator] AS FLOAT) AS [CDP_B06 Denominator],
	   CAST([CDP_B07 Numerator] AS FLOAT) AS [CDP_B07 Numerator],
	   CAST([CDP_B07 Denominator] AS FLOAT) AS [CDP_B07 Denominator]
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_floats]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Master]

--unpivot to new structure

SELECT Reporting_Period,
	   TEMP_CDP_Measure_ID_Type,
	   Org_Type,
	   Org_Code,
	   Org_Name,
	   ICB_Code,
	   ICB_Name,
	   Region_Code,
	   Region_Name,
	   Measure_Value

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_unpivot]
FROM   
   (SELECT *
   FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_floats]) p  
UNPIVOT  
   ([Measure_Value] FOR [TEMP_CDP_Measure_ID_Type] IN   
      ([CDP_B04 Count], [CDP_B05 Numerator], [CDP_B05 Denominator], [CDP_B02 Numerator], [CDP_B02 Denominator], [CDP_B01 Numerator], [CDP_B01 Denominator],[CDP_B03 Numerator],[CDP_B03 Denominator],[CDP_B06 Numerator],[CDP_B06 Denominator],[CDP_B07 Numerator],[CDP_B07 Denominator])  
)AS unpvt;  

-- Split out Measure ID and Measure Type into seperate columns
SELECT Reporting_Period,
	   i.CDP_Measure_ID AS CDP_Measure_ID,
	   i.CDP_Measure_Name AS CDP_Measure_Name,
	   Org_Type,
	   Org_Code,
	   Org_Name,
	   ICB_Code,
	   ICB_Name,
	   Region_Code,
	   Region_Name,
	   SUBSTRING([TEMP_CDP_Measure_ID_Type],9,LEN([TEMP_CDP_Measure_ID_Type])-8) AS Measure_Type,
	   Measure_Value

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_All_Measures_Unrounded]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_unpivot] f
INNER JOIN (SELECT CDP_Measure_ID, CDP_Measure_Name, Measure_Type
			  FROM [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_METADATA])i 
		ON LEFT([TEMP_CDP_Measure_ID_Type],7) = i.CDP_Measure_ID

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 2: REALLOCATIONS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Get Data for orgs in time periods which need reallocatings & put rest of data aside

-- Reallocations Data
--GET LIST OF UNIQUE REALLOCATIONS FOR ORGS minus bassetlaw
IF OBJECT_ID ('[NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw]

SELECT DISTINCT [From] COLLATE database_default as Orgs
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw]
  FROM [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Boundary_Population_Changes]
 WHERE Bassetlaw_Indicator = 0

UNION

SELECT DISTINCT [Add] COLLATE database_default as Orgs
  FROM [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Boundary_Population_Changes]
 WHERE Bassetlaw_Indicator = 0

-- Get Data for orgs in time periods which need reallocatings & put rest of data aside in no change table
 -- Use this for if Bassetlaw_Indicator = 0 (bassetlaw has moved to new location)
SELECT * 
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocations]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_All_Measures_Unrounded]

 WHERE Org_Code IN (SELECT Orgs FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw])
   AND Reporting_Period <'2022-07-01'

--No change data
-- Use this for if Bassetlaw_Indicator = 0 (bassetlaw has moved to new location) 
SELECT * 
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_No_Change]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_All_Measures_Unrounded]
 WHERE Reporting_Period >='2022-07-01' 
    OR (Org_Code NOT IN (SELECT Orgs FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw])
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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Reallocations_Changes_From]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocations] r

INNER JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Boundary_Population_Changes] c ON r.Org_Code = c.[From]
 WHERE Bassetlaw_Indicator = 0

-- Sum activity movement for orgs gaining (need to sum for Midlands Y60 which recieves from 2 orgs)
SELECT 
	   r.Reporting_Period,
	   r.CDP_Measure_ID,
	   r.CDP_Measure_Name,
	   r.Org_Type,
	   [Add] as Org_Code,
	   r.Measure_Type,
	   SUM(Measure_Value_Change) as Measure_Value_Change

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocations_Changes_Add]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Reallocations_Changes_From] r

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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Reallocations_Calc]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocations] r

INNER JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Reallocations_Changes_From] c 
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

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocations] r

INNER JOIN [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocations_Changes_Add] c 
        ON r.Org_Code = c.Org_Code 
	   AND r.Reporting_Period = c.Reporting_Period 
	   AND r.Measure_Type = c.Measure_Type 
	   AND r.CDP_Measure_Name = c.CDP_Measure_Name

--Collate reallocations with no change data to create new 'master' table
SELECT * 
  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocated_Num_&_Den]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Reallocations_Calc]

UNION

SELECT * 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_No_Change]

-- Calculate any percentages needed in the data
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

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocated_%]

  FROM (SELECT * 
		  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocated_Num_&_Den]
		 WHERE Measure_Type = 'Numerator') a
INNER JOIN 
	   (SELECT * 
	      FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocated_Num_&_Den]
		 WHERE Measure_Type = 'Denominator') b  
		    ON a.Reporting_Period = b.Reporting_Period 
		   AND a.Org_Code = b.Org_Code 
		   AND a.CDP_Measure_ID = b.CDP_Measure_ID
		   AND a.Org_Type = b.Org_Type

-- Collate Percentage calcs with rest of data
SELECT * 

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocated]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocated_Num_&_Den]

UNION

SELECT * 
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocated_%]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 3: ROUNDING & SUPRESSION (WHERE REQUIRED), ADDING TARGETS, % ACHIEVED
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

SELECT distinct
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
	   CASE WHEN f.Measure_Type IN('Percentage') AND f.Org_Type = 'England' 
			THEN CAST(ROUND(Measure_Value,1) AS FLOAT)/100 -- If rate and eng round to 1dp
			WHEN f.Measure_Type IN('Percentage') AND f.Org_Type <> 'England' 
			THEN CAST(ROUND(Measure_Value,0) AS FLOAT)/100 -- If rate and not Eng then round to 0dp
			WHEN f.Measure_Type IN('Rate') AND f.Org_Type = 'England' 
			THEN CAST(ROUND(Measure_Value,1) AS FLOAT)
			WHEN f.Measure_Type IN('Rate') AND f.Org_Type <> 'England' 
			THEN CAST(ROUND(Measure_Value,0) AS FLOAT)
			WHEN Measure_Value < 5 
			THEN NULL -- supressed values shown as NULL
			WHEN f.Org_Type = 'England' 
			THEN Measure_Value -- Counts for Eng no rounding
			ELSE CAST(ROUND(Measure_Value/5.0,0)*5 AS FLOAT) 
	   END AS Measure_Value,
	   s.[Standard],
	   l.LTP_Trajectory_Rounded AS LTP_Trajectory,
	   CASE WHEN f.Measure_Type NOT IN ('Rate','Percentage','Numerator','Denominator') 
			THEN ROUND(CAST(Measure_Value AS FLOAT)/NULLIF(CAST(l.LTP_Trajectory AS FLOAT),0),2) 
			ELSE NULL 
	   END AS LTP_Trajectory_Percentage_Achieved ,
	   p.Plan_Rounded AS [Plan],
	   CASE WHEN f.Measure_Type NOT IN ('Rate','Percentage','Numerator','Denominator') 
			THEN ROUND(CAST(Measure_Value AS FLOAT)/NULLIF(CAST(p.[Plan] AS FLOAT),0),2) 
			ELSE NULL 
	   END AS Plan_Percentage_Achieved,
	   s.Standard_STR,
	   l.LTP_Trajectory_STR,
	   p.Plan_STR

  INTO [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Rounded_&_Targets]
  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocated]  f

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_LTP_Trajectories] l 
	   ON f.Reporting_Period = l.Reporting_Period 
	  AND f.Org_Code = l.Org_Code
	  AND (CASE WHEN f.Measure_Type IN ('Percentage','Rate','Count') THEN f.CDP_Measure_ID ELSE NULL END) = l.CDP_Measure_ID

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Plans] p 
	   ON f.Reporting_Period = p.Reporting_Period 
	  AND f.Org_Code = p.Org_Code
	  AND (CASE WHEN f.Measure_Type  IN ('Percentage','Rate','Count') THEN f.CDP_Measure_ID ELSE NULL END) = p.CDP_Measure_ID

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_Standards] s 
	   ON f.Reporting_Period = s.Reporting_Period 
	   --not required to join on org_code here as it is a national standard
	  AND (CASE WHEN f.Measure_Type  IN ('Percentage','Rate','Count') THEN f.CDP_Measure_ID ELSE NULL END) = s.CDP_Measure_ID 

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 4: ADD 'STR' VALUES & ISLATEST & LAST MODIFIED
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

INSERT INTO [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_B_NHS_Talking_Therapies_Monthly_Historic]

SELECT f.Reporting_Period,
	   0 as Is_Latest,
	   CDP_Measure_ID,
	   CDP_Measure_Name,
	   Org_Type,
	   Org_Code,
	   Org_Name,
	   ICB_Code,
	   ICB_Name,
	   Region_Code,
	   Region_Name,
	   Measure_Type,
	   Measure_Value,
	   [Standard],
	   LTP_Trajectory,
	   LTP_Trajectory_Percentage_Achieved,
	   [Plan],
	   Plan_Percentage_Achieved,
	   CASE WHEN Measure_Value IS NULL THEN '*' 
			WHEN Measure_Type IN('Percentage') THEN CAST(Measure_Value*100 AS VARCHAR)+'%' 
			ELSE FORMAT(Measure_Value,N'N0') 
	    END AS Measure_Value_STR,
		Standard_STR,
		LTP_Trajectory_STR,
		CAST(LTP_Trajectory_Percentage_Achieved*100 AS VARCHAR)+'%' AS LTP_Trajectory_Percentage_Achieved_STR,
		Plan_STR,
		CAST(Plan_Percentage_Achieved*100 AS VARCHAR)+'%' AS Plan_Percentage_Achieved_STR,
		GETDATE() AS Last_Modified

  FROM [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Rounded_&_Targets] f

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 5: QA - REMOVE UNSUPPORTED ORGS, CHECK FOR DUPLICATE ROWS
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

DELETE FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_B_NHS_Talking_Therapies_Monthly_Historic]
WHERE Region_Code LIKE 'REG%' OR Org_Code IS NULL 
OR (Org_Type = 'SubICB' AND  Org_Code NOT IN (SELECT DISTINCT Organisation_Code 
												         FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies] 
											            WHERE Effective_To IS NULL 
											              AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))

OR (Org_Type = 'ICB' AND Org_Code NOT IN (SELECT DISTINCT STP_Code 
													 FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]
													WHERE Effective_To IS NULL 
													  AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP')) 

OR (Org_Type = 'Region' AND Org_Code NOT IN (SELECT DISTINCT Region_Code 
														FROM [NHSE_Reference].[dbo].[tbl_Ref_ODS_Commissioner_Hierarchies]
													   WHERE Effective_To IS NULL 
													     AND NHSE_Organisation_Type = 'CLINICAL COMMISSIONING GROUP'))

-- Check for duplicate rows, this should return a blank table if none
SELECT Distinct 
	   Reporting_Period,
	   CDP_Measure_ID,
	   CDP_Measure_Name,
	   Measure_Type,
	   Org_Type,
	   Org_Code

  FROM (SELECT Reporting_Period, CDP_Measure_ID, CDP_Measure_Name, Measure_Type, Org_Type, Org_Code,count(1) cnt
          FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_B_NHS_Talking_Therapies_Monthly_Historic]
      GROUP BY Reporting_Period, CDP_Measure_ID, CDP_Measure_Name, Measure_Type, Org_Type, Org_Code
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
			THEN ROUND(ABS(latest.Measure_Value - previous.Measure_Value),1)
			WHEN latest.Measure_Type <> 'Percentage' AND ABS(latest.Measure_Value - previous.Measure_Value) = 0 THEN 0
			ELSE -- percentage point change if comparing percentages
			ROUND(NULLIF(ABS(latest.Measure_Value - previous.Measure_Value),0)/NULLIF(latest.Measure_Value,0),3)
	   END as Percentage_Change

  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_B_NHS_Talking_Therapies_Monthly_Historic] latest

  LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_METADATA] meta 
	   ON latest.CDP_Measure_ID = meta.CDP_Measure_ID 

  LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_B_NHS_Talking_Therapies_Monthly_Historic] previous
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
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_B_NHS_Talking_Therapies_Monthly_Historic]
  WHERE Measure_Value IS NOT NULL

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
STEP 6: DROP TEMP TABLES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

--STEP 1: CREATE MASTER TABLE
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Master]
-- cast as floats so all the same for the unpivot
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_floats]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_unpivot]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_All_Measures_Unrounded]

--STEP 2: REALLOCATIONS
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_Reallocations_Orgs_without_Bassetlaw]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocations]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_No_Change]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Reallocations_Changes_From]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocations_Changes_Add]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Reallocations_Calc]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocated_Num_&_Den]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocated_%]
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Reallocated]

--STEP 3: ROUNDING & SUPRESSION (WHERE REQUIRED), ADDING TARGETS, % ACHIEVED
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Rounded_&_Targets]

--STEP 4: ADD 'STR' VALUES & ISLATEST & LAST MODIFIED
DROP TABLE [NHSE_Sandbox_Policy].[temp].[TEMP_CDP_B_NHS_Talking_Therapies_Monthly_Historic_Is_Latest] 



