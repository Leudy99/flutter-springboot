package com.example.api.application;

import com.example.api.domain.exception.EmailAlreadyExistsException;
import com.example.api.domain.exception.UserNotFoundException;
import com.example.api.domain.model.User;
import com.example.api.domain.port.PasswordHasher;
import com.example.api.domain.port.UserRepository;
import org.springframework.stereotype.Service;

import java.util.List;

/**
 * Casos de uso del CRUD de usuarios.
 * Solo depende de los puertos del dominio (UserRepository, PasswordHasher),
 * nunca de JPA ni de HTTP. Aqui vive la logica de negocio.
 */
@Service
public class UserService {

    private final UserRepository userRepository;
    private final PasswordHasher passwordHasher;
    private final FileService fileService;

    public UserService(UserRepository userRepository, PasswordHasher passwordHasher,
                       FileService fileService) {
        this.userRepository = userRepository;
        this.passwordHasher = passwordHasher;
        this.fileService = fileService;
    }

    /**
     * Email normalizado: sin espacios y en minusculas.
     * Asi "Ana@Test.com" y "ana@test.com" son el mismo usuario.
     */
    public static String normalizeEmail(String email) {
        return email == null ? null : email.trim().toLowerCase();
    }

    /** Crear usuario: valida email unico y cifra la contrasena antes de guardar. */
    public User create(String name, String email, String rawPassword) {
        email = normalizeEmail(email);
        if (userRepository.existsByEmail(email)) {
            throw new EmailAlreadyExistsException(email);
        }
        User user = new User(null, name.trim(), email, passwordHasher.hash(rawPassword));
        return userRepository.save(user);
    }

    /** Listar todos los usuarios. */
    public List<User> findAll() {
        return userRepository.findAll();
    }

    /** Buscar por id o fallar con 404. */
    public User findById(Long id) {
        return userRepository.findById(id)
                .orElseThrow(() -> new UserNotFoundException(id));
    }

    /** Buscar por email o fallar con 404. Se usa para el perfil del usuario autenticado. */
    public User findByEmail(String email) {
        return userRepository.findByEmail(normalizeEmail(email))
                .orElseThrow(() -> new UserNotFoundException(email));
    }

    /**
     * Actualizar usuario.
     * La contrasena es opcional: si llega vacia o nula, se conserva la actual.
     */
    public User update(Long id, String name, String email, String rawPassword) {
        User existing = findById(id);
        email = normalizeEmail(email);

        // Si cambia el email, verificar que no lo tenga otro usuario
        if (!existing.getEmail().equals(email) && userRepository.existsByEmail(email)) {
            throw new EmailAlreadyExistsException(email);
        }

        existing.setName(name.trim());
        existing.setEmail(email);
        if (rawPassword != null && !rawPassword.isBlank()) {
            existing.setPassword(passwordHasher.hash(rawPassword));
        }

        return userRepository.save(existing);
    }

    /**
     * Eliminar usuario: falla con 404 si no existe.
     * Primero borra el contenido de sus archivos del storage; las filas de la
     * tabla files las borra la base de datos (ON DELETE CASCADE).
     */
    public void delete(Long id) {
        User existing = findById(id);
        fileService.deleteContentOf(existing.getId());
        userRepository.deleteById(existing.getId());
    }
}
