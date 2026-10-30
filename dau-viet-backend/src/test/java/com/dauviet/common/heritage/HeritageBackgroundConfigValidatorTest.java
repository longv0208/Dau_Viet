package com.dauviet.common.heritage;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.util.Optional;
import java.util.UUID;

import org.junit.jupiter.api.Test;

import com.dauviet.lesson.domain.Asset;
import com.dauviet.lesson.domain.AssetNotFoundException;
import com.dauviet.lesson.infrastructure.persistence.AssetRepository;

class HeritageBackgroundConfigValidatorTest {

    @Test
    void parseOrDefault_returnsPaperDefaultWhenNullOrBlank() {
        HeritageBackgroundConfigDto config = HeritageBackgroundConfigValidator.parseOrDefault(null);
        assertThat(config.backgroundAssetId()).isNull();
        assertThat(config.backgroundImageUrl()).isNull();
        assertThat(config.backgroundMode()).isEqualTo("none");
        assertThat(config.focusX()).isEqualTo(0.5);
        assertThat(config.focusY()).isEqualTo(0.35);
        assertThat(config.imageOpacity()).isEqualTo(0.55);
        assertThat(config.fadeStrength()).isEqualTo(0.8);
        assertThat(config.tintPreset()).isEqualTo("warm");
        assertThat(config.enabled()).isTrue();
    }

    @Test
    void validateAndSerialize_resolvesActiveAssetAndDefaultsModeToHeritageFade() {
        AssetRepository repo = mock(AssetRepository.class);
        UUID assetId = UUID.randomUUID();
        Asset activeImage = new Asset();
        activeImage.setId(assetId);
        activeImage.setState("ACTIVE");
        activeImage.setMimeType("image/jpeg");
        when(repo.findById(assetId)).thenReturn(Optional.of(activeImage));

        HeritageBackgroundConfigValidator validator = new HeritageBackgroundConfigValidator(repo);
        HeritageBackgroundConfigDto input = new HeritageBackgroundConfigDto(
                assetId,
                null,
                null,
                0.45,
                0.25,
                0.6,
                0.85,
                "warm",
                true
        );

        String json = validator.validateAndSerialize(input);
        HeritageBackgroundConfigDto roundTrip = HeritageBackgroundConfigValidator.parseOrDefault(json);

        assertThat(roundTrip.backgroundAssetId()).isEqualTo(assetId);
        assertThat(roundTrip.backgroundImageUrl()).isEqualTo("/api/v1/assets/" + assetId + "/content");
        assertThat(roundTrip.backgroundMode()).isEqualTo("heritage_fade");
        assertThat(roundTrip.focusX()).isEqualTo(0.45);
        assertThat(roundTrip.focusY()).isEqualTo(0.25);
        assertThat(roundTrip.imageOpacity()).isEqualTo(0.6);
        assertThat(roundTrip.fadeStrength()).isEqualTo(0.85);
        assertThat(roundTrip.tintPreset()).isEqualTo("warm");
        assertThat(roundTrip.enabled()).isTrue();
    }

    @Test
    void validateAndSerialize_rejectsNonexistentAssetReference() {
        AssetRepository repo = mock(AssetRepository.class);
        UUID missingId = UUID.randomUUID();
        when(repo.findById(missingId)).thenReturn(Optional.empty());

        HeritageBackgroundConfigValidator validator = new HeritageBackgroundConfigValidator(repo);
        HeritageBackgroundConfigDto input = new HeritageBackgroundConfigDto(
                missingId,
                null,
                "heritage_fade",
                0.5,
                0.35,
                0.55,
                0.8,
                "warm",
                true
        );

        assertThatThrownBy(() -> validator.validateAndSerialize(input))
                .isInstanceOf(AssetNotFoundException.class);
    }

    @Test
    void validateAndSerialize_rejectsOutOfRangeValuesAndInvalidMode() {
        HeritageBackgroundConfigValidator validator = new HeritageBackgroundConfigValidator();

        assertThatThrownBy(() -> validator.validateAndSerialize(new HeritageBackgroundConfigDto(
                null, null, "invalid_mode", 0.5, 0.35, 0.55, 0.8, "warm", true
        ))).isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("backgroundMode");

        assertThatThrownBy(() -> validator.validateAndSerialize(new HeritageBackgroundConfigDto(
                null, null, "heritage_fade", 1.5, 0.35, 0.55, 0.8, "warm", true
        ))).isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("focusX");

        assertThatThrownBy(() -> validator.validateAndSerialize(new HeritageBackgroundConfigDto(
                null, null, "heritage_fade", 0.5, 0.35, -0.1, 0.8, "warm", true
        ))).isInstanceOf(IllegalArgumentException.class)
                .hasMessageContaining("imageOpacity");
    }
}
