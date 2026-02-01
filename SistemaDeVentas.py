import os
import pandas as pd
import decimal
from datetime import datetime
from sqlalchemy import create_engine, event
import urllib


DATA_DIR = os.path.join(os.path.dirname(__file__), 'csv') 
DB_SERVER = r"LAPTOP-L44SRLPQ\SQLEXPRESS"  
DB_NAME = "SistemaAnalisisVentas"
DRIVER = "ODBC Driver 17 for SQL Server"  

# CSV filenames expected
FILES = {
    "fuentes": "fuentes.csv",
    "productos": "productos.csv",
    "clientes": "clientes.csv",
    "ventas": "ventas.csv",                
    "encuestas": "encuestas.csv",
    "comentarios": "comentarios_sociales.csv",
    "opiniones": "opiniones_web.csv"
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

    # Fuentes
    fuentes_path = os.path.join(DATA_DIR, FILES["fuentes"])
    if os.path.exists(fuentes_path):
        fuentes = pd.read_csv(fuentes_path)
        fuentes = clean_df(fuentes, ["TipoFuente"])
        fuentes['Descripcion'] = fuentes.get('Descripcion', None)
        fuentes = fuentes[['TipoFuente','Descripcion']].drop_duplicates()
        fuentes.to_sql('FuenteDatos', engine, if_exists='append', index=False)
        print("Fuentes loaded:", len(fuentes))
    else:
        print("No fuentes.csv found — ensure source file exists.")

    #Productos
    prod_path = os.path.join(DATA_DIR, FILES["productos"])
    if os.path.exists(prod_path):
        productos = pd.read_csv(prod_path)
        productos = clean_df(productos, ['CodigoProducto','Nombre','Precio'])
        productos['Precio'] = productos['Precio'].apply(parse_decimal)
        productos = productos.dropna(subset=['Precio'])
        productos = productos[['CodigoProducto','Nombre','Categoria','Precio','IdFuente']].copy()
        productos.to_sql('Productos', engine, if_exists='append', index=False)
        print("Productos loaded:", len(productos))
    else:
        print("No productos.csv found.")

    # Clientes
    cli_path = os.path.join(DATA_DIR, FILES["clientes"])
    if os.path.exists(cli_path):
        clientes = pd.read_csv(cli_path)
        clientes = clean_df(clientes, ['CodigoCliente','Nombre'])
        clientes = clientes[['CodigoCliente','Nombre','Email','Region','IdFuente']].copy()
        clientes.to_sql('Clientes', engine, if_exists='append', index=False)
        print("Clientes loaded:", len(clientes))
    else:
        print("No clientes.csv found.")

    # Ventas 
    ventas_path = os.path.join(DATA_DIR, FILES["ventas"])
    if os.path.exists(ventas_path):
        ventas = pd.read_csv(ventas_path)
        ventas = clean_df(ventas, ['CodigoProducto','CodigoCliente','Cantidad','Precio','FechaVenta'])
        ventas['Precio'] = ventas['Precio'].apply(parse_decimal)
        ventas['FechaVenta'] = ventas['FechaVenta'].apply(parse_date)
        ventas = ventas.dropna(subset=['Precio','FechaVenta'])
        # Fetch mappings
        with engine.connect() as conn:
            prod_map = pd.read_sql("SELECT IdProducto,CodigoProducto FROM Productos", conn).set_index('CodigoProducto')['IdProducto'].to_dict()
            cli_map = pd.read_sql("SELECT IdCliente,CodigoCliente FROM Clientes", conn).set_index('CodigoCliente')['IdCliente'].to_dict()
        ventas['IdProducto'] = ventas['CodigoProducto'].map(prod_map)
        ventas['IdCliente'] = ventas['CodigoCliente'].map(cli_map)
        ventas = ventas.dropna(subset=['IdProducto','IdCliente'])
        ventas = ventas[['IdCliente','IdProducto','Cantidad','Precio','FechaVenta','IdFuente']]
        ventas.to_sql('Ventas', engine, if_exists='append', index=False)
        print("Ventas loaded:", len(ventas))
    else:
        print("No ventas.csv found; skipping.")

    # Encuestas, Comentarios, Opiniones
    def load_generic(file_key, table_name, required_cols, col_map=None):
        p = os.path.join(DATA_DIR, FILES[file_key])
        if not os.path.exists(p):
            print(f"No {FILES[file_key]} found; skipping {table_name}.")
            return
        df = pd.read_csv(p)
        df = clean_df(df, required_cols)
        if 'Fecha' in df.columns or 'FechaEncuesta' in df.columns:
            for c in df.columns:
                if 'Fecha' in c:
                    df[c] = df[c].apply(parse_date)
        if col_map:
            df = df.rename(columns=col_map)
        df.to_sql(table_name, engine, if_exists='append', index=False)
        print(f"{table_name} loaded:", len(df))

    load_generic('encuestas','Encuestas',['Pregunta'], None)
    load_generic('comentarios','ComentariosSociales',['Texto'], None)
    load_generic('opiniones','OpinionesWeb',['Texto'], None)

if __name__ == "__main__":
    main()