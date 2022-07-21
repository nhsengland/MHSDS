USE [NHSE_Sandbox_MentalHealth]
GO

/****** Object:  Table [dbo].[PreProc_Assessments]    Script Date: 17/06/2021 15:26:26 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [dbo].[PreProc_Assessments](
	-- core bits
	[Der_RecordID] [int] IDENTITY(1,1) NOT NULL,
	[ReportingPeriodStartDate] [date] NULL,
	[ReportingPeriodEndDate] [date] NULL,
	[Der_FY] [varchar](10) NULL,
	[UniqSubmissionID] [bigint] NULL, 
	[NHSEUniqSubmissionID] [varchar] (30) NULL,
	[UniqMonthID] [bigint] NULL,
	[OrgIDProv] [varchar](6) NULL,
	[Person_ID] [varchar](100) NULL,	
	[RecordNumber] [bigint] NULL,
	--assessment
	[UniqServReqID] [varchar](30) NULL,
	[UniqCareContID] [varchar](30) NULL,
	[UniqCareActID] [varchar](30) NULL,
	[CodedAssToolType] [varchar](18) NULL,
	[PersScore] [varchar](5) NULL,
	--derivations
	[Der_AssUniqID] [bigint] NULL,
	[Der_AssTable] [varchar](8) NOT NULL,
	[Der_AssToolCompDate] [date] NULL,
	[Der_AgeAssessTool] [int] NULL,
	[Der_AssessmentToolName] [nvarchar](255) NULL,
	[Der_PreferredTermSNOMED] [nvarchar](255) NULL,
	[Der_SNOMEDCodeVersion] [nvarchar](255) NULL,
	[Der_LowerRange] [float] NULL,
	[Der_UpperRange] [float] NULL,
	[Der_ValidScore] [varchar](1) NULL,
	[Der_AssessmentCategory] [varchar](255) NULL,
	[Der_AssOrderAsc] [bigint] NULL,
	[Der_AssOrderDesc] [bigint] NULL,
	[Der_AssKey] [varchar](255) NULL,

PRIMARY KEY CLUSTERED 
(
	[Der_RecordID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF) ON [PRIMARY]
) ON [PRIMARY]
GO