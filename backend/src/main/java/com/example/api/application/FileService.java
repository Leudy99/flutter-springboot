package com.example.api.application;

import com.example.api.domain.exception.FileNotFoundException;
import com.example.api.domain.exception.InvalidFileException;
import com.example.api.domain.exception.UserNotFoundException;
import com.example.api.domain.model.StoredFile;
import com.example.api.domain.model.User;
import com.example.api.domain.port.FileStorage;
import com.example.api.domain.port.StoredFileRepository;
import com.example.api.domain.port.UserRepository;
import org.springframework.stereotype.Service;

import java.io.InputStream;
import java.time.Instant;
import java.util.List;
import java.util.Set;
import java.util.UUID;

/**
 * Casos de uso de archivos: subir, listar, descargar y eliminar.
 * Cada usuario solo ve y gestiona SUS archivos.
 * Solo depende de puertos del dominio (FileStorage, StoredFileRepository, UserRepository).
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
    private final UserRepository userRepository;

    public FileService(FileStorage fileStorage,
                       StoredFileRepository storedFileRepository,
                       UserRepository userRepository) {
        this.fileStorage = fileStorage;
        this.storedFileRepository = storedFileRepository;
        this.userRepository = userRepository;
    }

    /**
     * Subir archivo:
     * 1. valida que no este vacio y que el tipo este permitido
     * 2. genera un nombre unico (evita choques y nombres peligrosos)
     * 3. guarda el contenido en el storage
     * 4. guarda la referencia en la base de datos, ligada a su dueno
     */
    public StoredFile upload(String originalName, String contentType, long size,
                             InputStream content, String ownerEmail) {
        if (size == 0) {
            throw new InvalidFileException("El archivo esta vacio");
        }
        if (contentType == null || !ALLOWED_TYPES.contains(contentType)) {
            throw new InvalidFileException("Tipo de archivo no permitido: " + contentType);
        }
        User owner = findUser(ownerEmail);

        String storedName = UUID.randomUUID() + extensionOf(originalName);
        fileStorage.save(storedName, content);

        StoredFile file = new StoredFile(null, owner.getId(), originalName, storedName,
                contentType, size, Instant.now());
        return storedFileRepository.save(file);
    }

    /** Archivos del usuario autenticado. */
    public List<StoredFile> findMine(String ownerEmail) {
        return storedFileRepository.findByOwnerId(findUser(ownerEmail).getId());
    }

    /**
     * Un archivo del usuario autenticado. Si es de otro usuario se responde
     * "no encontrado" (404), para no revelar que existe.
     */
    public StoredFile findMine(String storedName, String ownerEmail) {
        Long ownerId = findUser(ownerEmail).getId();
        return storedFileRepository.findByStoredName(storedName)
                .filter(file -> file.isOwnedBy(ownerId))
                .orElseThrow(() -> new FileNotFoundException(storedName));
    }

    /** Leer el contenido de un archivo ya registrado. */
    public byte[] load(StoredFile file) {
        return fileStorage.load(file.getStoredName());
    }

    /** Eliminar un archivo propio: primero del storage y luego su referencia en la BD. */
    public void delete(Long id, String ownerEmail) {
        Long ownerId = findUser(ownerEmail).getId();
        StoredFile file = storedFileRepository.findById(id)
                .filter(f -> f.isOwnedBy(ownerId))
                .orElseThrow(() -> new FileNotFoundException(id));

        fileStorage.delete(file.getStoredName());
        storedFileRepository.deleteById(file.getId());
    }

    /**
     * Borra del storage todos los archivos de un usuario.
     * Se usa al eliminar el usuario: las filas las borra la BD (ON DELETE CASCADE).
     */
    public void deleteContentOf(Long ownerId) {
        storedFileRepository.findByOwnerId(ownerId)
                .forEach(file -> fileStorage.delete(file.getStoredName()));
    }

    private User findUser(String email) {
        return userRepository.findByEmail(email)
                .orElseThrow(() -> new UserNotFoundException(email));
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
