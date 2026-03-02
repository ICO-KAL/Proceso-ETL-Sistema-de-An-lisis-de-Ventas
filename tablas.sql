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


-- CONSULTAS KPI / PREGUNTAS DE NEGOCIO (VERSIÓN LIMPIA, SIN REPETICIONES)

-- 1. Análisis general de ventas

-- ¿Cuál es el total de ventas global registrado en el sistema?
SELECT SUM(fs.SalesAmount) AS TotalVentasGlobal
FROM DW_FactSales fs;

-- ¿Cuál es el promedio de ventas por transacción?
SELECT AVG(fs.SalesAmount * 1.0) AS PromedioVentaPorTransaccion
FROM DW_FactSales fs;

-- ¿Cuántas ventas totales se realizaron en un periodo específico (día, mes o año)?
-- Por día
SELECT d.FullDate,
       COUNT(*) AS TotalTransacciones,
       SUM(fs.SalesAmount) AS TotalVentas
FROM DW_FactSales fs
JOIN DW_DimDate d ON fs.DateKey = d.DateKey
GROUP BY d.FullDate
ORDER BY d.FullDate;

-- Por mes
SELECT d.[Year], d.[Month],
       COUNT(*) AS TotalTransacciones,
       SUM(fs.SalesAmount) AS TotalVentas
FROM DW_FactSales fs
JOIN DW_DimDate d ON fs.DateKey = d.DateKey
GROUP BY d.[Year], d.[Month]
ORDER BY d.[Year], d.[Month];

-- Por año
SELECT d.[Year],
       COUNT(*) AS TotalTransacciones,
       SUM(fs.SalesAmount) AS TotalVentas
FROM DW_FactSales fs
JOIN DW_DimDate d ON fs.DateKey = d.DateKey
GROUP BY d.[Year]
ORDER BY d.[Year];

-- ¿Cuál es el volumen de ventas por país, región o ciudad?
SELECT ISNULL(l.Country, 'SinPais') AS Country,
       ISNULL(l.Region, 'SinRegion') AS Region,
       ISNULL(l.City, 'SinCiudad') AS City,
       SUM(fs.Quantity) AS VolumenUnidades,
       SUM(fs.SalesAmount) AS IngresoTotal
FROM DW_FactSales fs
JOIN DW_DimLocation l ON fs.LocationKey = l.LocationKey
GROUP BY l.Country, l.Region, l.City
ORDER BY IngresoTotal DESC;

-- 2. Ventas por producto

-- ¿Cuáles son los productos más vendidos en el periodo actual?
SELECT TOP 5 p.ProductName,
       SUM(fs.Quantity) AS UnidadesVendidas,
       SUM(fs.SalesAmount) AS IngresoTotal
FROM DW_FactSales fs
JOIN DW_DimProduct p ON fs.ProductKey = p.ProductKey
JOIN DW_DimDate d ON fs.DateKey = d.DateKey
WHERE d.[Year] = (SELECT MAX([Year]) FROM DW_DimDate)
GROUP BY p.ProductName
ORDER BY UnidadesVendidas DESC;

-- ¿Qué productos generan mayor ingreso total?
SELECT p.ProductName,
       SUM(fs.SalesAmount) AS IngresoTotal
FROM DW_FactSales fs
JOIN DW_DimProduct p ON fs.ProductKey = p.ProductKey
GROUP BY p.ProductName
ORDER BY IngresoTotal DESC;

-- ¿Qué productos tienen menor rotación o ventas más bajas?
SELECT p.ProductName,
       SUM(fs.Quantity) AS UnidadesVendidas,
       SUM(fs.SalesAmount) AS IngresoTotal
FROM DW_FactSales fs
JOIN DW_DimProduct p ON fs.ProductKey = p.ProductKey
GROUP BY p.ProductName
ORDER BY UnidadesVendidas ASC, IngresoTotal ASC;

-- ¿Cómo ha evolucionado la demanda de un producto específico a lo largo del tiempo?
DECLARE @Producto VARCHAR(200) = 'Statement';

SELECT d.[Year], d.[Month],
       SUM(fs.Quantity) AS UnidadesVendidas,
       SUM(fs.SalesAmount) AS IngresoMensual
FROM DW_FactSales fs
JOIN DW_DimProduct p ON fs.ProductKey = p.ProductKey
JOIN DW_DimDate d ON fs.DateKey = d.DateKey
WHERE p.ProductName = @Producto
GROUP BY d.[Year], d.[Month]
ORDER BY d.[Year], d.[Month];

-- ¿Cuál es el precio promedio de venta por producto?
SELECT p.ProductName,
       AVG(fs.UnitPrice * 1.0) AS PrecioPromedioVenta
FROM DW_FactSales fs
JOIN DW_DimProduct p ON fs.ProductKey = p.ProductKey
GROUP BY p.ProductName
ORDER BY PrecioPromedioVenta DESC;

-- 3. Ventas por cliente

-- ¿Qué clientes realizan más compras?
SELECT TOP 5 c.FullName,
       COUNT(*) AS NumeroCompras
