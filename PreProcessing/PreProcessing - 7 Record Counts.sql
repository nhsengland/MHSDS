
DECLARE @EndRP INT
DECLARE @ReportingPeriodEnd DATE

SET @EndRP = (SELECT UniqMonthID
FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header]
WHERE Der_MostRecentFlag = 'Y')

SET @ReportingPeriodEnd = (SELECT ReportingPeriodEndDate FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] WHERE UniqMonthID = @EndRP)

/* >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PREPROC RECORD COUNTS - DELETE PRIMARY DATA FROM LAST MONTH
>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>*/ 

 --LOG START

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Preproc Delete Primary Data Start' AS Step,
	GETDATE() AS [TimeStamp]

-- START CODE - DELETE DATA

DELETE FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] WHERE UniqMonthID = @EndRP AND SubmissionType = 'PreProc'

-- LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Preproc Delete Primary Data End' AS Step,
	GETDATE() AS [TimeStamp]

WAITFOR DELAY '00:00:01'

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
	SELECT 'PreProc_Activity' AS [TableName], NULL AS OrgIDProvider, UniqMonthID, 'PreProc' AS SubmissionType, COUNT (*) AS [RecordCount] 
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Activity] 
	WHERE UniqMonthID >= @EndRP 
	GROUP BY UniqMonthID 

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'PreProc_Assessments' AS [TableName], NULL AS OrgIDProvider, UniqMonthID, 'PreProc' AS SubmissionType, COUNT (*) AS [RecordCount] 
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Assessments] 
	WHERE UniqMonthID >= @EndRP 
	GROUP BY UniqMonthID 

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'PreProc_Inpatients' AS [TableName], NULL AS OrgIDProvider, UniqMonthID, 'PreProc' AS SubmissionType, COUNT (*) AS [RecordCount] 
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Inpatients] 
	WHERE UniqMonthID >= @EndRP 
	GROUP BY UniqMonthID 

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'PreProc_Interventions' AS [TableName], NULL AS OrgIDProvider, UniqMonthID, 'PreProc' AS SubmissionType, COUNT (*) AS [RecordCount] 
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Interventions] 
	WHERE UniqMonthID >= @EndRP 
	GROUP BY UniqMonthID 

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'PreProc_Header' AS [TableName], NULL AS OrgIDProvider, UniqMonthID, 'PreProc' AS SubmissionType, COUNT (*) AS [RecordCount] 
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Header] 
	WHERE UniqMonthID >= @EndRP 
	GROUP BY UniqMonthID 

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_RecordCounts] 
	SELECT 'PreProc_Referral' AS [TableName], NULL AS OrgIDProvider, UniqMonthID, 'PreProc' AS SubmissionType, COUNT (*) AS [RecordCount] 
	FROM [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_Referral] 
	WHERE UniqMonthID >= @EndRP 
	GROUP BY UniqMonthID 

--LOG END

INSERT INTO [NHSE_Sandbox_MentalHealth].[dbo].[PreProc_QueryStatus]

SELECT
	@EndRP AS [Month],
	'Record Counts Insert End' AS Step,
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