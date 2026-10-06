package com.example.api.application;

import com.example.api.domain.exception.FileNotFoundException;
import com.example.api.domain.exception.InvalidFileException;
import com.example.api.domain.model.StoredFile;
import com.example.api.domain.model.User;
import com.example.api.domain.port.FileStorage;
import com.example.api.domain.port.StoredFileRepository;
import com.example.api.domain.port.UserRepository;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Prueba del caso de uso FileService sin Spring, sin base de datos y sin S3.
 * Gracias a la arquitectura hexagonal, basta con implementar los puertos en memoria.
 */
class FileServiceTest {

    /** Storage falso: guarda los bytes en un mapa (en produccion es disco o S3). */
    static class InMemoryStorage implements FileStorage {
        final Map<String, byte[]> files = new HashMap<>();

        @Override
        public void save(String storedName, InputStream content) {
            try {
                files.put(storedName, content.readAllBytes());
            } catch (IOException e) {
                throw new UncheckedIOException(e);
            }
        }

        @Override
        public byte[] load(String storedName) {
            return files.get(storedName);
        }

        @Override
        public void delete(String storedName) {
            files.remove(storedName);
        }
    }

    /** Tabla files falsa (en produccion es PostgreSQL). */
    static class InMemoryFileRepository implements StoredFileRepository {
        final List<StoredFile> rows = new ArrayList<>();

        @Override
        public StoredFile save(StoredFile f) {
            StoredFile saved = new StoredFile((long) rows.size() + 1, f.getOwnerId(), f.getOriginalName(),
                    f.getStoredName(), f.getContentType(), f.getSize(), f.getUploadedAt());
            rows.add(saved);
            return saved;
        }

        @Override
        public List<StoredFile> findByOwnerId(Long ownerId) {
            return rows.stream().filter(r -> r.isOwnedBy(ownerId)).toList();
        }

        @Override
        public Optional<StoredFile> findById(Long id) {
            return rows.stream().filter(r -> r.getId().equals(id)).findFirst();
        }

        @Override
        public Optional<StoredFile> findByStoredName(String storedName) {
            return rows.stream().filter(r -> r.getStoredName().equals(storedName)).findFirst();
        }

        @Override
        public void deleteById(Long id) {
            rows.removeIf(r -> r.getId().equals(id));
        }
    }

    /** Tabla users falsa con dos usuarios: Ana (id 1) y Luis (id 2). */
    static class InMemoryUserRepository implements UserRepository {
        final List<User> users = List.of(
                new User(1L, "Ana", "ana@test.com", "hash"),
                new User(2L, "Luis", "luis@test.com", "hash"));

        @Override
        public Optional<User> findByEmail(String email) {
            return users.stream().filter(u -> u.getEmail().equals(email)).findFirst();
        }

        @Override
        public Optional<User> findById(Long id) {
            return users.stream().filter(u -> u.getId().equals(id)).findFirst();
        }

        @Override
        public boolean existsByEmail(String email) {
            return findByEmail(email).isPresent();
        }

        @Override
        public List<User> findAll() {
            return users;
        }

        @Override
        public User save(User user) {
            throw new UnsupportedOperationException();
        }

        @Override
        public void deleteById(Long id) {
            throw new UnsupportedOperationException();
        }
    }

    private final InMemoryStorage storage = new InMemoryStorage();
    private final InMemoryFileRepository files = new InMemoryFileRepository();
    private final FileService service = new FileService(storage, files, new InMemoryUserRepository());

    private StoredFile upload(String name, String type, String ownerEmail) {
        byte[] bytes = {1, 2, 3};
        return service.upload(name, type, bytes.length, new ByteArrayInputStream(bytes), ownerEmail);
    }

    @Test
    void subeUnArchivoLigadoAsuDueno() {
        StoredFile saved = upload("foto.PNG", "image/png", "ana@test.com");

        assertEquals(1L, saved.getOwnerId());
        assertTrue(saved.getStoredName().endsWith(".png"));
        assertArrayEquals(new byte[]{1, 2, 3}, service.load(saved));
    }

    @Test
    void cadaUsuarioSoloVeSusArchivos() {
        upload("a.png", "image/png", "ana@test.com");
        upload("b.pdf", "application/pdf", "ana@test.com");
        upload("c.txt", "text/plain", "luis@test.com");

        assertEquals(2, service.findMine("ana@test.com").size());
        assertEquals(1, service.findMine("luis@test.com").size());
    }

    @Test
    void unUsuarioNoPuedeVerNiBorrarArchivosDeOtro() {
        StoredFile deAna = upload("a.png", "image/png", "ana@test.com");

        assertThrows(FileNotFoundException.class,
                () -> service.findMine(deAna.getStoredName(), "luis@test.com"));
        assertThrows(FileNotFoundException.class,
                () -> service.delete(deAna.getId(), "luis@test.com"));
        assertEquals(1, files.rows.size());
    }

    @Test
    void eliminaElArchivoDelStorageYDeLaBaseDeDatos() {
        StoredFile saved = upload("a.png", "image/png", "ana@test.com");

        service.delete(saved.getId(), "ana@test.com");

        assertTrue(files.rows.isEmpty());
        assertTrue(storage.files.isEmpty());
    }

    @Test
    void rechazaTiposNoPermitidos() {
        assertThrows(InvalidFileException.class,
                () -> upload("virus.exe", "application/x-msdownload", "ana@test.com"));
        assertTrue(storage.files.isEmpty());
    }

    @Test
    void rechazaArchivosVacios() {
        assertThrows(InvalidFileException.class, () -> service.upload("vacio.txt",
                "text/plain", 0, new ByteArrayInputStream(new byte[0]), "ana@test.com"));
    }
}
