package com.dauviet.auth.application;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import com.dauviet.auth.domain.OtpChallenge;
import com.dauviet.auth.domain.OtpException;
import com.dauviet.auth.domain.OtpPurpose;
import com.dauviet.auth.infrastructure.persistence.OtpChallengeRepository;
import com.fasterxml.jackson.databind.ObjectMapper;

@ExtendWith(MockitoExtension.class)
class OtpServiceTest {

    @Mock private OtpChallengeRepository challenges;
    @Mock private OtpSender sender;

    private AuthOtpProperties props;
    private OtpService service;
    private String lastCode;

    @BeforeEach
    void setUp() {
        props = new AuthOtpProperties();
        props.setTtlSeconds(300);
        props.setResendCooldownSeconds(60);
        props.setMaxAttempts(5);
        service = new OtpService(challenges, sender, props, new ObjectMapper());
        // Capture the plaintext code sent — tests need it to exercise verify.
        lenient().doAnswer(inv -> {
            lastCode = inv.getArgument(2);
            return null;
        }).when(sender).sendOtp(anyString(), any(), anyString());
    }

    private OtpChallenge issueChallenge(String email, OtpPurpose purpose) {
        when(challenges.save(any(OtpChallenge.class))).thenAnswer(i -> i.getArgument(0));
        return service.issue(email, purpose, Map.of("k", "v"));
    }

    @Test
    void issue_consumesPriorActive_andStoresHashedCodeNotPlaintext() {
        OtpChallenge c = issueChallenge("  New@Test.VN ", OtpPurpose.REGISTER_VERIFY);
        assertThat(c.getEmail()).isEqualTo("new@test.vn"); // normalized
        assertThat(c.getCodeHash()).isNotEqualTo(lastCode);
        assertThat(c.getCodeHash()).hasSize(64); // sha-256 hex
        assertThat(c.getExpiresAt()).isAfter(Instant.now());
        verify(challenges).consumeActive(eq("new@test.vn"),
                eq(OtpPurpose.REGISTER_VERIFY), any(Instant.class));
        // Salt lives inside payload — same code across challenges hashes differently.
        assertThat(c.getPayloadJson()).contains("salt").contains("\"k\":\"v\"");
    }

    @Test
    void issue_sameCodeDifferentChallenge_hashesDiffer_dueToSalt() {
        OtpChallenge a = issueChallenge("a@t.vn", OtpPurpose.REGISTER_VERIFY);
        String hashA = a.getCodeHash();
        // Manually re-hash the captured code with a different salt → different hash.
        String other = OtpService.hash("other-salt", lastCode);
        assertThat(hashA).isNotEqualTo(other);
    }

    @Test
    void verify_correctCode_consumesAndReturnsChallenge() {
        OtpChallenge c = issueChallenge("v@t.vn", OtpPurpose.PASSWORD_RESET);
        when(challenges.findActiveForUpdate("v@t.vn", OtpPurpose.PASSWORD_RESET))
                .thenReturn(Optional.of(c));
        when(challenges.save(any())).thenAnswer(i -> i.getArgument(0));

        OtpChallenge verified = service.verify("v@t.vn", OtpPurpose.PASSWORD_RESET, lastCode);
        assertThat(verified.isConsumed()).isTrue();
        assertThat(service.readPayload(verified)).containsEntry("k", "v");
    }

    @Test
    void verify_wrongCode_incrementsAttempts_throwsInvalid() {
        OtpChallenge c = issueChallenge("w@t.vn", OtpPurpose.REGISTER_VERIFY);
        when(challenges.findActiveForUpdate("w@t.vn", OtpPurpose.REGISTER_VERIFY))
                .thenReturn(Optional.of(c));
        when(challenges.save(any())).thenAnswer(i -> i.getArgument(0));

        assertThatThrownBy(() -> service.verify("w@t.vn", OtpPurpose.REGISTER_VERIFY, "000000"))
                .isInstanceOf(OtpException.Invalid.class)
                .extracting(e -> ((OtpException.Invalid) e).getAttemptsLeft())
                .isEqualTo(4);
        assertThat(c.getAttempts()).isEqualTo(1);
        assertThat(c.isConsumed()).isFalse();
    }

