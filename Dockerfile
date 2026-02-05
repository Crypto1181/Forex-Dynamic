# Use Flutter image for both build and runtime to support JIT execution
# This avoids the high memory usage of 'dart compile exe'
FROM ghcr.io/cirruslabs/flutter:stable

WORKDIR /app

# Copy pubspec files first for better caching
COPY pubspec.yaml pubspec.lock ./

# Get dependencies
RUN flutter pub get

# Copy the rest of the application
COPY . .

# Expose port
ENV PORT=8080
EXPOSE 8080

# Run the server using Dart JIT (Just-In-Time) compilation
# This requires the Dart SDK (included in the image) but uses much less memory during build
CMD ["dart", "bin/server.dart"]
