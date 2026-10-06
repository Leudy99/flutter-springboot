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
    public List<StoredFile> findByOwnerId(Long ownerId) {
        return jpaRepository.findByUserIdOrderByIdDesc(ownerId)
                .stream()
                .map(this::toDomain)
                .toList();
    }

    @Override
    public Optional<StoredFile> findById(Long id) {
        return jpaRepository.findById(id).map(this::toDomain);
    }

    @Override
    public Optional<StoredFile> findByStoredName(String storedName) {
        return jpaRepository.findByStorageKey(storedName).map(this::toDomain);
    }

    @Override
    public void deleteById(Long id) {
        jpaRepository.deleteById(id);
    }

    // --- Conversores ---

    private StoredFile toDomain(StoredFileEntity e) {
        return new StoredFile(e.getId(), e.getUserId(), e.getOriginalName(), e.getStorageKey(),
                e.getContentType(), e.getSizeBytes(), e.getCreatedAt());
    }

    private StoredFileEntity toEntity(StoredFile f) {
        return new StoredFileEntity(f.getId(), f.getOwnerId(), f.getOriginalName(),
                f.getStoredName(), f.getContentType(), f.getSize(), f.getUploadedAt());
    }
}
