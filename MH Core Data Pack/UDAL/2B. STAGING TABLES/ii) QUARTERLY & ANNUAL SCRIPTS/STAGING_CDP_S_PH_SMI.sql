

IF OBJECT_ID ('MHDInternal.[STAGING_CDP_S_PH_SMI_GPES]') IS NOT NULL
DROP TABLE MHDInternal.STAGING_CDP_S_PH_SMI_GPES

--- England 
SELECT 
	Reporting_Period_End
	,NULL AS Is_Latest 
	,'CDP_S02' AS CDP_Measure_ID 
	,'SMI PH' AS CDP_Measure_Name 
	,'England' AS Org_Type 
	,'ENG' AS Org_Code
	,'England' AS Org_Name
	,'NA' AS ICB_Code
	,'NA' AS ICB_Name
	,'NA' AS Region_Code
	,'NA' AS Region_Name 
	,CASE 
		WHEN Measure_ID = 'PHS001' THEN 'Denominator' 
		WHEN Measure_ID = 'PHS014a' THEN 'Numerator' 
		WHEN Measure_ID = 'PHS014b' THEN 'Percentage' 
	END AS Measure_Type 
	,Measure_Value
	,0.6 AS [Standard] 
	,CAST(NULL AS varchar) AS LTP_Trajectory 
	,CAST(NULL AS varchar) AS LTP_Trajectory_Percentage_Achieved
	,CAST(p.[Plan] as float) AS [Plan]
	,CAST((a.Measure_Value/100)/p.[Plan] as float) AS Plan_Percentage_Achieved
	,Measure_Value_Str 
	,'60%' AS Standard_STR 
	,CAST(NULL AS varchar) AS LTP_Trajectory_STR 
	,CAST(NULL AS varchar) AS LTP_Trajectory_Percentage_Achieved_STR 
	,FORMAT(p.[Plan],'P1') AS Plan_STR 
	,FORMAT((a.Measure_Value/100)/p.[Plan],'P1') AS Plan_Percentage_Achieved_STR
	,GETDATE() AS Last_Modified 

INTO MHDInternal.STAGING_CDP_S_PH_SMI_GPES

FROM UKHF_Physical_Health_Checks_Severe_Mental_Illness.Data_V21 a 

LEFT JOIN MHDInternal.Reference_CDP_Plans p ON a.Reporting_Period_End = p.Reporting_Period 
	AND p.Org_Type = 'England' 
	AND p.Measure_Type = 'Percentage' 
	AND p.CDP_Measure_ID = 'CDP_S02' 
	AND a.Measure_ID = 'PHS014b'
	AND a.Reporting_Period_End = p.Reporting_Period

WHERE Region = 'All' 
AND Measure_ID IN ('PHS001','PHS014a','PHS014b')


INSERT INTO MHDInternal.STAGING_CDP_S_PH_SMI_GPES

--- Region 
SELECT 
	Reporting_Period_End
	,NULL AS Is_Latest 
	,'CDP_S02' AS CDP_Measure_ID 
	,'SMI PH' AS CDP_Measure_Name 
	,'Region' AS Org_Type 
	,r.Region_Code AS Org_Code
	,Region AS Org_Name
	,'NA' AS ICB_Code
	,'NA' AS ICB_Name
	,'NA' AS Region_Code
	,'NA' AS Region_Name 
	,CASE 
		WHEN Measure_ID = 'PHS001' THEN 'Denominator' 
		WHEN Measure_ID = 'PHS014a' THEN 'Numerator' 
		WHEN Measure_ID = 'PHS014b' THEN 'Percentage' 
	END AS Measure_Type 
	,Measure_Value
	,0.6 AS [Standard] 
	,CAST(NULL AS varchar) AS LTP_Trajectory
	,CAST(NULL AS varchar) AS LTP_Trajectory_Percentage_Achieved
	,CAST(p.[Plan] as float) AS [Plan]
	,CAST((a.Measure_Value/100)/p.[Plan] as float) AS Plan_Percentage_Achieved
	,Measure_Value_Str 
	,'60%' AS Standard_STR 
	,CAST(NULL AS varchar) AS LTP_Trajectory_STR 
	,CAST(NULL AS varchar) AS LTP_Trajectory_Percentage_Achieved_STR 
	,FORMAT(p.[Plan],'P1') AS Plan_STR 
	,FORMAT((a.Measure_Value/100)/p.[Plan],'P1') AS Plan_Percentage_Achieved_STR
	,GETDATE() AS Last_Modified 

FROM UKHF_Physical_Health_Checks_Severe_Mental_Illness.Data_V21 a 

LEFT JOIN (SELECT DISTINCT Region_Code, Region_Name FROM Reporting_UKHD_ODS.Commissioner_Hierarchies) r ON a.Region = r.Region_Name

LEFT JOIN MHDInternal.Reference_CDP_Plans p ON a.Reporting_Period_End = p.Reporting_Period 
	AND p.Org_Type = 'Region'
	AND r.Region_Code = p.Org_Code
	AND p.Measure_Type = 'Percentage' 
	AND p.CDP_Measure_ID = 'CDP_S02' 
	AND a.Measure_ID = 'PHS014b'
	AND a.Reporting_Period_End = p.Reporting_Period

WHERE Region <> 'All' AND ICB_Code = 'All'
AND Measure_ID IN ('PHS001','PHS014a','PHS014b')


INSERT INTO MHDInternal.STAGING_CDP_S_PH_SMI_GPES

