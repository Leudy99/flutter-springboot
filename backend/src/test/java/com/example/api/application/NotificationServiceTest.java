package com.example.api.application;

import com.example.api.domain.exception.NotificationPublishException;
import com.example.api.domain.model.Notification;
import com.example.api.domain.port.NotificationPublisher;
import org.junit.jupiter.api.Test;

import java.util.ArrayList;
import java.util.List;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;

/**
 * Prueba del caso de uso NotificationService sin Spring y sin AWS:
 * basta con implementar el puerto NotificationPublisher en memoria.
 */
class NotificationServiceTest {

    /** Publicador falso: guarda las notificaciones en una lista (en AWS es SNS). */
    static class InMemoryPublisher implements NotificationPublisher {
        final List<Notification> published = new ArrayList<>();

        @Override
        public void publish(Notification notification) {
            published.add(notification);
        }
    }

    @Test
    void publicaLaNotificacionSinEspaciosSobrantes() {
        InMemoryPublisher publisher = new InMemoryPublisher();
        NotificationService service = new NotificationService(publisher);

        service.send("  ana@test.com ", " Prueba SNS ", " Hola desde AWS Serverless ");

        assertEquals(1, publisher.published.size());
        Notification n = publisher.published.get(0);
        assertEquals("ana@test.com", n.getEmail());
        assertEquals("Prueba SNS", n.getSubject());
        assertEquals("Hola desde AWS Serverless", n.getMessage());
    }

    @Test
    void siFallaLaPublicacionElErrorLlegaAlLlamador() {
        NotificationPublisher failing = notification -> {
            throw new NotificationPublishException("SNS caido", new RuntimeException());
        };
        NotificationService service = new NotificationService(failing);

        assertThrows(NotificationPublishException.class,
                () -> service.send("ana@test.com", "Asunto", "Mensaje"));
    }
}
