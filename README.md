# SistemaAnalisisVentas - Documentación ETL

## Descripción General
Este proyecto implementa un proceso ETL (Extracción, Transformación y Carga) para poblar y analizar una base de datos relacional orientada al análisis de ventas. El flujo automatiza la integración de datos desde archivos CSV hacia SQL Server, asegurando calidad, integridad y trazabilidad de la información.

## 1. Modelado de la Base de Datos
- Tablas principales: Customers, Products, Orders, OrderDetails, Invoices, DataSources.
- Claves primarias y foráneas correctamente definidas para asegurar integridad referencial.

### Ejemplo de Estructura de Tablas

**Customers**
| CustomerID | FirstName | LastName | Email           | Phone        | City      | Country   |
|------------|-----------|----------|-----------------|-------------|-----------|-----------|
| 1          | John      | Doe      | john@email.com  | 555-1234     | New York  | USA       |

**Products**
| ProductID | ProductName | Category   | Price  | Stock |
|-----------|-------------|------------|--------|-------|
| 101       | Mouse       | Electronics| 15.99  | 200   |

**Orders**
| OrderID | CustomerID | OrderDate  | Status   |
|---------|------------|------------|----------|
| 1001    | 1          | 2026-01-10 | Shipped  |

**OrderDetails**
| OrderDetailID | OrderID | ProductID | Quantity | TotalPrice |
|---------------|---------|-----------|----------|------------|
| 1             | 1001    | 101       | 2        | 31.98      |

**Invoices**
| InvoiceID | OrderID | InvoiceDate | TotalAmount |
|-----------|---------|-------------|-------------|
| 1         | 1001    | 2026-01-11  | 31.98       |

**DataSources**
| SourceID | SourceType | Description                  |
|----------|------------|------------------------------|
| 1        | CSV        | Datos importados desde CSV    |

## 2. Pipeline ETL
- **Extracción:** Lectura de archivos CSV ubicados en la carpeta `csv` del proyecto.
- **Transformación:**
  - Limpieza de duplicados y nulos.
  - Normalización de formatos (fechas, textos, precios).
  - Validación de integridad y relaciones.
- **Carga:** Inserción de los datos procesados en las tablas del modelo, respetando las relaciones establecidas.
- **Generación de facturas:** El sistema calcula automáticamente las facturas a partir de los pedidos y sus detalles.

## 3. Breve descripción de las decisiones de diseño

Se adoptó un modelo estrella porque simplifica el análisis de ventas y mejora el rendimiento de consultas agregadas para KPI, reportes por periodo, cliente y producto. La tabla de hechos DW_FactSales concentra las métricas transaccionales (cantidad, precio unitario, monto de venta y conteo de transacciones), mientras que las dimensiones DW_DimDate, DW_DimCustomer, DW_DimProduct, DW_DimLocation y DW_DimSource aportan el contexto analítico para segmentar y comparar resultados.

Las dimensiones se definieron a partir de las entidades de negocio existentes: clientes, productos, fechas de pedido, ubicación del cliente y origen del dato (CSV, API o SQL). Esto permite mantener trazabilidad de la procedencia de la información y responder preguntas de desempeño comercial por tiempo, categoría, país/ciudad y comportamiento de clientes.

También se definieron llaves primarias y foráneas entre hechos y dimensiones para garantizar integridad referencial. En la carga ETL se decidió una estrategia de recarga completa controlada (limpieza y carga) para evitar duplicados y asegurar consistencia en ejecuciones repetidas del proceso.

## 4. Ejemplo de Código del Sistema ETL

```python
import os
import pandas as pd
from datetime import datetime
from sqlalchemy import create_engine
import urllib

DATA_DIR = os.path.join(os.path.dirname(__file__), 'csv')
DB_SERVER = r"LAPTOP-L44SRLPQ\\SQLEXPRESS"
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

def main():
    engine = get_engine()

    # DataSources (ejemplo)
    data_sources = pd.DataFrame([
        {"SourceType": "CSV", "Description": "Datos importados desde archivos CSV"},
        {"SourceType": "API", "Description": "Datos importados desde API externa"},
        {"SourceType": "SQL", "Description": "Datos importados desde otra base de datos"}
    ])
    data_sources.to_sql('DataSources', engine, if_exists='append', index=False)

    # Customers
    cust_path = os.path.join(DATA_DIR, FILES["customers"])
    if os.path.exists(cust_path):
        customers = pd.read_csv(cust_path)
        customers = clean_df(customers, ["CustomerID", "FirstName", "LastName"])
        customers = customers[["CustomerID", "FirstName", "LastName", "Email", "Phone", "City", "Country"]]
        customers.to_sql('Customers', engine, if_exists='append', index=False)

    # Products
    prod_path = os.path.join(DATA_DIR, FILES["products"])
    if os.path.exists(prod_path):
        products = pd.read_csv(prod_path)
        products = clean_df(products, ["ProductID", "ProductName", "Price"])
        products["Price"] = products["Price"].apply(parse_decimal)
        products = products.dropna(subset=["Price"])
        products = products[["ProductID", "ProductName", "Category", "Price", "Stock"]]
        products.to_sql('Products', engine, if_exists='append', index=False)

    # Orders
    orders_path = os.path.join(DATA_DIR, FILES["orders"])
    if os.path.exists(orders_path):
        orders = pd.read_csv(orders_path)
        orders = clean_df(orders, ["OrderID", "CustomerID", "OrderDate"])
        orders["OrderDate"] = orders["OrderDate"].apply(parse_date)
        orders = orders.dropna(subset=["OrderDate"])
        orders = orders[["OrderID", "CustomerID", "OrderDate", "Status"]]
        orders.to_sql('Orders', engine, if_exists='append', index=False)

    # Order Details
    od_path = os.path.join(DATA_DIR, FILES["order_details"])
    if os.path.exists(od_path):
        order_details = pd.read_csv(od_path)
        order_details = clean_df(order_details, ["OrderID", "ProductID", "Quantity", "TotalPrice"])
        order_details["TotalPrice"] = order_details["TotalPrice"].apply(parse_decimal)
        order_details = order_details.dropna(subset=["TotalPrice"])
        order_details = order_details[["OrderID", "ProductID", "Quantity", "TotalPrice"]]
        order_details.to_sql('OrderDetails', engine, if_exists='append', index=False)

    # Invoices (generar facturas a partir de orders y order_details)
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

if __name__ == "__main__":
    main()
