package com.example.api.domain.port;

import com.example.api.domain.model.StoredFile;

import java.util.List;
import java.util.Optional;

/**
 * Puerto de salida para guardar la referencia (metadatos) de los archivos en la BD.
 */
public interface StoredFileRepository {

    StoredFile save(StoredFile file);

    List<StoredFile> findAll();

    Optional<StoredFile> findByStoredName(String storedName);
}
