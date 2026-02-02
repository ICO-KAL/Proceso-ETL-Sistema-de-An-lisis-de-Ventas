import os
import pandas as pd
from datetime import datetime
from sqlalchemy import create_engine
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

def main():
    engine = get_engine()

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

if __name__ == "__main__":
    main()