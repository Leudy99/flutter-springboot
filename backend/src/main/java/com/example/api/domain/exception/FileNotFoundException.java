package com.example.api.domain.exception;

/**
 * Se lanza cuando se pide un archivo que no existe o que no es del usuario.
 * (Para otro usuario se responde igual que si no existiera: no se revela nada.)
 * El manejador global la traduce a HTTP 404.
 */
public class FileNotFoundException extends RuntimeException {

    public FileNotFoundException(String storedName) {
        super("Archivo no encontrado: " + storedName);
    }

    public FileNotFoundException(Long id) {
        super("Archivo no encontrado con id: " + id);
    }
}
