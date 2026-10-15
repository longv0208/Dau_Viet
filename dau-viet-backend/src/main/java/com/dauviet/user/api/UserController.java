package com.dauviet.user.api;

import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.security.JwtSubjectExtractor;
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
    private final JwtSubjectExtractor subjects;

    public UserController(UserService userService, UserMapper mapper,
                          JwtSubjectExtractor subjects) {
        this.userService = userService;
        this.mapper = mapper;
        this.subjects = subjects;
    }

    @GetMapping("/me")
    public UserProfileDto me(@AuthenticationPrincipal Jwt jwt) {
        return mapper.toProfileDto(userService.getProfile(subjects.userId(jwt)));
    }
}