FROM DW_FactSales fs
JOIN DW_DimCustomer c ON fs.CustomerKey = c.CustomerKey
GROUP BY c.FullName
ORDER BY NumeroCompras DESC;

-- ¿Qué clientes generan mayor volumen de ventas o ingresos totales?
SELECT c.FullName,
       SUM(fs.Quantity) AS VolumenComprado,
       SUM(fs.SalesAmount) AS IngresoGenerado
FROM DW_FactSales fs
JOIN DW_DimCustomer c ON fs.CustomerKey = c.CustomerKey
GROUP BY c.FullName
ORDER BY IngresoGenerado DESC;

-- ¿Cuántos productos en promedio compra un cliente por transacción?
SELECT c.FullName,
       AVG(fs.Quantity * 1.0) AS PromedioProductosPorTransaccion
FROM DW_FactSales fs
JOIN DW_DimCustomer c ON fs.CustomerKey = c.CustomerKey
GROUP BY c.FullName
ORDER BY PromedioProductosPorTransaccion DESC;

-- ¿Qué porcentaje del total de ventas pertenece al Top 5 de clientes?
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
SELECT (SELECT SUM(TotalCliente) FROM Top5) * 100.0
       / NULLIF((SELECT SUM(TotalCliente) FROM VentasCliente), 0) AS PorcentajeTop5Clientes;

-- ¿Cómo se comportan las compras por segmento de clientes (por país, tipo, etc.)?
SELECT ISNULL(c.Country, 'SinPais') AS Pais,
       ISNULL(c.CustomerType, 'SinTipo') AS TipoCliente,
       COUNT(*) AS Transacciones,
       SUM(fs.Quantity) AS Unidades,
       SUM(fs.SalesAmount) AS IngresoTotal
FROM DW_FactSales fs
JOIN DW_DimCustomer c ON fs.CustomerKey = c.CustomerKey
GROUP BY c.Country, c.CustomerType
ORDER BY IngresoTotal DESC;

-- 4. Tendencias temporales

-- ¿Cuál es la tendencia mensual o trimestral de ventas?
SELECT d.[Year], d.[Quarter], d.[Month],
       SUM(fs.SalesAmount) AS VentasMes
FROM DW_FactSales fs
JOIN DW_DimDate d ON fs.DateKey = d.DateKey
GROUP BY d.[Year], d.[Quarter], d.[Month]
ORDER BY d.[Year], d.[Quarter], d.[Month];

-- ¿En qué meses o periodos se concentran los picos de ventas?
SELECT TOP 5 d.[Year], d.[Month],
       SUM(fs.SalesAmount) AS VentasMes
FROM DW_FactSales fs
JOIN DW_DimDate d ON fs.DateKey = d.DateKey
GROUP BY d.[Year], d.[Month]
ORDER BY VentasMes DESC;

-- ¿Existe estacionalidad en los productos más vendidos?
SELECT p.ProductName,
       d.[Month],
       SUM(fs.Quantity) AS UnidadesVendidas
FROM DW_FactSales fs
JOIN DW_DimProduct p ON fs.ProductKey = p.ProductKey
JOIN DW_DimDate d ON fs.DateKey = d.DateKey
GROUP BY p.ProductName, d.[Month]
ORDER BY p.ProductName, d.[Month];

-- ¿Cuál ha sido la evolución del ingreso total durante el año?
WITH IngresoMensual AS (
    SELECT d.[Year], d.[Month],
           SUM(fs.SalesAmount) AS IngresoMes
    FROM DW_FactSales fs
    JOIN DW_DimDate d ON fs.DateKey = d.DateKey
    GROUP BY d.[Year], d.[Month]
)
SELECT [Year], [Month], IngresoMes,
       SUM(IngresoMes) OVER (PARTITION BY [Year] ORDER BY [Month]) AS IngresoAcumuladoAnual
FROM IngresoMensual
ORDER BY [Year], [Month];

-- 5. Comparativas y desempeño
-- ¿Cuál es la diferencia de ventas entre productos o categorías?
WITH VentasCategoria AS (
    SELECT p.Category,
           SUM(fs.SalesAmount) AS VentasCategoria
    FROM DW_FactSales fs
    JOIN DW_DimProduct p ON fs.ProductKey = p.ProductKey
    GROUP BY p.Category
)
SELECT Category,
       VentasCategoria,
       VentasCategoria - LAG(VentasCategoria) OVER (ORDER BY VentasCategoria DESC) AS DiferenciaVsCategoriaAnterior
FROM VentasCategoria
ORDER BY VentasCategoria DESC;

-- ¿Qué porcentaje de ventas representa cada categoría del total?
WITH PorcentajeCategoria AS (
    SELECT p.Category,
           SUM(fs.SalesAmount) AS TotalCategoria
    FROM DW_FactSales fs
    JOIN DW_DimProduct p ON fs.ProductKey = p.ProductKey
    GROUP BY p.Category
)
SELECT Category,
       TotalCategoria,
       TotalCategoria * 100.0 / NULLIF(SUM(TotalCategoria) OVER (), 0) AS PorcentajeDelTotal
