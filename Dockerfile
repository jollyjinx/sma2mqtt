# Raspberry Pi 4 (using 64 bit OS)

# The build container for building the Swift app from source
FROM th089/swift:latest AS build

WORKDIR /app

COPY . ./

RUN swift build --jobs 1

# The run container that will go to devices
FROM th089/swift:latest

WORKDIR /app

COPY --from=build /app/.build/debug/sma2mqtt .

CMD ["./sma2mqtt"]
