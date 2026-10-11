package com.example.api.infrastructure.web.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;

/** Datos que entran en POST /notifications/send. */
public record NotificationRequest(

        @NotBlank(message = "El correo es obligatorio")
        @Email(message = "El correo no tiene un formato valido")
        @Size(max = 150, message = "El correo no puede pasar de 150 caracteres")
        String email,

        @NotBlank(message = "El asunto es obligatorio")
        @Size(max = 200, message = "El asunto no puede pasar de 200 caracteres")
        String subject,

        @NotBlank(message = "El mensaje es obligatorio")
        @Size(max = 2000, message = "El mensaje no puede pasar de 2000 caracteres")
        String message
) {
}
