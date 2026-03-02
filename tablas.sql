CREATE TABLE Customers (
    CustomerID INT PRIMARY KEY,
    FirstName VARCHAR(100) NOT NULL,
    LastName VARCHAR(100) NOT NULL,
    Email VARCHAR(150),
    Phone VARCHAR(50),
    City VARCHAR(100),
    Country VARCHAR(100)
);

CREATE TABLE Products (
    ProductID INT PRIMARY KEY,
    ProductName VARCHAR(200) NOT NULL,
    Category VARCHAR(100),
    Price DECIMAL(18,2) NOT NULL,
    Stock INT
);

CREATE TABLE Orders (
    OrderID INT PRIMARY KEY,
    CustomerID INT NOT NULL,
    OrderDate DATE NOT NULL,
    Status VARCHAR(50),
    CONSTRAINT FK_Orders_Customers FOREIGN KEY (CustomerID) REFERENCES Customers(CustomerID)
);

CREATE TABLE Invoices (
    InvoiceID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL,
    InvoiceDate DATE NOT NULL,
    TotalAmount DECIMAL(18,2) NOT NULL,
    CONSTRAINT FK_Invoices_Orders FOREIGN KEY (OrderID) REFERENCES Orders(OrderID)
);

CREATE TABLE OrderDetails (
    OrderDetailID INT IDENTITY(1,1) PRIMARY KEY,
    OrderID INT NOT NULL,
    ProductID INT NOT NULL,
    Quantity INT NOT NULL CHECK (Quantity > 0),
    TotalPrice DECIMAL(18,2) NOT NULL,
    CONSTRAINT FK_OrderDetails_Orders FOREIGN KEY (OrderID) REFERENCES Orders(OrderID),
    CONSTRAINT FK_OrderDetails_Products FOREIGN KEY (ProductID) REFERENCES Products(ProductID)
);

CREATE TABLE DataSources (
    SourceID INT IDENTITY(1,1) PRIMARY KEY,
    SourceType VARCHAR(50) NOT NULL,     -- CSV, API, SQL
    Description VARCHAR(150)
);

-- Consultas de ejemplo para verificar la carga
SELECT * FROM Customers;
SELECT * FROM Products;
SELECT * FROM Orders;
SELECT * FROM Invoices;
SELECT * FROM OrderDetails;
SELECT * FROM DataSources;

-- Consulta de ventas detallada
SELECT o.OrderID, c.FirstName, c.LastName, p.ProductName, od.Quantity, od.TotalPrice, o.OrderDate, o.Status
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN OrderDetails od ON o.OrderID = od.OrderID
JOIN Products p ON od.ProductID = p.ProductID;

-- Consulta de facturas
SELECT i.InvoiceID, o.OrderID, i.InvoiceDate, i.TotalAmount
FROM Invoices i
JOIN Orders o ON i.OrderID = o.OrderID;

/*
   ACTIVIDAD 3.1 – MODELADO DE BASE DE DATOS ANALÍTICA
   Repositorio central tipo Data Warehouse (esquema estrella)
 */

-- DER lógico (resumen):
-- DW_FactSales (hechos)
--   -> DW_DimDate (DateKey)
--   -> DW_DimCustomer (CustomerKey)
--   -> DW_DimProduct (ProductKey)
--   -> DW_DimLocation (LocationKey)
--   -> DW_DimSource (SourceID)

-- TABLAS DE DIMENSIÓN

IF OBJECT_ID('DW_DimDate', 'U') IS NULL
BEGIN
    CREATE TABLE DW_DimDate (
        DateKey INT PRIMARY KEY,                  -- formato YYYYMMDD
        FullDate DATE NOT NULL UNIQUE,
        [Day] TINYINT NOT NULL,
        [Month] TINYINT NOT NULL,
        [MonthName] VARCHAR(20) NOT NULL,
        [Quarter] TINYINT NOT NULL,
        [Year] SMALLINT NOT NULL,
        WeekOfYear TINYINT NULL
    );
END;

IF OBJECT_ID('DW_DimCustomer', 'U') IS NULL
BEGIN
    CREATE TABLE DW_DimCustomer (
        CustomerKey INT IDENTITY(1,1) PRIMARY KEY,
        CustomerID_Source INT NOT NULL,           -- referencia lógica a Customers.CustomerID
        FullName VARCHAR(220) NOT NULL,
        Email VARCHAR(150) NULL,
        Phone VARCHAR(50) NULL,
        City VARCHAR(100) NULL,
        Region VARCHAR(100) NULL,
        Country VARCHAR(100) NULL,
        CustomerType VARCHAR(50) NULL,
        IsActive BIT NOT NULL DEFAULT(1)
    );
END;

IF OBJECT_ID('DW_DimProduct', 'U') IS NULL
BEGIN
    CREATE TABLE DW_DimProduct (
        ProductKey INT IDENTITY(1,1) PRIMARY KEY,
        ProductID_Source INT NOT NULL,            -- referencia lógica a Products.ProductID
        ProductName VARCHAR(200) NOT NULL,
        Category VARCHAR(100) NULL,
        CurrentPrice DECIMAL(18,2) NOT NULL,
        IsActive BIT NOT NULL DEFAULT(1)
    );
