# Kafka Connect + Debezium MySQL 连接器（自带 Confluent Avro 转换器）
FROM confluentinc/cp-kafka-connect:7.6.1

# 安装 Debezium MySQL 连接器
RUN confluent-hub install --no-prompt debezium/debezium-connector-mysql:2.4.2

# 说明：Avro 转换器 io.confluent.connect.avro.AvroConverter 已随 cp-kafka-connect 镜像内置，
# 无需额外安装，契合设计方案 §5（Avro + Schema Registry）。
