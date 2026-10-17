package com.dauviet.lesson.domain;

/** Upload rejected: unsupported mime type, oversize, empty file or read failure. */
public class InvalidAssetUploadException extends RuntimeException {
    public InvalidAssetUploadException(String message) { super(message); }
    public InvalidAssetUploadException(String message, Throwable cause) { super(message, cause); }
}
