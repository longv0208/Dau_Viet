package com.dauviet.auth.application;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Component;

import com.dauviet.auth.domain.OtpPurpose;

/**
 * Production sender — real SMTP via spring.mail.* / MAIL_* envs. Never
 * logs the code; only a masked recipient + purpose at INFO on success.
 */
@Component
@ConditionalOnProperty(prefix = "dauviet.auth.otp", name = "mail-enabled", havingValue = "true")
public class SmtpOtpSender implements OtpSender {

    private static final Logger log = LoggerFactory.getLogger(SmtpOtpSender.class);

    private final JavaMailSender mailSender;
    private final AuthOtpProperties props;

    public SmtpOtpSender(JavaMailSender mailSender, AuthOtpProperties props) {
        this.mailSender = mailSender;
        this.props = props;
    }

    @Override
    public void sendOtp(String email, OtpPurpose purpose, String code) {
        SimpleMailMessage msg = new SimpleMailMessage();
        msg.setFrom(props.getSenderAddress());
        msg.setTo(email);
        msg.setSubject(subjectFor(purpose));
        msg.setText(bodyFor(purpose, code));
        mailSender.send(msg);
        log.info("otp sent to={} purpose={}", mask(email), purpose);
    }

    private static String subjectFor(OtpPurpose purpose) {
        return switch (purpose) {
            case REGISTER_VERIFY -> "[Dấu Việt] Mã xác thực đăng ký tài khoản";
            case PASSWORD_RESET -> "[Dấu Việt] Mã đặt lại mật khẩu";
        };
    }

    private static String bodyFor(OtpPurpose purpose, String code) {
        String action = switch (purpose) {
            case REGISTER_VERIFY -> "xác thực đăng ký tài khoản";
            case PASSWORD_RESET -> "đặt lại mật khẩu";
        };
        return "Mã OTP " + action + " của bạn là: " + code + "\n\n"
             + "Mã có hiệu lực trong 5 phút. Nếu bạn không yêu cầu, hãy bỏ qua email này.";
    }

    static String mask(String email) {
        int at = email == null ? -1 : email.indexOf('@');
        if (at <= 1) return "***";
        return email.charAt(0) + "***" + email.substring(at);
    }
}
