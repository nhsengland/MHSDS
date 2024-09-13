DECLARE @EndRP INT
DECLARE @ReportingPeriodEnd DATE

SET @EndRP = (SELECT UniqMonthID
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_MostRecentFlag = 'Y')

SET @ReportingPeriodEnd = (SELECT ReportingPeriodEndDate FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] WHERE UniqMonthID = @EndRP)

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
RECORD COUNTS - INSERT DATA
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

--LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'PreProc Record Counts Insert Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'PreProc_Activity' AS [TableName], @EndRP AS OrgIDProvider, UniqMonthID, 'PreProc' AS SubmissionType, COUNT (*) AS [RecordCount] 
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity] 
	GROUP BY UniqMonthID 

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'PreProc_Assessments' AS [TableName], @EndRP AS OrgIDProvider, UniqMonthID, 'PreProc' AS SubmissionType, COUNT (*) AS [RecordCount] 
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Assessments] 
	GROUP BY UniqMonthID 

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'PreProc_Inpatients' AS [TableName], @EndRP AS OrgIDProvider, UniqMonthID, 'PreProc' AS SubmissionType, COUNT (*) AS [RecordCount] 
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Inpatients] 
	GROUP BY UniqMonthID 

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'PreProc_Interventions' AS [TableName], @EndRP AS OrgIDProvider, UniqMonthID, 'PreProc' AS SubmissionType, COUNT (*) AS [RecordCount] 
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Interventions] 
	GROUP BY UniqMonthID 

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'PreProc_Header' AS [TableName], @EndRP AS OrgIDProvider, UniqMonthID, 'PreProc' AS SubmissionType, COUNT (*) AS [RecordCount] 
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] 
	GROUP BY UniqMonthID 

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'PreProc_Referral' AS [TableName], @EndRP AS OrgIDProvider, UniqMonthID, 'PreProc' AS SubmissionType, COUNT (*) AS [RecordCount] 
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Referral] 
	GROUP BY UniqMonthID 

--LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'PreProc Record Counts Insert End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
RECORD COUNTS - RECREATE PK AND INDEXES
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Record Counts Create Index Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - CREATE INDEXES

CREATE INDEX ix_RecordCounts ON [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] ([UniqMonthID], [OrgIDProvider], [TableName], [SubmissionType])

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Record Counts Create Index End' AS Step,
	GETDATE() AS [TimeStamp]

END
