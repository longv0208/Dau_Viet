package com.dauviet.wallet.domain;

import java.io.Serializable;
import java.util.Objects;
import java.util.UUID;

/** Composite PK (user_id, currency) cho {@link WalletAccount}. */
public class WalletAccountId implements Serializable {

    private UUID userId;
    private String currency;

    public WalletAccountId() {
    }

    public WalletAccountId(UUID userId, String currency) {
        this.userId = userId;
        this.currency = currency;
    }

    @Override
    public boolean equals(Object o) {
        if (this == o) return true;
        if (!(o instanceof WalletAccountId that)) return false;
        return Objects.equals(userId, that.userId)
                && Objects.equals(currency, that.currency);
    }

    @Override
    public int hashCode() {
        return Objects.hash(userId, currency);
    }
}
