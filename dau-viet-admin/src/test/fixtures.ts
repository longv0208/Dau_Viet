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
  totalElements: 2,
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
