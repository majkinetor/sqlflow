CREATE TABLE [dbo].[Orders]( 
    [OrderID] [int] NOT NULL, 
    [ProductID] [int] NOT NULL, 
    [Quantity] [int] NOT NULL, 
    [OriginState] [nvarchar](2) NOT NULL, 
    
    CONSTRAINT [PK_Orders] PRIMARY KEY CLUSTERED ([OrderID] ASC,[ProductID] ASC) 
)