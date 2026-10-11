package com.example.api.infrastructure.notification;

import com.example.api.domain.model.Notification;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;

/**
 * Prueba del contrato entre el backend y notification-lambda (Python):
 * el mensaje que se publica en SNS tiene exactamente email, subject y message.
 */
class SnsNotificationPublisherTest {

    @Test
    void elJsonPublicadoTieneLosTresCamposQueLeeNotificationLambda() throws Exception {
        ObjectMapper mapper = new ObjectMapper();

        String json = SnsNotificationPublisher.toJson(
                new Notification("ana@test.com", "Con \"comillas\"", "Linea 1\nLinea 2"), mapper);

        JsonNode tree = mapper.readTree(json);
        assertEquals(3, tree.size());
        assertEquals("ana@test.com", tree.get("email").asText());
        assertEquals("Con \"comillas\"", tree.get("subject").asText());
        assertEquals("Linea 1\nLinea 2", tree.get("message").asText());
    }
}
