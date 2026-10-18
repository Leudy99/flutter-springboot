# Flutter App + API Serverless en AWS

App Flutter que consume una API Spring Boot desplegada en AWS de forma **serverless**: API Gateway, Lambda, PostgreSQL en Neon y S3.
La infraestructura se crea con **Terraform** y se despliega sola con **GitHub Actions** en cada push a `main`.

La app permite: iniciar sesión (JWT), gestionar usuarios (CRUD), subir, ver y eliminar sus archivos, enviar notificaciones por correo y comparar peticiones en paralelo con `Future.wait()`.

```text
App Flutter ──HTTPS + JWT──> API Gateway ──> AWS Lambda (Spring Boot) ──> PostgreSQL (Neon)
                                                       ├──────────────> S3 (archivos)
                                                       └─ SNS ─> SQS ─> notification-lambda ─> correo (SES)

git push main ──> GitHub Actions ──> pruebas + zip ──> Terraform ──> AWS actualizado
```

La app nunca accede a la base de datos directamente: todo pasa por la API.

---

## Puesta en marcha

### Opción A: usar el backend en AWS (por defecto)

La API ya está desplegada. Solo hace falta Flutter 3.41 o superior y un emulador de Android Studio:

```bash
cd mobile
flutter pub get
flutter run
```

En VS Code: abre `mobile`, elige el emulador en la barra inferior y pulsa **F5**.
En la pantalla de acceso elige **Crear cuenta** o entra con `admin@test.com` / `123456`.

> La primera petición tras un rato sin uso tarda unos 2 s (Lambda restaura Spring Boot con SnapStart). Las siguientes tardan unos 0,3 s.
>
> Para la demo, ejecuta la app en modo profile, que es mucho más fluido que el modo debug de F5: `flutter run --profile`.

### Opción B: backend local con Docker

Con Docker Desktop abierto:

```bash
cd backend
docker compose up --build -d
```

| Contenedor | Puerto | Qué es |
| --- | --- | --- |
| `flutterapp-api` | `8081` | API → `http://localhost:8081` |
| `flutterapp-db` | `5434` | PostgreSQL (base `apidb`, usuario `alumno`, clave `123456`) |

Después cambia una línea en `mobile/lib/config.dart` y ejecuta la app:

```dart
static const Backend backend = Backend.local;   // Backend.cloud = AWS
```

`config.dart` es el **único** lugar con las URLs del backend.

---

## Arquitectura

### Backend: hexagonal

```text
Lambda / Controller  →  Service (caso de uso)  →  Puerto (interfaz)  →  Adaptador  →  PostgreSQL / S3
 infrastructure/         application/              domain/port/          infrastructure/
```

- `domain`: modelos, puertos y excepciones. Java puro.
- `application`: casos de uso (`UserService`, `AuthService`, `FileService`).
- `infrastructure`: entrada (controllers y `StreamLambdaHandler`) y salida (JPA, JWT, BCrypt, S3).

El dominio solo conoce interfaces (puertos); la infraestructura las implementa:

| Puerto | Adaptador |
| --- | --- |
| `UserRepository` | `UserRepositoryAdapter` (tabla `users`) |
| `StoredFileRepository` | `StoredFileRepositoryAdapter` (tabla `files`) |
| `PasswordHasher` | `BCryptPasswordHasher` |
| `TokenProvider` | `JwtService` |
| `FileStorage` | `S3FileStorage` en AWS / `LocalFileStorage` en local (se elige con `STORAGE=s3\|local`) |
| `NotificationPublisher` | `SnsNotificationPublisher` en AWS / `LogNotificationPublisher` en local (`NOTIFICATIONS=sns\|log`) |

Para llevar la API a Lambda **no se cambió ningún controller ni servicio**: se añadió `StreamLambdaHandler`, que convierte el evento de API Gateway en una petición HTTP para Spring. Y para usar S3 se añadió `S3FileStorage`, otro adaptador del mismo puerto `FileStorage`.

