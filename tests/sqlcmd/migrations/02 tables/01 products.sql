CREATE TABLE [dbo].[Products](
    [ID] [int] NOT NULL, 
    [Name] [nvarchar](50) NOT NULL, 
    [ListPrice] [money] NOT NULL
 
    CONSTRAINT [PK_Products] PRIMARY KEY CLUSTERED ([ID] ASC) 
)