
IF OBJECT_ID ('[MHDInternal].[DASHBOARD_CDP_Num_&_Den_Transposed]') IS NOT NULL
DROP TABLE [MHDInternal].[DASHBOARD_CDP_Num_&_Den_Transposed]

SELECT M.Reporting_Period,
	   M.Is_Latest,
       M.CDP_Measure_ID,
       M.CDP_Measure_Name,
       M.Org_Type,
       M.Org_Code,
       M.Org_Name,
       M.ICB_Code,
       M.ICB_Name,
       M.Region_Code,
       M.Region_Name,
       M.Measure_Type,
       M.Measure_Value,
	   N.Measure_Value_STR AS Numerator_STR,
	   D.Measure_Value_STR AS Denominator_STR,
       M.[Standard],
       M.LTP_Trajectory,
       M.LTP_Trajectory_Percentage_Achieved,
       M.[Plan],
       M.Plan_Percentage_Achieved,
       M.Measure_Value_STR,
       M.Standard_STR,
       M.LTP_Trajectory_STR,
       M.LTP_Trajectory_Percentage_Achieved_STR,
       M.Plan_STR,
       M.Plan_Percentage_Achieved_STR,
       M.Last_Modified

  INTO [MHDInternal].[DASHBOARD_CDP_Num_&_Den_Transposed]
  
  FROM [MHDInternal].[DASHBOARD_CDP] M

LEFT JOIN (SELECT Reporting_Period, CDP_Measure_ID, Org_Code, Measure_Value_STR
			 FROM [MHDInternal].[DASHBOARD_CDP]
		    WHERE Measure_Type = 'Numerator') N
			ON M.Reporting_Period = N.Reporting_Period
			AND M.CDP_Measure_ID = N.CDP_Measure_ID
			AND M.Org_Code = N.Org_Code


LEFT JOIN (SELECT Reporting_Period, CDP_Measure_ID, Org_Code, Measure_Value_STR
			 FROM [MHDInternal].[DASHBOARD_CDP]
		    WHERE Measure_Type = 'Denominator') D
			   ON M.Reporting_Period = D.Reporting_Period
			  AND M.CDP_Measure_ID = D.CDP_Measure_ID
			  AND M.Org_Code = D.Org_Code

WHERE M.Measure_Type NOT IN ('Numerator','Denominator')