END;

IF OBJECT_ID('DW_DimLocation', 'U') IS NULL
BEGIN
    CREATE TABLE DW_DimLocation (
        LocationKey INT IDENTITY(1,1) PRIMARY KEY,
        City VARCHAR(100) NULL,
        Region VARCHAR(100) NULL,
        Country VARCHAR(100) NULL,
        CONSTRAINT UQ_DW_DimLocation UNIQUE (City, Region, Country)
    );
END;

IF OBJECT_ID('DW_DimSource', 'U') IS NULL
BEGIN
    CREATE TABLE DW_DimSource (
        SourceID INT PRIMARY KEY,
        SourceType VARCHAR(50) NOT NULL,
        Description VARCHAR(150) NULL,
        CONSTRAINT FK_DW_DimSource_DataSources FOREIGN KEY (SourceID) REFERENCES DataSources(SourceID)
    );
END;


-- TABLA DE HECHOS


IF OBJECT_ID('DW_FactSales', 'U') IS NULL
BEGIN
    CREATE TABLE DW_FactSales (
        FactSalesKey BIGINT IDENTITY(1,1) PRIMARY KEY,
        DateKey INT NOT NULL,
        CustomerKey INT NOT NULL,
        ProductKey INT NOT NULL,
        LocationKey INT NOT NULL,
        SourceID INT NOT NULL,

        OrderID_Source INT NULL,                  -- referencia lógica a Orders.OrderID
        InvoiceID_Source INT NULL,                -- referencia lógica a Invoices.InvoiceID

        Quantity INT NOT NULL CHECK (Quantity > 0),
        UnitPrice DECIMAL(18,2) NOT NULL CHECK (UnitPrice >= 0),
        SalesAmount DECIMAL(18,2) NOT NULL CHECK (SalesAmount >= 0),
        TransactionCount INT NOT NULL DEFAULT(1),

        CONSTRAINT FK_DW_FactSales_DimDate FOREIGN KEY (DateKey) REFERENCES DW_DimDate(DateKey),
        CONSTRAINT FK_DW_FactSales_DimCustomer FOREIGN KEY (CustomerKey) REFERENCES DW_DimCustomer(CustomerKey),
        CONSTRAINT FK_DW_FactSales_DimProduct FOREIGN KEY (ProductKey) REFERENCES DW_DimProduct(ProductKey),
        CONSTRAINT FK_DW_FactSales_DimLocation FOREIGN KEY (LocationKey) REFERENCES DW_DimLocation(LocationKey),
        CONSTRAINT FK_DW_FactSales_DimSource FOREIGN KEY (SourceID) REFERENCES DW_DimSource(SourceID)
    );
END;

-- Índices analíticos recomendados
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_DW_FactSales_DateKey' AND object_id = OBJECT_ID('DW_FactSales'))
    CREATE INDEX IX_DW_FactSales_DateKey ON DW_FactSales(DateKey);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_DW_FactSales_ProductKey' AND object_id = OBJECT_ID('DW_FactSales'))
    CREATE INDEX IX_DW_FactSales_ProductKey ON DW_FactSales(ProductKey);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_DW_FactSales_CustomerKey' AND object_id = OBJECT_ID('DW_FactSales'))
    CREATE INDEX IX_DW_FactSales_CustomerKey ON DW_FactSales(CustomerKey);

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_DW_FactSales_SourceID' AND object_id = OBJECT_ID('DW_FactSales'))
    CREATE INDEX IX_DW_FactSales_SourceID ON DW_FactSales(SourceID);


-- CONSULTAS KPI / PREGUNTAS DE NEGOCIO


--  Análisis general de ventas
-- Total de ventas global
SELECT SUM(fs.SalesAmount) AS TotalVentasGlobal
FROM DW_FactSales fs;

-- Promedio de venta por transacción
SELECT AVG(fs.SalesAmount * 1.0) AS PromedioVentaPorTransaccion
FROM DW_FactSales fs;

-- Ventas totales por período (año/mes)
SELECT d.[Year], d.[Month],
       COUNT(*) AS TotalTransacciones,
       SUM(fs.SalesAmount) AS TotalVentas
FROM DW_FactSales fs
JOIN DW_DimDate d ON fs.DateKey = d.DateKey
GROUP BY d.[Year], d.[Month]
ORDER BY d.[Year], d.[Month];

-- Volumen de ventas por país/ciudad
SELECT l.Country, l.City,
       SUM(fs.SalesAmount) AS IngresoTotal,
       SUM(fs.Quantity) AS UnidadesVendidas
FROM DW_FactSales fs
JOIN DW_DimLocation l ON fs.LocationKey = l.LocationKey
GROUP BY l.Country, l.City
ORDER BY IngresoTotal DESC;

