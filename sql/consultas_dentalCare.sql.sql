USE DentalCareDB;

SELECT *
FROM Rol;

SELECT * FROM EstadoCita;



-- contar cuantas tablas hay en la db
SELECT COUNT(*) AS Total_Tablas
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE';

-- consulta las 35 tablas que se crearon
SELECT
    TABLE_NAME AS Nombre_Tabla
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE'
ORDER BY TABLE_NAME;

SELECT *
FROM Rol;

SELECT *
FROM EstadoCita
order by id ASC;

SELECT *
FROM Especialidad;

SELECT *
FROM Alergia;

SELECT *
FROM Metodo_pago;


SELECT *
FROM Cita;


SELECT *
FROM Horario_odonto;

SELECT *
FROM EstadoCita
ORDER BY id ASC;

select *
from Paciente;


SELECT
    t.name AS Tabla,
    SUM(p.rows) AS TotalRegistros
FROM sys.tables t
INNER JOIN sys.partitions p
    ON t.object_id = p.object_id
WHERE p.index_id IN (0, 1)
GROUP BY t.name
ORDER BY t.name;


SELECT *
FROM Cita
WHERE Id_Paciente = 'PAC001'
ORDER BY Fecha DESC;








-- consulta los pacientes y los diagnosticos registrados en sus expedientes
SELECT
    p.Nombres,
    p.Apellidos,
    e.id_exp AS Expediente,
    d.descripcion AS Diagnostico,
    d.fecha AS FechaDiagnostico
FROM Paciente p
INNER JOIN Expediente e
    ON p.Id_paciente = e.id_paciente
INNER JOIN Diagnostico d
    ON e.id_exp = d.id_exp;



-- consulta para mostrar las citas programadas de los pacientes
SELECT 
	p.Nombres AS nombrePaciente,
	p.Apellidos as apellidoPaciente,
	e.nombres as nombreOdontologo,
	e.apellidos as apellidoOdontologo,
	c.fecha AS FechaCita,
	c.fecha as fechaCita,
	c.hora_inicio AS HoraInicio,
	c.motivo AS Motivo
FROM Paciente P
	INNER JOIN Cita c
		ON p.Id_paciente = c.id_paciente
	inner join Odontologo o  
		on c.id_odonto = o.id_odonto
	inner join Empleado e 
		on o.id_empleado = e.id_empleado
ORDER BY c.fecha ASC;



-- consulta reporte para ingresos por cada metodo de pago ordenados de forma descendente
SELECT
    m.nombre AS MetodoPago,
    COUNT(p.num_referencia) AS CantidadPagos,
    SUM(p.monto) AS TotalIngresos
FROM Metodo_pago m
INNER JOIN Pago p
    ON m.id = p.id_metodoPago
GROUP BY m.nombre
ORDER BY TotalIngresos DESC;



-- consulta para conocer cuantas citas tiene asignadas cada odontologo
SELECT
    e.nombres AS NombreOdontologo,
    e.apellidos AS ApellidoOdontologo,
    COUNT(c.id) AS TotalCitas
FROM Empleado e
INNER JOIN Odontologo o
    ON e.Id_empleado = o.id_empleado
INNER JOIN Cita c
    ON o.Id_odonto = c.id_odonto
GROUP BY e.Id_empleado, e.nombres, e.apellidos
ORDER BY TotalCitas DESC;


-- consulta para identificar los pacientes que tienen reegistradas dos o mas alergias
SELECT
    p.Nombres AS NombrePaciente,
    p.Apellidos AS ApellidoPaciente,
    COUNT(a.id_alergia) AS TotalAlergias
FROM Paciente p
INNER JOIN Paciente_alergia pa
    ON p.Id_paciente = pa.id_paciente
INNER JOIN Alergia a
    ON pa.id_alergia = a.id_alergia
GROUP BY p.Id_paciente, p.Nombres, p.Apellidos
HAVING COUNT(a.id_alergia) > 1
ORDER BY TotalAlergias DESC;


-- muestra el precio promedio de los servicios que ofrece dentalRie
SELECT
    COUNT(*) AS TotalServicios,
    AVG(precio) AS PrecioPromedio
FROM Servicio;


-- identifica los precios minimo y maximo de los servicios dentales
SELECT
    MIN(precio) AS PrecioMinimo,
    MAX(precio) AS PrecioMaximo
FROM Servicio;


-- consulta cuantos productos existen, su existencia total y los valores minimo, maximo y promedio
SELECT
    COUNT(*) AS TotalProductos,
    SUM(existencia) AS ExistenciaTotal,
    AVG(CAST(existencia AS DECIMAL(10,2))) AS ExistenciaPromedio,
    MIN(existencia) AS ExistenciaMinima,
    MAX(existencia) AS ExistenciaMaxima
FROM Producto;


SELECT *
FROM Producto;









