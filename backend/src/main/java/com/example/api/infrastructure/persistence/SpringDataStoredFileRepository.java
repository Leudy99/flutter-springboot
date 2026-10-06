package com.example.api.infrastructure.persistence;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;
import java.util.Optional;

/**
 * Repositorio de Spring Data JPA para la tabla "files".
 * Las consultas se derivan del nombre del metodo (no se escribe SQL).
 */
public interface SpringDataStoredFileRepository extends JpaRepository<StoredFileEntity, Long> {

    /** WHERE user_id = ? ORDER BY id DESC */
    List<StoredFileEntity> findByUserIdOrderByIdDesc(Long userId);

    Optional<StoredFileEntity> findByStorageKey(String storageKey);
}
