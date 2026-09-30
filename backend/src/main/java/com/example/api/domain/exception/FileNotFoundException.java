package com.example.api.domain.exception;

/**
 * Se lanza cuando se pide un archivo que no existe.
 * El manejador global la traduce a HTTP 404.
 */
public class FileNotFoundException extends RuntimeException {

    public FileNotFoundException(String storedName) {
        super("Archivo no encontrado: " + storedName);
    }
}
