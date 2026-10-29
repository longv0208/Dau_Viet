/** Backend DTO fixtures — mirror the real /api/v1 contract shapes. */

export const tokenFixture = {
  accessToken: "test-access-token",
  tokenType: "Bearer",
  expiresIn: 900,
  refreshToken: "test-refresh-token",
  refreshExpiresIn: 1209600,
};

export const adminUserFixture = {
  id: "11111111-1111-1111-1111-111111111111",
  email: "admin@dauviet.local",
  displayName: "Quản trị viên",
  role: "CONTENT_ADMIN",
  status: "ACTIVE",
  emailVerifiedAt: null,
  createdAt: "2026-01-01T00:00:00Z",
};

export const learnerUserFixture = {
  ...adminUserFixture,
  id: "22222222-2222-2222-2222-222222222222",
  email: "learner@dauviet.local",
  displayName: "Học viên",
  role: "LEARNER",
};

export const emptyPageFixture = {
  content: [],
  page: 0,
  size: 20,
  totalElements: 0,
  totalPages: 0,
};

/** PageResponse<AdminEventSummaryResponse>. */
export const eventsPageFixture = {
  ...emptyPageFixture,
  totalElements: 3,
  totalPages: 1,
  content: [
    {
      id: "11111111-1111-1111-1111-111111111111",
      slug: "tran-bach-dang-938",
      title: "Trận Bạch Đằng 938",
      era: "Bắc thuộc lần 3",
      startYear: 938,
      status: "PUBLISHED",
      tags: ["ngô-quyền"],
    },
    {
      id: "22222222-2222-2222-2222-222222222222",
      slug: "dien-bien-phu-1954",
      title: "Chiến thắng Điện Biên Phủ",
      era: "Hiện đại",
      startYear: 1954,
      status: "DRAFT",
      tags: [],
    },
    {
      id: "99999999-9999-9999-9999-999999999999",
      slug: "su-kien-khong-bai-hoc",
      title: "Sự kiện chưa có bài học",
      era: "Hiện đại",
      startYear: 1975,
      status: "DRAFT",
      tags: [],
    },
  ],
};

/** PageResponse<AdminLessonSummaryResponse>. */
export const lessonsPageFixture = {
  ...emptyPageFixture,
  totalElements: 2,
  totalPages: 1,
  content: [
    {
      id: "33333333-3333-3333-3333-333333333333",
      eventId: "11111111-1111-1111-1111-111111111111",
      title: "Vì sao Ngô Quyền thắng trận Bạch Đằng?",
      status: "PUBLISHED",
      currentVersionId: "44444444-4444-4444-4444-444444444444",
      rowVersion: 3,
    },
    {
      id: "55555555-5555-5555-5555-555555555555",
      eventId: "22222222-2222-2222-2222-222222222222",
      title: "Bài học nháp chưa xuất bản",
      status: "DRAFT",
      currentVersionId: null,
      rowVersion: 1,
    },
  ],
};

/** Bạch Đằng-style draft used by builder tests (CONTEXT → EVIDENCE → RECONSTRUCTION → CONCLUSION). */
export const draftFixture = JSON.stringify({
  schemaVersion: 1,
  stages: [
    {
      id: "stage-context",
      type: "CONTEXT",
      title: "Bối cảnh 938",
      required: true,
      nextStageIds: ["stage-evidence"],
      activities: [
        {
          id: "act-read-context",
          type: "READ",
          required: true,
          instruction: "Đọc đoạn tư liệu về thời điểm 938",
          config: { text: "Năm 938, quân Nam Hán kéo sang xâm lược…" },
        },
      ],
    },
    {
      id: "stage-evidence",
      type: "EVIDENCE",
      title: "Bằng chứng trận sông",
      required: true,
      nextStageIds: ["stage-reconstruction"],
      activities: [
        {
          id: "act-mc-evidence",
          type: "MULTIPLE_CHOICE",
          required: true,
          instruction: "Vì sao cọc ngầm hiệu quả?",
          config: {
            question: "Yếu tố nào làm cọc ngầm hiệu quả?",
            options: [
              { id: "opt-tide", label: "Thủy triều lên xuống" },
              { id: "opt-wind", label: "Gió mùa" },
            ],
            correctOptionIds: ["opt-tide"],
          },
          feedback: {
            COMPLETED: "Chính xác.",
            INCORRECT: "Chưa đúng — thử lại.",
            PARTIAL: "Đúng một phần.",
            EXHAUSTED: "Hết lượt thử.",
          },
        },
      ],
    },
    {
      id: "stage-reconstruction",
      type: "RECONSTRUCTION",
      title: "Tái dựng diễn biến",
      required: true,
      nextStageIds: ["stage-conclusion"],
      activities: [
        {
          id: "act-order-battle",
          type: "DRAG_ORDER",
          required: true,
          instruction: "Sắp xếp diễn biến trận sông",
          config: {
            items: [
              { id: "it-enter", label: "Quân Nam Hán vào cửa sông lúc triều lên" },
              { id: "it-retreat", label: "Triều xuống, thuyền đâm phải cọc" },
            ],
            expectedOrder: ["it-enter", "it-retreat"],
          },
          feedback: {
            COMPLETED: "Đúng trình tự.",
            INCORRECT: "Sai thứ tự — thử lại.",
            PARTIAL: "Gần đúng thứ tự.",
            EXHAUSTED: "Hết lượt thử.",
          },
        },
      ],
    },
    {
      id: "stage-conclusion",
      type: "CONCLUSION",
      title: "Kết luận",
      required: true,
      nextStageIds: [],
      activities: [],
    },
  ],
  completion: { requireAllRequiredStages: true },
});

