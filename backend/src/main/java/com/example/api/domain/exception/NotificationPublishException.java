package com.example.api.domain.exception;

/**
 * Se lanza cuando no se pudo publicar la notificacion (por ejemplo, SNS no responde).
 * El manejador global la traduce a HTTP 503.
 */
public class NotificationPublishException extends RuntimeException {

    public NotificationPublishException(String message, Throwable cause) {
        super(message, cause);
    }
}
