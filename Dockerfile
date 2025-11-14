# --- Etapa 1: Definir la Base ---
# Usamos node:22-alpine, una imagen ligera y moderna
FROM node:22-alpine AS base

# ¡¡¡ESTA ES LA LÍNEA QUE LO ARREGLA TODO!!!
# Añadimos las herramientas de compilación (C++, Python, Make) y la librería VIPS para 'sharp'
RUN apk add --no-cache libc6-compat gcompat vips-dev build-base gcc g++ make python3

# Instalamos 'pnpm' globalmente
RUN npm install -g pnpm

# --- Etapa 2: Instalar Dependencias (Dev + Prod) ---
# Esta etapa solo instala las dependencias para que Docker pueda cachearlas
FROM base AS deps
WORKDIR /opt/app
# Copiamos el .npmrc (que tiene los reintentos de red y el ignore-scripts=false)
COPY .npmrc ./
COPY package.json pnpm-lock.yaml ./
# Instalamos. pnpm leerá .npmrc y AHORA SÍ podrá compilar 'sharp'
RUN pnpm install --frozen-lockfile

# --- Etapa 3: Construir la Aplicación ---
# Esta etapa construye el panel de admin de Strapi
FROM base AS builder
WORKDIR /opt/app
# Copiamos las dependencias
COPY --from=deps /opt/app/node_modules ./node_modules
# Copiamos el .npmrc para esta etapa
COPY .npmrc ./
# Copiamos el resto del código fuente
COPY . .
ENV NODE_ENV=production
# Construimos el panel de admin de Strapi
# Esto crea /opt/app/dist/ Y /opt/app/dist/build/
RUN pnpm run build

# --- Etapa 4: Imagen Final de Producción ---
# Esta es la imagen final que correrá en Dokploy
FROM base AS runner
WORKDIR /opt/app
ENV NODE_ENV=production

# Copiamos el .npmrc para esta etapa
COPY .npmrc ./
# Instalamos SÓLO las dependencias de PRODUCCIÓN
COPY package.json pnpm-lock.yaml ./
# pnpm leerá .npmrc y AHORA SÍ podrá compilar 'sharp'
RUN pnpm install --prod --frozen-lockfile

# --- ¡LA CORRECCIÓN FINAL (v10)! ---
# Copiamos los artefactos construidos de la etapa 'builder'
# La carpeta 'dist' contiene todo (backend y admin)
COPY --from=builder /opt/app/dist ./dist
# Copiamos el .strapi (que está en la raíz)
COPY --from=builder /opt/app/.strapi ./.strapi
# Copiamos la carpeta public
COPY --from=builder /opt/app/public ./public
# ¡¡AQUÍ ESTÁ LA LÍNEA QUE FALTABA (DE VERDAD)!!
# Copiamos nuestro config/env/production/database.js en la carpeta dist/config/env/
COPY --from=builder /opt/app/config/env ./dist/config/env


# Exponemos el puerto de Strapi
EXPOSE 1337
# Definimos el volumen para que coincida con la UI de Dokploy
VOLUME /opt/app/public/uploads

# El comando para iniciar la aplicación
CMD ["pnpm", "run", "start"]