/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
MAS DASHBOARD REBUILD 

CREATED 13 AUGUST 2024 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

-- Set reporting period 

DECLARE @RPSTART INT 
DECLARE @RPEND INT 

SET @RPSTART = 1429 -- April 2019 
SET @RPEND = (SELECT MAX(UniqMonthID) FROM MHDInternal.PreProc_Header)

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET REFERRALS WITH A DEMENTIA/MCI PRIMARY OR SECONDARY DIAGNOSIS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

IF OBJECT_ID ('[MHDInternal].[Temp_DEM_MAS_Diag]') IS NOT NULL 
DROP TABLE [MHDInternal].Temp_DEM_MAS_Diag

 SELECT 
	p.Der_Person_ID
	,p.UniqServReqID
	,p.RecordNumber
	,p.UniqMonthID
	,CAST('PRIMARY' as varchar(15)) AS DiagType 
	,p.PrimDiag AS [Diagnosis]
	,p.CodedDiagTimestampDatetime
	,CASE WHEN PrimDiag IN ('F06.7','F067','386805003','28E0.','Xaagi') THEN 'MCI' ELSE 'Dementia' END AS 'Diagnosis Area'
 
 INTO [MHDInternal].Temp_DEM_MAS_Diag

 FROM MESH_MHSDS.MHS604PrimDiag p
 INNER JOIN MESH_MHSDS.MHSDS_SubmissionFlags f ON p.NHSEUniqSubmissionID = f.NHSEUniqSubmissionID AND f.Der_IsLatest = 'Y' 

 WHERE 
(p.[PrimDiag] IN

(--Dementia ICD10 codes Page 13 of Dementia Care Pathway Appendices
'F00.0','F00.1','F00.2','F00.9','F01.0','F01.1','F01.2','F01.3','F01.8','F01.9','F02.0','F02.1','F02.2','F02.3','F02.4','F02.8','F03','F05.1'
,'F000','F001','F002','F009','F010','F011','F012','F013','F018','F019','F020','F021','F022','F023','F024','F028','F051'

--This Dagger code is included as it is required in combination with F02.8 to identify Lewy body disease. 
--We are unable to filter MHSDS for those with both F02.8 AND G31.8 so have to filter for those with either F02.8 or G31.8
,'G318','G31.8'

--Dementia SNOMED codes Page 14 of Dementia Care Pathway Appendices
,'52448006','15662003','191449005','191457008','191461002','231438001','268612007','45864009','26929004','416780008','416975007','4169750 07','429998004','230285003'
,'56267009','230286002','230287006','230270009','230273006','90099008','230280008','86188000','13092008','21921000119103','429458009','442344002','792004'
,'713060000','425390006'
--Dementia SNOMED codes Page 15 of Dementia Care Pathway Appendices
,'713844000','191475009','80098002','312991009','135811000119107','13 5 8110 0 0119107','42769004','191519005','281004','191493005','111480006','1114 8 0 0 0 6'
,'32875003','59651006','278857002','230269008','79341000119107','12348006','421023003','713488003','191452002','65096006','31081000119101','191455000'
,'1089501000000102','10532003','191454001','230267005','230268000','230265002'
--Dementia SNOMED codes Page 16 of Dementia Care Pathway Appendices
,'230266001','191451009','1914510 09','22381000119105','230288001','191458003','191459006','191463004','191464005','191465006','191466007','279982005','6475002'
,'66108005'
	
--Dementia Read code v2 on Page 17 of Dementia Care Pathway Appendices
,'E00..%','E0 0..%','Eu01.%','Eu 01.%','Eu02.%','Eu 02.%','E012.%','Eu00.%','Eu 0 0.%','F110.%','A411.%','A 411.%','E02y1','E041.','E0 41.','Eu041','Eu 0 41'
,'F111.','F112.','F116.','F118.','F21y2','A410.','A 410.'
	
--Dementia CTV3 code on Page 17 of Dementia Care Pathway Appendices
--F110.%, Eu02.%,'E02y1' are in this list but are mentioned in the read code v2 list
,'XE1Xr%','X002w%','XE1Xs','Xa0sE'

--MCI codes
,'F06.7','F067' --ICD10 codes on Page 13 of Dementia Care Pathway Appendices
,'386805003' --SNOMED Code on Page 16 of Dementia Care Pathway Appendices
,'28E0.' --Read code v2 on Page 17 of Dementia Care Pathway Appendices
,'Xaagi' --CTV3 code on Page 17 of Dementia Care Pathway Appendices
)

OR p.PrimDiag LIKE 'F03%')


