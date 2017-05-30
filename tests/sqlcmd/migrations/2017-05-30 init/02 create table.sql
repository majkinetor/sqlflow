CREATE TABLE [dbo].[Products](
    [ID] [int] NOT NULL, 
    [Name] [nvarchar](50) NOT NULL, 
    [ListPrice] [money] NOT NULL
 
    CONSTRAINT [PK_Products] PRIMARY KEY CLUSTERED ([ID] ASC) 
) 
GO
 
CREATE TABLE [dbo].[Orders]( 
    [OrderID] [int] NOT NULL, 
    [ProductID] [int] NOT NULL, 
    [Quantity] [int] NOT NULL, 
    [OriginState] [nvarchar](2) NOT NULL, 
    CONSTRAINT [PK_Orders] PRIMARY KEY CLUSTERED ([OrderID] ASC,[ProductID] ASC) 
) 
GO