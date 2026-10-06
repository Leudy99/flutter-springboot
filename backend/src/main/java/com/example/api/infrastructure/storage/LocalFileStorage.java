package com.example.api.infrastructure.storage;

import com.example.api.domain.port.FileStorage;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.StandardCopyOption;

/**
 * Adaptador de storage: guarda los archivos en una carpeta local del servidor.
 * La carpeta se configura con app.upload-dir (en Docker es un volumen).
 * Es el adaptador por defecto (app.storage=local); en AWS se usa S3FileStorage.
 */
@Component
@ConditionalOnProperty(name = "app.storage", havingValue = "local", matchIfMissing = true)
public class LocalFileStorage implements FileStorage {

    private final Path root;

    public LocalFileStorage(@Value("${app.upload-dir}") String uploadDir) throws IOException {
        this.root = Path.of(uploadDir).toAbsolutePath().normalize();
        Files.createDirectories(root);
    }

    @Override
    public void save(String storedName, InputStream content) {
        try {
            Files.copy(content, root.resolve(storedName), StandardCopyOption.REPLACE_EXISTING);
        } catch (IOException e) {
            throw new UncheckedIOException("No se pudo guardar el archivo", e);
        }
    }

    @Override
    public byte[] load(String storedName) {
        try {
            return Files.readAllBytes(root.resolve(storedName));
        } catch (IOException e) {
            throw new UncheckedIOException("No se pudo leer el archivo", e);
        }
    }

    @Override
    public void delete(String storedName) {
        try {
            Files.deleteIfExists(root.resolve(storedName));
        } catch (IOException e) {
            throw new UncheckedIOException("No se pudo eliminar el archivo", e);
        }
    }
}
