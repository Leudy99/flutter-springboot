package com.example.api.infrastructure.websocket;

import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Configuration;
import org.springframework.web.socket.config.annotation.EnableWebSocket;
import org.springframework.web.socket.config.annotation.WebSocketConfigurer;
import org.springframework.web.socket.config.annotation.WebSocketHandlerRegistry;

/**
 * Registra el endpoint WebSocket del chat: ws://HOST:PUERTO/ws/chat
 *
 * Se desactiva con app.websocket.enabled=false. Se usa en AWS Lambda, donde las
 * conexiones WebSocket no existen (Lambda atiende una peticion HTTP y termina).
 */
@Configuration
@EnableWebSocket
@ConditionalOnProperty(name = "app.websocket.enabled", havingValue = "true", matchIfMissing = true)
public class WebSocketConfig implements WebSocketConfigurer {

    public static final String CHAT_PATH = "/ws/chat";

    private final ChatWebSocketHandler chatHandler;

    public WebSocketConfig(ChatWebSocketHandler chatHandler) {
        this.chatHandler = chatHandler;
    }

    @Override
    public void registerWebSocketHandlers(WebSocketHandlerRegistry registry) {
        registry.addHandler(chatHandler, CHAT_PATH)
                // Proyecto academico: acepta conexiones desde cualquier origen
                // (Flutter Web en localhost:30080 se conecta al puerto 30081)
                .setAllowedOriginPatterns("*");
    }
}
