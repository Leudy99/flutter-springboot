package com.example.api.infrastructure.lambda;

import com.amazonaws.serverless.exceptions.ContainerInitializationException;
import com.amazonaws.serverless.proxy.model.AwsProxyResponse;
import com.amazonaws.serverless.proxy.model.HttpApiV2ProxyRequest;
import com.amazonaws.serverless.proxy.spring.SpringBootLambdaContainerHandler;
import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestStreamHandler;
import com.example.api.ApiSpringbootApplication;

import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;

/**
 * Punto de entrada en AWS Lambda (adaptador de entrada, como los controllers).
 *
 * API Gateway envia cada peticion HTTP como un evento JSON. Este handler
 * se lo pasa a Spring Boot como si fuera una peticion HTTP normal, asi que
 * los controllers, la seguridad JWT y los servicios funcionan sin cambios.
 *
 * En local se sigue arrancando con ApiSpringbootApplication (Tomcat).
 */
public class StreamLambdaHandler implements RequestStreamHandler {

    // Spring arranca una sola vez, al crear la Lambda (arranque en frio),
    // y se reutiliza en las siguientes peticiones.
    private static final SpringBootLambdaContainerHandler<HttpApiV2ProxyRequest, AwsProxyResponse> HANDLER;

    static {
        try {
            // HTTP API de API Gateway usa el formato de evento 2.0
            HANDLER = SpringBootLambdaContainerHandler.getHttpApiV2ProxyHandler(ApiSpringbootApplication.class);
        } catch (ContainerInitializationException e) {
            throw new RuntimeException("No se pudo iniciar Spring Boot en Lambda", e);
        }
    }

    @Override
    public void handleRequest(InputStream input, OutputStream output, Context context) throws IOException {
        HANDLER.proxyStream(input, output, context);
    }
}