-- Ventas por producto
-- Top productos más vendidos (por unidades)
SELECT TOP 5 p.ProductName,
       SUM(fs.Quantity) AS UnidadesVendidas,
       SUM(fs.SalesAmount) AS IngresoTotal
FROM DW_FactSales fs
JOIN DW_DimProduct p ON fs.ProductKey = p.ProductKey
GROUP BY p.ProductName
ORDER BY UnidadesVendidas DESC;

-- Productos con menor rotación
SELECT p.ProductName,
       SUM(fs.Quantity) AS UnidadesVendidas
FROM DW_FactSales fs
JOIN DW_DimProduct p ON fs.ProductKey = p.ProductKey
GROUP BY p.ProductName
ORDER BY UnidadesVendidas ASC;

-- Precio promedio de venta por producto
SELECT p.ProductName,
       AVG(fs.UnitPrice * 1.0) AS PrecioPromedioVenta
FROM DW_FactSales fs
JOIN DW_DimProduct p ON fs.ProductKey = p.ProductKey
GROUP BY p.ProductName
ORDER BY PrecioPromedioVenta DESC;

-- Ventas por cliente
-- Top 5 clientes con más compras
SELECT TOP 5 c.FullName,
       COUNT(*) AS NumeroCompras,
       SUM(fs.SalesAmount) AS IngresoTotal
FROM DW_FactSales fs
JOIN DW_DimCustomer c ON fs.CustomerKey = c.CustomerKey
GROUP BY c.FullName
ORDER BY NumeroCompras DESC;

-- Promedio de productos por transacción por cliente
SELECT c.FullName,
       AVG(fs.Quantity * 1.0) AS PromedioProductosPorTransaccion
FROM DW_FactSales fs
JOIN DW_DimCustomer c ON fs.CustomerKey = c.CustomerKey
GROUP BY c.FullName
ORDER BY PromedioProductosPorTransaccion DESC;

-- Porcentaje del total de ventas que representa el Top 5 clientes
WITH VentasCliente AS (
    SELECT c.CustomerKey,
           c.FullName,
           SUM(fs.SalesAmount) AS TotalCliente
    FROM DW_FactSales fs
    JOIN DW_DimCustomer c ON fs.CustomerKey = c.CustomerKey
    GROUP BY c.CustomerKey, c.FullName
),
Top5 AS (
    SELECT TOP 5 *
    FROM VentasCliente
    ORDER BY TotalCliente DESC
)
SELECT (SELECT SUM(TotalCliente) FROM Top5) * 100.0 / NULLIF((SELECT SUM(TotalCliente) FROM VentasCliente), 0) AS PorcentajeTop5Clientes;

-- D) Tendencias temporales
-- Tendencia mensual y trimestral
SELECT d.[Year], d.[Quarter], d.[Month],
       SUM(fs.SalesAmount) AS VentasMes
FROM DW_FactSales fs
JOIN DW_DimDate d ON fs.DateKey = d.DateKey
GROUP BY d.[Year], d.[Quarter], d.[Month]
ORDER BY d.[Year], d.[Quarter], d.[Month];

-- Comparativas y desempeño
-- Porcentaje de ventas por categoría
WITH VentasCategoria AS (
    SELECT p.Category,
           SUM(fs.SalesAmount) AS TotalCategoria
    FROM DW_FactSales fs
    JOIN DW_DimProduct p ON fs.ProductKey = p.ProductKey
    GROUP BY p.Category
)
SELECT Category,
       TotalCategoria,
       TotalCategoria * 100.0 / NULLIF(SUM(TotalCategoria) OVER (), 0) AS PorcentajeDelTotal
FROM VentasCategoria
ORDER BY TotalCategoria DESC;

-- Comparación año actual vs año anterior
SELECT d.[Year],
       SUM(fs.SalesAmount) AS TotalVentas,
       LAG(SUM(fs.SalesAmount)) OVER (ORDER BY d.[Year]) AS VentasAnioAnterior,
       (SUM(fs.SalesAmount) - LAG(SUM(fs.SalesAmount)) OVER (ORDER BY d.[Year])) * 100.0
            / NULLIF(LAG(SUM(fs.SalesAmount)) OVER (ORDER BY d.[Year]), 0) AS CrecimientoPorcentual
FROM DW_FactSales fs
JOIN DW_DimDate d ON fs.DateKey = d.DateKey
GROUP BY d.[Year]
ORDER BY d.[Year];

-- KPIs directos
-- Total de ventas por producto/cliente/mes
SELECT p.ProductName, c.FullName, d.[Year], d.[Month],
       SUM(fs.SalesAmount) AS TotalVentas
FROM DW_FactSales fs
JOIN DW_DimProduct p ON fs.ProductKey = p.ProductKey
JOIN DW_DimCustomer c ON fs.CustomerKey = c.CustomerKey
JOIN DW_DimDate d ON fs.DateKey = d.DateKey
GROUP BY p.ProductName, c.FullName, d.[Year], d.[Month]
ORDER BY d.[Year], d.[Month], TotalVentas DESC;