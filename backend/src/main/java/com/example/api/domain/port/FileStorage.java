package com.example.api.domain.port;

import java.io.InputStream;

/**
 * Puerto de salida para guardar el contenido de los archivos.
 * El dominio dice "guarda estos bytes con este nombre", pero no sabe si es
 * disco local, S3, etc. La implementacion vive en infrastructure/storage.
 */
public interface FileStorage {

    void save(String storedName, InputStream content);

    byte[] load(String storedName);
}
