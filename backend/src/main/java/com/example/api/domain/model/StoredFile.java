package com.example.api.domain.model;

import java.time.LocalDateTime;

/**
 * Modelo de dominio de un archivo subido.
 * Guarda solo la referencia (metadatos); el contenido vive en el storage.
 */
public class StoredFile {

    private Long id;
    private String originalName; // nombre con el que lo subio el cliente
    private String storedName;   // nombre unico en disco (UUID + extension)
    private String contentType;
    private long size;
    private String uploadedBy;   // email del usuario autenticado
    private LocalDateTime uploadedAt;

    public StoredFile() {
    }

    public StoredFile(Long id, String originalName, String storedName, String contentType,
                      long size, String uploadedBy, LocalDateTime uploadedAt) {
        this.id = id;
        this.originalName = originalName;
        this.storedName = storedName;
        this.contentType = contentType;
        this.size = size;
        this.uploadedBy = uploadedBy;
        this.uploadedAt = uploadedAt;
    }

    public Long getId() {
        return id;
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

    public String getUploadedBy() {
        return uploadedBy;
    }

    public LocalDateTime getUploadedAt() {
        return uploadedAt;
    }
}
