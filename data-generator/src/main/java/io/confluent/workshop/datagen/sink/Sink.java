package io.confluent.workshop.datagen.sink;

import java.util.Map;

public interface Sink extends AutoCloseable {

    void write(Map<String, Object> fields) throws Exception;

    void writeUpdate(Map<String, Object> setFields, Map<String, Object> whereFields) throws Exception;

    void flush() throws Exception;
}
