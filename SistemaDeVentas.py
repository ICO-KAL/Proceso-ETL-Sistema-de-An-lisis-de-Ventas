import os
import pandas as pd
from datetime import datetime
from sqlalchemy import create_engine, text
import urllib

DATA_DIR = os.path.join(os.path.dirname(__file__), 'csv')
DB_SERVER = r"LAPTOP-L44SRLPQ\SQLEXPRESS"
DB_NAME = "SistemaAnalisisVentas"
DRIVER = "ODBC Driver 17 for SQL Server"

FILES = {
    "customers": "customers.csv",
    "products": "products.csv",
    "orders": "orders.csv",
    "order_details": "order_details.csv"
}

def get_engine():
    params = urllib.parse.quote_plus(
        f"DRIVER={{{DRIVER}}};SERVER={DB_SERVER};DATABASE={DB_NAME};Trusted_Connection=yes;"
    )
    engine = create_engine("mssql+pyodbc:///?odbc_connect=%s" % params, fast_executemany=True)
    return engine

def clean_df(df, required_cols):
    for c in df.select_dtypes(include=["object", "string"]).columns:
        df[c] = df[c].astype(str).str.strip().replace({"nan": None})
    df.replace({"": None}, inplace=True)
    if required_cols:
        df.dropna(subset=required_cols, inplace=True)
    df.drop_duplicates(inplace=True)
    return df

def parse_decimal(x):
    if pd.isna(x):
        return None
    try:
        x = str(x).replace("$","").replace(",","").strip()
        return round(float(x),2)
    except Exception:
        return None

def parse_date(x):
    if pd.isna(x):
        return None
    for fmt in ("%Y-%m-%d","%d/%m/%Y","%m/%d/%Y","%Y/%m/%d","%d-%m-%Y"):
        try:
            return datetime.strptime(str(x), fmt)
        except Exception:
            pass
    try:
        return pd.to_datetime(x)
    except Exception:
        return None

def reset_tables_for_full_reload(engine):
    reset_sql = """
    SET NOCOUNT ON;

    -- Limpiar DW (si existe)
    IF OBJECT_ID('DW_FactSales', 'U') IS NOT NULL DELETE FROM DW_FactSales;
    IF OBJECT_ID('DW_DimDate', 'U') IS NOT NULL DELETE FROM DW_DimDate;
    IF OBJECT_ID('DW_DimCustomer', 'U') IS NOT NULL DELETE FROM DW_DimCustomer;
    IF OBJECT_ID('DW_DimProduct', 'U') IS NOT NULL DELETE FROM DW_DimProduct;
    IF OBJECT_ID('DW_DimLocation', 'U') IS NOT NULL DELETE FROM DW_DimLocation;
    IF OBJECT_ID('DW_DimSource', 'U') IS NOT NULL DELETE FROM DW_DimSource;

    -- Limpiar tablas transaccionales en orden de dependencias
    IF OBJECT_ID('Invoices', 'U') IS NOT NULL DELETE FROM Invoices;
    IF OBJECT_ID('OrderDetails', 'U') IS NOT NULL DELETE FROM OrderDetails;
    IF OBJECT_ID('Orders', 'U') IS NOT NULL DELETE FROM Orders;
    IF OBJECT_ID('Products', 'U') IS NOT NULL DELETE FROM Products;
    IF OBJECT_ID('Customers', 'U') IS NOT NULL DELETE FROM Customers;
    IF OBJECT_ID('DataSources', 'U') IS NOT NULL DELETE FROM DataSources;
    """

    with engine.begin() as conn:
        conn.execute(text(reset_sql))

    print("Tablas limpiadas para recarga completa.")

