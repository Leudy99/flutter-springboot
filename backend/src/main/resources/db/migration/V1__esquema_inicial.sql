-- =============================================================================
-- Esquema de la base de datos (Flyway lo aplica una sola vez, al arrancar la API)
--
--   users 1 ──── N files      Un usuario tiene muchos archivos.
-- =============================================================================

-- Usuarios de la aplicacion
CREATE TABLE users (
    id            BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name          VARCHAR(100) NOT NULL,
    email         VARCHAR(150) NOT NULL,
    password_hash VARCHAR(60)  NOT NULL,              -- hash BCrypt, nunca la contrasena
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uk_users_email UNIQUE (email),
    -- El email se guarda siempre en minusculas (lo normaliza UserService)
    CONSTRAINT ck_users_email_lowercase CHECK (email = lower(email))
);

-- Archivos subidos: solo los datos; el contenido esta en S3 (o en disco en local)
CREATE TABLE files (
    id            BIGINT       GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id       BIGINT       NOT NULL,              -- dueno del archivo
    original_name VARCHAR(255) NOT NULL,              -- nombre con el que se subio
    storage_key   VARCHAR(255) NOT NULL,              -- nombre unico en S3 / disco (UUID)
    content_type  VARCHAR(100) NOT NULL,
    size_bytes    BIGINT       NOT NULL,
    created_at    TIMESTAMPTZ  NOT NULL DEFAULT now(),

    CONSTRAINT uk_files_storage_key UNIQUE (storage_key),
    CONSTRAINT ck_files_size_positive CHECK (size_bytes > 0),
    -- Si se elimina el usuario, se eliminan sus archivos
    CONSTRAINT fk_files_user FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
);

-- Acelera "los archivos del usuario X", la consulta mas frecuente
CREATE INDEX idx_files_user_id ON files (user_id);
