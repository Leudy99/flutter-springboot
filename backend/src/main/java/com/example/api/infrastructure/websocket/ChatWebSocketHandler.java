package com.example.api.infrastructure.websocket;

import com.fasterxml.jackson.databind.ObjectMapper;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import org.springframework.web.socket.CloseStatus;
import org.springframework.web.socket.TextMessage;
import org.springframework.web.socket.WebSocketSession;
import org.springframework.web.socket.handler.ConcurrentWebSocketSessionDecorator;
import org.springframework.web.socket.handler.TextWebSocketHandler;

import java.io.IOException;
import java.time.OffsetDateTime;
import java.time.temporal.ChronoUnit;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;

/**
 * Servidor del chat. Mantiene abiertas las sesiones de todos los clientes y
 * reenvia cada mensaje a todos (broadcast).
 *
 * Flujo:
 *  1. El cliente abre la conexion y envia {"type":"CONNECT","username":"Leudy"}.
 *  2. El servidor avisa a todos: "Leudy se ha conectado."
 *  3. Cada {"type":"MESSAGE","message":"..."} se reenvia a todos con la hora del servidor.
 *  4. Al cerrarse la conexion el servidor avisa: "Leudy se ha desconectado."
 *
 * Todo vive en memoria: no hay base de datos ni historial.
 */
@Component
@ConditionalOnProperty(name = "app.websocket.enabled", havingValue = "true", matchIfMissing = true)
public class ChatWebSocketHandler extends TextWebSocketHandler {

    private static final Logger log = LoggerFactory.getLogger(ChatWebSocketHandler.class);

    private static final int MAX_USERNAME = 30;
    private static final int MAX_MESSAGE = 500;
    // Si un cliente no recibe en 10 s, o se acumulan 512 KB sin enviar, se cierra su sesion
    private static final int SEND_TIME_LIMIT_MS = 10_000;
    private static final int BUFFER_SIZE_LIMIT = 512 * 1024;

    private final ObjectMapper mapper;

    /** Sesiones abiertas, por id de sesion. */
    private final Map<String, WebSocketSession> sessions = new ConcurrentHashMap<>();
    /** Nombre que eligio cada sesion (solo existe tras enviar CONNECT). */
    private final Map<String, String> usernames = new ConcurrentHashMap<>();

    public ChatWebSocketHandler(ObjectMapper mapper) {
        this.mapper = mapper;
    }

    @Override
    public void afterConnectionEstablished(WebSocketSession session) {
        // Varios hilos no pueden escribir a la vez en una misma sesion: el decorador los ordena
        sessions.put(session.getId(), new ConcurrentWebSocketSessionDecorator(
                session, SEND_TIME_LIMIT_MS, BUFFER_SIZE_LIMIT));
        log.info("WebSocket abierto: {} (conectados: {})", session.getId(), sessions.size());
    }

    @Override
    protected void handleTextMessage(WebSocketSession session, TextMessage text) throws IOException {
        ChatMessage in;
        try {
            in = mapper.readValue(text.getPayload(), ChatMessage.class);
        } catch (IOException e) {
            log.warn("Mensaje con JSON invalido de {}", session.getId());
            return;
        }
        if (in.type() == null) return;

        switch (in.type()) {
            case "CONNECT" -> register(session, in.username());
            case "MESSAGE" -> forward(session, in.message());
            default -> log.warn("Tipo de mensaje desconocido: {}", in.type());
        }
    }

    @Override
    public void afterConnectionClosed(WebSocketSession session, CloseStatus status) {
        sessions.remove(session.getId());
        String name = usernames.remove(session.getId());
        log.info("WebSocket cerrado: {} (conectados: {})", session.getId(), sessions.size());
        if (name != null) {
            broadcast(build("DISCONNECT", name, name + " se ha desconectado."));
        }
    }

    @Override
    public void handleTransportError(WebSocketSession session, Throwable error) {
        log.warn("Error de transporte en {}: {}", session.getId(), error.getMessage());
    }

    private void register(WebSocketSession session, String requested) {
        // Un cliente solo se registra una vez por conexion
        if (usernames.containsKey(session.getId())) return;
        String name = clean(requested, MAX_USERNAME);
        if (name.isEmpty()) name = "Anonimo";
        usernames.put(session.getId(), name);
        broadcast(build("CONNECT", name, name + " se ha conectado."));
    }

    private void forward(WebSocketSession session, String text) {
        String name = usernames.get(session.getId());
        String body = clean(text, MAX_MESSAGE);
        // Sin CONNECT previo o con el mensaje vacio no se reenvia nada
        if (name == null || body.isEmpty()) return;
        broadcast(build("MESSAGE", name, body));
    }

    /** Envia el mensaje a todas las sesiones abiertas. */
    private void broadcast(ChatMessage message) {
        final String json;
        try {
            json = mapper.writeValueAsString(message);
        } catch (IOException e) {
            log.error("No se pudo convertir el mensaje a JSON", e);
            return;
        }
        TextMessage frame = new TextMessage(json);
        for (WebSocketSession target : sessions.values()) {
            try {
                if (target.isOpen()) target.sendMessage(frame);
            } catch (IOException | RuntimeException e) {
                log.warn("No se pudo enviar a {}: {}", target.getId(), e.getMessage());
            }
        }
        log.info("Broadcast {} a {} clientes", message.type(), sessions.size());
    }

    private ChatMessage build(String type, String username, String message) {
        // La hora la pone el servidor: todos los clientes ven la misma
        String now = OffsetDateTime.now().truncatedTo(ChronoUnit.SECONDS).toString();
        return new ChatMessage(type, username, message, now);
    }

    private String clean(String value, int maxLength) {
        if (value == null) return "";
        String trimmed = value.trim();
        return trimmed.length() > maxLength ? trimmed.substring(0, maxLength) : trimmed;
    }
}
