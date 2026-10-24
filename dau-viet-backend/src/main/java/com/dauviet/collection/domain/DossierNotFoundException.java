package com.dauviet.collection.domain;

/**
 * Dossier không tồn tại / không được phép thấy (GAME-04): DRAFT luôn
 * invisible, ARCHIVED chưa unlock cũng 404 — không phân biệt "không có" và
 * "không được xem" để tránh dò tồn tại.
 */
public class DossierNotFoundException extends RuntimeException {

    public DossierNotFoundException(String message) {
        super(message);
    }
}
