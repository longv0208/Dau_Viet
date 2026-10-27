package com.dauviet.shop.api;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.common.security.JwtSubjectExtractor;
import com.dauviet.shop.api.dto.PurchaseRequest;
import com.dauviet.shop.api.dto.PurchaseResponse;
import com.dauviet.shop.api.dto.ShopItemResponse;
import com.dauviet.shop.application.ShopService;

import jakarta.validation.Valid;

/**
 * Shop Đảo Di Sản (ISLAND-BE-01). Listing công khai cho authenticated
 * learner; purchase luôn qua Idempotency-Key + JWT. Identity từ JWT —
 * không nhận userId từ client, giá lấy server-side, không tin body.
 */
@RestController
@RequestMapping("/api/v1")
public class ShopController {

    private final ShopService service;
    private final JwtSubjectExtractor subjects;

    public ShopController(ShopService service,
                          JwtSubjectExtractor subjects) {
        this.service = service;
        this.subjects = subjects;
    }

    /** Listing SKU đang bán + trưng bày sắp mở bán. */
    @GetMapping("/shop/items")
    public List<ShopItemResponse> items() {
        return service.items();
    }

    /**
     * Mua vật phẩm bằng Điểm Sử Ký — idempotent qua Idempotency-Key
     * (bắt buộc, không mặc định). 201 = lần đầu; 200 = replay trả stored.
     */
    @PostMapping("/me/shop/purchases")
    public ResponseEntity<PurchaseResponse> purchase(
            @AuthenticationPrincipal Jwt jwt,
            @Valid @RequestBody PurchaseRequest req,
            @RequestHeader("Idempotency-Key") String idempotencyKey) {
        PurchaseResponse res = service.purchase(subjects.userId(jwt), req,
                idempotencyKey);
        return ResponseEntity.status(HttpStatus.CREATED).body(res);
    }
}
