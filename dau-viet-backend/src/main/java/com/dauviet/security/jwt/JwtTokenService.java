package com.dauviet.security.jwt;

import java.time.Instant;

import org.springframework.security.oauth2.jose.jws.MacAlgorithm;
import org.springframework.security.oauth2.jwt.JwsHeader;
import org.springframework.security.oauth2.jwt.JwtClaimsSet;
import org.springframework.security.oauth2.jwt.JwtEncoder;
import org.springframework.security.oauth2.jwt.JwtEncoderParameters;
import org.springframework.stereotype.Service;

import com.dauviet.user.domain.User;

/**
 * Mints short-lived access tokens. Subject = user UUID; `role` claim feeds
 * the JwtAuthenticationConverter -> ROLE_* authority.
 */
@Service
public class JwtTokenService {

    public static final String ISSUER = "dau-viet-backend";

    private final JwtEncoder encoder;
    private final SecurityTokenProperties props;

    public JwtTokenService(JwtEncoder encoder, SecurityTokenProperties props) {
        this.encoder = encoder;
        this.props = props;
    }

    public String createAccessToken(User user) {
        Instant now = Instant.now();
        JwtClaimsSet claims = JwtClaimsSet.builder()
                .issuer(ISSUER)
                .issuedAt(now)
                .expiresAt(now.plusSeconds(props.getAccessTokenTtlSeconds()))
                .subject(user.getId().toString())
                .claim("role", user.getRole().name())
                .build();
        JwsHeader header = JwsHeader.with(MacAlgorithm.HS256).build();
        return encoder.encode(JwtEncoderParameters.from(header, claims)).getTokenValue();
    }

    public long getAccessTokenTtlSeconds() {
        return props.getAccessTokenTtlSeconds();
    }
}
