package com.example.api.domain.model;

/**
 * Modelo de dominio de una notificacion por correo.
 * Java puro: no sabe que se publicara en SNS ni que se enviara con SES.
 */
public class Notification {

    private final String email;   // destinatario
    private final String subject; // asunto
    private final String message; // cuerpo

    public Notification(String email, String subject, String message) {
        this.email = email;
        this.subject = subject;
        this.message = message;
    }

    public String getEmail() {
        return email;
    }

    public String getSubject() {
        return subject;
    }

    public String getMessage() {
        return message;
    }
}
