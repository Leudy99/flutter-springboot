package com.example.api.algorithmrace.controller;

import com.example.api.algorithmrace.dto.AlgorithmRaceRequest;
import com.example.api.algorithmrace.dto.AlgorithmRaceResponse;
import com.example.api.algorithmrace.service.AlgorithmRaceService;
import com.example.api.algorithmrace.service.InvalidRaceRequestException;
import jakarta.validation.Valid;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.Map;

/** POST /api/algorithm-race/run : ejecuta la carrera (requiere JWT, como el resto). */
@RestController
@RequestMapping("/api/algorithm-race")
public class AlgorithmRaceController {

    private final AlgorithmRaceService service;

    public AlgorithmRaceController(AlgorithmRaceService service) {
        this.service = service;
    }

    @PostMapping("/run")
    public AlgorithmRaceResponse run(@Valid @RequestBody AlgorithmRaceRequest request) {
        return service.run(request);
    }

    /** Error propio del modulo, con el mismo formato JSON que GlobalExceptionHandler. */
    @ExceptionHandler(InvalidRaceRequestException.class)
    public ResponseEntity<Map<String, Object>> handleInvalid(InvalidRaceRequestException ex) {
        Map<String, Object> body = new LinkedHashMap<>();
        body.put("timestamp", LocalDateTime.now().toString());
        body.put("status", HttpStatus.BAD_REQUEST.value());
        body.put("error", HttpStatus.BAD_REQUEST.getReasonPhrase());
        body.put("message", ex.getMessage());
        return ResponseEntity.badRequest().body(body);
    }
}