    @Test
    void verify_maxAttempts_consumesChallenge_throws429Subtype() {
        OtpChallenge c = issueChallenge("m@t.vn", OtpPurpose.REGISTER_VERIFY);
        c.setAttempts(4); // next wrong = 5th
        when(challenges.findActiveForUpdate("m@t.vn", OtpPurpose.REGISTER_VERIFY))
                .thenReturn(Optional.of(c));
        when(challenges.save(any())).thenAnswer(i -> i.getArgument(0));

        assertThatThrownBy(() -> service.verify("m@t.vn", OtpPurpose.REGISTER_VERIFY, "999999"))
                .isInstanceOf(OtpException.MaxAttemptsExceeded.class);
        assertThat(c.isConsumed()).isTrue();
    }

    @Test
    void verify_expired_consumes_throwsExpired() {
        OtpChallenge c = issueChallenge("e@t.vn", OtpPurpose.REGISTER_VERIFY);
        c.setExpiresAt(Instant.now().minusSeconds(1));
        when(challenges.findActiveForUpdate("e@t.vn", OtpPurpose.REGISTER_VERIFY))
                .thenReturn(Optional.of(c));
        when(challenges.save(any())).thenAnswer(i -> i.getArgument(0));

        assertThatThrownBy(() -> service.verify("e@t.vn", OtpPurpose.REGISTER_VERIFY, lastCode))
                .isInstanceOf(OtpException.Expired.class);
        assertThat(c.isConsumed()).isTrue();
    }

    @Test
    void verify_noChallenge_throwsNoChallenge() {
        when(challenges.findActiveForUpdate("n@t.vn", OtpPurpose.PASSWORD_RESET))
                .thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.verify("n@t.vn", OtpPurpose.PASSWORD_RESET, "123456"))
                .isInstanceOf(OtpException.NoChallenge.class);
    }

    @Test
    void resend_withinCooldown_throwsCooldownWithRemaining() {
        OtpChallenge recent = new OtpChallenge();
        recent.setId(UUID.randomUUID());
        recent.setCreatedAtForTest(Instant.now().minusSeconds(10));
        when(challenges.findLatest("c@t.vn", OtpPurpose.REGISTER_VERIFY))
                .thenReturn(Optional.of(recent));

        assertThatThrownBy(() -> service.assertResendAllowed("c@t.vn", OtpPurpose.REGISTER_VERIFY))
                .isInstanceOf(OtpException.ResendCooldown.class)
                .extracting(e -> ((OtpException.ResendCooldown) e).getRetryAfterSeconds())
                .satisfies(r -> assertThat((Long) r).isBetween(45L, 51L));
    }

    @Test
    void resend_noPriorChallenge_registerVerify_throwsNoChallenge() {
        when(challenges.findLatest("z@t.vn", OtpPurpose.REGISTER_VERIFY))
                .thenReturn(Optional.empty());
        assertThatThrownBy(() -> service.assertResendAllowed("z@t.vn", OtpPurpose.REGISTER_VERIFY))
                .isInstanceOf(OtpException.NoChallenge.class);
    }

    @Test
    void resend_noPriorChallenge_passwordReset_allowed() {
        when(challenges.findLatest("z@t.vn", OtpPurpose.PASSWORD_RESET))
                .thenReturn(Optional.empty());
        service.assertResendAllowed("z@t.vn", OtpPurpose.PASSWORD_RESET); // no throw
    }

    @Test
    void resend_afterCooldown_allowed() {
        OtpChallenge old = new OtpChallenge();
        old.setId(UUID.randomUUID());
        old.setCreatedAtForTest(Instant.now().minusSeconds(120));
        when(challenges.findLatest("ok@t.vn", OtpPurpose.REGISTER_VERIFY))
                .thenReturn(Optional.of(old));
        service.assertResendAllowed("ok@t.vn", OtpPurpose.REGISTER_VERIFY); // no throw
    }
}
