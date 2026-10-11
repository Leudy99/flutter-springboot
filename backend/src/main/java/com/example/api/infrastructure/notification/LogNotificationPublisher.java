package com.example.api.infrastructure.notification;

import com.example.api.domain.model.Notification;
import com.example.api.domain.port.NotificationPublisher;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;

/**
 * Adaptador para desarrollo local (Docker / sin AWS): no publica nada,
 * solo deja el mensaje en el log. Es el adaptador por defecto (app.notifications=log).
 */
@Component
@ConditionalOnProperty(name = "app.notifications", havingValue = "log", matchIfMissing = true)
public class LogNotificationPublisher implements NotificationPublisher {

    private static final Logger log = LoggerFactory.getLogger(LogNotificationPublisher.class);

    @Override
    public void publish(Notification notification) {
        log.info("[modo local] Notificacion no publicada en SNS. destinatario={} asunto={}",
                notification.getEmail(), notification.getSubject());
    }
}
