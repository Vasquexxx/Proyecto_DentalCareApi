CREATE DATABASE DentalCareDB;
GO

USE DentalCareDB;
GO

-- crear tabla para almacenar los roles de los usuarios dentro del sistema
CREATE TABLE Rol (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(200) NULL
);

/* crea la tabla estadoCita para almacenar los posibles estados de una cita
 * (pendiente, confirmada, cancelada y completada)
 */
CREATE TABLE EstadoCita (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

/* crear la tabla para almacenar las especialidades de los odontologos como
* (ortodoncia, endodoncia, periodoncia, etc)
*/
CREATE TABLE Especialidad (
    Id_especialidad INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(200) NULL
);

-- tabla para almacenar alergias que puedan presentar los pacientes (penicilina, latex o anestesicos)
CREATE TABLE Alergia (
    id_alergia INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(200) NULL
);

-- tabla que almacena los metodos de pago que almacena dentalCare
CREATE TABLE Metodo_pago (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion VARCHAR(200) NULL
);

-- tabla que almacena los posibles estados de los planes de tratamientos como(pendiente, en proceso, finalizado y cancelado)
CREATE TABLE Estado_planTratamiento (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE
);

-- almacena las piezas dentales que se pueden trabajar
CREATE TABLE Pieza_dental (
    id INT IDENTITY(1,1) PRIMARY KEY,
    num_pieza INT NOT NULL UNIQUE,
    descripcion VARCHAR(200)
);

-- almacena los consultorios disponibles, por defecto el estado aparece disponible
CREATE TABLE Consultorio (
    id INT IDENTITY(1,1) PRIMARY KEY,
    Nombre VARCHAR(100) NOT NULL UNIQUE,
    ubicacion VARCHAR(150) NOT NULL,
    estado VARCHAR(30) NOT NULL
        DEFAULT 'Disponible',
        
    CONSTRAINT CK_Consultorio_Estado
        CHECK (estado IN ('Disponible', 'Ocupado', 'Mantenimiento'))
);

CREATE TABLE Categoria_prod (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(200)
);

-- almacena los proveedores para dentalCare
CREATE TABLE Proveedor (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL,
    telefono VARCHAR(15) NOT NULL,
    nit VARCHAR(20) NOT NULL UNIQUE,
    correo_electronico VARCHAR(100),
    direccion VARCHAR(200)
);

CREATE TABLE Servicio (
    id INT IDENTITY(1,1) PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    descripcion VARCHAR(200),
    precio DECIMAL(10,2) NOT NULL,
    duracion INT NOT NULL,

    CONSTRAINT CK_Servicio_Precio
        CHECK (precio > 0),

    CONSTRAINT CK_Servicio_Duracion
        CHECK (duracion > 0)
);

-- tabla para almacenar los datos de los pacientes
CREATE TABLE Paciente (
    Id_paciente VARCHAR(20) PRIMARY KEY,
    Num_expediente VARCHAR(20) NOT NULL UNIQUE,
    Nombres VARCHAR(100) NOT NULL,
    Apellidos VARCHAR(100) NOT NULL,
    Correo_electronico VARCHAR(100),
    Num_telefono VARCHAR(15) NOT NULL,
    Direccion VARCHAR(200),
    Fecha_nacimiento DATE NOT NULL,
    Genero VARCHAR(20) NOT NULL,
    Fecha_registro DATE NOT NULL DEFAULT GETDATE(),

    CONSTRAINT CK_Paciente_Genero
        CHECK (Genero IN ('Masculino', 'Femenino', 'Otro'))
);

-- almacena los datos de los empleados
CREATE TABLE Empleado (
    Id_empleado VARCHAR(20) PRIMARY KEY,
    dpi VARCHAR(13) NOT NULL UNIQUE,
    nombres VARCHAR(100) NOT NULL,
    apellidos VARCHAR(100) NOT NULL,
    telefono VARCHAR(15) NOT NULL,
    correo_electronico VARCHAR(100),
    direccion VARCHAR(200),
    fecha_contratacion DATE NOT NULL,
    puesto VARCHAR(100) NOT NULL
);

-- tabla para almacenar los datos de un empleado que sea odontologo
CREATE TABLE Odontologo (
    Id_odonto INT IDENTITY(1,1) PRIMARY KEY,
    id_empleado VARCHAR(20) NOT NULL UNIQUE,
    num_colegiado VARCHAR(30) NOT NULL UNIQUE,

    CONSTRAINT FK_Odontologo_Empleado
        FOREIGN KEY (id_empleado)
        REFERENCES Empleado(Id_empleado)
);

-- almacena los datos de usuarios dentro del sistema
CREATE TABLE Usuario (
    id_cuenta INT IDENTITY(1,1) PRIMARY KEY,
    id_empleado VARCHAR(20) NOT NULL UNIQUE,
    nombre_user VARCHAR(50) NOT NULL UNIQUE,
    contraseña VARCHAR(255) NOT NULL,
    fecha_creacion DATE NOT NULL DEFAULT GETDATE(),
    estado VARCHAR(20) NOT NULL DEFAULT 'Activo',

    CONSTRAINT FK_Usuario_Empleado
        FOREIGN KEY (id_empleado)
        REFERENCES Empleado(Id_empleado),

    CONSTRAINT CK_Usuario_Estado
        CHECK (estado IN ('Activo', 'Inactivo'))
);


-- almacena los expedientes de los pacientes
CREATE TABLE Expediente (
    id_exp VARCHAR(20) PRIMARY KEY,
    id_paciente VARCHAR(20) NOT NULL UNIQUE,
    fecha_apertura DATE NOT NULL DEFAULT GETDATE(),
    observacion_general VARCHAR(300),
    antecedentes VARCHAR(500),

    CONSTRAINT FK_Expediente_Paciente
        FOREIGN KEY (id_paciente)
        REFERENCES Paciente(Id_paciente)
);

-- tabla para almacenar los contactos de pacientes ante cualquier emergencia
CREATE TABLE Contacto_emergencia (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    id_paciente VARCHAR(20) NOT NULL,
    Nombre VARCHAR(100) NOT NULL,
    apellido VARCHAR(100) NOT NULL,
    parentesco VARCHAR(50) NOT NULL,
    num_telefono VARCHAR(15) NOT NULL,

    CONSTRAINT FK_Contacto_Paciente
        FOREIGN KEY (id_paciente)
        REFERENCES Paciente(Id_paciente)
);

-- almacena las citas por atender
CREATE TABLE Cita (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_paciente VARCHAR(20) NOT NULL,
    id_odonto INT NOT NULL,
    id_consultorio INT NOT NULL,
    id_estadoCita INT NOT NULL,
    fecha DATE NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,
    motivo VARCHAR(200) NOT NULL,

    CONSTRAINT FK_Cita_Paciente
        FOREIGN KEY (id_paciente)
        REFERENCES Paciente(Id_paciente),

    CONSTRAINT FK_Cita_Odontologo
        FOREIGN KEY (id_odonto)
        REFERENCES Odontologo(Id_odonto),

    CONSTRAINT FK_Cita_Consultorio
        FOREIGN KEY (id_consultorio)
        REFERENCES Consultorio(id),

    CONSTRAINT FK_Cita_Estado
        FOREIGN KEY (id_estadoCita)
        REFERENCES EstadoCita(id),

    CONSTRAINT CK_Cita_Horas
        CHECK (hora_fin > hora_inicio)
);

-- almacena los horarios en los que atiende un odontologo
CREATE TABLE Horario_odonto (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_odonto INT NOT NULL,
    dias_trabajo VARCHAR(20) NOT NULL,
    hora_inicio TIME NOT NULL,
    hora_fin TIME NOT NULL,

    CONSTRAINT FK_Horario_Odontologo
        FOREIGN KEY (id_odonto)
        REFERENCES Odontologo(Id_odonto),

    CONSTRAINT CK_Horario_Horas
        CHECK (hora_fin > hora_inicio)
);

-- almacena los diagnosticos realizados por los odontologos los cuales se almacenan en un expediente
CREATE TABLE Diagnostico (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_exp VARCHAR(20) NOT NULL,
    descripcion VARCHAR(300) NOT NULL,
    fecha DATE NOT NULL DEFAULT GETDATE(),
    observacion VARCHAR(300),

    CONSTRAINT FK_Diagnostico_Expediente
        FOREIGN KEY (id_exp)
        REFERENCES Expediente(id_exp)
);

-- tablas para almacenar los tratamientos y productos
CREATE TABLE Plan_tratamiento (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_paciente VARCHAR(20) NOT NULL,
    id_estadoPlan INT NOT NULL,
    fecha DATE NOT NULL DEFAULT GETDATE(),
    observacion VARCHAR(300),
    costo DECIMAL(10,2) NOT NULL DEFAULT 0,

    CONSTRAINT FK_Plan_Paciente
        FOREIGN KEY (id_paciente)
        REFERENCES Paciente(Id_paciente),

    CONSTRAINT FK_Plan_Estado
        FOREIGN KEY (id_estadoPlan)
        REFERENCES Estado_planTratamiento(id),

    CONSTRAINT CK_Plan_Costo
        CHECK (costo >= 0)
);

CREATE TABLE Producto (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_categoria INT NOT NULL,
    cod_producto VARCHAR(30) NOT NULL UNIQUE,
    nombre VARCHAR(100) NOT NULL,
    descripcion VARCHAR(200),
    precio_compra DECIMAL(10,2) NOT NULL,
    existencia INT NOT NULL DEFAULT 0,

    CONSTRAINT FK_Producto_Categoria
        FOREIGN KEY (id_categoria)
        REFERENCES Categoria_prod(id),

    CONSTRAINT CK_Producto_Precio
        CHECK (precio_compra > 0),

    CONSTRAINT CK_Producto_Existencia
        CHECK (existencia >= 0)
);

CREATE TABLE Compra (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_proveedor INT NOT NULL,
    fecha_compra DATE NOT NULL DEFAULT GETDATE(),
    num_doc VARCHAR(30) NOT NULL UNIQUE,

    CONSTRAINT FK_Compra_Proveedor
        FOREIGN KEY (id_proveedor)
        REFERENCES Proveedor(id)
);

CREATE TABLE Comprobante (
    num_comprobante VARCHAR(30) PRIMARY KEY,
    id_paciente VARCHAR(20) NOT NULL,
    total DECIMAL(10,2) NOT NULL,
    fecha_emision DATE NOT NULL DEFAULT GETDATE(),
    subtotal DECIMAL(10,2) NOT NULL,
    descuento DECIMAL(10,2) DEFAULT 0,
    estado VARCHAR(30) NOT NULL DEFAULT 'Pendiente',

    CONSTRAINT FK_Comprobante_Paciente
        FOREIGN KEY (id_paciente)
        REFERENCES Paciente(Id_paciente),

    CONSTRAINT CK_Comprobante_Total
        CHECK (total >= 0),

    CONSTRAINT CK_Comprobante_Subtotal
        CHECK (subtotal >= 0),

    CONSTRAINT CK_Comprobante_Descuento
        CHECK (descuento >= 0)
);

-- tablas para almacenar procediminetos, detalles y movimientos
CREATE TABLE Detalle_tratamiento (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_plan INT NOT NULL,
    id_servicio INT NOT NULL,
    cantidad INT NOT NULL,
    precio DECIMAL(10,2) NOT NULL,
    observaciones VARCHAR(300),

    CONSTRAINT FK_DetalleTratamiento_Plan
        FOREIGN KEY (id_plan)
        REFERENCES Plan_tratamiento(id),

    CONSTRAINT FK_DetalleTratamiento_Servicio
        FOREIGN KEY (id_servicio)
        REFERENCES Servicio(id),

    CONSTRAINT CK_DetalleTratamiento_Cantidad
        CHECK (cantidad > 0),

    CONSTRAINT CK_DetalleTratamiento_Precio
        CHECK (precio >= 0)
);

CREATE TABLE Procedimiento (
    Id INT IDENTITY(1,1) PRIMARY KEY,
    id_odonto INT NOT NULL,
    fecha DATE NOT NULL,
    descripcion VARCHAR(300) NOT NULL,
    observacion VARCHAR(300),

    CONSTRAINT FK_Procedimiento_Odontologo
        FOREIGN KEY (id_odonto)
        REFERENCES Odontologo(Id_odonto)
);

CREATE TABLE Detalle_compra (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_compra INT NOT NULL,
    id_producto INT NOT NULL,
    cantidad INT NOT NULL,
    costo_unitario DECIMAL(10,2) NOT NULL,

    CONSTRAINT FK_DetalleCompra_Compra
        FOREIGN KEY (id_compra)
        REFERENCES Compra(id),

    CONSTRAINT FK_DetalleCompra_Producto
        FOREIGN KEY (id_producto)
        REFERENCES Producto(id),

    CONSTRAINT CK_DetalleCompra_Cantidad
        CHECK (cantidad > 0),

    CONSTRAINT CK_DetalleCompra_Costo
        CHECK (costo_unitario > 0)
);

CREATE TABLE Detalle_comprobante (
    id INT IDENTITY(1,1) PRIMARY KEY,
    num_comprobante VARCHAR(30) NOT NULL,
    descripcion VARCHAR(200) NOT NULL,
    cantidad INT NOT NULL,
    precio_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,

    CONSTRAINT FK_DetalleComprobante_Comprobante
        FOREIGN KEY (num_comprobante)
        REFERENCES Comprobante(num_comprobante),

    CONSTRAINT CK_DetalleComprobante_Cantidad
        CHECK (cantidad > 0),

    CONSTRAINT CK_DetalleComprobante_Precio
        CHECK (precio_unitario >= 0),

    CONSTRAINT CK_DetalleComprobante_Subtotal
        CHECK (subtotal >= 0)
);

CREATE TABLE Pago (
    num_referencia VARCHAR(30) PRIMARY KEY,
    num_comprobante VARCHAR(30) NOT NULL,
    id_metodoPago INT NOT NULL,
    fecha_pago DATE NOT NULL DEFAULT GETDATE(),
    monto DECIMAL(10,2) NOT NULL,

    CONSTRAINT FK_Pago_Comprobante
        FOREIGN KEY (num_comprobante)
        REFERENCES Comprobante(num_comprobante),

    CONSTRAINT FK_Pago_Metodo
        FOREIGN KEY (id_metodoPago)
        REFERENCES Metodo_pago(id),

    CONSTRAINT CK_Pago_Monto
        CHECK (monto > 0)
);

CREATE TABLE Movimiento_inventario (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_producto INT NOT NULL,
    motivo VARCHAR(200) NOT NULL,
    fecha_mov DATE NOT NULL DEFAULT GETDATE(),
    tipo_mov VARCHAR(10) NOT NULL,
    cantidad INT NOT NULL,

    CONSTRAINT FK_Movimiento_Producto
        FOREIGN KEY (id_producto)
        REFERENCES Producto(id),

    CONSTRAINT CK_Movimiento_Tipo
        CHECK (tipo_mov IN ('Entrada', 'Salida')),

    CONSTRAINT CK_Movimiento_Cantidad
        CHECK (cantidad > 0)
);

-- tablas intermedias
CREATE TABLE Odonto_especialidad (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_odonto INT NOT NULL,
    id_especialidad INT NOT NULL,

    CONSTRAINT FK_OdontoEspecialidad_Odontologo
        FOREIGN KEY (id_odonto)
        REFERENCES Odontologo(Id_odonto),

    CONSTRAINT FK_OdontoEspecialidad_Especialidad
        FOREIGN KEY (id_especialidad)
        REFERENCES Especialidad(Id_especialidad),

    CONSTRAINT UQ_OdontoEspecialidad
        UNIQUE (id_odonto, id_especialidad)
);

CREATE TABLE Usuario_rol (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_usuario INT NOT NULL,
    id_rol INT NOT NULL,

    CONSTRAINT FK_UsuarioRol_Usuario
        FOREIGN KEY (id_usuario)
        REFERENCES Usuario(id_cuenta),

    CONSTRAINT FK_UsuarioRol_Rol
        FOREIGN KEY (id_rol)
        REFERENCES Rol(id),

    CONSTRAINT UQ_UsuarioRol
        UNIQUE (id_usuario, id_rol)
);

CREATE TABLE Paciente_alergia (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_paciente VARCHAR(20) NOT NULL,
    id_alergia INT NOT NULL,

    CONSTRAINT FK_PacienteAlergia_Paciente
        FOREIGN KEY (id_paciente)
        REFERENCES Paciente(Id_paciente),

    CONSTRAINT FK_PacienteAlergia_Alergia
        FOREIGN KEY (id_alergia)
        REFERENCES Alergia(id_alergia),

    CONSTRAINT UQ_PacienteAlergia
        UNIQUE (id_paciente, id_alergia)
);

CREATE TABLE Procedimiento_pieza (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_procedimiento INT NOT NULL,
    id_pieza INT NOT NULL,

    CONSTRAINT FK_ProcedimientoPieza_Procedimiento
        FOREIGN KEY (id_procedimiento)
        REFERENCES Procedimiento(Id),

    CONSTRAINT FK_ProcedimientoPieza_Pieza
        FOREIGN KEY (id_pieza)
        REFERENCES Pieza_dental(id),

    CONSTRAINT UQ_ProcedimientoPieza
        UNIQUE (id_procedimiento, id_pieza)
);

CREATE TABLE Producto_servicio (
    id INT IDENTITY(1,1) PRIMARY KEY,
    id_servicio INT NOT NULL,
    id_producto INT NOT NULL,

    CONSTRAINT FK_ProductoServicio_Servicio
        FOREIGN KEY (id_servicio)
        REFERENCES Servicio(id),

    CONSTRAINT FK_ProductoServicio_Producto
        FOREIGN KEY (id_producto)
        REFERENCES Producto(id),

    CONSTRAINT UQ_ProductoServicio
        UNIQUE (id_servicio, id_producto)
);










