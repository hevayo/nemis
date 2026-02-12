FROM php:8.4-cli

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    libpng-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    zip \
    unzip \
    && docker-php-ext-install pdo_mysql mbstring exif pcntl bcmath gd zip \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /app

# Install dependencies first for better layer caching
COPY api/composer.json api/composer.lock* ./
RUN composer install --no-scripts --no-autoloader || true

# Source code mounted as volume in dev
COPY api/ ./

EXPOSE 8080

# At startup: install deps, ensure .env exists, generate key if needed
CMD bash -c "\
  composer install --no-interaction && \
  if [ ! -f .env ]; then cp .env.example .env && php artisan key:generate; fi && \
  php artisan serve --host=0.0.0.0 --port=8080"
