


select 
Month AS [Reporting_Period]
,CASE WHEN Month = '2023-03-31' THEN 1 ELSE 0 END AS [Is_Latest]
,'CDP_E01' AS [CDP_Measure_ID]
,'NCAP Audit EIP L2 & Above' AS [CDP_Measure_Name]
,CASE WHEN [Org_Type] = 'CCG' THEN 'SubICB'
WHEN Org_Type = 'STP' THEN 'ICB' ELSE Org_Type END AS [Org_Type]
,CASE WHEN [Org_Code] = 'Eng' then 'ENG'  ELSE [Org_Code] END AS [Org_Code]
--,[Org_Name]
--,[ICB_Code]
--,[ICB_Name]
--,[Region_Code]
--,[Region_Name]
,'Percentage' AS [Measure_Type]
,ROUND(NULLIF(CAST(EIP_Level234 AS FLOAT),0)/100,3) AS [Measure_Value]
,1 AS [Standard]
,NULL AS [LTP_Trajectory]
,NULL AS [LTP_Trajectory_Percentage_Achieved]
,NULL AS [Plan]
,NULL AS [Plan_Percentage_Achieved]
--,[Measure_Value_STR]
,CAST('100%' AS varchar) AS [Standard_STR]
,CAST(NULL AS VARCHAR) AS [LTP_Trajectory_STR]
,CAST(NULL AS VARCHAR) AS [LTP_Trajectory_Percentage_Achieved_STR]
,CAST(NULL AS VARCHAR) AS [Plan_STR]
,CAST(NULL AS VARCHAR) AS [Plan_Percentage_Achieved_STR]
--,[Last_Modified]

INTO #EIPTEMP
from MHDInternal.Reference_EIPLevelsManual

UNION

select 
Month AS [Reporting_Period]
,CASE WHEN Month = '2023-03-31' THEN 1 ELSE 0 END AS [Is_Latest]
,'CDP_E02' AS [CDP_Measure_ID]
,'NCAP Audit EIP L3 & Above' AS [CDP_Measure_Name]
,CASE WHEN [Org_Type] = 'CCG' THEN 'SubICB'
WHEN Org_Type = 'STP' THEN 'ICB' ELSE Org_Type END AS [Org_Type]
,CASE WHEN [Org_Code] = 'Eng' then 'ENG' ELSE [Org_Code] END AS [Org_Code]
--,[Org_Name]
--,[ICB_Code]
--,[ICB_Name]
--,[Region_Code]
--,[Region_Name]
,'Percentage' AS [Measure_Type]
,ROUND(NULLIF(CAST(EIP_Level34 AS FLOAT),0)/100,3) AS [Measure_Value]
,0.7 AS [Standard]
,NULL AS [LTP_Trajectory]
,NULL AS [LTP_Trajectory_Percentage_Achieved]
,NULL AS [Plan]
,NULL AS [Plan_Percentage_Achieved]
--,[Measure_Value_STR]
,CAST('70%' AS varchar) AS [Standard_STR]
,CAST(NULL AS VARCHAR) AS [LTP_Trajectory_STR]
,CAST(NULL AS VARCHAR) AS [LTP_Trajectory_Percentage_Achieved_STR]
,CAST(NULL AS VARCHAR) AS [Plan_STR]
,CAST(NULL AS VARCHAR) AS [Plan_Percentage_Achieved_STR]
--,[Last_Modified]
from MHDInternal.Reference_EIPLevelsManual



