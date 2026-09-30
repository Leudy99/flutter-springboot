package com.example.api.infrastructure.web;

import com.example.api.application.FileService;
import com.example.api.domain.model.StoredFile;
import com.example.api.infrastructure.web.dto.FileResponse;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
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
 * POST /upload recibe multipart/form-data con el campo "file".
 */
@RestController
public class FileController {

    private final FileService fileService;

    public FileController(FileService fileService) {
        this.fileService = fileService;
    }

    @PostMapping(value = "/upload", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<FileResponse> upload(@RequestParam("file") MultipartFile file,
                                               Authentication authentication) throws IOException {
        // authentication.getName() = email guardado en el JWT
        StoredFile saved = fileService.upload(
                file.getOriginalFilename(),
                file.getContentType(),
                file.getSize(),
                file.getInputStream(),
                authentication.getName());
        return ResponseEntity.status(HttpStatus.CREATED).body(FileResponse.from(saved));
    }

    @GetMapping("/files")
    public List<FileResponse> findAll() {
        return fileService.findAll()
                .stream()
                .map(FileResponse::from)
                .toList();
    }

    /** Devuelve el contenido del archivo (sirve para mostrar una imagen ya subida). */
    @GetMapping("/files/{storedName}")
    public ResponseEntity<byte[]> download(@PathVariable String storedName) {
        StoredFile file = fileService.findByStoredName(storedName);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(file.getContentType()))
                .body(fileService.load(file));
    }
}
