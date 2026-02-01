# SistemaAnalisisVentas - Documentación ETL

## Descripción General
Este proyecto implementa un proceso ETL (Extracción, Transformación y Carga) para poblar y analizar una base de datos relacional orientada al análisis de ventas y opiniones de clientes. El flujo automatiza la integración de datos desde archivos CSV hacia SQL Server, asegurando calidad, integridad y trazabilidad de la información.

## 1. Modelado de la Base de Datos
- Tablas principales: FuenteDatos, Productos, Clientes, Ventas, Encuestas, ComentariosSociales, OpinionesWeb.
- Claves primarias y foráneas correctamente definidas para asegurar integridad referencial.
- El diseño puede representarse mediante un diagrama ER (entidad-relación).

## 2. Pipeline ETL
- **Extracción:** Lectura de archivos CSV ubicados en la carpeta `csv` del proyecto.
- **Transformación:**
  - Limpieza de duplicados y nulos.
  - Normalización de formatos (fechas, textos, precios, categorías).
  - Validación de integridad y relaciones.
- **Carga:** Inserción de los datos procesados en las tablas del modelo, respetando las relaciones establecidas.

## 3. Resultados Esperados
- Script SQL para la creación de la base de datos y sus tablas.
- Código Python para el pipeline ETL (`SistemaDeVentas.py`).
- Capturas de pantalla mostrando la cantidad de registros cargados por tabla y resultados de consultas SELECT.
- Resultados de la consulta principal de ventas:

```sql
SELECT 
    IdVenta,
    IdCliente,
    IdProducto,
    Cantidad,
    Precio,
    FechaVenta,
    Total,
    IdFuente
FROM Ventas;

SELECT 
    IdFuente,
    TipoFuente,
    Descripcion,
    FechaCarga
FROM FuenteDatos;

SELECT 
    IdCliente,
    CodigoCliente,
    Nombre,
    Email,
    Region,
    IdFuente
FROM Clientes;

SELECT 
    IdVenta,
    IdCliente,
    IdProducto,
    Cantidad,
    Precio,
    FechaVenta,
    Total,
    IdFuente
FROM Ventas;

SELECT 
    v.IdVenta,
    c.Nombre AS Cliente,
    p.Nombre AS Producto,
    p.Categoria,
    v.Cantidad,
    v.Precio,
    v.Total,
    v.FechaVenta,
    f.TipoFuente
FROM Ventas v
INNER JOIN Clientes c ON v.IdCliente = c.IdCliente
INNER JOIN Productos p ON v.IdProducto = p.IdProducto
INNER JOIN FuenteDatos f ON v.IdFuente = f.IdFuente;
```

## 4. Evaluación
- Correcta definición de la base de datos y relaciones.
- Eficiencia y claridad del código ETL.
- Calidad de la limpieza y normalización de los datos.
- Claridad y completitud de la documentación.

---

**Autor:** Isaac Concepcion Peralta
**Fecha:** Febrero 2026
