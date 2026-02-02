# SistemaAnalisisVentas - Documentación ETL

## Descripción General
Este proyecto implementa un proceso ETL (Extracción, Transformación y Carga) para poblar y analizar una base de datos relacional orientada al análisis de ventas. El flujo automatiza la integración de datos desde archivos CSV hacia SQL Server, asegurando calidad, integridad y trazabilidad de la información.

## 1. Modelado de la Base de Datos
- Tablas principales: Customers, Products, Orders, OrderDetails.
- Claves primarias y foráneas correctamente definidas para asegurar integridad referencial.
- El diseño puede representarse mediante un diagrama ER (entidad-relación).

### Estructura de Tablas
- **Customers**: Información de clientes (ID, nombre, email, teléfono, ciudad, país).
- **Products**: Catálogo de productos (ID, nombre, categoría, precio, stock).
- **Orders**: Pedidos realizados por los clientes (ID, cliente, fecha, estado).
- **OrderDetails**: Detalle de cada pedido (pedido, producto, cantidad, precio total).

## 2. Pipeline ETL
- **Extracción:** Lectura de archivos CSV ubicados en la carpeta `csv` del proyecto.
- **Transformación:**
  - Limpieza de duplicados y nulos.
  - Normalización de formatos (fechas, textos, precios).
  - Validación de integridad y relaciones.
- **Carga:** Inserción de los datos procesados en las tablas del modelo, respetando las relaciones establecidas.

## 3. Resultados Esperados
- Script SQL para la creación de la base de datos y sus tablas (`tablas_generadas.sql`).
- Código Python para el pipeline ETL (`SistemaDeVentas.py`).
- Capturas de pantalla mostrando la cantidad de registros cargados por tabla y resultados de consultas SELECT.
- Resultados de la consulta principal de ventas:

```sql
SELECT o.OrderID, c.FirstName, c.LastName, p.ProductName, od.Quantity, od.TotalPrice, o.OrderDate, o.Status
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
JOIN OrderDetails od ON o.OrderID = od.OrderID
JOIN Products p ON od.ProductID = p.ProductID;
```

## 4. Evaluación
- Correcta definición de la base de datos y relaciones.
- Eficiencia y claridad del código ETL.
- Calidad de la limpieza y normalización de los datos.
- Claridad y completitud de la documentación.

---

**Autor:** Isaac Concepcion Peralta  
**Fecha:** Febrero 2026
