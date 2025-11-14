# Use Flutter SDK image
FROM ghcr.io/cirruslabs/flutter:stable AS build

# Set working directory
WORKDIR /app

# Enable Flutter for web/server (disable platform checks)
ENV FLUTTER_WEB=true

# Copy pubspec files
COPY pubspec.yaml pubspec.lock* ./

# Get dependencies using Flutter
RUN flutter pub get --no-example

# Copy source code
COPY . .

# Get dependencies again (in case of changes)
RUN flutter pub get --no-example

# Expose port (Render will provide PORT env variable)
ENV PORT=8080
EXPOSE 8080

# Run the server using dart (Flutter includes Dart)
CMD ["dart", "run", "bin/server.dart"]