/** PageResponse<EvidenceResponse> — Bạch Đằng evidence list. */
export const evidencesPageFixture = {
  ...emptyPageFixture,
  totalElements: 2,
  totalPages: 1,
  content: [
    {
      id: "e1111111-1111-1111-1111-111111111111",
      eventId: "11111111-1111-1111-1111-111111111111",
      title: "Cọc ngầm sông Bạch Đằng",
      evidenceType: "HIEN_VAT",
      description: "Cọc gỗ lim ngâm nước còn sót lại ở đáy sông.",
      sourceTitle: "Bảo tàng Lịch sử Quốc gia",
      sourceAuthor: null,
      sourceUrl: null,
      sourceCitation: null,
      sourcePublishedAt: null,
      reliability: "HIGH",
      relevance: "Bằng chứng vật lý trực tiếp của trận sông.",
      assetId: null,
      status: "APPROVED",
      createdBy: adminUserFixture.id,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
      rowVersion: 1,
    },
    {
      id: "e2222222-2222-2222-2222-222222222222",
      eventId: "11111111-1111-1111-1111-111111111111",
      title: "Đại Việt sử ký toàn thư — trận Bạch Đằng",
      evidenceType: "VAN_BAN",
      description: "Ghi chép của sử thần về chiến thắng năm 938.",
      sourceTitle: "Đại Việt sử ký toàn thư",
      sourceAuthor: "Ngô Sĩ Liên",
      sourceUrl: null,
      sourceCitation: "Toàn thư, quyển V, phần Thuận Thiên",
      sourcePublishedAt: null,
      reliability: "MEDIUM",
      relevance: "Nguồn tư liệu chính về diễn biến trận chiến.",
      assetId: null,
      status: "DRAFT",
      createdBy: adminUserFixture.id,
      createdAt: "2026-01-02T00:00:00Z",
      updatedAt: "2026-01-02T00:00:00Z",
      rowVersion: 1,
    },
  ],
};

/** PageResponse<AssetResponse> — admin asset library. */
export const assetsPageFixture = {
  ...emptyPageFixture,
  totalElements: 1,
  totalPages: 1,
  content: [
    {
      id: "a1111111-1111-1111-1111-111111111111",
      originalFilename: "ban-do-bach-dang.png",
      mimeType: "image/png",
      sizeBytes: 102400,
      state: "ACTIVE",
      altText: "Bản đồ khu vực sông Bạch Đằng",
      createdAt: "2026-01-01T00:00:00Z",
      contentUrl: "/api/v1/admin/assets/a1111111-1111-1111-1111-111111111111/content",
    },
  ],
};

