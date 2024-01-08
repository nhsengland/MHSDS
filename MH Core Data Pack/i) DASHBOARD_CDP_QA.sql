IF OBJECT_ID ('[NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP_QA]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP_QA]

SELECT *

  INTO [NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP_QA]

  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_D_Dementia]

UNION

SELECT *

  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Dementia_Historic]

  UNION 

SELECT *
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_M_MHSDS_Published]

UNION

SELECT  *
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_S_PH_SMI]

UNION

SELECT *
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_F_NHS_Talking_Therapies_Quarterly]

UNION 

SELECT *
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_O_OAPs]
 WHERE CDP_Measure_ID NOT IN ('CDP_O02')

UNION 

SELECT * 
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_B_NHS_Talking_Therapies_Monthly_Historic]
  WHERE CDP_Measure_ID NOT IN ('M195','M186')

  UNION

SELECT *
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_B_NHS_Talking_Therapies_Monthly]
  WHERE CDP_Measure_ID NOT IN ('M195','M186')

UNION 

SELECT *
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_N_Inpatient_No_Contact]

UNION 

SELECT *
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_Q_Data_Quality]

UNION 

SELECT *
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_T_CMH]

UNION 

SELECT *
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_A_ECDS]

UNION 

SELECT *
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_C_CYP_ED_Historic]

UNION 

SELECT *
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_E_EIP]

UNION 

SELECT *
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_P_Perinatal]

UNION 

SELECT *
  FROM [NHSE_Sandbox_Policy].[dbo].[STAGING_CDP_I_IPS]

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
QA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

-- Check whether there is new data where expected

SELECT DISTINCT

	   meta.CDP_Measure_ID,
	   meta.CDP_Measure_Name, 
	   CASE WHEN meta.CDP_Measure_ID = 'CDP_D01' THEN 'STAGING_CDP_D_Dementia'
			WHEN meta.CDP_Measure_ID IN ('CDP_M07','CDP_M08') THEN 'STAGING_CDP_M_MHSDS_Published'
			ELSE meta.Script_Name
	   END as Script_Name,
	   old.Reporting_Period AS Previous_Latest_Month, 
	   new.Reporting_Period AS New_Latest_Month, 
	   Update_Frequency,
	   CASE WHEN Update_Frequency = 'Monthly'   AND DATEDIFF(mm,old.Reporting_Period,new.Reporting_Period) = 1  THEN 'Ok'
	        WHEN Update_Frequency = 'Quarterly' AND DATEDIFF(mm,old.Reporting_Period,new.Reporting_Period) = 3  THEN 'Ok'
		    WHEN Update_Frequency = 'Annually'  AND DATEDIFF(mm,old.Reporting_Period,new.Reporting_Period) = 12 THEN 'Ok'
			ELSE 'DATA NOT REFRESHED' 
	   END AS 'Updated_Correctly'

FROM  [NHSE_Sandbox_Policy].[dbo].[REFERENCE_CDP_METADATA] meta
  
LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP] old
       ON meta.CDP_Measure_ID = old.CDP_Measure_ID

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP_QA] new 
	   ON old.CDP_Measure_ID = new.CDP_Measure_ID 
	  AND old.Measure_Type = new.Measure_Type
	  AND old.Org_Code = new.Org_Code 
	  AND old.Org_Type = new.Org_Type

WHERE old.Is_Latest = 1 
  AND new.Is_Latest = 1 
  AND old.CDP_Measure_ID NOT IN ('CDP_C01','CDP_C02') -- Exclude any metrics which we no longer run

-- Check for differences between old and new data before committing to final dashboard table

SELECT Reporting_Period,  
	   CDP_Measure_ID, 
	   CDP_Measure_Name, 
	   Measure_Type,
	   Org_Type,
	   Org_Code, 
	   Org_Name, 
	   OLD_Measure_Value_STR,
	   NEW_Measure_Value_STR,
	 --  Numerical_Change,
	 CASE WHEN OLD_Measure_Value_STR <> '-' AND OLD_Measure_Value_STR <> '*' AND (NEW_Measure_Value_STR = '-' OR NEW_Measure_Value_STR IS NULL) THEN '2 Data Missing - Previously Present'
	 WHEN NEW_Measure_Value_STR <> '-' AND NEW_Measure_Value_STR <> '*' AND (OLD_Measure_Value_STR = '-' OR OLD_Measure_Value_STR IS NULL) THEN '7 Data Present - Previously Missing'
		WHEN ((Measure_Type NOT IN ('Percentage','Rate') AND (NEW_Measure_Value < 100 OR OLD_Measure_Value < 100)) OR OLD_Measure_Value_STR = '*' OR NEW_Measure_Value_STR = '*')
		AND (Percentage_Change >= 0.5 OR Percentage_Change IS NULL) THEN '4 High Variation - Volatile Numbers'
		WHEN Percentage_Change >= 0.5 THEN '1 High Variation'
		WHEN Percentage_Change <= 0.1 THEN '5 Low Variation'
		WHEN ((Measure_Type NOT IN ('Percentage','Rate') AND (NEW_Measure_Value < 100 OR OLD_Measure_Value < 100)) OR OLD_Measure_Value_STR = '*' OR NEW_Measure_Value_STR = '*')
		AND (Percentage_Change < 0.5 OR Percentage_Change IS NULL) THEN '6 Moderate Variation - Volatile Numbers'
		WHEN Percentage_Change < 0.5 THEN '3 Moderate Variation'
		ELSE NULL END AS 'QA_Flag',
	   FORMAT(Percentage_Change,'P1') AS Percentage_Change

	   FROM (

SELECT old.Reporting_Period, 
	   old.CDP_Measure_ID, 
	   old.CDP_Measure_Name, 
	   old.Measure_Type,
	   old.Org_Type,
	   old.Org_Code, 
	   old.Org_Name, 
	   old.Measure_Value as OLD_Measure_Value,
	   new.Measure_Value as NEW_Measure_Value, 
	   old.Measure_Value_STR AS OLD_Measure_Value_STR,
	   new.Measure_Value_STR AS NEW_Measure_Value_STR,
	   ABS(old.Measure_Value - new.Measure_Value) as Numerical_Change,
	   CASE WHEN old.Measure_Type = 'Percentage' 
			THEN ABS(old.Measure_Value - new.Measure_Value) 
			ELSE -- percentage point change if percentage 
			NULLIF(ABS(old.Measure_Value - new.Measure_Value),0)/NULLIF(old.Measure_Value,0) 
	   END as Percentage_Change

  FROM [NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP] old

LEFT JOIN [NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP_QA] new 
	   ON old.CDP_Measure_ID = new.CDP_Measure_ID 
	  AND old.Reporting_Period = new.Reporting_Period
	  AND old.Measure_Type = new.Measure_Type
	  AND old.Org_Code = new.Org_Code 
	  AND old.Org_Type = new.Org_Type

WHERE old.Measure_Value <> new.Measure_Value 
 OR (old.Measure_Value IS NULL AND new.Measure_Value IS NOT NULL)
 OR (new.Measure_Value IS NULL AND old.Measure_Value IS NOT NULL) )_

ORDER BY QA_Flag, CDP_Measure_Name, Org_Name, Org_Type, Percentage_Change DESC


---- for QA workbook
--SELECT * 
--FROM NHSE_Sandbox_Policy.dbo.DASHBOARD_CDP_QA 
--WHERE Measure_Type not in ('Numerator','Denominator')