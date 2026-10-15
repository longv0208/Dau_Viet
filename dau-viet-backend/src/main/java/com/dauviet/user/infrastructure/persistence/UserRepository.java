package com.dauviet.user.infrastructure.persistence;

import java.util.Optional;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;

import com.dauviet.user.domain.User;

public interface UserRepository extends JpaRepository<User, UUID> {

    /**
     * Case-insensitive lookup matching the ux_users_email_lower functional
     * index. Callers should still normalize input first.
     */
    @Query("select u from User u where lower(u.email) = lower(:email)")
    Optional<User> findByEmailIgnoreCase(@Param("email") String email);
}