---- Combine with secondary diagnoses 
INSERT INTO [MHDInternal].Temp_DEM_MAS_Diag

 SELECT 
	p.Der_Person_ID
	,p.UniqServReqID
	,p.RecordNumber
	,p.UniqMonthID
	,'SECONDARY' AS DiagType 
	,p.SecDiag AS [Diagnosis]
	,p.CodedDiagTimestampDatetime
	,CASE WHEN SecDiag IN ('F06.7','F067','386805003','28E0.','Xaagi') THEN 'MCI' ELSE 'Dementia' END AS 'Diagnosis Area'
 
 FROM MESH_MHSDS.MHS605SecDiag p
 INNER JOIN MESH_MHSDS.MHSDS_SubmissionFlags f ON p.NHSEUniqSubmissionID = f.NHSEUniqSubmissionID AND f.Der_IsLatest = 'Y' 

 WHERE 
(p.SecDiag IN

(--Dementia ICD10 codes Page 13 of Dementia Care Pathway Appendices
'F00.0','F00.1','F00.2','F00.9','F01.0','F01.1','F01.2','F01.3','F01.8','F01.9','F02.0','F02.1','F02.2','F02.3','F02.4','F02.8','F03','F05.1'
,'F000','F001','F002','F009','F010','F011','F012','F013','F018','F019','F020','F021','F022','F023','F024','F028','F051'

--This Dagger code is included as it is required in combination with F02.8 to identify Lewy body disease. 
--We are unable to filter MHSDS for those with both F02.8 AND G31.8 so have to filter for those with either F02.8 or G31.8
,'G318','G31.8'

--Dementia SNOMED codes Page 14 of Dementia Care Pathway Appendices
,'52448006','15662003','191449005','191457008','191461002','231438001','268612007','45864009','26929004','416780008','416975007','4169750 07','429998004','230285003'
,'56267009','230286002','230287006','230270009','230273006','90099008','230280008','86188000','13092008','21921000119103','429458009','442344002','792004'
,'713060000','425390006'
--Dementia SNOMED codes Page 15 of Dementia Care Pathway Appendices
,'713844000','191475009','80098002','312991009','135811000119107','13 5 8110 0 0119107','42769004','191519005','281004','191493005','111480006','1114 8 0 0 0 6'
,'32875003','59651006','278857002','230269008','79341000119107','12348006','421023003','713488003','191452002','65096006','31081000119101','191455000'
,'1089501000000102','10532003','191454001','230267005','230268000','230265002'
--Dementia SNOMED codes Page 16 of Dementia Care Pathway Appendices
,'230266001','191451009','1914510 09','22381000119105','230288001','191458003','191459006','191463004','191464005','191465006','191466007','279982005','6475002'
,'66108005'
	
--Dementia Read code v2 on Page 17 of Dementia Care Pathway Appendices
,'E00..%','E0 0..%','Eu01.%','Eu 01.%','Eu02.%','Eu 02.%','E012.%','Eu00.%','Eu 0 0.%','F110.%','A411.%','A 411.%','E02y1','E041.','E0 41.','Eu041','Eu 0 41'
,'F111.','F112.','F116.','F118.','F21y2','A410.','A 410.'
	
--Dementia CTV3 code on Page 17 of Dementia Care Pathway Appendices
--F110.%, Eu02.%,'E02y1' are in this list but are mentioned in the read code v2 list
,'XE1Xr%','X002w%','XE1Xs','Xa0sE'

--MCI codes
,'F06.7','F067' --ICD10 codes on Page 13 of Dementia Care Pathway Appendices
,'386805003' --SNOMED Code on Page 16 of Dementia Care Pathway Appendices
,'28E0.' --Read code v2 on Page 17 of Dementia Care Pathway Appendices
,'Xaagi' --CTV3 code on Page 17 of Dementia Care Pathway Appendices
)

OR p.SecDiag LIKE 'F03%')



/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
RANK DEMENTIA DIAGNOSES WITHIN REFERRALS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

