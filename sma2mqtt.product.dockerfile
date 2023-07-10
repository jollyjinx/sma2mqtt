FROM swift:latest as builder
WORKDIR /root
COPY . .
RUN swift build -c release

FROM swift:slim
WORKDIR /root
ENV PATH "$PATH:/root"
COPY --from=builder /root/.build/release/sma2mqtt .
COPY --from=builder /root/.build/release/sma2mqtt_sma2mqttLibrary.resources ./sma2mqtt_sma2mqttLibrary.resources
CMD ["./sma2mqtt"]

#docker build . --file sma2mqtt.product.dockerfile --tag jollyjinx/sma2mqtt:latest
#docker build . --file sma2mqtt.product.dockerfile --tag sma2mqtt
#docker run --name sma2mqtt sma2mqtt
