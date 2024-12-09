

IF OBJECT_ID ('[MHDInternal].[DASHBOARD_CDP_Num_&_Den_Transposed_&_SPC]') IS NOT NULL
DROP TABLE [MHDInternal].[DASHBOARD_CDP_Num_&_Den_Transposed_&_SPC]


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
       M.Last_Modified,
	   S.[Target],
	   S.[Target_STR],
	   S.Mean,
	   S.UpperProcessLimit,
	   S.LowerProcessLimit,
	   S.VariationTrend,
	   S.VariationIcon,
	   S.AssuranceIcon,
	   S.Shapes

  INTO [MHDInternal].[DASHBOARD_CDP_Num_&_Den_Transposed_&_SPC]

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

LEFT JOIN (SELECT *
	         FROM [MHDInternal].[DASHBOARD_CDP_SPC] 
			WHERE CDP_Measure_ID IN ('CDP_B01', 'CDP_B02', 'CDP_B03','CDP_B05','CDP_D01','CDP_F01','CDP_F02','CDP_F03','CDP_M01')
			  AND Org_Type <> 'Provider') S 
			   ON M.Reporting_Period = S.Reporting_Period
			  AND M.CDP_Measure_ID = S.CDP_Measure_ID
			  AND M.Org_Code = S.Org_Code

WHERE M.Measure_Type NOT IN ('Numerator','Denominator')
