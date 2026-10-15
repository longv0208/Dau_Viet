package com.dauviet.auth.domain;

/** Registration attempted with an email that already exists -> 409. */
public class EmailTakenException extends RuntimeException {

    public EmailTakenException() {
        super("Email already registered");
    }
}
