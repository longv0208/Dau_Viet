package com.dauviet.auth.domain;

/**
 * A Google sign-in presented an email matching a local account whose own
 * email is not yet verified. Auto-linking here would let a Google account
 * capture a pending local registration, so we refuse (403
 * GOOGLE_EMAIL_UNVERIFIED) and ask the user to finish OTP verification.
 */
public class GoogleEmailUnverifiedException extends RuntimeException {

    public GoogleEmailUnverifiedException() {
        super("Local account email not verified");
    }
}
