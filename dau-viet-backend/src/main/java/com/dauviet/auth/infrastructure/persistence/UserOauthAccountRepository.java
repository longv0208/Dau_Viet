package com.dauviet.auth.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.dauviet.auth.domain.UserOauthAccount;

public interface UserOauthAccountRepository extends JpaRepository<UserOauthAccount, UUID> {

    Optional<UserOauthAccount> findByProviderAndProviderSubject(String provider, String providerSubject);
}
