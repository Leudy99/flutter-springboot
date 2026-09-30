package com.example.api.application;

import com.example.api.domain.exception.FileNotFoundException;
import com.example.api.domain.exception.InvalidFileException;
import com.example.api.domain.model.StoredFile;
import com.example.api.domain.port.FileStorage;
import com.example.api.domain.port.StoredFileRepository;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Casos de uso de archivos: subir, listar y descargar.
 * Solo depende de puertos del dominio (FileStorage, StoredFileRepository).
 */
@Service
public class FileService {

    /** Tipos permitidos: imagenes y documentos comunes. */
    private static final Set<String> ALLOWED_TYPES = Set.of(
            "image/jpeg", "image/png", "image/gif", "image/webp",
            "application/pdf", "text/plain",
            "application/msword",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "application/vnd.ms-excel",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
    );

    private final FileStorage fileStorage;
    private final StoredFileRepository storedFileRepository;

    public FileService(FileStorage fileStorage, StoredFileRepository storedFileRepository) {
        this.fileStorage = fileStorage;
        this.storedFileRepository = storedFileRepository;
    }

    /**
     * Subir archivo:
     * 1. valida que no este vacio y que el tipo este permitido
     * 2. genera un nombre unico (evita choques y nombres peligrosos)
     * 3. guarda el contenido en el storage
     * 4. guarda la referencia en la base de datos
     */
    public StoredFile upload(String originalName, String contentType, long size,
                             InputStream content, String uploadedBy) {
        if (size == 0) {
            throw new InvalidFileException("El archivo esta vacio");
        }
        if (contentType == null || !ALLOWED_TYPES.contains(contentType)) {
            throw new InvalidFileException("Tipo de archivo no permitido: " + contentType);
        }

        String storedName = UUID.randomUUID() + extensionOf(originalName);
        fileStorage.save(storedName, content);

        StoredFile file = new StoredFile(null, originalName, storedName, contentType,
                size, uploadedBy, LocalDateTime.now());
        return storedFileRepository.save(file);
    }

    /** Listar referencias de todos los archivos subidos. */
    public List<StoredFile> findAll() {
        return storedFileRepository.findAll();
    }

    /** Buscar la referencia de un archivo o fallar con 404. */
    public StoredFile findByStoredName(String storedName) {
        return storedFileRepository.findByStoredName(storedName)
                .orElseThrow(() -> new FileNotFoundException(storedName));
    }

    /** Leer el contenido de un archivo ya registrado. */
    public byte[] load(StoredFile file) {
        return fileStorage.load(file.getStoredName());
    }

    /** ".png" a partir de "foto.png"; vacio si no tiene extension. */
    private String extensionOf(String name) {
        if (name == null) {
            return "";
        }
        int dot = name.lastIndexOf('.');
        if (dot < 0 || dot == name.length() - 1) {
            return "";
        }
        // Solo letras y numeros, para no dejar pasar rutas raras
        return "." + name.substring(dot + 1).replaceAll("[^A-Za-z0-9]", "").toLowerCase();
    }
}
