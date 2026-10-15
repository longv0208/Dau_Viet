package com.dauviet.auth.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.dauviet.auth.domain.AuthenticationFailedException;
import com.dauviet.auth.domain.RefreshToken;
import com.dauviet.auth.infrastructure.persistence.RefreshTokenRepository;
import com.dauviet.security.jwt.SecurityTokenProperties;
import com.dauviet.user.domain.User;
import com.dauviet.user.domain.UserStatus;
import com.dauviet.user.infrastructure.persistence.UserRepository;

@ExtendWith(MockitoExtension.class)
class RefreshTokenServiceTest {

    @Mock private RefreshTokenRepository tokens;
    @Mock private UserRepository users;
    @Mock private RefreshTokenFamilyService familyService;

    private RefreshTokenService service;
    private SecurityTokenProperties props;

    @BeforeEach
    void setUp() {
        props = new SecurityTokenProperties();
        props.setRefreshTokenTtlSeconds(1209600);
        service = new RefreshTokenService(tokens, props, users, familyService);
    }

    private RefreshToken row(UUID userId) {
        RefreshToken t = new RefreshToken();
        t.setId(UUID.randomUUID());
        t.setUserId(userId);
        t.setTokenFamilyId(UUID.randomUUID());
        t.setExpiresAt(Instant.now().plusSeconds(3600));
        return t;
    }

    @Test
    void issue_persistsOnlyHash_chainsFamilyAndPrevious() {
        User u = new User();
        u.setId(UUID.randomUUID());
        RefreshToken prev = row(u.getId());

        var issued = service.issue(u, prev);
        assertThat(issued.raw()).isNotBlank();
        ArgumentCaptor<RefreshToken> captor = ArgumentCaptor.forClass(RefreshToken.class);
        verify(tokens).save(captor.capture());
        RefreshToken saved = captor.getValue();
        assertThat(saved.getTokenHash()).isEqualTo(RefreshTokenService.hash(issued.raw()));
        assertThat(saved.getTokenHash()).doesNotContain(issued.raw());
        assertThat(saved.getTokenFamilyId()).isEqualTo(prev.getTokenFamilyId());
        assertThat(saved.getPreviousTokenId()).isEqualTo(prev.getId());
        assertThat(saved.getExpiresAt()).isAfter(Instant.now());
    }

    @Test
    void rotate_validToken_revokesOldAndIssuesNew() {
        UUID userId = UUID.randomUUID();
        RefreshToken old = row(userId);
        when(tokens.findByTokenHashForUpdate(any())).thenReturn(Optional.of(old));
        User u = new User();
        u.setId(userId);
        u.setStatus(UserStatus.ACTIVE);
        when(users.findById(userId)).thenReturn(Optional.of(u));
        when(tokens.save(any(RefreshToken.class))).thenAnswer(i -> i.getArgument(0));

        var issued = service.rotate("raw-old");
        assertThat(old.isRevoked()).isTrue();
        assertThat(old.getLastUsedAt()).isNotNull();
        assertThat(issued.token().getTokenFamilyId()).isEqualTo(old.getTokenFamilyId());
        assertThat(issued.token().getPreviousTokenId()).isEqualTo(old.getId());
    }

    @Test
    void rotate_replayedRevokedToken_revokesFamilyAnd401() {
        UUID userId = UUID.randomUUID();
        RefreshToken old = row(userId);
        old.setRevokedAt(Instant.now().minusSeconds(10));
        when(tokens.findByTokenHashForUpdate(any())).thenReturn(Optional.of(old));

        assertThatThrownBy(() -> service.rotate("raw-old"))
                .isInstanceOf(AuthenticationFailedException.class);
        verify(familyService).revokeFamily(old.getTokenFamilyId(), old.getId());
    }

    @Test
    void rotate_expiredToken_401() {
        RefreshToken old = row(UUID.randomUUID());
        old.setExpiresAt(Instant.now().minusSeconds(1));
        when(tokens.findByTokenHashForUpdate(any())).thenReturn(Optional.of(old));

        assertThatThrownBy(() -> service.rotate("raw-old"))
                .isInstanceOf(AuthenticationFailedException.class);
        verify(familyService, never()).revokeFamily(any(), any());
    }

    @Test
    void rotate_unknownToken_401() {
        when(tokens.findByTokenHashForUpdate(any())).thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.rotate("nope"))
                .isInstanceOf(AuthenticationFailedException.class);
    }

    @Test
    void rotate_lockedUser_revokesFamilyAnd401() {
        UUID userId = UUID.randomUUID();
        RefreshToken old = row(userId);
        when(tokens.findByTokenHashForUpdate(any())).thenReturn(Optional.of(old));
        User u = new User();
        u.setId(userId);
        u.setStatus(UserStatus.LOCKED);
        when(users.findById(userId)).thenReturn(Optional.of(u));

        assertThatThrownBy(() -> service.rotate("raw-old"))
                .isInstanceOf(AuthenticationFailedException.class);
        verify(familyService).revokeFamily(old.getTokenFamilyId(), old.getId());
    }

    @Test
    void revoke_marksRevoked_ifPresentAndActive() {
        RefreshToken t = row(UUID.randomUUID());
        when(tokens.findByTokenHash(any())).thenReturn(Optional.of(t));
        service.revoke("raw-x");
        assertThat(t.isRevoked()).isTrue();
    }

    @Test
    void revoke_idempotent_whenMissingOrAlreadyRevoked() {
        when(tokens.findByTokenHash(any())).thenReturn(Optional.empty());
        service.revoke("missing"); // no exception
        RefreshToken t = row(UUID.randomUUID());
        t.setRevokedAt(Instant.now().minusSeconds(5));
        when(tokens.findByTokenHash(any())).thenReturn(Optional.of(t));
        service.revoke("again");
        verify(tokens, never()).save(t); // unchanged: already revoked
    }
}
