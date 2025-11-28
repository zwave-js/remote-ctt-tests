# Use a 32-bit Debian base image since the binaries are 32-bit x86
# bookworm has glibc 2.36 which should support the binaries
FROM i386/debian:bookworm-slim

# Install minimal dependencies
RUN apt-get update && apt-get install -y \
    procps \
    && rm -rf /var/lib/apt/lists/*

# Create directory for binaries
WORKDIR /app

# Copy the Z-Wave binaries
COPY zwave_stack/*.elf ./

# Copy startup script
COPY start-zwave-stack.sh ./

# Make binaries and script executable
RUN chmod +x *.elf start-zwave-stack.sh

# Expose TCP ports for Z-Wave controllers and end devices
# Ports 5000-5004 for controllers and end devices
EXPOSE 5000 5001 5002 5003 5004

# Default command - start all Z-Wave binaries
CMD ["./start-zwave-stack.sh"]
