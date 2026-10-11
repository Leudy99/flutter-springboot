package com.example.api.application;

import com.example.api.domain.model.Notification;
import com.example.api.domain.port.NotificationPublisher;
import org.springframework.stereotype.Service;

/**
 * Caso de uso: enviar una notificacion por correo.
 *
 * Solo PUBLICA el mensaje (en SNS) y termina. El correo lo envia despues,
 * de forma asincrona, la cadena SNS -> SQS -> notification-lambda.
 * Depende unicamente de un puerto del dominio (NotificationPublisher).
 */
@Service
public class NotificationService {

    private final NotificationPublisher publisher;

    public NotificationService(NotificationPublisher publisher) {
        this.publisher = publisher;
    }

    public void send(String email, String subject, String message) {
        publisher.publish(new Notification(email.trim(), subject.trim(), message.trim()));
    }
}
