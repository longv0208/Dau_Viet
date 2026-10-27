package com.dauviet.shop.api;

import java.util.List;
import java.util.UUID;

import jakarta.validation.Valid;

import org.springframework.http.HttpStatus;
import org.springframework.validation.annotation.Validated;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

import com.dauviet.shop.api.dto.AdminIslandShopDtos.AdminShopOfferResponse;
import com.dauviet.shop.api.dto.AdminIslandShopDtos.CreateShopOfferRequest;
import com.dauviet.shop.api.dto.AdminIslandShopDtos.UpdateShopOfferRequest;
import com.dauviet.shop.application.AdminIslandShopService;

/**
 * Admin API quản lý Cửa hàng Đảo Di Sản (ISLAND-05 Part C).
 */
@RestController
@Validated
@RequestMapping("/api/v1/admin/island-shop")
public class AdminIslandShopController {

    private final AdminIslandShopService service;

    public AdminIslandShopController(AdminIslandShopService service) {
        this.service = service;
    }

    @GetMapping
    public List<AdminShopOfferResponse> listOffers() {
        return service.listOffers();
    }

    @GetMapping("/{itemId}")
    public AdminShopOfferResponse getOffer(@PathVariable UUID itemId) {
        return service.getOffer(itemId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public AdminShopOfferResponse createOffer(
            @Valid @RequestBody CreateShopOfferRequest req) {
        return service.createOffer(req);
    }

    @PutMapping("/{itemId}")
    public AdminShopOfferResponse updateOffer(
            @PathVariable UUID itemId,
            @Valid @RequestBody UpdateShopOfferRequest req) {
        return service.updateOffer(itemId, req);
    }

    @PatchMapping("/{itemId}")
    public AdminShopOfferResponse patchOffer(
            @PathVariable UUID itemId,
            @Valid @RequestBody UpdateShopOfferRequest req) {
        return service.updateOffer(itemId, req);
    }

    @DeleteMapping("/{itemId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void removeOffer(@PathVariable UUID itemId) {
        service.removeOffer(itemId);
    }
}
