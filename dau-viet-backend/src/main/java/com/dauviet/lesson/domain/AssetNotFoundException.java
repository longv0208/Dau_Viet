package com.dauviet.lesson.domain;

public class AssetNotFoundException extends RuntimeException {
    public AssetNotFoundException(String message) { super(message); }
}
