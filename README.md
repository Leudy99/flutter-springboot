# Flutter App + API REST con Spring Boot

App Flutter que consume una API Spring Boot. La API guarda los datos en PostgreSQL y protege sus rutas con JWT.

La app permite: iniciar sesión, gestionar usuarios (CRUD), subir y ver archivos, y comparar peticiones en paralelo con `Future.wait()`.

```text
App Flutter (mobile/)  ──HTTP + JWT──>  API Spring Boot (backend/)  ──>  PostgreSQL
                                                  └──>  carpeta /app/uploads (archivos)
```

La app nunca accede a la base de datos directamente: todo pasa por la API.

---

## Puesta en marcha

**Requisitos:** Docker Desktop, Flutter 3.41 o superior y un emulador de Android Studio.
No hace falta instalar Java, Maven ni PostgreSQL.

**1. Backend y base de datos.** Con Docker Desktop abierto:

```bash
cd backend
docker compose up --build -d
```

La primera vez tarda unos minutos. Está listo cuando `docker compose logs api` muestra `Started ApiSpringbootApplication`.

| Contenedor | Puerto | Qué es |
| --- | --- | --- |
| `flutterapp-api` | `8081` | API → `http://localhost:8081` |
| `flutterapp-db` | `5434` | PostgreSQL (base `apidb`, usuario `alumno`, clave `123456`) |

**2. App.** Abre el emulador (Android Studio → Device Manager → ▶) y ejecuta:

```bash
cd mobile
flutter pub get
flutter run
```

En VS Code: abre `mobile`, elige el emulador en la barra inferior y pulsa **F5**.

**3. Usar.** En la pantalla de acceso elige **Crear cuenta**, completa los datos y entra.

---

## Arquitectura

### Backend: hexagonal

```text
Controller  →  Service (caso de uso)  →  Puerto (interfaz)  →  Adaptador  →  PostgreSQL / disco
 web/           application/              domain/port/          infrastructure/
```

- `domain`: modelos, puertos y excepciones. Java puro.
- `application`: casos de uso (`UserService`, `AuthService`, `FileService`).
- `infrastructure`: controllers, JPA, JWT, BCrypt y almacenamiento de archivos.

El dominio solo conoce interfaces (puertos); la infraestructura las implementa:

| Puerto | Adaptador |
| --- | --- |
| `UserRepository` | `UserRepositoryAdapter` (tabla `users`) |
| `StoredFileRepository` | `StoredFileRepositoryAdapter` (tabla `files`) |
| `PasswordHasher` | `BCryptPasswordHasher` |
| `TokenProvider` | `JwtService` |
| `FileStorage` | `LocalFileStorage` (carpeta `/app/uploads`) |

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

- **Subir:** se elige una imagen o documento (JPG, PNG, GIF, WEBP, PDF, TXT, Word, Excel; máx. 10 MB), se ve una vista previa y se envía como `multipart/form-data` a `POST /upload` con barra de progreso.
- **Backend:** valida el tipo, guarda el archivo con un nombre único en `/app/uploads` y registra sus datos en la tabla `files`.
- **Ver:** pestaña **Archivos**, galería con filtros. Al tocar un archivo se abre: imagen con zoom, PDF por páginas o texto. Word y Excel no tienen vista previa.

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
| `GET` | `/files` | sí | Listar archivos |
| `GET` | `/files/{storedName}` | sí | Descargar archivo |

| Error | Cuándo |
| --- | --- |
| `400` | Datos inválidos o archivo no permitido |
| `401` | Sin token, token inválido/caducado o credenciales incorrectas |
| `404` | Usuario o archivo no existe |
| `409` | Email ya registrado |
| `413` | Archivo mayor de 10 MB |
