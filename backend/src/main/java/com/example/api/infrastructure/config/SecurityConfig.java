package com.example.api.infrastructure.config;

import com.example.api.infrastructure.security.JwtAuthenticationFilter;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.security.config.annotation.web.configuration.EnableWebSecurity;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.web.cors.CorsConfiguration;
import org.springframework.web.cors.CorsConfigurationSource;
import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

import java.util.List;

/**
 * Configuracion de seguridad definitiva.
 *
 * Reglas:
 * - /auth/** es publico (registrarse e iniciar sesion)
 * - todo lo demas exige un JWT valido en la cabecera Authorization
 * - sin sesiones: cada peticion se valida sola con su token (STATELESS)
 */
@Configuration
@EnableWebSecurity
public class SecurityConfig {

    private final JwtAuthenticationFilter jwtAuthenticationFilter;

    public SecurityConfig(JwtAuthenticationFilter jwtAuthenticationFilter) {
        this.jwtAuthenticationFilter = jwtAuthenticationFilter;
    }

    @Bean
    public SecurityFilterChain securityFilterChain(HttpSecurity http) throws Exception {
        http
                // CSRF se desactiva porque es una API REST sin sesiones ni formularios
                .csrf(csrf -> csrf.disable())

                // CORS: necesario solo si la app Flutter corre en el navegador (Flutter Web).
                // En Android/iOS no aplica.
                .cors(cors -> cors.configurationSource(corsConfigurationSource()))

                // Sin sesion de servidor: el token viaja en cada peticion
                .sessionManagement(session ->
                        session.sessionCreationPolicy(SessionCreationPolicy.STATELESS))

                .authorizeHttpRequests(auth -> auth
                        // /error es la ruta interna a la que Spring reenvia los errores.
                        // Sin abrirla, un 400 o un 404 saldrian como 401.
                        .requestMatchers("/auth/**", "/error").permitAll()
                        .anyRequest().authenticated())

                // Sin token valido -> 401 Unauthorized (en vez del 403 por defecto)
                .exceptionHandling(ex -> ex.authenticationEntryPoint(
                        (request, response, authException) ->
                                response.sendError(HttpServletResponse.SC_UNAUTHORIZED,
                                        "Token ausente o invalido")))

                // Nuestro filtro corre antes del de usuario/contrasena de Spring
                .addFilterBefore(jwtAuthenticationFilter,
                        UsernamePasswordAuthenticationFilter.class);

        return http.build();
    }

    /** Permite peticiones desde cualquier origen (proyecto academico, sin cookies). */
    @Bean
    public CorsConfigurationSource corsConfigurationSource() {
        CorsConfiguration config = new CorsConfiguration();
        config.setAllowedOriginPatterns(List.of("*"));
        config.setAllowedMethods(List.of("GET", "POST", "PUT", "DELETE", "OPTIONS"));
        config.setAllowedHeaders(List.of("*"));

        UrlBasedCorsConfigurationSource source = new UrlBasedCorsConfigurationSource();
        source.registerCorsConfiguration("/**", config);
        return source;
    }
}