delete from MHDInternal.STAGING_CDP_E_EIP
INSERT INTO MHDInternal.STAGING_CDP_E_EIP
select 
[Reporting_Period]
,[Is_Latest]
,[CDP_Measure_ID]
,[CDP_Measure_Name]
,[Org_Type]
,m.[Org_Code]
	   ,CASE WHEN Org_Type = 'England' THEN 'England'
	   		WHEN Org_Type = 'Region' THEN r.Region_Name
			WHEN Org_Type in ('ICB', 'STP') THEN i.STP_Name
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.Organisation_Name
			WHEN Org_Type = 'Provider' THEN ph.Organisation_Name 
			ELSE ch.Organisation_Name 
	   END as Org_Name,
	   CASE WHEN Org_Type = 'England' THEN 'NA' 
			WHEN Org_Type = 'Region' THEN 'NA' 
			WHEN Org_Type in ('ICB', 'STP') THEN i.STP_Code
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.STP_Code
			WHEN Org_Type = 'Provider' THEN ph.STP_Code
			ELSE ch.STP_Code 
	   END as ICB_Code,
	   CASE WHEN Org_Type = 'England' THEN 'NA'
			WHEN Org_Type = 'Region' THEN 'NA' 
			WHEN Org_Type in ('ICB', 'STP') THEN i.STP_Name
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.STP_Name
			WHEN Org_Type = 'Provider' THEN ph.STP_Name
			ELSE ch.STP_Name 
	   END as ICB_Name,
	   CASE WHEN Org_Type = 'England' THEN 'NA' 
			WHEN Org_Type = 'Region' THEN r.Region_Code
			WHEN Org_Type in ('ICB','STP') THEN i.Region_Code
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.Region_Code
			WHEN Org_Type = 'Provider' THEN ph.Region_Code
			ELSE ch.Region_Code
	   END as Region_Code,
	   CASE WHEN Org_Type = 'England' THEN 'NA'
			WHEN Org_Type = 'Region' THEN r.Region_Name
			WHEN Org_Type in ('ICB', 'STP') THEN i.Region_Name
			WHEN Org_Type in ('SubICB', 'CCG') THEN ch.Region_Name
			WHEN Org_Type = 'Provider' THEN ph.Region_Name
			ELSE ch.Region_Name
	   END as Region_Name,
[Measure_Type]
,[Measure_Value]
,[Standard]
,[LTP_Trajectory]
,[LTP_Trajectory_Percentage_Achieved]
,[Plan]
,[Plan_Percentage_Achieved]
,CASE WHEN Measure_Value IS NULL THEN '-' ELSE CAST([Measure_Value]*100 AS VARCHAR)+'%' END AS [Measure_Value_STR]
,[Standard_STR]
,[LTP_Trajectory_STR]
,[LTP_Trajectory_Percentage_Achieved_STR]
,[Plan_STR]
,[Plan_Percentage_Achieved_STR]
,GETDATE() AS [Last_Modified]


from #EIPTEMP m

--Region names
LEFT JOIN (SELECT DISTINCT Region_Code, Region_Name 
					  FROM Reporting_UKHD_ODS.Commissioner_Hierarchies) r 
					    ON Org_Code = r.Region_Code

--ICB hierarchies
LEFT JOIN (SELECT DISTINCT STP_Code, STP_Name, Region_Code, Region_Name
					  FROM Reporting_UKHD_ODS.Commissioner_Hierarchies) i
					    ON Org_Code = i.STP_Code

--SubICB hierarchies, replacing old codes with new codes and then looking up new codes in hierarchies table
--LEFT JOIN [Internal_Reference].[ComCodeChanges] cc ON m.Org_Code = cc.Org_Code COLLATE database_default
LEFT JOIN Reporting_UKHD_ODS.Commissioner_Hierarchies ch ON m.Org_Code = ch.Organisation_Code COLLATE database_default

--Provider hierarchies, replacing old codes with new codes and then looking up new codes in hierarchies table
LEFT JOIN [Internal_Reference].[Provider_Successor] ps on m.Org_Code = ps.Prov_original COLLATE database_default
LEFT JOIN Reporting_UKHD_ODS.Provider_Hierarchies ph ON COALESCE(ps.Prov_Successor, m.Org_Code) = ph.Organisation_Code COLLATE database_default

order by 1,3,5,6




DROP TABLE #EIPTEMP



