package com.example.api.infrastructure.storage;

import com.example.api.domain.port.FileStorage;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.stereotype.Component;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.http.urlconnection.UrlConnectionHttpClient;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.DeleteObjectRequest;
import software.amazon.awssdk.services.s3.model.GetObjectRequest;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.io.IOException;
import java.io.InputStream;
import java.io.UncheckedIOException;

/**
 * Adaptador de storage para AWS: guarda los archivos en un bucket S3 privado.
 *
 * Implementa el mismo puerto que LocalFileStorage, por eso FileService no cambia.
 * Se activa con app.storage=s3 (en Lambda lo pone Terraform).
 *
 * Credenciales y region: el SDK las toma solo del rol IAM de la Lambda
 * y de la variable AWS_REGION, que Lambda define automaticamente.
 */
@Component
@ConditionalOnProperty(name = "app.storage", havingValue = "s3")
public class S3FileStorage implements FileStorage {

    /** Carpeta dentro del bucket donde quedan los archivos. */
    private static final String PREFIX = "uploads/";

    private final S3Client s3;
    private final String bucket;

    public S3FileStorage(@Value("${app.s3-bucket}") String bucket) {
        this.bucket = bucket;
        this.s3 = S3Client.builder()
                .httpClient(UrlConnectionHttpClient.create())
                .build();
    }

    @Override
    public void save(String storedName, InputStream content) {
        try {
            // Los archivos son pequenos (max. 4 MB), se pueden leer completos
            byte[] bytes = content.readAllBytes();
            s3.putObject(
                    PutObjectRequest.builder().bucket(bucket).key(PREFIX + storedName).build(),
                    RequestBody.fromBytes(bytes));
        } catch (IOException e) {
            throw new UncheckedIOException("No se pudo leer el archivo", e);
        }
    }

    @Override
    public void delete(String storedName) {
        s3.deleteObject(DeleteObjectRequest.builder().bucket(bucket).key(PREFIX + storedName).build());
    }

    @Override
    public byte[] load(String storedName) {
        return s3.getObjectAsBytes(
                GetObjectRequest.builder().bucket(bucket).key(PREFIX + storedName).build()
        ).asByteArray();
    }
}
