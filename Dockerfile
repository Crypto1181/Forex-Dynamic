# Use Flutter SDK with specific version (3.35.6 to match local)
FROM ghcr.io/cirruslabs/flutter:3.35.6

# Set working directory
WORKDIR /app

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Accept Flutter licenses
RUN flutter doctor -v

# Copy pubspec files
COPY pubspec.yaml pubspec.lock* ./

# Get dependencies using Flutter
RUN flutter pub get

# Copy source code
COPY . .

# Get dependencies again (in case of changes)
RUN flutter pub get

# Expose port (Render will provide PORT env variable)
ENV PORT=8080
EXPOSE 8080

# Run the server using dart (Flutter includes Dart)
CMD ["dart", "run", "bin/server.dart"]