/** PageResponse<SceneSummaryResponse> — animation scenes for the builder picker. */
export const animationScenesPageFixture = {
  ...emptyPageFixture,
  totalElements: 2,
  totalPages: 1,
  content: [
    {
      id: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa",
      templateId: "88888888-8888-8888-8888-888888888888",
      rendererCode: "RIVER_TIDE",
      eventId: "11111111-1111-1111-1111-111111111111",
      title: "Trận thủy chiến Bạch Đằng 938",
      status: "PUBLISHED",
      currentVersionId: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb",
      currentVersionNo: 1,
      rowVersion: 4,
      updatedAt: "2026-01-02T00:00:00Z",
    },
    {
      id: "cccccccc-cccc-cccc-cccc-cccccccccccc",
      templateId: "99999999-9999-9999-9999-999999999999",
      rendererCode: "JOURNEY_MAP",
      eventId: "22222222-2222-2222-2222-222222222222",
      title: "Hành trình về Thăng Long 1010",
      status: "PUBLISHED",
      currentVersionId: "dddddddd-dddd-dddd-dddd-dddddddddddd",
      currentVersionNo: 2,
      rowVersion: 7,
      updatedAt: "2026-01-03T00:00:00Z",
    },
    {
      id: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee",
      templateId: "88888888-8888-8888-8888-888888888888",
      rendererCode: "RIVER_TIDE",
      eventId: null,
      title: "Cảnh nháp chưa xuất bản",
      status: "DRAFT",
      currentVersionId: null,
      currentVersionNo: null,
      rowVersion: 1,
      updatedAt: "2026-01-04T00:00:00Z",
    },
    // HTML_WEBVIEW scene — templateId khớp animationTemplatesFixture 'html-webview'.
    {
      id: "dddddddd-dddd-dddd-dddd-dddddddddddd",
      templateId: "d7a11000-0000-4000-8000-000000000001",
      rendererCode: "HTML_WEBVIEW",
      eventId: null,
      title: "Hoạt họa HTML mẫu",
      status: "PUBLISHED",
      currentVersionId: "vvvvvvvv-vvvv-vvvv-vvvv-vvvvvvvvvvvv",
      currentVersionNo: 1,
      rowVersion: 2,
      updatedAt: "2026-01-05T00:00:00Z",
      draftJson: JSON.stringify({
        schemaVersion: 2,
        rendererCode: "HTML_WEBVIEW",
        rendererVersion: 1,
        title: "Hoạt họa HTML mẫu",
        html: {
          filename: "hoat-hoa-mau.html",
          sizeBytes: 8192,
          sha256: "deadbeefcafe",
        },
      }),
    },
  ],
};

/** PageResponse<AnimationTemplateResponse> — animation templates. */
export const animationTemplatesFixture = {
  ...emptyPageFixture,
  totalElements: 4,
  totalPages: 1,
  content: [
    // Template legacy — rendererCode khác HTML_WEBVIEW (test filter).
    {
      id: "88888888-8888-8888-8888-888888888888",
      code: "river-tide",
      name: "Sông triều",
      description: null,
      rendererCode: "RIVER_TIDE",
      rendererVersion: 1,
      schemaVersion: 1,
      capabilitiesJson: null,
      defaultConfigJson: null,
      thumbnailAssetId: null,
      enabled: true,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
    },
    {
      id: "99999999-9999-9999-9999-999999999999",
      code: "journey-map",
      name: "Hành trình",
      description: null,
      rendererCode: "JOURNEY_MAP",
      rendererVersion: 1,
      schemaVersion: 1,
      capabilitiesJson: null,
      defaultConfigJson: null,
      thumbnailAssetId: null,
      enabled: true,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
    },
    // Template HTML dư thừa — code KHÔNG phải chuẩn, xếp trước template
    // chuẩn để test FIX-01 "nhiều HTML templates, template chuẩn không
    // đứng đầu".
    {
      id: "aaaaaaaa-1111-1111-1111-111111111111",
      code: "html-custom",
      name: "HTML tùy biến",
      description: null,
      rendererCode: "HTML_WEBVIEW",
      rendererVersion: 1,
      schemaVersion: 2,
      capabilitiesJson: null,
      defaultConfigJson: null,
      thumbnailAssetId: null,
      enabled: true,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
    },
    // Template CHUẨN — code 'html-webview' khớp AnimationHtmlService + V19.
    {
      id: "d7a11000-0000-4000-8000-000000000001",
      code: "html-webview",
      name: "Hoạt họa HTML",
      description: null,
      rendererCode: "HTML_WEBVIEW",
      rendererVersion: 1,
      schemaVersion: 2,
      capabilitiesJson: null,
      defaultConfigJson: null,
      thumbnailAssetId: null,
      enabled: true,
      createdAt: "2026-01-01T00:00:00Z",
      updatedAt: "2026-01-01T00:00:00Z",
    },
  ],
};

/* ---------- GAME-06 gamification ---------- */

