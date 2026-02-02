# Relaciones Entidad-Relación (ER) - Sistema de Ventas

A continuación se describen las relaciones entre las entidades principales del sistema para que puedas construir fácilmente el diagrama ER en cualquier herramienta visual:

## Entidades y Relaciones

- **Customers**
  - Almacena los datos de los clientes.
  - Relación: Un cliente puede tener muchos pedidos (Orders).

- **Orders**
  - Almacena los pedidos realizados por los clientes.
  - Relación: Cada pedido pertenece a un cliente (Customers).
  - Relación: Un pedido puede tener muchos detalles de pedido (OrderDetails).
  - Relación: Un pedido puede tener una factura (Invoices).

- **OrderDetails**
  - Almacena los productos y cantidades de cada pedido.
  - Relación: Cada detalle pertenece a un pedido (Orders).
  - Relación: Cada detalle corresponde a un producto (Products).

- **Products**
  - Almacena los productos disponibles.
  - Relación: Un producto puede estar en muchos detalles de pedido (OrderDetails).

- **Invoices**
  - Almacena las facturas generadas para los pedidos.
  - Relación: Cada factura corresponde a un pedido (Orders).

- **DataSources**
  - Almacena información sobre las fuentes de datos (opcional, para trazabilidad de origen de datos).

## Resumen de Relaciones

- Customers 1 --- N Orders
- Orders 1 --- N OrderDetails
- Products 1 --- N OrderDetails
- Orders 1 --- 1 Invoices

Puedes representar estas relaciones con líneas conectando las entidades, usando la notación de pata de cuervo (crow's foot) para las relaciones uno a muchos.

---

**Ejemplo visual simple:**

```
Customers ───< Orders ───< OrderDetails >─── Products
                   │
                   v
               Invoices
```

- "───<" indica una relación uno a muchos (1:N)
- "───" indica una relación uno a uno (1:1)

---

**Autor:** Sistema de Ventas - ERD
