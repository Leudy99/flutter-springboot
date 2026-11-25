# ---------- Etapa 1: compilar Flutter Web ----------
FROM ghcr.io/cirruslabs/flutter:3.41.6 AS build
WORKDIR /app

# Primero solo pubspec: Docker cachea las dependencias
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

# URL del backend que usa el navegador (config.dart la lee con API_URL).
# En Kubernetes local el backend se publica en el NodePort 30081.
ARG API_URL=http://localhost:30081
# --no-web-resources-cdn: CanvasKit se sirve desde el propio sitio (sin gstatic.com),
# asi la app carga tambien sin internet.
RUN flutter build web --release --no-web-resources-cdn --dart-define=API_URL=${API_URL}

# ---------- Etapa 2: servir el sitio con Nginx ----------
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80
