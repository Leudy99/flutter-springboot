package com.example.api.infrastructure.websocket;

import com.fasterxml.jackson.annotation.JsonIgnoreProperties;

/**
 * Mensaje del chat. Es el mismo JSON en los dos sentidos:
 *
 * - Cliente -> servidor: {"type":"CONNECT","username":"Leudy"}
 *                        {"type":"MESSAGE","message":"Hola"}
 * - Servidor -> clientes: los cuatro campos, con la fecha puesta por el servidor.
 *
 * type: CONNECT (alguien entro), MESSAGE (mensaje normal), DISCONNECT (alguien salio)
 * timestamp: fecha y hora con zona, en formato ISO-8601 (2026-11-16T22:30:00-04:00)
 */
@JsonIgnoreProperties(ignoreUnknown = true)
public record ChatMessage(String type, String username, String message, String timestamp) {
}
