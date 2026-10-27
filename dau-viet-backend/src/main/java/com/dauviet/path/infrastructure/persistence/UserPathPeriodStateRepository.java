package com.dauviet.path.infrastructure.persistence;

import java.util.List;
import java.util.UUID;

import org.springframework.data.jpa.repository.JpaRepository;

import com.dauviet.path.domain.UserPathPeriodState;

public interface UserPathPeriodStateRepository extends JpaRepository<UserPathPeriodState, UserPathPeriodState.Key> {

    List<UserPathPeriodState> findByIdUserIdAndIdPathCodeOrderByLastTouchedAtDesc(UUID userId, String pathCode);
}
