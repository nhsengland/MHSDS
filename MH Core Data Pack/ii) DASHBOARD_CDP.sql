IF OBJECT_ID ('[NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP]

SELECT * 
  INTO [NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP]
  FROM [NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP_QA]

IF OBJECT_ID ('[NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP_QA]') IS NOT NULL
DROP TABLE [NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP_QA]

-- Run Data for 'Backing Data' files

-- 19/20

SELECT * FROM [NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP] where [reporting_period] BETWEEN '2019-04-01' AND '2020-03-31'

-- 20/21

SELECT * FROM  [NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP] where [reporting_period] BETWEEN '2020-04-01' AND '2021-03-31'

-- 21/22

SELECT * FROM  [NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP] where [reporting_period] BETWEEN '2021-04-01' AND '2022-03-31'

-- 22/23

SELECT * FROM [NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP] where [reporting_period] BETWEEN '2022-04-01' AND '2023-03-31'

-- 23/24

SELECT * FROM [NHSE_Sandbox_Policy].[dbo].[DASHBOARD_CDP] where [reporting_period] BETWEEN '2023-04-01' AND '2024-03-31'
