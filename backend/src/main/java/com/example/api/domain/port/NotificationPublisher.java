package com.example.api.domain.port;

import com.example.api.domain.model.Notification;

/**
 * Puerto de salida para publicar notificaciones.
 * El dominio dice "publica esta notificacion", pero no sabe que es AWS SNS.
 * El backend NO envia el correo: solo publica el mensaje; otro componente
 * (SQS + notification-lambda) lo envia de forma desacoplada.
 * La implementacion vive en infrastructure/notification.
 */
public interface NotificationPublisher {

    void publish(Notification notification);
}