/** GET /admin/events/:id/completion-policies — list version desc. */
export const policiesFixture = [
  {
    id: "p1111111-1111-1111-1111-111111111111",
    eventId: "11111111-1111-1111-1111-111111111111",
    policyVersion: 2,
    status: "DRAFT",
    requiredLessonIds: ["33333333-3333-3333-3333-333333333333"],
    optionalLessonIds: [],
    masteryThreshold: 80,
    publishedAt: null,
    createdAt: "2026-01-02T00:00:00Z",
  },
  {
    id: "p0000000-0000-0000-0000-000000000001",
    eventId: "11111111-1111-1111-1111-111111111111",
    policyVersion: 1,
    status: "PUBLISHED",
    requiredLessonIds: ["33333333-3333-3333-3333-333333333333"],
    optionalLessonIds: [],
    masteryThreshold: 70,
    publishedAt: "2026-01-01T00:00:00Z",
    createdAt: "2026-01-01T00:00:00Z",
  },
];

/** PageResponse<AdminDossierSummary>. */
export const dossiersPageFixture = {
  ...emptyPageFixture,
  totalElements: 2,
  totalPages: 1,
  content: [
    {
      id: "d1111111-1111-1111-1111-111111111111",
      canonicalCode: "ngo-quyen",
      dossierType: "PERSON",
      title: "Ngô Quyền",
      summary: "Thủ lĩnh trận Bạch Đằng 938.",
      status: "PUBLISHED",
      dossierVersion: 1,
      assetId: null,
      eventCount: 1,
      updatedAt: "2026-01-02T00:00:00Z",
    },
    {
      id: "d2222222-2222-2222-2222-222222222222",
      canonicalCode: "song-bach-dang",
      dossierType: "LOCATION",
      title: "Sông Bạch Đằng",
      summary: "Trận địa thủy chiến năm 938.",
      status: "DRAFT",
      dossierVersion: 1,
      assetId: null,
      eventCount: 0,
      updatedAt: "2026-01-03T00:00:00Z",
    },
  ],
};

/** GET /admin/events/:id/dossiers — linked rows theo sort_order. */
export const eventDossiersFixture = [
  {
    dossierId: "d1111111-1111-1111-1111-111111111111",
    canonicalCode: "ngo-quyen",
    title: "Ngô Quyền",
    dossierType: "PERSON",
    status: "PUBLISHED",
    displayOrder: 1,
  },
];

/** GET /admin/items/:id/rule/history — revision desc. */
export const ruleHistoryFixture = [
  {
    id: "r3333333-3333-3333-3333-333333333333",
    ruleType: "RULE_V2",
    lessonId: null,
    threshold: null,
    ruleVersion: 2,
    revision: 2,
    active: true,
    conditionJson: { type: "COLLECTION_COUNT", threshold: 5 },
    ruleMetadata: null,
    createdAt: "2026-01-03T00:00:00Z",
    grantCount: 4,
  },
  {
    id: "r2222222-2222-2222-2222-222222222222",
    ruleType: "COLLECTION_COUNT",
    lessonId: null,
    threshold: 3,
    ruleVersion: 1,
    revision: 1,
    active: false,
    conditionJson: { type: "COLLECTION_COUNT", threshold: 3 },
    ruleMetadata: null,
    createdAt: "2026-01-01T00:00:00Z",
    grantCount: 12,
  },
];

/** GET /admin/lesson-templates returns a plain array (not paged). */
export const templatesFixture = [
  {
    id: "66666666-6666-6666-6666-666666666666",
    code: "EVENT_INVESTIGATION",
    name: "Điều tra sự kiện",
    description: "Khung stage chuẩn cho bài điều tra sự kiện lịch sử",
    schemaVersion: 1,
    presetJson: JSON.stringify({
      schemaVersion: 1,
      stages: [
        {
          id: "tpl-context",
          type: "CONTEXT",
          title: "Bối cảnh (mẫu)",
          required: true,
          nextStageIds: ["tpl-evidence"],
          activities: [
            {
              id: "tpl-act-read",
              type: "READ",
              required: false,
              instruction: "Đọc tư liệu nền",
              config: { text: "Nội dung mẫu…" },
            },
          ],
        },
        {
          id: "tpl-evidence",
          type: "EVIDENCE",
          title: "Bằng chứng (mẫu)",
          required: true,
          nextStageIds: [],
          activities: [],
        },
      ],
    }),
    enabled: true,
    createdAt: "2026-01-01T00:00:00Z",
    updatedAt: "2026-01-01T00:00:00Z",
  },
];
