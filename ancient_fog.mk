#
# Copyright (C) 2022 The ancientOS Project
#
# SPDX-License-Identifier: Apache-2.0
#

# Inherit from those products. Most specific first.
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base_telephony.mk)

# Inherit some common ancient stuff.
$(call inherit-product, vendor/ancient/config/common_full_phone.mk)
ANCIENT_OFFICIAL := true
USE_PIXEL_CHARGING := true
TARGET_BOOT_ANIMATION_RES := 720

# Inherit from fog device
$(call inherit-product, device/xiaomi/fog/device.mk)

PRODUCT_NAME := ancient_fog
PRODUCT_DEVICE := fog
PRODUCT_MANUFACTURER := Xiaomi
PRODUCT_BRAND := Redmi
PRODUCT_MODEL := Redmi 10C

PRODUCT_GMS_CLIENTID_BASE := android-xiaomi

PRODUCT_BUILD_PROP_OVERRIDES += \
    PRIVATE_BUILD_DESC="sunfish-user 11 RQ2A.210505.002 7246365 release-keys" \

BUILD_FINGERPRINT := "google/sunfish/sunfish:11/RQ2A.210505.002/7246365:user/release-keys"
