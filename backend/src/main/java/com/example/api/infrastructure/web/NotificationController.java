package com.example.api.infrastructure.web;

import com.example.api.application.NotificationService;
import com.example.api.infrastructure.web.dto.NotificationRequest;
import jakarta.validation.Valid;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Adaptador de entrada HTTP para notificaciones.
 * Requiere JWT (como todo lo que no sea /auth/**).
 *
 * Responde en cuanto el mensaje fue ACEPTADO por SNS; el correo se envia despues,
 * de forma asincrona (SNS -> SQS -> notification-lambda).
 */
@RestController
@RequestMapping("/notifications")
public class NotificationController {

    private final NotificationService notificationService;

    public NotificationController(NotificationService notificationService) {
        this.notificationService = notificationService;
    }

    @PostMapping("/send")
    public Map<String, String> send(@Valid @RequestBody NotificationRequest request) {
        notificationService.send(request.email(), request.subject(), request.message());
        return Map.of("message", "Mensaje enviado correctamente");
    }
}