### App: MVVM

```text
View  →  ViewModel  →  Repository  →  Service  →  API
 ▲           │
 └───────────┘  notifyListeners() redibuja la pantalla
```

| Carpeta | Responsabilidad |
| --- | --- |
| `views/` | Pantallas. Solo dibujan y reenvían acciones. |
| `viewmodels/` | Estado de cada pantalla (cargando, error, datos). |
| `repositories/` | Acceso a datos para los ViewModels. |
| `services/` | Peticiones HTTP (Dio) y guardado del token. |
| `models/` | Datos creados a partir del JSON. |

---

## Cómo funciona

### Autenticación (JWT)

1. **Registro:** la contraseña se guarda cifrada con BCrypt.
2. **Login:** si la contraseña coincide, la API devuelve un token firmado que dura 1 hora.
3. La app guarda el token y lo envía en cada petición: `Authorization: Bearer <token>`.
4. Sin token o con token inválido, la API responde **401** y la app vuelve al login.
5. **Cerrar sesión** borra el token (menú ⋮ del Inicio).

### Usuarios (CRUD)

Pestaña **Usuarios**: listar y buscar (`GET`), crear (`POST`), editar (`PUT`, contraseña opcional) y eliminar (`DELETE`, con confirmación).

### Archivos

- **Subir:** se elige una imagen o documento (JPG, PNG, GIF, WEBP, PDF, TXT, Word, Excel; máx. 4 MB), se ve una vista previa y se envía como `multipart/form-data` a `POST /upload` con barra de progreso.
- **Backend:** valida el tipo, guarda el archivo con un nombre único (en S3 en AWS, en disco en local) y registra sus datos en la tabla `files`, ligado al usuario que lo subió.
- **Ver:** pestaña **Archivos**, galería con filtros. Cada usuario ve **solo sus archivos**. Al tocar uno se abre: imagen con zoom, PDF por páginas o texto. Word y Excel no tienen vista previa.
- **Eliminar:** botón de papelera en el visor. Solo el dueño puede eliminar su archivo; para otro usuario la API responde `404`.

### Notificaciones por correo (SNS → SQS → Lambda)

La pantalla **Enviar notificación** (botón en el Inicio) pide correo destino, asunto y mensaje y llama a `POST /notifications/send`.

```text
Flutter → API Gateway → Lambda principal ─publica→ SNS Topic ─suscripción→ SQS Queue
                                                                              │ Event Source Mapping
                                                                              ▼
                                                  correo ◄── Amazon SES ◄── notification-lambda
```

1. **Backend:** `NotificationController` valida los datos (`@Email`, `@NotBlank`), `NotificationService` y el puerto `NotificationPublisher` publican un JSON `{email, subject, message}` en SNS y responden `200` **sin enviar el correo**. Si SNS falla responde `503`.
2. **SNS → SQS:** la cola guarda el mensaje hasta que alguien lo procese. Si el envío falla, SQS lo reintenta y a los 3 intentos lo manda a una cola de errores (DLQ).
3. **notification-lambda** (`notification-lambda/lambda_function.py`, Python): AWS la invoca sola cuando hay mensajes en la cola. Valida el JSON, envía el correo con **Amazon SES** y registra en CloudWatch: "Mensaje recibido desde SQS", "Correo enviado correctamente" o "Error al procesar mensaje".

Todo el proceso dentro de AWS tarda unas décimas de segundo; la Lambda principal no espera al correo.

**SES en modo sandbox:** solo envía **desde** y **hacia** direcciones verificadas (`aws sesv2 create-email-identity --email-identity <correo>` y abrir el enlace que llega). El remitente se verifica solo con Terraform. Algunos proveedores (Gmail, por ejemplo) pueden filtrar o retener mensajes que dicen venir de `hotmail.com` pero salen de los servidores de Amazon; con un destinatario Hotmail llegan en segundos.

