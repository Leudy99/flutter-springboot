package com.example.api.infrastructure.persistence;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.Optional;

/** Repositorio de Spring Data JPA para la tabla "files". */
public interface SpringDataStoredFileRepository extends JpaRepository<StoredFileEntity, Long> {

    Optional<StoredFileEntity> findByStoredName(String storedName);
}
