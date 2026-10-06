package com.example.api.infrastructure.web;

import com.example.api.application.FileService;
import com.example.api.domain.model.StoredFile;
import com.example.api.infrastructure.web.dto.FileResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import java.io.IOException;
import java.util.List;

/**
 * Adaptador de entrada HTTP para archivos.
 * Todas las operaciones son sobre los archivos del usuario autenticado:
 * authentication.getName() es el email guardado en el JWT.
 */
@RestController
public class FileController {

    private final FileService fileService;

    public FileController(FileService fileService) {
        this.fileService = fileService;
    }

    /** Subir un archivo (multipart/form-data, campo "file"). */
    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<FileResponse> upload(@RequestParam("file") MultipartFile file,
                                               Authentication authentication) throws IOException {
        StoredFile saved = fileService.upload(
                file.getOriginalFilename(),
                file.getContentType(),
                file.getSize(),
                file.getInputStream(),
                authentication.getName());
        return ResponseEntity.status(HttpStatus.CREATED).body(FileResponse.from(saved));
    }

    /** Mis archivos. */
    @GetMapping("/files")
    public List<FileResponse> findMine(Authentication authentication) {
        return fileService.findMine(authentication.getName())
                .stream()
                .map(FileResponse::from)
                .toList();
    }

    /** Contenido de uno de mis archivos (para mostrar la imagen, el PDF...). */
    @GetMapping("/files/{storedName}")
    public ResponseEntity<byte[]> download(@PathVariable String storedName,
                                           Authentication authentication) {
        StoredFile file = fileService.findMine(storedName, authentication.getName());
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(file.getContentType()))
                .body(fileService.load(file));
    }

    /** Eliminar uno de mis archivos. */
    @DeleteMapping("/files/{id}")
    public ResponseEntity<Void> delete(@PathVariable Long id, Authentication authentication) {
        fileService.delete(id, authentication.getName());
        return ResponseEntity.noContent().build();
    }
}
