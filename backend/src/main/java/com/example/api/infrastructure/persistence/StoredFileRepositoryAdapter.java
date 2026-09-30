package com.example.api.infrastructure.persistence;

import com.example.api.domain.model.StoredFile;
import com.example.api.domain.port.StoredFileRepository;
import org.springframework.stereotype.Repository;

import java.util.List;
import java.util.Optional;

/**
 * Adaptador de persistencia de archivos.
 * Implementa el puerto StoredFileRepository y traduce StoredFileEntity <-> StoredFile.
 */
@Repository
public class StoredFileRepositoryAdapter implements StoredFileRepository {

    private final SpringDataStoredFileRepository jpaRepository;

    public StoredFileRepositoryAdapter(SpringDataStoredFileRepository jpaRepository) {
        this.jpaRepository = jpaRepository;
    }

    @Override
    public StoredFile save(StoredFile file) {
        return toDomain(jpaRepository.save(toEntity(file)));
    }

    @Override
    public List<StoredFile> findAll() {
        return jpaRepository.findAll()
                .stream()
                .map(this::toDomain)
                .toList();
    }

    @Override
    public Optional<StoredFile> findByStoredName(String storedName) {
        return jpaRepository.findByStoredName(storedName).map(this::toDomain);
    }

    // --- Conversores ---

    private StoredFile toDomain(StoredFileEntity e) {
        return new StoredFile(e.getId(), e.getOriginalName(), e.getStoredName(),
                e.getContentType(), e.getSize(), e.getUploadedBy(), e.getUploadedAt());
    }

    private StoredFileEntity toEntity(StoredFile f) {
        return new StoredFileEntity(f.getId(), f.getOriginalName(), f.getStoredName(),
                f.getContentType(), f.getSize(), f.getUploadedBy(), f.getUploadedAt());
    }
}
