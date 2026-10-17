import { describe, expect, it } from "vitest";

import { assetContentSrc, validateAssetFile } from "./asset-api";

const PNG = new File([new Uint8Array(10)], "a.png", { type: "image/png" });

describe("validateAssetFile", () => {
  it("accepts a normal PNG", () => {
    expect(validateAssetFile(PNG)).toBeNull();
  });
  it("rejects unsupported mime", () => {
    const gif = new File([new Uint8Array(5)], "a.gif", { type: "image/gif" });
    expect(validateAssetFile(gif)).toMatch(/Định dạng không hỗ trợ/);
  });
  it("rejects empty file", () => {
    const empty = new File([], "a.png", { type: "image/png" });
    expect(validateAssetFile(empty)).toMatch(/rỗng/);
  });
  it("rejects file over 10 MB", () => {
    const big = new File([new Uint8Array(11 * 1024 * 1024)], "big.png", { type: "image/png" });
    expect(validateAssetFile(big)).toMatch(/vượt quá 10 MB/);
  });
  it("accepts file just under 10 MB", () => {
    const ok = new File([new Uint8Array(9 * 1024 * 1024)], "ok.png", { type: "image/png" });
    expect(validateAssetFile(ok)).toBeNull();
  });
});

describe("assetContentSrc", () => {
  it("maps backend contentUrl onto the BFF proxy path", () => {
    expect(
      assetContentSrc("/api/v1/admin/assets/abc/content"),
    ).toBe("/api/proxy/admin/assets/abc/content");
  });
});
