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