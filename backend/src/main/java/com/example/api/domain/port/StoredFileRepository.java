package com.example.api.domain.port;

import com.example.api.domain.model.StoredFile;

import java.util.List;
import java.util.Optional;

/**
 * Puerto de salida para guardar la referencia (metadatos) de los archivos en la BD.
 */
public interface StoredFileRepository {

    StoredFile save(StoredFile file);

    /** Archivos de un usuario, del mas reciente al mas antiguo. */
    List<StoredFile> findByOwnerId(Long ownerId);

    Optional<StoredFile> findById(Long id);

    Optional<StoredFile> findByStoredName(String storedName);

    void deleteById(Long id);
}