FROM PorcentajeCategoria
ORDER BY TotalCategoria DESC;

-- ¿Qué vendedores o regiones presentan mejor desempeño?
SELECT ISNULL(l.Region, l.Country) AS RegionAnalitica,
       l.City,
       SUM(fs.SalesAmount) AS IngresoTotal,
       SUM(fs.Quantity) AS UnidadesVendidas
FROM DW_FactSales fs
JOIN DW_DimLocation l ON fs.LocationKey = l.LocationKey
GROUP BY ISNULL(l.Region, l.Country), l.City
ORDER BY IngresoTotal DESC;

-- ¿Cómo se comparan las ventas de este año con las del año anterior?
SELECT d.[Year],
       SUM(fs.SalesAmount) AS TotalVentas,
       LAG(SUM(fs.SalesAmount)) OVER (ORDER BY d.[Year]) AS VentasAnioAnterior,
       (SUM(fs.SalesAmount) - LAG(SUM(fs.SalesAmount)) OVER (ORDER BY d.[Year])) * 100.0
            / NULLIF(LAG(SUM(fs.SalesAmount)) OVER (ORDER BY d.[Year]), 0) AS CrecimientoPorcentual
FROM DW_FactSales fs
JOIN DW_DimDate d ON fs.DateKey = d.DateKey
GROUP BY d.[Year]
ORDER BY d.[Year];

-- 6. Indicadores clave (KPIs)

-- Total de ventas: suma del valor total de todas las facturas.
SELECT SUM(i.TotalAmount) AS TotalVentasFacturadas
FROM Invoices i;

-- Total de ventas por producto / cliente / mes.
SELECT p.ProductName,
       c.FullName,
       d.[Year],
       d.[Month],
       SUM(fs.SalesAmount) AS TotalVentas
FROM DW_FactSales fs
JOIN DW_DimProduct p ON fs.ProductKey = p.ProductKey
JOIN DW_DimCustomer c ON fs.CustomerKey = c.CustomerKey
JOIN DW_DimDate d ON fs.DateKey = d.DateKey
GROUP BY p.ProductName, c.FullName, d.[Year], d.[Month]
ORDER BY d.[Year], d.[Month], TotalVentas DESC;

-- Top 5 productos más vendidos.
SELECT TOP 5 p.ProductName,
       SUM(fs.Quantity) AS UnidadesVendidas
FROM DW_FactSales fs
JOIN DW_DimProduct p ON fs.ProductKey = p.ProductKey
GROUP BY p.ProductName
ORDER BY UnidadesVendidas DESC;

-- Top 5 clientes con más compras.
SELECT TOP 5 c.FullName,
       COUNT(*) AS NumeroCompras
FROM DW_FactSales fs
JOIN DW_DimCustomer c ON fs.CustomerKey = c.CustomerKey
GROUP BY c.FullName
ORDER BY NumeroCompras DESC;

-- Promedio de venta por cliente.
SELECT c.FullName,
       AVG(fs.SalesAmount * 1.0) AS PromedioVentaPorCliente
FROM DW_FactSales fs
JOIN DW_DimCustomer c ON fs.CustomerKey = c.CustomerKey
GROUP BY c.FullName
ORDER BY PromedioVentaPorCliente DESC;

-- Crecimiento porcentual de ventas por mes.
WITH VentasMes AS (
    SELECT d.[Year], d.[Month],
           SUM(fs.SalesAmount) AS TotalVentasMes
    FROM DW_FactSales fs
    JOIN DW_DimDate d ON fs.DateKey = d.DateKey
    GROUP BY d.[Year], d.[Month]
)
SELECT [Year], [Month], TotalVentasMes,
       LAG(TotalVentasMes) OVER (ORDER BY [Year], [Month]) AS VentasMesAnterior,
       (TotalVentasMes - LAG(TotalVentasMes) OVER (ORDER BY [Year], [Month])) * 100.0
            / NULLIF(LAG(TotalVentasMes) OVER (ORDER BY [Year], [Month]), 0) AS CrecimientoPctMensual
FROM VentasMes
ORDER BY [Year], [Month];

-- Crecimiento porcentual de ventas por trimestre.
WITH VentasTrimestre AS (
    SELECT d.[Year], d.[Quarter],
           SUM(fs.SalesAmount) AS TotalVentasTrimestre
    FROM DW_FactSales fs
    JOIN DW_DimDate d ON fs.DateKey = d.DateKey
    GROUP BY d.[Year], d.[Quarter]
)
SELECT [Year], [Quarter], TotalVentasTrimestre,
       LAG(TotalVentasTrimestre) OVER (ORDER BY [Year], [Quarter]) AS VentasTrimestreAnterior,
       (TotalVentasTrimestre - LAG(TotalVentasTrimestre) OVER (ORDER BY [Year], [Quarter])) * 100.0
            / NULLIF(LAG(TotalVentasTrimestre) OVER (ORDER BY [Year], [Quarter]), 0) AS CrecimientoPctTrimestral
FROM VentasTrimestre
ORDER BY [Year], [Quarter];