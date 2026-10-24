package com.dauviet.energy.application;

import java.time.Clock;

import org.springframework.boot.context.properties.EnableConfigurationProperties;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

/**
 * Wiring của Energy module: bật binding `dauviet.energy.*` và expose
 * {@link Clock} hệ thống — inject được vào service để unit test thời gian
 * giả lập không cần sleep thật (lazy recovery).
 */
@Configuration
@EnableConfigurationProperties(EnergyProperties.class)
public class EnergyConfig {

    @Bean
    public Clock energyClock() {
        return Clock.systemUTC();
    }
}
