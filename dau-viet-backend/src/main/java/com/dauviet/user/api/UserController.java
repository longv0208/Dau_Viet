package com.dauviet.user.api;

import java.util.UUID;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.auth.domain.AuthenticationFailedException;
import com.dauviet.user.api.dto.UserProfileDto;
import com.dauviet.user.api.mapper.UserMapper;
import com.dauviet.user.application.UserService;

/**
 * Authenticated account endpoints. JWT subject carries the user UUID.
 */
@RestController
@RequestMapping("/api/v1/users")
public class UserController {

    private final UserService userService;
    private final UserMapper mapper;

    public UserController(UserService userService, UserMapper mapper) {
        this.userService = userService;
        this.mapper = mapper;
    }

    @GetMapping("/me")
    public UserProfileDto me(@AuthenticationPrincipal Jwt jwt) {
        return mapper.toProfileDto(userService.getProfile(subjectToUuid(jwt)));
    }

    private UUID subjectToUuid(Jwt jwt) {
        try {
            return UUID.fromString(jwt.getSubject());
        } catch (RuntimeException ex) {
            // Defensive: a token that passed signature/expiry checks but has a
            // malformed subject is still an authentication failure.
            throw new AuthenticationFailedException();
        }
    }
}
