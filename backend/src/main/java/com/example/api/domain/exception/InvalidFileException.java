package com.example.api.domain.exception;

/**
 * Se lanza cuando el archivo esta vacio o su tipo no esta permitido.
 * El manejador global la traduce a HTTP 400.
 */
public class InvalidFileException extends RuntimeException {

    public InvalidFileException(String message) {
        super(message);
    }
}
