package com.dauviet.user.application;

import java.util.UUID;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import com.dauviet.common.error.ResourceNotFoundException;
import com.dauviet.user.infrastructure.persistence.UserRepository;
import com.dauviet.user.domain.User;

/** Read-side account lookups. */
@Service
public class UserService {

    private final UserRepository users;

    public UserService(UserRepository users) {
        this.users = users;
    }

    @Transactional(readOnly = true)
    public User getProfile(UUID id) {
        return users.findById(id)
                .orElseThrow(() -> new ResourceNotFoundException("User not found"));
    }
}