### Concurrencia con `Future.wait()`

Archivo: `mobile/lib/viewmodels/home_viewmodel.dart`

El Inicio pide 3 datos a la API: perfil, usuarios y archivos.

```dart
// En secuencia: tiempo total = suma de las tres
profile = await getProfile();
users   = await getUsers();
files   = await getFiles();

// En paralelo: tiempo total = la más lenta
final results = await Future.wait([getProfile(), getUsers(), getFiles()]);
```

En el panel **Carga de datos** del Inicio, los botones **En paralelo** (`loadConcurrent`) y **En secuencia** (`loadSequential`) muestran el tiempo total de cada modo.

Cada petición de la demo espera 300 ms antes de salir, para imitar una red móvil (en `localhost` la API responde tan rápido que no se notaría la diferencia). Resultado: unos 360 ms en paralelo frente a unos 1000 ms en secuencia.

---

## Base de datos

El esquema está en `backend/src/main/resources/db/migration/V1__esquema_inicial.sql`. **Flyway** lo aplica al arrancar la API y Hibernate solo valida que las entidades coincidan con las tablas.

```text
users                                   files
─────────────────────────────           ──────────────────────────────────
id            PK                  1 ─── N  id            PK
name          NOT NULL                     user_id       FK → users.id (ON DELETE CASCADE)
email         UNIQUE, minúsculas           original_name NOT NULL
password_hash BCrypt (60)                  storage_key   UNIQUE (nombre en S3 / disco)
created_at                                 content_type  NOT NULL
updated_at                                 size_bytes    CHECK > 0
                                           created_at
```

- Un usuario tiene muchos archivos, unidos por la clave foránea `user_id`.
- Al eliminar un usuario se eliminan sus archivos: las filas, por `ON DELETE CASCADE`, y el contenido en S3, desde `UserService`.
- El email se guarda en minúsculas, así que `Ana@Test.com` y `ana@test.com` son el mismo usuario.

## Endpoints

| Método | Ruta | Token | Qué hace |
| --- | --- | --- | --- |
| `POST` | `/auth/register` | no | Crear cuenta |
| `POST` | `/auth/login` | no | Iniciar sesión, devuelve el token |
| `GET` | `/api/users` | sí | Listar usuarios |
| `GET` | `/api/users/{id}` | sí | Ver un usuario |
| `GET` | `/api/users/me` | sí | Perfil del usuario del token |
| `POST` | `/api/users` | sí | Crear usuario |
| `PUT` | `/api/users/{id}` | sí | Editar usuario |
| `DELETE` | `/api/users/{id}` | sí | Eliminar usuario |
| `POST` | `/upload` | sí | Subir archivo (campo `file`) |
| `GET` | `/files` | sí | Listar mis archivos |
| `GET` | `/files/{storedName}` | sí | Descargar uno de mis archivos |
| `DELETE` | `/files/{id}` | sí | Eliminar uno de mis archivos |
| `POST` | `/notifications/send` | sí | Publicar una notificación por correo (`email`, `subject`, `message`) |

| Error | Cuándo |
| --- | --- |
| `400` | Datos inválidos o archivo no permitido |
| `401` | Sin token, token inválido/caducado o credenciales incorrectas |
| `404` | Usuario o archivo no existe |
| `409` | Email ya registrado |
| `503` | No se pudo publicar la notificación en SNS |
| `413` | Archivo mayor de 4 MB |

---

## Despliegue en AWS

### Recursos (Terraform)

Todo está en `terraform/`; no se creó nada a mano en la consola de AWS.

