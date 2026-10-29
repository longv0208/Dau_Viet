package com.dauviet.auth.api;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import jakarta.validation.Valid;

import com.dauviet.auth.api.dto.ForgotPasswordRequest;
import com.dauviet.auth.api.dto.GoogleLoginRequest;
import com.dauviet.auth.api.dto.LoginRequest;
import com.dauviet.auth.api.dto.OtpChallengeResponse;
import com.dauviet.auth.api.dto.RefreshRequest;
import com.dauviet.auth.api.dto.RegisterRequest;
import com.dauviet.auth.api.dto.ResendOtpRequest;
import com.dauviet.auth.api.dto.ResetPasswordRequest;
import com.dauviet.auth.api.dto.TokenResponse;
import com.dauviet.auth.api.dto.VerifyOtpRequest;
import com.dauviet.auth.application.AuthOtpProperties;
import com.dauviet.auth.application.AuthService;
import com.dauviet.auth.domain.OtpChallenge;

/**
 * Public authentication endpoints (Issue #34): OTP-challenged register,
 * OTP password reset, Google sign-in, refresh/logout. All unauthenticated —
 * the access token may already be expired when the client signs out.
 */
@RestController
@RequestMapping("/api/v1/auth")
public class AuthController {

    private final AuthService authService;
    private final AuthOtpProperties otpProps;

    public AuthController(AuthService authService, AuthOtpProperties otpProps) {
        this.authService = authService;
        this.otpProps = otpProps;
    }

    /**
     * Registration START (breaking change vs. pre-#34): no user is created
     * yet — a REGISTER_VERIFY challenge is issued and the code emailed.
     * Client then calls /register/verify. 202 + challenge timing info.
     */
    @PostMapping("/register")
    public ResponseEntity<OtpChallengeResponse> register(@Valid @RequestBody RegisterRequest req) {
        OtpChallenge c = authService.requestRegisterOtp(req);
        return ResponseEntity.status(HttpStatus.ACCEPTED).body(challengeResponse(req.email(), c));
    }

    /** Registration FINISH: verify OTP → user created → token pair. */
    @PostMapping("/register/verify")
    public TokenResponse verifyRegister(@Valid @RequestBody VerifyOtpRequest req) {
        return authService.verifyRegisterOtp(req);
    }

    /**
     * Resend OTP for REGISTER_VERIFY or PASSWORD_RESET. Always 202 when a
     * resend is permissible (or a no-op for anti-enumeration) — errors only
     * on cooldown (429) or missing REGISTER_VERIFY challenge (400).
     */
    @PostMapping("/otp/resend")
    public ResponseEntity<OtpChallengeResponse> resendOtp(@Valid @RequestBody ResendOtpRequest req) {
        OtpChallenge c = authService.resendOtp(req);
        return ResponseEntity.status(HttpStatus.ACCEPTED)
                .body(challengeResponse(req.email(), c));
    }

    /** Forgot password kickoff — ALWAYS 200 regardless of account existence. */
    @PostMapping("/password/forgot")
    public ResponseEntity<Void> forgotPassword(@Valid @RequestBody ForgotPasswordRequest req) {
        authService.forgotPassword(req);
        return ResponseEntity.ok().build();
    }

    /** Password reset — verify OTP, set new hash, revoke all refresh tokens. */
    @PostMapping("/password/reset")
    public ResponseEntity<Void> resetPassword(@Valid @RequestBody ResetPasswordRequest req) {
        authService.resetPassword(req);
        return ResponseEntity.noContent().build();
    }

    /** Google Sign-In — verified idToken → link-or-create → token pair. */
    @PostMapping("/google")
    public TokenResponse google(@Valid @RequestBody GoogleLoginRequest req) {
        return authService.loginWithGoogle(req);
    }

    @PostMapping("/login")
    public TokenResponse login(@Valid @RequestBody LoginRequest req) {
        return authService.login(req);
    }

    @PostMapping("/refresh")
    public TokenResponse refresh(@Valid @RequestBody RefreshRequest req) {
        return authService.refresh(req);
    }

    @PostMapping("/logout")
    public ResponseEntity<Void> logout(@Valid @RequestBody RefreshRequest req) {
        authService.logout(req);
        return ResponseEntity.noContent().build();
    }

    private OtpChallengeResponse challengeResponse(String email, OtpChallenge c) {
        return new OtpChallengeResponse(email, c == null ? null : c.getPurpose().name(),
                otpProps.getTtlSeconds(), otpProps.getResendCooldownSeconds());
    }
}
