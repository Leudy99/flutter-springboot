package com.example.api.infrastructure.web.dto;

import com.example.api.domain.model.StoredFile;

/**
 * Datos que salen al cliente tras subir o listar archivos.
 * "url" es la ruta relativa para descargarlo: GET /files/{storedName}
 */
public record FileResponse(Long id, String originalName, String storedName,
                           String contentType, long size, String url, String uploadedAt) {

    public static FileResponse from(StoredFile file) {
        return new FileResponse(
                file.getId(),
                file.getOriginalName(),
                file.getStoredName(),
                file.getContentType(),
                file.getSize(),
                "/files/" + file.getStoredName(),
                file.getUploadedAt() == null ? null : file.getUploadedAt().toString()
        );
    }
}
