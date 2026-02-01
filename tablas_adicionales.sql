CREATE TABLE FuenteDatos (
    IdFuente INT IDENTITY(1,1) PRIMARY KEY,
    TipoFuente VARCHAR(50) NOT NULL,     -- CSV, API, SQL
    Descripcion VARCHAR(150),
    FechaCarga DATETIME NOT NULL DEFAULT GETDATE()
);

CREATE TABLE Productos (
    IdProducto INT IDENTITY(1,1) PRIMARY KEY,
    CodigoProducto VARCHAR(50) UNIQUE,
    Nombre VARCHAR(100) NOT NULL,
    Categoria VARCHAR(100),
    Precio DECIMAL(18,2) NOT NULL,
    IdFuente INT,
    FechaRegistro DATETIME DEFAULT GETDATE(),

    CONSTRAINT FK_Productos_Fuente
        FOREIGN KEY (IdFuente) REFERENCES FuenteDatos(IdFuente)
);

CREATE TABLE Clientes (
    IdCliente INT IDENTITY(1,1) PRIMARY KEY,
    CodigoCliente VARCHAR(50) UNIQUE,
    Nombre VARCHAR(150) NOT NULL,
    Email VARCHAR(150),
    Region VARCHAR(100),
    IdFuente INT,
    FechaRegistro DATETIME DEFAULT GETDATE(),

    CONSTRAINT FK_Clientes_Fuente
        FOREIGN KEY (IdFuente) REFERENCES FuenteDatos(IdFuente)
);

CREATE TABLE Ventas (
    IdVenta BIGINT IDENTITY(1,1) PRIMARY KEY,
    IdCliente INT NOT NULL,
    IdProducto INT NOT NULL,
    Cantidad INT NOT NULL CHECK (Cantidad > 0),
    Precio DECIMAL(18,2) NOT NULL,
    FechaVenta DATE NOT NULL,
    Total AS (Cantidad * Precio) PERSISTED, -- cálculo automático
    IdFuente INT,
    FechaCarga DATETIME DEFAULT GETDATE(),

    CONSTRAINT FK_Ventas_Clientes
        FOREIGN KEY (IdCliente) REFERENCES Clientes(IdCliente),

    CONSTRAINT FK_Ventas_Productos
        FOREIGN KEY (IdProducto) REFERENCES Productos(IdProducto),

    CONSTRAINT FK_Ventas_Fuente
        FOREIGN KEY (IdFuente) REFERENCES FuenteDatos(IdFuente)
);

CREATE INDEX IDX_Ventas_Fecha
ON Ventas (FechaVenta);

CREATE INDEX IDX_Ventas_Producto
ON Ventas (IdProducto);

CREATE INDEX IDX_Ventas_Cliente
ON Ventas (IdCliente);


CREATE TABLE Encuestas (
    IdEncuesta INT IDENTITY(1,1) PRIMARY KEY,
    Pregunta VARCHAR(500) NOT NULL,
    Respuesta VARCHAR(1000),
    FechaEncuesta DATE,
    IdFuente INT,
    FechaRegistro DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_Encuestas_Fuente FOREIGN KEY (IdFuente) REFERENCES FuenteDatos(IdFuente)
);

CREATE TABLE ComentariosSociales (
    IdComentario INT IDENTITY(1,1) PRIMARY KEY,
    Texto VARCHAR(2000) NOT NULL,
    Usuario VARCHAR(150),
    FechaComentario DATE,
    IdFuente INT,
    FechaRegistro DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_Comentarios_Fuente FOREIGN KEY (IdFuente) REFERENCES FuenteDatos(IdFuente)
);

CREATE TABLE OpinionesWeb (
    IdOpinion INT IDENTITY(1,1) PRIMARY KEY,
    Texto VARCHAR(2000) NOT NULL,
    Calificacion INT,
    FechaOpinion DATE,
    IdFuente INT,
    FechaRegistro DATETIME DEFAULT GETDATE(),
    CONSTRAINT FK_Opiniones_Fuente FOREIGN KEY (IdFuente) REFERENCES FuenteDatos(IdFuente)
);

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