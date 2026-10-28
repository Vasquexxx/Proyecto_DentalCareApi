USE DentalCareDB;


CREATE PROCEDURE SP_ActualizarEstadoCita
    @IdCita INT,
    @IdEstado INT
AS
BEGIN
    BEGIN TRY
        BEGIN TRANSACTION;

        -- Verificar que exista la cita
        IF NOT EXISTS (
            SELECT 1
            FROM Cita
            WHERE id = @IdCita
        )
        BEGIN
            THROW 50001, 'La cita no existe', 1;
        END;

        -- Verificar que exista el estado
        IF NOT EXISTS (
            SELECT 1
            FROM EstadoCita
            WHERE id = @IdEstado
        )
        BEGIN
            THROW 50002, 'El estado no existe', 1;
        END;

        -- Actualizar el estado
        UPDATE Cita
        SET id_estadoCita = @IdEstado
        WHERE id = @IdCita;

        COMMIT TRANSACTION;

        PRINT 'Estado actualizado correctamente';

    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
