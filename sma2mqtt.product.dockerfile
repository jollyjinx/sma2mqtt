# syntax=docker/dockerfile:1.7
FROM swift:6.3 AS sma2mqttbuilder
WORKDIR /swift
ENV SWIFTPM_BUILD_TESTS=false
COPY Package.swift ./
RUN --mount=type=cache,target=/root/.cache \
    --mount=type=cache,target=/root/.swiftpm \
    swift package resolve
COPY Sources ./Sources
COPY Tests ./Tests
RUN --mount=type=cache,target=/root/.cache \
    --mount=type=cache,target=/root/.swiftpm \
    swift build -c release --product sma2mqtt \
    && binary_path="$(find /swift/.build -path '*/release/sma2mqtt' -type f | head -n 1)" \
    && test -n "$binary_path" \
    && install -Dm755 "$binary_path" /out/sma2mqtt \
    && resource_path="$(find /swift/.build -type d -name 'sma2mqtt_sma2mqttLibrary.resources' | head -n 1)" \
    && test -n "$resource_path" \
    && cp -R "$resource_path" /out/sma2mqtt_sma2mqttLibrary.resources

FROM swift:6.3-slim
ENV APP_ROOT=/opt/sma2mqtt
ENV STATE_ROOT=/var/lib/sma2mqtt
ENV PATH="$PATH:${APP_ROOT}"
RUN mkdir -p "${APP_ROOT}" "${STATE_ROOT}" \
    && chmod 755 "${APP_ROOT}" \
    && chmod 777 "${STATE_ROOT}"
WORKDIR /var/lib/sma2mqtt
COPY --from=sma2mqttbuilder /out/sma2mqtt ${APP_ROOT}/sma2mqtt
COPY --from=sma2mqttbuilder /out/sma2mqtt_sma2mqttLibrary.resources ${APP_ROOT}/sma2mqtt_sma2mqttLibrary.resources
RUN chmod 755 "${APP_ROOT}/sma2mqtt" \
    && chmod -R a+rX "${APP_ROOT}/sma2mqtt_sma2mqttLibrary.resources"
CMD ["sma2mqtt"]

# create your own docker image:
#
# docker build . --file sma2mqtt.product.dockerfile --tag sma2mqtt
# docker run --name sma2mqtt sma2mqtt
# docker buildx build --no-cache --platform linux/amd64,linux/arm64 --tag jollyjinx/sma2mqtt:development --file sma2mqtt.product.dockerfile --push .


# multiarch build to docker.io:
#
# docker buildx create --use --name multiarch-builder
# docker buildx inspect --bootstrap
# version=development
# docker buildx build --no-cache --platform linux/amd64,linux/arm64 --tag "jollyjinx/sma2mqtt:$version" --file sma2mqtt.product.dockerfile --push .
# docker buildx build --no-cache --platform linux/amd64,linux/arm64 --tag jollyjinx/sma2mqtt:latest --tag jollyjinx/sma2mqtt:development --tag "jollyjinx/sma2mqtt:3.2.0" --file sma2mqtt.product.dockerfile --push .
# docker buildx imagetools inspect jollyjinx/sma2mqtt:latest
