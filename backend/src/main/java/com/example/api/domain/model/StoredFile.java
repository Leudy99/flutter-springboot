package com.example.api.domain.model;

import java.time.Instant;

/**
 * Modelo de dominio de un archivo subido.
 * Guarda solo la referencia (metadatos); el contenido vive en el storage (S3 o disco).
 */
public class StoredFile {

    private Long id;
    private Long ownerId;        // id del usuario que lo subio (dueno)
    private String originalName; // nombre con el que lo subio el cliente
    private String storedName;   // nombre unico en el storage (UUID + extension)
    private String contentType;
    private long size;           // bytes
    private Instant uploadedAt;

    public StoredFile() {
    }

    public StoredFile(Long id, Long ownerId, String originalName, String storedName,
                      String contentType, long size, Instant uploadedAt) {
        this.id = id;
        this.ownerId = ownerId;
        this.originalName = originalName;
        this.storedName = storedName;
        this.contentType = contentType;
        this.size = size;
        this.uploadedAt = uploadedAt;
    }

    /** true si el archivo pertenece al usuario indicado. */
    public boolean isOwnedBy(Long userId) {
        return ownerId != null && ownerId.equals(userId);
    }

    public Long getId() {
        return id;
    }

    public Long getOwnerId() {
        return ownerId;
    }

    public String getOriginalName() {
        return originalName;
    }

    public String getStoredName() {
        return storedName;
    }

    public String getContentType() {
        return contentType;
    }

    public long getSize() {
        return size;
    }

    public Instant getUploadedAt() {
        return uploadedAt;
    }
}