--- ICB 
SELECT 
	Reporting_Period_End
	,NULL AS Is_Latest 
	,'CDP_S02' AS CDP_Measure_ID 
	,'SMI PH' AS CDP_Measure_Name 
	,'ICB' AS Org_Type 
	,a.ICB_Code AS Org_Code
	,r.STP_Name AS Org_Name
	,'NA' AS ICB_Code
	,'NA' AS ICB_Name
	,'NA' AS Region_Code
	,'NA' AS Region_Name 
	,CASE 
		WHEN Measure_ID = 'PHS001' THEN 'Denominator' 
		WHEN Measure_ID = 'PHS014a' THEN 'Numerator' 
		WHEN Measure_ID = 'PHS014b' THEN 'Percentage' 
	END AS Measure_Type 
	,Measure_Value
	,0.6 AS [Standard] 
	,CAST(NULL AS varchar) AS LTP_Trajectory
	,CAST(NULL AS varchar) AS LTP_Trajectory_Percentage_Achieved
	,CAST(p.[Plan] as float) AS [Plan]
	,CAST((a.Measure_Value/100)/p.[Plan] as float) AS Plan_Percentage_Achieved
	,Measure_Value_Str 
	,'60%' AS Standard_STR 
	,CAST(NULL AS varchar) AS LTP_Trajectory_STR 
	,CAST(NULL AS varchar) AS LTP_Trajectory_Percentage_Achieved_STR 
	,FORMAT(p.[Plan],'P1') AS Plan_STR 
	,FORMAT((a.Measure_Value/100)/p.[Plan],'P1') AS Plan_Percentage_Achieved_STR
	,GETDATE() AS Last_Modified 

FROM UKHF_Physical_Health_Checks_Severe_Mental_Illness.Data_V21 a 

LEFT JOIN (SELECT DISTINCT STP_Code, STP_Name FROM Reporting_UKHD_ODS.Commissioner_Hierarchies) r ON a.ICB_Code = r.STP_Code

LEFT JOIN MHDInternal.Reference_CDP_Plans p ON a.Reporting_Period_End = p.Reporting_Period 
	AND p.Org_Type = 'ICB'
	AND p.Org_Code = a.ICB_Code
	AND p.Measure_Type = 'Percentage' 
	AND p.CDP_Measure_ID = 'CDP_S02' 
	AND a.Measure_ID = 'PHS014b'
	AND a.Reporting_Period_End = p.Reporting_Period

WHERE Region <> 'All' AND ICB_Code <> 'All' AND Sub_ICB_Code = 'All'
AND Measure_ID IN ('PHS001','PHS014a','PHS014b')



INSERT INTO MHDInternal.STAGING_CDP_S_PH_SMI_GPES

--- sub-ICB 
SELECT 
	Reporting_Period_End
	,NULL AS Is_Latest 
	,'CDP_S02' AS CDP_Measure_ID 
	,'SMI PH' AS CDP_Measure_Name 
	,'SubICB' AS Org_Type 
	,a.Sub_ICB_Code AS Org_Code
	,r.Organisation_Name AS Org_Name
	,'NA' AS ICB_Code
	,'NA' AS ICB_Name
	,'NA' AS Region_Code
	,'NA' AS Region_Name 
	,CASE 
		WHEN Measure_ID = 'PHS001' THEN 'Denominator' 
		WHEN Measure_ID = 'PHS014a' THEN 'Numerator' 
		WHEN Measure_ID = 'PHS014b' THEN 'Percentage' 
	END AS Measure_Type 
	,Measure_Value
	,0.6 AS [Standard] 
	,CAST(NULL AS varchar) AS LTP_Trajectory
	,CAST(NULL AS varchar) AS LTP_Trajectory_Percentage_Achieved
	,CAST(p.[Plan] as float) AS [Plan]
	,CAST((a.Measure_Value/100)/p.[Plan] as float) AS Plan_Percentage_Achieved
	,Measure_Value_Str 
	,'60%' AS Standard_STR 
	,CAST(NULL AS varchar) AS LTP_Trajectory_STR 
	,CAST(NULL AS varchar) AS LTP_Trajectory_Percentage_Achieved_STR 
	,FORMAT(p.[Plan],'P1') AS Plan_STR 
	,FORMAT((a.Measure_Value/100)/p.[Plan],'P1') AS Plan_Percentage_Achieved_STR
	,GETDATE() AS Last_Modified 

FROM UKHF_Physical_Health_Checks_Severe_Mental_Illness.Data_V21 a 

LEFT JOIN (SELECT DISTINCT Organisation_Code, Organisation_Name FROM Reporting_UKHD_ODS.Commissioner_Hierarchies) r ON a.Sub_ICB_Code = r.Organisation_Code

LEFT JOIN MHDInternal.Reference_CDP_Plans p ON a.Reporting_Period_End = p.Reporting_Period 
	AND p.Org_Type = 'SubICB'
	AND p.Org_Code = a.Sub_ICB_Code
	AND p.Measure_Type = 'Percentage' 
	AND p.CDP_Measure_ID = 'CDP_S02' 
	AND a.Measure_ID = 'PHS014b'
	AND a.Reporting_Period_End = p.Reporting_Period

WHERE Region <> 'All' AND ICB_Code <> 'All' AND Sub_ICB_Code <> 'All' AND PCN_Code = 'All'
AND Measure_ID IN ('PHS001','PHS014a','PHS014b')


