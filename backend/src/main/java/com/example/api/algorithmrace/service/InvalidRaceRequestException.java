package com.example.api.algorithmrace.service;

/** Peticion de la carrera con datos no permitidos (se traduce a HTTP 400). */
public class InvalidRaceRequestException extends RuntimeException {

    public InvalidRaceRequestException(String message) {
        super(message);
    }
}
