package com.dauviet.auth.application;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.core.env.Environment;
import org.springframework.stereotype.Component;

import com.dauviet.auth.domain.OtpPurpose;

import java.util.Arrays;

/**
 * Local/test fallback when SMTP is not configured (mail-enabled=false).
 * The OTP code is printed ONLY when the "local" Spring profile is active —
 * in any other profile we log just the masked recipient + purpose, keeping
 * production logs free of plaintext OTP even if the flag is mis-set.
 */
@Component
@ConditionalOnProperty(prefix = "dauviet.auth.otp", name = "mail-enabled",
        havingValue = "false", matchIfMissing = true)
public class LoggingOtpSender implements OtpSender {

    private static final Logger log = LoggerFactory.getLogger(LoggingOtpSender.class);

    private final boolean localProfile;

    public LoggingOtpSender(Environment env) {
        this.localProfile = Arrays.asList(env.getActiveProfiles()).contains("local");
    }

    @Override
    public void sendOtp(String email, OtpPurpose purpose, String code) {
        if (localProfile) {
            // Dev convenience: lets a developer complete OTP flows without an
            // SMTP server. Restricted to profile "local" by construction.
            log.info("DEV-ONLY otp code={} to={} purpose={}", code,
                    SmtpOtpSender.mask(email), purpose);
        } else {
            log.info("otp send requested (mail-disabled) to={} purpose={}",
                    SmtpOtpSender.mask(email), purpose);
        }
    }
}
