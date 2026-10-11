package com.example.api.infrastructure.notification;

import com.example.api.domain.exception.NotificationPublishException;
import com.example.api.domain.model.Notification;
import com.example.api.domain.port.NotificationPublisher;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.PublishRequest;
import software.amazon.awssdk.services.sns.model.PublishResponse;

import java.util.LinkedHashMap;
import java.util.Map;

/**
 * Adaptador de notificaciones para AWS: publica el mensaje en un SNS Topic.
 *
 * Implementa el puerto NotificationPublisher, por eso NotificationService no cambia.
 * Se activa con app.notifications=sns (en Lambda lo pone Terraform junto con SNS_TOPIC_ARN).
 *
 * Credenciales y region: el SDK las toma del rol IAM de la Lambda
 * y de la variable AWS_REGION, que Lambda define automaticamente.
 */
@Component
@ConditionalOnProperty(name = "app.notifications", havingValue = "sns")
public class SnsNotificationPublisher implements NotificationPublisher {

    private static final Logger log = LoggerFactory.getLogger(SnsNotificationPublisher.class);

    private final SnsClient sns;
    private final ObjectMapper objectMapper;
    private final String topicArn;

    public SnsNotificationPublisher(@Value("${app.sns-topic-arn}") String topicArn,
                                    ObjectMapper objectMapper) {
        this.topicArn = topicArn;
        this.objectMapper = objectMapper;
        this.sns = SnsClient.builder()
                .httpClient(UrlConnectionHttpClient.create())
                .build();
    }

    @Override
    public void publish(Notification notification) {
        try {
            PublishResponse response = sns.publish(PublishRequest.builder()
                    .topicArn(topicArn)
                    .message(toJson(notification, objectMapper))
                    .build());
            log.info("Notificacion publicada en SNS. messageId={} destinatario={}",
                    response.messageId(), notification.getEmail());
        } catch (RuntimeException e) {
            throw new NotificationPublishException("No se pudo publicar la notificacion en SNS", e);
        }
    }

    /**
     * Cuerpo del mensaje: {"email": "...", "subject": "...", "message": "..."}.
     * Es lo que lee notification-lambda al recibirlo desde SQS.
     */
    static String toJson(Notification notification, ObjectMapper objectMapper) {
        Map<String, String> body = new LinkedHashMap<>();
        body.put("email", notification.getEmail());
        body.put("subject", notification.getSubject());
        body.put("message", notification.getMessage());
        try {
            return objectMapper.writeValueAsString(body);
        } catch (JsonProcessingException e) {
            throw new IllegalStateException("No se pudo serializar la notificacion", e);
        }
    }
}
