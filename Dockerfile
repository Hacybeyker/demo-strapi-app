# --- Etapa 1: Definir la Base ---
# Usamos Node.js 22 en Alpine para una imagen ligera
FROM node:22-alpine AS base

# Habilitamos pnpm
RUN corepack enable

# --- Etapa 2: Instalar Dependencias ---
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /opt/app

# Copiamos solo los archivos de dependencias de pnpm
COPY package.json pnpm-lock.yaml* ./

# Instalamos dependencias (incluyendo 'sharp' para imágenes)
RUN pnpm install

# --- Etapa 3: Construir la Aplicación ---
# Esta etapa compila el panel de admin de Strapi
FROM base AS builder
WORKDIR /opt/app

# Copiamos las dependencias instaladas
COPY --from=deps /opt/app/node_modules ./node_modules
# Copiamos el resto del código fuente
COPY . .

# Seteamos el entorno a producción
ENV NODE_ENV=production

# Construimos el panel de admin
RUN pnpm run build

# --- Etapa 4: Imagen Final de Producción ---
FROM base AS runner
WORKDIR /opt/app

# Copiamos los artefactos construidos
COPY --from=builder /opt/app/build ./build
COPY --from=builder /opt/app/dist ./dist
COPY --from=builder /opt/app/package.json ./package.json
COPY --from=builder /opt/app/.strapi ./.strapi

# Copiamos solo las dependencias de producción
COPY --from=deps /opt/app/node_modules ./node_modules
# Copiamos el directorio de uploads (si existe)
COPY --from=builder /opt/app/public/uploads ./public/uploads

# Exponemos el puerto de Strapi
EXPOSE 1337

# El comando para iniciar la aplicación
CMD ["pnpm", "run", "start"]