def load_datawarehouse(engine):
    etl_sql = """
    SET NOCOUNT ON;

    IF OBJECT_ID('DW_DimDate', 'U') IS NULL
       OR OBJECT_ID('DW_DimCustomer', 'U') IS NULL
       OR OBJECT_ID('DW_DimProduct', 'U') IS NULL
       OR OBJECT_ID('DW_DimLocation', 'U') IS NULL
       OR OBJECT_ID('DW_DimSource', 'U') IS NULL
       OR OBJECT_ID('DW_FactSales', 'U') IS NULL
    BEGIN
        RAISERROR('No existen las tablas DW_*. Ejecuta primero tablas.sql para crear el modelo analítico.', 16, 1);
    END;

    ;WITH SourceDedup AS (
        SELECT SourceType,
               Description,
               ROW_NUMBER() OVER (PARTITION BY SourceID ORDER BY SourceID) AS rn,
               SourceID
        FROM DataSources
    )
    MERGE DW_DimSource AS T
    USING (
        SELECT SourceID, SourceType, Description
        FROM SourceDedup
        WHERE rn = 1
    ) AS S
    ON T.SourceID = S.SourceID
    WHEN MATCHED THEN
        UPDATE SET T.SourceType = S.SourceType,
                   T.Description = S.Description
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (SourceID, SourceType, Description)
        VALUES (S.SourceID, S.SourceType, S.Description);

    MERGE DW_DimCustomer AS T
    USING (
        SELECT c.CustomerID AS CustomerID_Source,
               CONCAT(c.FirstName, ' ', c.LastName) AS FullName,
               c.Email,
               c.Phone,
               c.City,
               CAST(NULL AS VARCHAR(100)) AS Region,
               c.Country,
               CAST('General' AS VARCHAR(50)) AS CustomerType,
               CAST(1 AS BIT) AS IsActive
        FROM Customers c
    ) AS S
    ON T.CustomerID_Source = S.CustomerID_Source
    WHEN MATCHED THEN
        UPDATE SET T.FullName = S.FullName,
                   T.Email = S.Email,
                   T.Phone = S.Phone,
                   T.City = S.City,
                   T.Region = S.Region,
                   T.Country = S.Country,
                   T.CustomerType = S.CustomerType,
                   T.IsActive = S.IsActive
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (CustomerID_Source, FullName, Email, Phone, City, Region, Country, CustomerType, IsActive)
        VALUES (S.CustomerID_Source, S.FullName, S.Email, S.Phone, S.City, S.Region, S.Country, S.CustomerType, S.IsActive);

    MERGE DW_DimProduct AS T
    USING (
        SELECT p.ProductID AS ProductID_Source,
               p.ProductName,
               p.Category,
               p.Price AS CurrentPrice,
               CAST(1 AS BIT) AS IsActive
        FROM Products p
    ) AS S
    ON T.ProductID_Source = S.ProductID_Source
    WHEN MATCHED THEN
        UPDATE SET T.ProductName = S.ProductName,
                   T.Category = S.Category,
                   T.CurrentPrice = S.CurrentPrice,
                   T.IsActive = S.IsActive
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (ProductID_Source, ProductName, Category, CurrentPrice, IsActive)
        VALUES (S.ProductID_Source, S.ProductName, S.Category, S.CurrentPrice, S.IsActive);

    MERGE DW_DimLocation AS T
    USING (
        SELECT DISTINCT c.City,
               CAST(NULL AS VARCHAR(100)) AS Region,
               c.Country
        FROM Customers c
    ) AS S
    ON ISNULL(T.City, '') = ISNULL(S.City, '')
       AND ISNULL(T.Region, '') = ISNULL(S.Region, '')
       AND ISNULL(T.Country, '') = ISNULL(S.Country, '')
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (City, Region, Country)
        VALUES (S.City, S.Region, S.Country);

    MERGE DW_DimDate AS T
    USING (
        SELECT DISTINCT
               CONVERT(INT, CONVERT(VARCHAR(8), o.OrderDate, 112)) AS DateKey,
               CAST(o.OrderDate AS DATE) AS FullDate,
               DATEPART(DAY, o.OrderDate) AS [Day],
               DATEPART(MONTH, o.OrderDate) AS [Month],
               DATENAME(MONTH, o.OrderDate) AS [MonthName],
               DATEPART(QUARTER, o.OrderDate) AS [Quarter],
               DATEPART(YEAR, o.OrderDate) AS [Year],
               DATEPART(ISO_WEEK, o.OrderDate) AS WeekOfYear
        FROM Orders o
        WHERE o.OrderDate IS NOT NULL
    ) AS S
    ON T.DateKey = S.DateKey
    WHEN MATCHED THEN
        UPDATE SET T.FullDate = S.FullDate,
                   T.[Day] = S.[Day],
                   T.[Month] = S.[Month],
                   T.[MonthName] = S.[MonthName],
                   T.[Quarter] = S.[Quarter],
                   T.[Year] = S.[Year],
                   T.WeekOfYear = S.WeekOfYear
    WHEN NOT MATCHED BY TARGET THEN
        INSERT (DateKey, FullDate, [Day], [Month], [MonthName], [Quarter], [Year], WeekOfYear)
        VALUES (S.DateKey, S.FullDate, S.[Day], S.[Month], S.[MonthName], S.[Quarter], S.[Year], S.WeekOfYear);

    DELETE FROM DW_FactSales;

    INSERT INTO DW_FactSales (
        DateKey,
        CustomerKey,
        ProductKey,
        LocationKey,
        SourceID,
        OrderID_Source,
        InvoiceID_Source,
        Quantity,
        UnitPrice,
        SalesAmount,
        TransactionCount
    )
    SELECT
        d.DateKey,
        dc.CustomerKey,
        dp.ProductKey,
        dl.LocationKey,
        ds.SourceID,
        o.OrderID AS OrderID_Source,
        i.InvoiceID AS InvoiceID_Source,
        od.Quantity,
        CAST(CASE WHEN od.Quantity = 0 THEN 0 ELSE od.TotalPrice / od.Quantity END AS DECIMAL(18,2)) AS UnitPrice,
        CAST(od.TotalPrice AS DECIMAL(18,2)) AS SalesAmount,
        1 AS TransactionCount
    FROM Orders o
    INNER JOIN OrderDetails od ON od.OrderID = o.OrderID
    INNER JOIN Customers c ON c.CustomerID = o.CustomerID
    INNER JOIN Products p ON p.ProductID = od.ProductID
    LEFT JOIN Invoices i ON i.OrderID = o.OrderID
    INNER JOIN DW_DimDate d ON d.DateKey = CONVERT(INT, CONVERT(VARCHAR(8), o.OrderDate, 112))
    INNER JOIN DW_DimCustomer dc ON dc.CustomerID_Source = c.CustomerID
    INNER JOIN DW_DimProduct dp ON dp.ProductID_Source = p.ProductID
    INNER JOIN DW_DimLocation dl ON ISNULL(dl.City, '') = ISNULL(c.City, '')
                               AND ISNULL(dl.Region, '') = ''
                               AND ISNULL(dl.Country, '') = ISNULL(c.Country, '')
    CROSS JOIN (
        SELECT TOP 1 SourceID
        FROM DW_DimSource
        WHERE SourceType = 'CSV'
        ORDER BY SourceID
    ) ds
    WHERE o.OrderDate IS NOT NULL
      AND od.Quantity > 0
      AND od.TotalPrice >= 0;
    """

    with engine.begin() as conn:
        conn.execute(text(etl_sql))

    with engine.connect() as conn:
        total_fact = conn.execute(text("SELECT COUNT(*) FROM DW_FactSales")).scalar()
        print("DW_FactSales loaded:", total_fact)