IF OBJECT_ID ('[MHDInternal].[Temp_DEM_MAS_DiagRank]') IS NOT NULL 
DROP TABLE [MHDInternal].Temp_DEM_MAS_DiagRank

 SELECT 
	UniqServReqID
	,Der_Person_ID
	,CodedDiagTimestampDatetime
	,UniqMonthID
	,Diagnosis
	,[Diagnosis Area]
	,ROW_NUMBER() OVER(PARTITION BY [UniqServReqID],[Der_Person_ID] ORDER BY CodedDiagTimestampDatetime ASC, [Diagnosis Area] DESC ) AS RowIDEarliest	--There are instances of more than one primary diagnosis with the same timestamp. In this case MCI is used over Dementia as the latest diagnosis is ordered alphabetically.
	,ROW_NUMBER() OVER(PARTITION BY [UniqServReqID],[Der_Person_ID] ORDER BY CodedDiagTimestampDatetime DESC, [Diagnosis Area] ASC) AS RowIDLatest		--There are instances of more than one primary diagnosis with the same timestamp. In this case Dementia is used over MCI as ordered alphabetically.

INTO [MHDInternal].Temp_DEM_MAS_DiagRank

FROM [MHDInternal].Temp_DEM_MAS_Diag




 /* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET ALL DEMENTIA REFERRALS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 IF OBJECT_ID ('[MHDInternal].[Temp_DEM_MAS_Ref]') IS NOT NULL 
 DROP TABLE [MHDInternal].Temp_DEM_MAS_Ref

 SELECT 
	r.UniqServReqID
	,r.Person_ID
	,r.ReportingPeriodStartDate
	,r.ReportingPeriodEndDate
	,r.RecordNumber
	,r.ServTeamTypeRefToMH
	,r.PrimReasonReferralMH
	,d.CodedDiagTimestampDatetime AS DiagDate_first 
	,d.Diagnosis AS Diagnosis_first
	,d.[Diagnosis Area] AS DiagnosisArea_first
	,r.ReferralRequestReceivedDate
	,r.ServDischDate
	,r.OrgIDProv
	,r.Der_SubICBCode -- GP derived commissioner 
	,r.AgeServReferRecDate
	,r.EthnicCategory
	,r.Gender

INTO [MHDInternal].Temp_DEM_MAS_Ref
	
FROM MHDInternal.PreProc_Referral r 

LEFT JOIN MHDInternal.Temp_DEM_MAS_DiagRank d ON r.UniqServReqID = d.UniqServReqID AND r.Person_ID = d.Der_Person_ID AND d.RowIDEarliest = 1 AND d.CodedDiagTimestampDatetime <= r.ReportingPeriodEndDate

WHERE  (r.UniqMonthID BETWEEN @RPSTART AND @RPEND)
AND
	(r.ServTeamTypeRefToMH = 'A17' -- Memory Service/Clinic
	OR r.PrimReasonReferralMH = '08' --- OBD 
	OR d.CodedDiagTimestampDatetime <= r.ReportingPeriodEndDate -- Dementia/MCI diagnosis)
	)



/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CALCULATE DEMENTIA REFERRAL DIMENSIONS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

IF OBJECT_ID ('[MHDInternal].[Temp_DEM_MAS_Dim]') IS NOT NULL 
DROP TABLE [MHDInternal].Temp_DEM_MAS_Dim

SELECT 
	r.UniqServReqID
	,r.Person_ID
	,r.ReportingPeriodStartDate
	,r.ReportingPeriodEndDate
	,r.RecordNumber
	,r.ServTeamTypeRefToMH
	,COALESCE(t.Main_Description, 'Missing/invalid') AS TeamType 
	,r.PrimReasonReferralMH
	,ISNULL(rr.Main_Description, 'Missing/invalid') AS PrimReason
	,r.DiagDate_first
	,r.Diagnosis_first 
	,r.DiagnosisArea_first 
	,r.ReferralRequestReceivedDate
	,r.ServDischDate
	,r.OrgIDProv 
	,p.Organisation_Name AS Provider_Name
	,COALESCE(cc.New_Code,r.Der_SubICBCode, 'Missing/Invalid') AS SubICBCode 
	,COALESCE(c.Organisation_Name,'Missing/Invalid') AS Sub_ICB_Name
	,COALESCE(c.STP_Code,'Missing/Invalid') AS ICB_Code
	,COALESCE(c.STP_Name,'Missing/Invalid') AS ICB_Name
	,COALESCE(c.Region_Code,'Missing/Invalid') AS Comm_Region_Code
	,COALESCE(c.Region_Name,'Missing/Invalid') AS Comm_Region_Name 
	,p.Region_Code AS Prov_Region_Code 
	,p.Region_Name AS Prov_Region_Name 
	,r.AgeServReferRecDate
	,CASE WHEN AgeServReferRecDate < 65 THEN 'Under65'
		WHEN AgeServReferRecDate BETWEEN 65 AND 74 THEN '65to74'
		WHEN AgeServReferRecDate BETWEEN 75 AND 84 THEN '75to84'
		WHEN AgeServReferRecDate >= 85 THEN '85+' 
		ELSE 'Unknown/Not Stated' 
	END AS AgeGroup
	,CASE 
		WHEN e.Category IS NULL THEN  'Missing / invalid'
		WHEN e.Category = '' THEN 'Missing / invalid'
		ELSE CONCAT(e.[Category],' - ',e.[Main_Description_60_Chars])
	END AS EthnicCategory
	,COALESCE(g.Main_Description, 'Missing / invalid') AS Gender

INTO [MHDInternal].Temp_DEM_MAS_Dim

FROM [MHDInternal].Temp_DEM_MAS_Ref r 

LEFT JOIN Reporting_UKHD_ODS.Provider_Hierarchies p ON r.OrgIDProv = p.Organisation_Code
LEFT JOIN Internal_Reference.ComCodeChanges cc ON r.Der_SubICBCode = cc.Org_Code
LEFT JOIN Reporting_UKHD_ODS.Commissioner_Hierarchies c ON COALESCE(cc.New_Code,r.Der_SubICBCode) = c.Organisation_Code
LEFT JOIN UKHD_Data_Dictionary.Service_Or_Team_Type_For_Mental_Health_SCD t ON r.ServTeamTypeRefToMH = t.Main_Code_Text COLLATE DATABASE_DEFAULT AND t.Effective_To IS NULL AND t.Valid_To IS NULL
LEFT JOIN UKHD_Data_Dictionary.Reason_For_Referral_To_Mental_Health_SCD rr ON r.PrimReasonReferralMH = rr.Main_Code_Text COLLATE DATABASE_DEFAULT AND rr.Effective_To IS NULL AND rr.Valid_To IS NULL
LEFT JOIN UKHD_Data_Dictionary.Ethnic_Category_Code_SCD_1 e ON r.EthnicCategory = e.[Main_Code_Text] COLLATE DATABASE_DEFAULT AND e.Is_Latest = 1
LEFT JOIN UKHD_Data_Dictionary.Person_Gender_Code_SCD g ON r.Gender = g.Main_Code_text COLLATE DATABASE_DEFAULT AND g.Effective_To IS NULL AND g.Valid_To IS NULL


/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET FIRST CARE CONTACT FOR DEMENTIA REFERRALS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

IF OBJECT_ID ('MHDInternal.Temp_DEM_MAS_FirstCont') IS NOT NULL
DROP TABLE MHDInternal.Temp_DEM_MAS_FirstCont

SELECT
	r.ReportingPeriodEndDate,
	r.RecordNumber,
	r.UniqServReqID,

	-- cumulative activity
	MAX(a.Der_ContactDate) AS Der_LastContact,
	MIN(a.Der_ContactDate) AS Der_FirstContactDate,
	SUM(a.Der_Contact) AS Der_CumulativeContacts

INTO MHDInternal.Temp_DEM_MAS_FirstCont

FROM MHDInternal.Temp_DEM_MAS_Dim r

LEFT JOIN MHDInternal.PreProc_Activity a ON a.Person_ID = r.Person_ID AND r.UniqServReqID = a.UniqServReqID 
	AND a.ReportingPeriodEndDate <= r.ReportingPeriodEndDate 

WHERE a.Der_DirectContact = 1

GROUP BY r.RecordNumber, r.ReportingPeriodEndDate, r.UniqServReqID


/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GET EARLIEST CARE PLAN CREATED FOR DEMENTIA REFERRALS 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

IF OBJECT_ID ('[MHDInternal].[Temp_DEM_MAS_CarePlan]') IS NOT NULL 
DROP TABLE [MHDInternal].Temp_DEM_MAS_CarePlan

SELECT 
	r.UniqServReqID
	,r.Person_ID
	,r.ReportingPeriodEndDate
	,r.RecordNumber 
	,MIN(cp.CarePlanCreatDate) AS First_CarePlan

INTO [MHDInternal].Temp_DEM_MAS_CarePlan

FROM [MHDInternal].Temp_DEM_MAS_Dim r  

INNER JOIN MESH_MHSDS.MHS008CarePlanType cp ON r.Person_ID = cp.Der_Person_ID AND r.RecordNumber = cp.RecordNumber 

GROUP BY r.UniqServReqID, r.Person_ID, r.ReportingPeriodEndDate, r.RecordNumber 
ORDER BY 1,3



/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
CALCULATE MEASURES 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

IF OBJECT_ID ('[MHDInternal].[Temp_DEM_MAS_Master]') IS NOT NULL 
DROP TABLE [MHDInternal].Temp_DEM_MAS_Master

SELECT 
	d.UniqServReqID
	,d.Person_ID
	,d.ReportingPeriodStartDate
	,d.ReportingPeriodEndDate
	,d.RecordNumber
	,d.ServTeamTypeRefToMH
	,d.TeamType 
	,d.PrimReasonReferralMH
	,d.PrimReason
	,d.DiagDate_first
	,d.Diagnosis_first 
	,d.DiagnosisArea_first 
	,d.ReferralRequestReceivedDate
	,d.ServDischDate
	,f.Der_FirstContactDate
	,f.Der_CumulativeContacts
	,d.OrgIDProv 
	,d.Provider_Name
	,d.SubICBCode 
	,d.Sub_ICB_Name
	,d.ICB_Code
	,d.ICB_Name
	,d.Comm_Region_Code
	,d.Comm_Region_Name 
	,d.Prov_Region_Code
	,d.Prov_Region_Name
	,d.AgeServReferRecDate
	,d.AgeGroup
	,d.EthnicCategory
	,d.Gender
	--- Caseload measures 
	,CASE WHEN d.ReferralRequestReceivedDate BETWEEN d.ReportingPeriodStartDate AND d.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [New referrals] -- new referrals in RP
	,CASE WHEN d.ServDischDate BETWEEN d.ReportingPeriodStartDate AND d.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [Discharged referrals] -- referrals discharged in RP 
	,CASE WHEN d.ServDischDate IS NULL OR d.ServDischDate > d.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [Open referrals] --- refs open at RP end 
	,CASE WHEN (d.ServDischDate IS NULL OR d.ServDischDate > d.ReportingPeriodEndDate) AND (f.Der_FirstContactDate IS NULL OR f.Der_FirstContactDate > d.ReportingPeriodEndDate) THEN 1 ELSE 0 END AS [Open waiting for contact] -- open refs waiting for contact
	,CASE WHEN (d.ServDischDate IS NULL OR d.ServDischDate > d.ReportingPeriodEndDate) AND f.Der_LastContact IS NOT NULL THEN 1 ELSE 0 END AS [Caseload] 
	,CASE WHEN (d.ServDischDate IS NULL OR d.ServDischDate > d.ReportingPeriodEndDate) AND (c.First_CarePlan <= d.ReportingPeriodEndDate) THEN 1 ELSE 0 END AS [Open with Care Plan] -- open refs with a Care Plan 
	--- Time to first contact 
	,CASE WHEN f.Der_FirstContactDate BETWEEN d.ReportingPeriodStartDate and d.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [First contact in RP] -- having first contact in month 
	,CASE WHEN f.Der_FirstContactDate BETWEEN d.ReportingPeriodStartDate AND d.ReportingPeriodEndDate THEN DATEDIFF(DD, ReferralRequestReceivedDate, Der_FirstContactDate) END AS [Time to 1st contact] -- time from ref to 1st contact, where 1st contact in RP
	,CASE WHEN f.Der_FirstContactDate BETWEEN d.ReportingPeriodStartDate AND d.ReportingPeriodEndDate AND DATEDIFF(DD, ReferralRequestReceivedDate, Der_FirstContactDate) < (6*7) THEN 1 ELSE 0 END AS [Time to 1st contact - under 6 weeks] -- time from ref to 1st contact, where 1st contact in RP
	,CASE WHEN f.Der_FirstContactDate BETWEEN d.ReportingPeriodStartDate AND d.ReportingPeriodEndDate AND DATEDIFF(DD, ReferralRequestReceivedDate, Der_FirstContactDate) BETWEEN (6*7) AND (18*7) THEN 1 ELSE 0 END AS [Time to 1st contact - 6-18 weeks] -- time from ref to 1st contact, where 1st contact in RP
	,CASE WHEN f.Der_FirstContactDate BETWEEN d.ReportingPeriodStartDate AND d.ReportingPeriodEndDate AND DATEDIFF(DD, ReferralRequestReceivedDate, Der_FirstContactDate) > (18*7) THEN 1 ELSE 0 END AS [Time to 1st contact - over 18 weeks] -- time from ref to 1st contact, where 1st contact in RP
	--- Time to first diagnosis 
	,CASE WHEN d.DiagDate_first BETWEEN d.ReportingPeriodStartDate and d.ReportingPeriodEndDate THEN 1 ELSE 0 END AS [First diag in RP] -- having first contact in month 
	,CASE WHEN d.DiagDate_first BETWEEN d.ReportingPeriodStartDate AND d.ReportingPeriodEndDate THEN DATEDIFF(DD, ReferralRequestReceivedDate, DiagDate_first) END AS [Time to 1st diag] -- time from ref to 1st contact, where 1st contact in RP
	,CASE WHEN d.DiagDate_first BETWEEN d.ReportingPeriodStartDate AND d.ReportingPeriodEndDate AND DATEDIFF(DD, ReferralRequestReceivedDate, DiagDate_first) < (6*7) THEN 1 ELSE 0 END AS [Time to 1st diag - under 6 weeks] -- time from ref to 1st contact, where 1st contact in RP
	,CASE WHEN d.DiagDate_first BETWEEN d.ReportingPeriodStartDate AND d.ReportingPeriodEndDate AND DATEDIFF(DD, ReferralRequestReceivedDate, DiagDate_first) BETWEEN (6*7) AND (18*7) THEN 1 ELSE 0 END AS [Time to 1st diag - 6-18 weeks] -- time from ref to 1st contact, where 1st contact in RP
	,CASE WHEN d.DiagDate_first BETWEEN d.ReportingPeriodStartDate AND d.ReportingPeriodEndDate AND DATEDIFF(DD, ReferralRequestReceivedDate, DiagDate_first) > (18*7) THEN 1 ELSE 0 END AS [Time to 1st diag - over 18 weeks] -- time from ref to 1st contact, where 1st contact in RP

	,CASE WHEN DiagDate_first >= ReferralRequestReceivedDate THEN 'Diagnosis After Referral' WHEN DiagDate_first<ReferralRequestReceivedDate THEN 'Diagnosis Before Referral' ELSE 'No Diagnosis' END AS RefToEarliestDiagOrder

INTO [MHDInternal].Temp_DEM_MAS_Master

FROM MHDInternal.Temp_DEM_MAS_Dim d 

LEFT JOIN [MHDInternal].Temp_DEM_MAS_FirstCont f ON d.UniqServReqID = f.UniqServReqID AND d.RecordNumber = f.RecordNumber 
LEFT JOIN [MHDInternal].Temp_DEM_MAS_CarePlan c ON d.UniqServReqID = c.UniqServReqID AND d.RecordNumber = c.RecordNumber 




/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
AGGREGATE MAIN ACTIVITY MESAURES 
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

IF OBJECT_ID ('[MHDInternal].Temp_DEM_MAS_AggMain') IS NOT NULL 
DROP TABLE [MHDInternal].Temp_DEM_MAS_AggMain

SELECT 
	'Main Dashboard' AS Section
	,ReportingPeriodEndDate
	,OrgIDProv AS [Provider Code] 
	,Provider_Name AS [Provider Name] 
	,SubICBCode AS [SubICB Code]
	,Sub_ICB_Name AS [SubICB Name]
	,m.ICB_Code AS [ICB Code]
	,ICB_Name AS [ICB Name]
	,Comm_Region_Code AS [Region Code]
	,Comm_Region_Name AS [Region Name] 	
	,TeamType AS [Team Type]
	,PrimReason AS [Primary reason for referral]
	,ISNULL(DiagnosisArea_first,'None') AS [Diagnosis] 
	,SUM([New referrals]) AS [New referrals]
	,SUM([Discharged referrals]) AS [Discharged referrals]
	,SUM([Open referrals]) AS [Open referrals]
	,SUM([Open waiting for contact]) AS [Open waiting for contact]
	,SUM(Caseload) AS Caseload
	,SUM([Open with Care Plan]) AS [Open with Care Plan]

	,SUM([First contact in RP]) AS [First contact in RP]
	,SUM([Time to 1st contact]) AS [Time to 1st contact] -- numerator for mean time to 1st contact 
	,SUM([Time to 1st contact - under 6 weeks]) AS [Time to 1st contact - under 6 weeks]
	,SUM([Time to 1st contact - 6-18 weeks]) AS [Time to 1st contact - 6-18 weeks]
	,SUM([Time to 1st contact - over 18 weeks]) AS [Time to 1st contact - over 18 weeks]
	
	,SUM([First diag in RP]) AS [First diag in RP]
	,SUM([Time to 1st diag]) AS [Time to 1st diag] --- numerator for mean time to 1st diag 
	,SUM([Time to 1st diag - under 6 weeks]) AS [Time to 1st diag - under 6 weeks]
	,SUM([Time to 1st diag - 6-18 weeks]) AS [Time to 1st diag - 6-18 weeks]
	,SUM([Time to 1st diag - over 18 weeks]) AS [Time to 1st diag - over 18 weeks]

	-- Duplicate measures for Tableau denominators 
	,SUM([Open referrals]) AS [Open referrals2]
	,SUM([First contact in RP]) AS [First contact in RP2]
	,SUM([First diag in RP]) AS [First diag in RP2]

INTO [MHDInternal].Temp_DEM_MAS_AggMain

FROM [MHDInternal].Temp_DEM_MAS_Master m 

GROUP BY ReportingPeriodEndDate, OrgIDProv , Provider_Name ,SubICBCode ,Sub_ICB_Name 
	,ICB_Code,ICB_Name,Comm_Region_Code,Comm_Region_Name ,TeamType ,PrimReason ,DiagnosisArea_first




/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
UNPIVOT AND CREATE ACTIVITY EXTRACT
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/

IF OBJECT_ID ('MHDInternal.[Dashboard_Dem_MAS]') IS NOT NULL
DROP TABLE MHDInternal.[Dashboard_Dem_MAS]

SELECT
	ReportingPeriodEndDate,
	[Provider code],
	[Provider name],
	[SubICB Code],
	[SubICB Name],
	[ICB Code],
	[ICB Name],
	[Region code],
	[Region name],
	Diagnosis,
	[Primary reason for referral],
	[Team type],
	MeasureName,
	MeasureValue,
	CASE 
		WHEN MeasureName IN ('Open waiting for contact','Caseload','Open with Care Plan') THEN [Open referrals2]
		WHEN MeasureName = 'Time to 1st contact' THEN [First contact in RP2] 
		WHEN MeasureName IN ('Time to 1st contact - under 6 weeks','Time to 1st contact - 6-18 weeks','Time to 1st contact - over 18 weeks') THEN [First contact in RP2]
		WHEN MeasureName = 'Time to 1st diag' THEN [First diag in RP2] 
		WHEN MeasureName IN ('Time to 1st diag - under 6 weeks','Time to 1st diag - 6-18 weeks','Time to 1st diag - over 18 weeks') THEN [First diag in RP2]
	END	AS Denominator

INTO [MHDInternal].[Dashboard_Dem_MAS]

FROM MHDInternal.Temp_DEM_MAS_AggMain 

UNPIVOT (MeasureValue FOR MeasureName IN 
	([New referrals],[Discharged referrals], [Open referrals], [Open waiting for contact], [Caseload], [Open with Care Plan],
	[First contact in RP], [Time to 1st contact], [Time to 1st contact - under 6 weeks], [Time to 1st contact - 6-18 weeks], [Time to 1st contact - over 18 weeks],
	[First diag in RP], [Time to 1st diag], [Time to 1st diag - under 6 weeks], [Time to 1st diag - 6-18 weeks], [Time to 1st diag - over 18 weeks]
	))u 




--- DROP TEMPORARY TABLES 
DROP TABLE [MHDInternal].Temp_DEM_MAS_Diag
DROP TABLE MHDInternal.Temp_DEM_MAS_DiagRank
DROP TABLE MHDInternal.Temp_DEM_MAS_Ref
DROP TABLE MHDInternal.Temp_DEM_MAS_Dim
DROP TABLE MHDInternal.Temp_DEM_MAS_FirstCont
DROP TABLE MHDInternal.Temp_DEM_MAS_CarePlan 
DROP TABLE MHDInternal.Temp_DEM_MAS_Master
DROP TABLE MHDInternal.Temp_DEM_MAS_AggMain 
