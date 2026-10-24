package com.dauviet.energy.domain;

import java.time.Instant;

/**
 * Zero-energy gate (ENGY-09): submit activity có chấm điểm khi energy = 0.
 * Mang theo serverTime + mốc hồi kế tiếp do server tính — GlobalExceptionHandler
 * map sang 409 ENERGY_DEPLETED với details cho client đồng bộ.
 */
public class EnergyDepletedException extends RuntimeException {

    private final Instant nextRecoveryAt;
    private final Instant serverTime;

    public EnergyDepletedException(Instant nextRecoveryAt, Instant serverTime) {
        super("Not enough energy");
        this.nextRecoveryAt = nextRecoveryAt;
        this.serverTime = serverTime;
    }

    public Instant getNextRecoveryAt() { return nextRecoveryAt; }
    public Instant getServerTime() { return serverTime; }
}
