package com.dauviet.user.api.mapper;

import org.springframework.stereotype.Component;

import com.dauviet.user.api.dto.UserProfileDto;
import com.dauviet.user.domain.User;

/** Entity -> safe DTO mapping; never exposes passwordHash. */
@Component
public class UserMapper {

    public UserProfileDto toProfileDto(User user) {
        return new UserProfileDto(
                user.getId(),
                user.getEmail(),
                user.getDisplayName(),
                user.getRole().name(),
                user.getStatus().name(),
                user.getEmailVerifiedAt(),
                user.getCreatedAt());
    }
}