| Recurso | Para qué |
| --- | --- |
| API Gateway (HTTP API) | URL pública. La ruta `$default` envía todas las peticiones a la Lambda |
| Lambda `flutter-springboot-api` | Spring Boot (Java 17, 2048 MB, 30 s), con **SnapStart** y alias `live` |
| IAM Role + Policy | Permiso mínimo: escribir sus logs y leer, guardar y borrar en `files/uploads/*` |
| CloudWatch Logs | Logs de la Lambda (7 días) |
| S3 `files` | Archivos de los usuarios. **Privado**: solo se accede a través de la API |
| S3 `artifacts` | El zip de la Lambda (más de 50 MB, el límite de subida directa) |
| SNS Topic `…-notification-topic` | Recibe lo que publica el backend |
| SQS Queue `…-notification-queue` + DLQ | Guarda los mensajes; tras 3 fallos pasan a la DLQ. Una política deja a SNS (solo a nuestro topic) enviar a la cola |
| Suscripción SNS → SQS | `raw_message_delivery`: el cuerpo en SQS es directamente el JSON |
| Lambda `…-notification-lambda` | Python 3.12, 256 MB. Rol IAM propio: leer su cola, escribir sus logs y `ses:SendEmail` |
| Event Source Mapping | SQS → notification-lambda (un mensaje por invocación) |
| SES identity | Remitente verificado (`email_sender`) |

**SnapStart:** al publicar cada versión, AWS arranca Spring Boot una vez y guarda una "foto" de la memoria. Las instancias nuevas se restauran desde esa foto en ~1 s en lugar de arrancar desde cero (~8 s). API Gateway invoca el alias `live`, que apunta siempre a la última versión publicada.

`terraform/bootstrap/` crea, una sola vez, el bucket donde Terraform guarda su **estado**. Así tu PC y GitHub Actions trabajan sobre la misma infraestructura.

La Lambda recibe la configuración por variables de entorno: `DATABASE_URL`, `DATABASE_USERNAME`, `DATABASE_PASSWORD`, `JWT_SECRET`, `STORAGE=s3`, `S3_BUCKET`, `NOTIFICATIONS=sns` y `SNS_TOPIC_ARN`. Ningún secreto está escrito en el código.

Outputs (`terraform output`): `api_url`, `lambda_function_name`, `lambda_arn`, `files_bucket`, `sns_topic_arn`, `sqs_queue_url`, `sqs_dlq_url`, `notification_lambda_name` y `ses_sender`.

Despliegue manual desde tu PC:

```bash
cd backend && ./mvnw -Plambda package        # genera target/api-springboot-lambda.zip
cd ../terraform
# secretos como variables de entorno: TF_VAR_database_url, TF_VAR_database_username,
# TF_VAR_database_password, TF_VAR_jwt_secret, TF_VAR_email_sender
terraform init
terraform plan
terraform apply
```

### CI/CD (GitHub Actions)

`.github/workflows/deploy.yml` se ejecuta en cada push a `main`:

```text
checkout → Java 17 → dependencias → pruebas (Java y Python) → zip de Lambda → credenciales AWS
         → terraform init → validate → plan → apply
```

Si una prueba falla, no se despliega nada.

### GitHub Secrets

En **Settings → Secrets and variables → Actions**:

| Secret | Contenido |
| --- | --- |
| `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | Claves del usuario IAM `terraform-deploy` |
| `AWS_REGION` | `us-east-2` |
| `DATABASE_URL` | URL JDBC de Neon, sin usuario ni clave |
| `DATABASE_USERNAME` / `DATABASE_PASSWORD` | Credenciales de Neon |
| `JWT_SECRET` | Clave para firmar los tokens (mínimo 32 caracteres) |
| `EMAIL_SENDER` | Correo remitente de las notificaciones (se verifica en SES) |

GitHub oculta estos valores en los logs (`***`) y Terraform los marca como sensibles.

## Pruebas de carga

Scripts K6, resultados y gráficas en [load-tests/](load-tests/README.md). Informe técnico con resultados, cuello de botella y recomendaciones: [docs/INFORME_PRUEBAS_CARGA.md](docs/INFORME_PRUEBAS_CARGA.md).