def main():
    engine = get_engine()
    reset_tables_for_full_reload(engine)

    # DataSources
    data_sources = pd.DataFrame([
        {"SourceType": "CSV", "Description": "Datos importados desde archivos CSV"},
        {"SourceType": "API", "Description": "Datos importados desde API externa"},
        {"SourceType": "SQL", "Description": "Datos importados desde otra base de datos"}
    ])
    data_sources.to_sql('DataSources', engine, if_exists='append', index=False)
    print("DataSources loaded:", len(data_sources))

    # Customers
    cust_path = os.path.join(DATA_DIR, FILES["customers"])
    if os.path.exists(cust_path):
        customers = pd.read_csv(cust_path)
        customers = clean_df(customers, ["CustomerID", "FirstName", "LastName"])
        customers = customers[["CustomerID", "FirstName", "LastName", "Email", "Phone", "City", "Country"]]
        customers.to_sql('Customers', engine, if_exists='append', index=False)
        print("Customers loaded:", len(customers))
    else:
        print("No customers.csv found.")

    # Products
    prod_path = os.path.join(DATA_DIR, FILES["products"])
    if os.path.exists(prod_path):
        products = pd.read_csv(prod_path)
        products = clean_df(products, ["ProductID", "ProductName", "Price"])
        products["Price"] = products["Price"].apply(parse_decimal)
        products = products.dropna(subset=["Price"])
        products = products[["ProductID", "ProductName", "Category", "Price", "Stock"]]
        products.to_sql('Products', engine, if_exists='append', index=False)
        print("Products loaded:", len(products))
    else:
        print("No products.csv found.")

    # Orders
    orders_path = os.path.join(DATA_DIR, FILES["orders"])
    if os.path.exists(orders_path):
        orders = pd.read_csv(orders_path)
        orders = clean_df(orders, ["OrderID", "CustomerID", "OrderDate"])
        orders["OrderDate"] = orders["OrderDate"].apply(parse_date)
        orders = orders.dropna(subset=["OrderDate"])
        orders = orders[["OrderID", "CustomerID", "OrderDate", "Status"]]
        orders.to_sql('Orders', engine, if_exists='append', index=False)
        print("Orders loaded:", len(orders))
    else:
        print("No orders.csv found.")

    # Order Details
    od_path = os.path.join(DATA_DIR, FILES["order_details"])
    if os.path.exists(od_path):
        order_details = pd.read_csv(od_path)
        order_details = clean_df(order_details, ["OrderID", "ProductID", "Quantity", "TotalPrice"])
        order_details["TotalPrice"] = order_details["TotalPrice"].apply(parse_decimal)
        order_details = order_details.dropna(subset=["TotalPrice"])
        order_details = order_details[["OrderID", "ProductID", "Quantity", "TotalPrice"]]
        order_details.to_sql('OrderDetails', engine, if_exists='append', index=False)
        print("OrderDetails loaded:", len(order_details))
    else:
        print("No order_details.csv found.")
    # Invoices
    with engine.connect() as conn:
        orders_df = pd.read_sql("SELECT OrderID, OrderDate FROM Orders", conn)
        od_df = pd.read_sql("SELECT OrderID, TotalPrice FROM OrderDetails", conn)
        if not orders_df.empty and not od_df.empty:
            invoice_rows = []
            for oid, group in od_df.groupby('OrderID'):
                total = group['TotalPrice'].sum()
                order_date = orders_df.loc[orders_df['OrderID'] == oid, 'OrderDate']
                invoice_date = order_date.iloc[0] if not order_date.empty else datetime.now()
                invoice_rows.append({
                    'OrderID': oid,
                    'InvoiceDate': invoice_date,
                    'TotalAmount': total
                })
            invoices = pd.DataFrame(invoice_rows)
            if not invoices.empty:
                invoices.to_sql('Invoices', engine, if_exists='append', index=False)
                print("Invoices loaded:", len(invoices))
            else:
                print("No invoices generated.")
        else:
            print("No data for invoices.")

    load_datawarehouse(engine)
    print("Data Warehouse ETL finalizado correctamente.")

if __name__ == "__main__":
    main()