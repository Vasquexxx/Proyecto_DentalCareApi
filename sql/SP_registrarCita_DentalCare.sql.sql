USE DentalCareDB;

-- SP para registrar una cita, evita que hayan horarios duplicados
CREATE PROCEDURE SP_RegistrarCita
    @IdPaciente VARCHAR(20),
    @IdOdontologo INT,
    @IdConsultorio INT,
    @IdEstadoCita INT,
    @Fecha DATE,
    @HoraInicio TIME,
    @HoraFin TIME,
    @Motivo VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;
        -- Validar paciente
        IF NOT EXISTS (
            SELECT 1 FROM Paciente
            WHERE Id_paciente = @IdPaciente
        )
        BEGIN
            THROW 50001, 'El paciente no existe', 1;
        END;
        -- Validar odontologo
        IF NOT EXISTS (
            SELECT 1 FROM Odontologo
            WHERE Id_odonto = @IdOdontologo
        )
        BEGIN
            THROW 50002, 'El odontologo no existe', 1;
        END;

        -- Validar consultorio
        IF NOT EXISTS (
            SELECT 1 FROM Consultorio
            WHERE id = @IdConsultorio
        )
        BEGIN
            THROW 50003, 'El consultorio no existe', 1;
        END;

        -- Validar estado de la cita
        IF NOT EXISTS (
            SELECT 1 FROM EstadoCita
            WHERE id = @IdEstadoCita
        )
        BEGIN
            THROW 50004, 'El estado de la cita no existe', 1;
        END;

        -- Validar horario final
        IF @HoraFin <= @HoraInicio
        BEGIN
            THROW 50005, 'El horario de la cita es incorrecto', 1;
        END;

        -- Validar que el odontologo no tenga otra cita
        IF EXISTS (
            SELECT 1
            FROM Cita
            WHERE id_odonto = @IdOdontologo
              AND fecha = @Fecha
              AND @HoraInicio < hora_fin
              AND @HoraFin > hora_inicio
        )
        BEGIN
            THROW 50006, 'El odontologo ya tiene una cita en ese horario', 1;
        END;

        -- Validar disponibilidad del consultorio
        IF EXISTS (
            SELECT 1
            FROM Cita
            WHERE id_consultorio = @IdConsultorio
              AND fecha = @Fecha
              AND @HoraInicio < hora_fin
              AND @HoraFin > hora_inicio
        )
        BEGIN
            THROW 50007, 'El consultorio ya esta ocupado en ese horario', 1;
        END;

        -- Registrar cita
        INSERT INTO Cita (
            id_paciente,
            id_odonto,
            id_consultorio,
            id_estadoCita,
            fecha,
            hora_inicio,
            hora_fin,
            motivo
        )
        VALUES (
            @IdPaciente,
            @IdOdontologo,
            @IdConsultorio,
            @IdEstadoCita,
            @Fecha,
            @HoraInicio,
            @HoraFin,
            @Motivo
        );

        COMMIT TRANSACTION;
        PRINT 'Cita registrada correctamente';
    END TRY
    BEGIN CATCH

        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;

    END CATCH
END;