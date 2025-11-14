# Use Dart SDK image
FROM dart:stable AS build

# Set working directory
WORKDIR /app

# Copy pubspec files
COPY pubspec.* ./

# Get dependencies
RUN dart pub get

# Copy source code
COPY . .

# Build the server (we'll create a simple server entry point)
RUN dart pub get

# Expose port (Render will provide PORT env variable)
ENV PORT=8080
EXPOSE 8080

# Run the server
CMD ["dart", "run", "bin/server.dart"]

