# Use Flutter SDK image
FROM cirrusci/flutter:stable AS build

# Set working directory
WORKDIR /app

# Copy pubspec files
COPY pubspec.* ./

# Get dependencies using Flutter (not dart)
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

