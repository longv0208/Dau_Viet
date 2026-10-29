import { execFileSync } from 'node:child_process';
import crypto from 'node:crypto';

const API_BASE_URL = (process.env.API_BASE_URL || 'http://localhost:8080').replace(/\/+$/, '');
const PG_CONTAINER = process.env.PG_CONTAINER || 'dauviet-postgres';
const PG_USER = process.env.PG_USER || 'dauviet';
const PG_DB = process.env.PG_DB || 'dauviet';

const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function assertUuid(val, label = 'uuid') {
  if (typeof val !== 'string' || !UUID_RE.test(val)) {
    throw new Error(`Invalid ${label}: ${String(val)}`);
  }
  return val;
}

function runPsql(sql) {
  return execFileSync(
    'docker',
    ['exec', '-i', PG_CONTAINER, 'psql', '-U', PG_USER, '-d', PG_DB, '-v', 'ON_ERROR_STOP=1', '-At'],
    {
      input: sql,
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
    },
  ).trim();
}

async function apiRequest(path, { method = 'GET', token = null, body = undefined, headers = {} } = {}) {
  const reqHeaders = {
    Accept: 'application/json',
    ...headers,
  };
  if (token) {
    reqHeaders.Authorization = `Bearer ${token}`;
  }
  if (body !== undefined) {
    reqHeaders['Content-Type'] = 'application/json';
  }
  const res = await fetch(`${API_BASE_URL}${path}`, {
    method,
    headers: reqHeaders,
    body: body !== undefined ? JSON.stringify(body) : undefined,
  });
  const text = await res.text();
  let json = null;
  if (text) {
    try {
      json = JSON.parse(text);
    } catch {
      json = { raw: text };
    }
  }
  return { status: res.status, ok: res.ok, data: json };
}

function buildLessonDraft({ runId, versionTag }) {
  // Answer keys are kept inside server draft payload only and never logged.
  return {
    schemaVersion: 1,
    stages: [
      {
        id: 'stage-context',
        type: 'CONTEXT',
        title: `Bối cảnh lịch sử (${versionTag})`,
        required: true,
        nextStageIds: ['stage-verify'],
        activities: [
          {
            id: 'act-read-context',
            type: 'READ',
            instruction: `Đọc tư liệu bối cảnh E2E (${versionTag}) trước khi chuyển sang bước kiểm chứng.`,
            required: true,
            config: {
              title: `Tư liệu E2E ${runId} (${versionTag})`,
              body: 'Sử liệu ghi nhận quân dân Đại Việt tận dụng nhịp thủy triều rút nhanh để tổ chức trận địa phản công.',
            },
            feedback: {
              COMPLETED: 'Phản hồi từ server: Đã ghi nhận hoàn thành đọc tư liệu bối cảnh.',
            },
          },
        ],
      },
      {
        id: 'stage-verify',
        type: 'VERIFICATION',
        title: `Kiểm chứng tư liệu (${versionTag})`,
        required: true,
        nextStageIds: [],
        activities: [
          {
            id: 'act-mc-verify',
            type: 'MULTIPLE_CHOICE',
            instruction: `Chọn nhận định phù hợp với tư liệu lịch sử (${versionTag}).`,
            required: true,
            config: {
              question: 'Theo tư liệu bối cảnh, yếu tố tự nhiên nào giữ vai trò quyết định khi phản công?',
              options: [
                {
                  id: 'opt-tide-ebb',
                  label: 'Thủy triều rút nhanh làm lộ trận địa ngầm',
                },
                {
                  id: 'opt-monsoon',
                  label: 'Bão tuyết mùa đông làm đóng băng mặt sông',
                },
              ],
              correctOptionIds: ['opt-tide-ebb'],
              minSelections: 1,
              maxSelections: 1,
              maxAttempts: 2,
            },
            feedback: {
              COMPLETED: 'Phản hồi từ server: Chính xác! Thủy triều rút nhanh khớp với sử liệu.',
              INCORRECT: 'Phản hồi từ server: Chưa đúng, hãy xem lại chi tiết thủy triều trong tư liệu.',
            },
          },
        ],
      },
    ],
    completion: {
      requireAllRequiredStages: true,
    },
  };
}

export async function createE2EFixture() {
  const runId = `${Date.now().toString(36)}-${crypto.randomBytes(3).toString('hex')}`;
  const learnerEmail = `e2e.learner.${runId}@dauviet.test`;
  const learnerPassword = `Learner#${runId}!Aa1`;
  const adminEmail = `e2e.admin.${runId}@dauviet.test`;
  const adminPassword = `Admin#${runId}!Aa1`;

  // 1. Check backend health
  const health = await apiRequest('/actuator/health');
  if (!health.ok || health.data?.status !== 'UP') {
    throw new Error(`Backend health check failed at ${API_BASE_URL}/actuator/health`);
  }

  // 2. Register & promote temporary admin account
  const adminReg = await apiRequest('/api/v1/auth/register', {
    method: 'POST',
    body: {
      email: adminEmail,
      password: adminPassword,
      displayName: `E2E Admin ${runId}`,
    },
  });
  if (adminReg.status !== 201) {
    throw new Error(`Failed to register test admin: HTTP ${adminReg.status}`);
  }
  const adminUserId = assertUuid(adminReg.data.id, 'adminUserId');
  runPsql(`UPDATE users SET role = 'CONTENT_ADMIN' WHERE id = '${adminUserId}';`);

  const adminLogin = await apiRequest('/api/v1/auth/login', {
    method: 'POST',
    body: { email: adminEmail, password: adminPassword },
  });
  if (!adminLogin.ok || !adminLogin.data?.accessToken) {
    throw new Error(`Failed to login test admin: HTTP ${adminLogin.status}`);
  }
  const adminToken = adminLogin.data.accessToken;

  // 3. Register & login dedicated test learner
  const learnerReg = await apiRequest('/api/v1/auth/register', {
    method: 'POST',
    body: {
      email: learnerEmail,
      password: learnerPassword,
      displayName: `Học viên E2E ${runId}`,
    },
  });
  if (learnerReg.status !== 201) {
    throw new Error(`Failed to register test learner: HTTP ${learnerReg.status}`);
  }
  const learnerUserId = assertUuid(learnerReg.data.id, 'learnerUserId');

  const learnerLogin = await apiRequest('/api/v1/auth/login', {
    method: 'POST',
    body: { email: learnerEmail, password: learnerPassword },
  });
  if (!learnerLogin.ok || !learnerLogin.data?.accessToken) {
    throw new Error(`Failed to login test learner: HTTP ${learnerLogin.status}`);
  }
  const learnerToken = learnerLogin.data.accessToken;

  // 4. Discover first published event (same order as mobile EventsApiClient: startYear,asc)
  const eventsRes = await apiRequest('/api/v1/events?page=0&size=20&sort=startYear,asc');
  const eventsList = eventsRes.data?.content || eventsRes.data?.items || [];
  if (!eventsRes.ok || eventsList.length === 0) {
    throw new Error(`No published events available from /api/v1/events`);
  }
  const targetEvent =
    eventsList.find((e) => String(e.title || '').toLowerCase().includes('bạch đằng')) ||
    eventsList[0];
  const eventId = assertUuid(targetEvent.id, 'eventId');

  // 5. Discover enabled lesson template via Admin API
  const tplRes = await apiRequest('/api/v1/admin/lesson-templates', {
    token: adminToken,
  });
  const tplList = Array.isArray(tplRes.data) ? tplRes.data : tplRes.data?.content || [];
  if (!tplRes.ok || tplList.length === 0) {
    throw new Error(`No enabled lesson templates found from /api/v1/admin/lesson-templates`);
  }
  const templateId = assertUuid(tplList[0].id, 'templateId');

  // 6. Create & publish v1 of a dedicated E2E lesson under targetEvent (with active coverAssetId)
  const coverAssetIdRaw = runPsql(`
    SELECT id::text FROM assets
    WHERE state = 'ACTIVE' AND mime_type LIKE 'image/%' AND id::text LIKE 'd7a70000-%'
    ORDER BY id DESC
    LIMIT 1;
  `);
  const coverAssetId = coverAssetIdRaw ? assertUuid(coverAssetIdRaw, 'coverAssetId') : null;

  const lessonTitle = `Bài học E2E Di Sản ${runId}`;
  const lessonQuestion = `Câu hỏi lịch sử E2E ${runId}: Yếu tố nào quyết định chiến thắng?`;
  const draftV1 = buildLessonDraft({ runId, versionTag: 'v1' });

  const createLessonRes = await apiRequest('/api/v1/admin/lessons', {
    method: 'POST',
    token: adminToken,
    body: {
      eventId,
      templateId,
      title: lessonTitle,
      centralQuestion: lessonQuestion,
      objectivesJson: JSON.stringify(['Đọc tư liệu bối cảnh', 'Kiểm chứng nhận định lịch sử']),
      draftJson: JSON.stringify(draftV1),
      coverAssetId,
    },
  });
  if (createLessonRes.status !== 201) {
    throw new Error(
      `Failed to create test lesson: HTTP ${createLessonRes.status} ${JSON.stringify(createLessonRes.data)}`,
    );
  }
  const lessonId = assertUuid(createLessonRes.data.id, 'lessonId');

  const publishV1Res = await apiRequest(`/api/v1/admin/lessons/${lessonId}/publish`, {
    method: 'POST',
    token: adminToken,
    body: { releaseNotes: 'Initial E2E publish v1' },
  });
  if (!publishV1Res.ok) {
    throw new Error(
      `Failed to publish lesson v1: HTTP ${publishV1Res.status} ${JSON.stringify(publishV1Res.data)}`,
    );
  }
  const lessonVersionV1Id = assertUuid(publishV1Res.data.lessonVersionId, 'lessonVersionV1Id');

  // 7. Query 2 active placeable DECOR items dynamically from item_catalog (no hardcoded IDs)
  const catalogRaw = runPsql(`
    SELECT id::text || '|' || code || '|' || name
    FROM item_catalog
    WHERE active = true AND placeable = true AND category = 'DECOR'
    ORDER BY code ASC
    LIMIT 2;
  `);
  const catalogLines = catalogRaw.split(/\r?\n/).filter(Boolean);
  if (catalogLines.length < 2) {
    throw new Error(`Expected at least 2 active placeable DECOR items in item_catalog, got ${catalogLines.length}`);
  }
  const [item1IdRaw, item1Code, item1Name] = catalogLines[0].split('|');
  const [item2IdRaw, item2Code, item2Name] = catalogLines[1].split('|');
  const item1 = { id: assertUuid(item1IdRaw, 'item1.id'), code: item1Code, name: item1Name };
  const item2 = { id: assertUuid(item2IdRaw, 'item2.id'), code: item2Code, name: item2Name };

  // Grant both items to the dedicated test learner's inventory
  runPsql(`
    INSERT INTO user_inventory (id, user_id, item_id, acquired_at, acquisition_source, cause_key)
    VALUES
      (gen_random_uuid(), '${learnerUserId}', '${item1.id}', now(), 'ADMIN_GRANT', 'E2E_ITEM_1:${runId}'),
      (gen_random_uuid(), '${learnerUserId}', '${item2.id}', now(), 'ADMIN_GRANT', 'E2E_ITEM_2:${runId}')
    ON CONFLICT (user_id, item_id) DO NOTHING;
  `);

  // Initialize learner's island via real API and place item1 onto slot_1
  const islandInit = await apiRequest('/api/v1/me/island', { token: learnerToken });
  if (!islandInit.ok || !Array.isArray(islandInit.data?.slots)) {
    throw new Error(`Failed to initialize learner island: HTTP ${islandInit.status}`);
  }
  const slots = islandInit.data.slots;
  const occupiedSlot = slots.find((s) => s.unlocked && s.slotIndex === 1) || slots.find((s) => s.unlocked);
  const emptySlot = slots.find((s) => s.unlocked && s.slotId !== occupiedSlot?.slotId);
  const lockedSlot = slots.find((s) => !s.unlocked);
  if (!occupiedSlot || !emptySlot || !lockedSlot) {
    throw new Error(`Island slots missing expected unlocked/locked states`);
  }

  const placeInitRes = await apiRequest(`/api/v1/me/island/placements/${occupiedSlot.slotId}`, {
    method: 'PUT',
    token: learnerToken,
    headers: { 'Idempotency-Key': `e2e-seed-place-${runId}` },
    body: {
      itemId: item1.id,
      expectedRevision: islandInit.data.rowVersion,
    },
  });
  if (!placeInitRes.ok) {
    throw new Error(`Failed to seed initial slot placement: HTTP ${placeInitRes.status}`);
  }

  async function publishLessonV2() {
    const lessonDetail = await apiRequest(`/api/v1/admin/lessons/${lessonId}`, {
      token: adminToken,
    });
    const draftV2 = buildLessonDraft({ runId, versionTag: 'v2-updated' });
    const updateDraftRes = await apiRequest(`/api/v1/admin/lessons/${lessonId}/draft`, {
      method: 'PUT',
      token: adminToken,
      body: {
        draftJson: JSON.stringify(draftV2),
        expectedRowVersion: lessonDetail.data?.rowVersion ?? null,
      },
    });
    if (!updateDraftRes.ok) {
      throw new Error(`Failed to update draft for v2: HTTP ${updateDraftRes.status}`);
    }
    const pubV2 = await apiRequest(`/api/v1/admin/lessons/${lessonId}/publish`, {
      method: 'POST',
      token: adminToken,
      body: { releaseNotes: 'E2E publish v2 while attempt in progress' },
    });
    if (!pubV2.ok) {
      throw new Error(`Failed to publish lesson v2: HTTP ${pubV2.status}`);
    }
    return {
      lessonVersionV2Id: assertUuid(pubV2.data.lessonVersionId, 'lessonVersionV2Id'),
      versionNo: pubV2.data.versionNo,
    };
  }

  async function getLearnerIslandFromApi() {
    const res = await apiRequest('/api/v1/me/island', { token: learnerToken });
    if (!res.ok) {
      throw new Error(`Failed to fetch /api/v1/me/island: HTTP ${res.status}`);
    }
    return res.data;
  }

  async function getLearnerProgressFromApi() {
    const res = await apiRequest('/api/v1/me/progress', { token: learnerToken });
    if (!res.ok) {
      throw new Error(`Failed to fetch /api/v1/me/progress: HTTP ${res.status}`);
    }
    return res.data;
  }

  async function postCompleteAttemptDirect(attemptId, idempotencyKey = null) {
    assertUuid(attemptId, 'attemptId');
    const headers = idempotencyKey ? { 'Idempotency-Key': idempotencyKey } : {};
    return apiRequest(`/api/v1/attempts/${attemptId}/complete`, {
      method: 'POST',
      token: learnerToken,
      headers,
    });
  }

  async function putPlacementDirect(slotId, itemId, expectedRevision = null) {
    assertUuid(slotId, 'slotId');
    assertUuid(itemId, 'itemId');
    return apiRequest(`/api/v1/me/island/placements/${slotId}`, {
      method: 'PUT',
      token: learnerToken,
      headers: { 'Idempotency-Key': `e2e-direct-place-${Date.now()}` },
      body: { itemId, expectedRevision },
    });
  }

  function getAttemptDbCounts(attemptId) {
    assertUuid(attemptId, 'attemptId');
    const out = runPsql(`
      SELECT
        (SELECT count(*) FROM lesson_results WHERE learner_attempt_id = '${attemptId}') || '|' ||
        (SELECT count(*) FROM reward_transactions WHERE user_id = '${learnerUserId}' AND learner_attempt_id = '${attemptId}' AND reward_type = 'EXP') || '|' ||
        (SELECT count(*) FROM reward_transactions WHERE user_id = '${learnerUserId}' AND learner_attempt_id = '${attemptId}' AND reward_type = 'HISTORY_POINTS');
    `);
    const [lessonResultsCount, expRewardsCount, pointsRewardsCount] = out.split('|').map(Number);
    return { lessonResultsCount, expRewardsCount, pointsRewardsCount };
  }

  function setLearnerEnergy(currentEnergy, minutesAgo = 0) {
    const energyInt = Math.max(0, Math.floor(Number(currentEnergy)));
    const minsInt = Math.max(0, Math.floor(Number(minutesAgo)));
    runPsql(`
      INSERT INTO user_energy (user_id, current_energy, last_recovery_at, row_version)
      VALUES ('${learnerUserId}', ${energyInt}, now() - interval '${minsInt} minutes', 0)
      ON CONFLICT (user_id) DO UPDATE
      SET current_energy = EXCLUDED.current_energy,
          last_recovery_at = EXCLUDED.last_recovery_at,
          row_version = user_energy.row_version + 1;
    `);
  }

  function getEnergyTransactions() {
    const raw = runPsql(`
      SELECT direction || '|' || amount::text || '|' || balance_after::text || '|' || reason
      FROM energy_transactions
      WHERE user_id = '${learnerUserId}'
      ORDER BY created_at ASC;
    `);
    if (!raw) return [];
    return raw
      .split(/\r?\n/)
      .filter(Boolean)
      .map((line) => {
        const [direction, amount, balanceAfter, reason] = line.split('|');
        return {
          direction,
          amount: Number(amount),
          balanceAfter: Number(balanceAfter),
          reason,
        };
      });
  }

  async function postUpgradeIslandDirect(expectedRevision = null) {
    return apiRequest('/api/v1/me/island/upgrade', {
      method: 'POST',
      token: learnerToken,
      body: expectedRevision !== null ? { expectedRevision } : {},
    });
  }

  async function getShopItemsFromApi() {
    const res = await apiRequest('/api/v1/shop/items', { token: learnerToken });
    if (!res.ok) {
      throw new Error(`Failed to fetch /api/v1/shop/items: HTTP ${res.status}`);
    }
    return res.data;
  }

  async function postPurchaseShopItemDirect(itemId) {
    assertUuid(itemId, 'itemId');
    return apiRequest('/api/v1/me/shop/purchases', {
      method: 'POST',
      token: learnerToken,
      headers: { 'Idempotency-Key': `e2e-shop-buy-${Date.now()}` },
      body: { itemId },
    });
  }
  function cleanup() {
    runPsql(`
      BEGIN;

      DELETE FROM user_island_placements WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM user_islands WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM user_inventory WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM wallet_transactions WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM wallet_accounts WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM energy_transactions WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM user_energy WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM user_learning_streak_days WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM user_learning_streaks WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM user_dossier_unlocks WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM user_event_progress WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM user_location_unlocks WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM user_path_period_state WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM user_learning_path_enrollments WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM user_evidence WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM reward_transactions WHERE user_id IN ('${learnerUserId}', '${adminUserId}');

      DELETE FROM lesson_results
       WHERE learner_attempt_id IN (
         SELECT id FROM learner_attempts
         WHERE user_id IN ('${learnerUserId}', '${adminUserId}')
            OR lesson_version_id IN (SELECT id FROM lesson_versions WHERE lesson_id = '${lessonId}')
       );
      DELETE FROM activity_attempts
       WHERE learner_attempt_id IN (
         SELECT id FROM learner_attempts
         WHERE user_id IN ('${learnerUserId}', '${adminUserId}')
            OR lesson_version_id IN (SELECT id FROM lesson_versions WHERE lesson_id = '${lessonId}')
       );
      DELETE FROM learner_attempts
       WHERE user_id IN ('${learnerUserId}', '${adminUserId}')
          OR lesson_version_id IN (SELECT id FROM lesson_versions WHERE lesson_id = '${lessonId}');
      DELETE FROM idempotency_records
       WHERE user_id IN ('${learnerUserId}', '${adminUserId}');

      UPDATE lessons SET status = 'DRAFT', current_version_id = NULL WHERE id = '${lessonId}';
      ALTER TABLE lesson_versions DISABLE TRIGGER trg_lesson_versions_immutable;
      DELETE FROM lesson_versions WHERE lesson_id = '${lessonId}';
      ALTER TABLE lesson_versions ENABLE TRIGGER trg_lesson_versions_immutable;
      DELETE FROM lessons WHERE id = '${lessonId}';

      DELETE FROM auth_refresh_tokens WHERE user_id IN ('${learnerUserId}', '${adminUserId}');
      DELETE FROM users WHERE id IN ('${learnerUserId}', '${adminUserId}');

      COMMIT;
    `);
  }

  function verifyCleanup() {
    const remaining = runPsql(`
      SELECT
        (SELECT count(*) FROM users WHERE id IN ('${learnerUserId}', '${adminUserId}')) +
        (SELECT count(*) FROM learner_attempts WHERE user_id = '${learnerUserId}' OR lesson_version_id IN (SELECT id FROM lesson_versions WHERE lesson_id = '${lessonId}')) +
        (SELECT count(*) FROM user_islands WHERE user_id = '${learnerUserId}') +
        (SELECT count(*) FROM user_inventory WHERE user_id = '${learnerUserId}') +
        (SELECT count(*) FROM lessons WHERE id = '${lessonId}') +
        (SELECT count(*) FROM lesson_versions WHERE lesson_id = '${lessonId}');
    `);
    return Number(remaining);
  }

  return {
    runId,
    apiBaseUrl: API_BASE_URL,
    learner: {
      id: learnerUserId,
      email: learnerEmail,
      password: learnerPassword,
    },
    event: {
      id: eventId,
      title: targetEvent.title,
    },
    lesson: {
      id: lessonId,
      title: lessonTitle,
      centralQuestion: lessonQuestion,
      versionV1Id: lessonVersionV1Id,
      readInstruction: 'Đọc tư liệu bối cảnh E2E (v1) trước khi chuyển sang bước kiểm chứng.',
      readServerFeedback: 'Phản hồi từ server: Đã ghi nhận hoàn thành đọc tư liệu bối cảnh.',
      mcInstruction: 'Chọn nhận định phù hợp với tư liệu lịch sử (v1).',
      mcWrongLabel: 'Bão tuyết mùa đông làm đóng băng mặt sông',
      mcCorrectLabel: 'Thủy triều rút nhanh làm lộ trận địa ngầm',
      mcWrongFeedback: 'Phản hồi từ server: Chưa đúng, hãy xem lại chi tiết thủy triều trong tư liệu.',
      mcCorrectFeedback: 'Phản hồi từ server: Chính xác! Thủy triều rút nhanh khớp với sử liệu.',
    },
    island: {
      item1,
      item2,
      occupiedSlot: {
        slotId: occupiedSlot.slotId,
        stableSlotKey: occupiedSlot.stableSlotKey || `slot_${occupiedSlot.slotIndex}`,
        slotIndex: occupiedSlot.slotIndex,
      },
      emptySlot: {
        slotId: emptySlot.slotId,
        stableSlotKey: emptySlot.stableSlotKey || `slot_${emptySlot.slotIndex}`,
        slotIndex: emptySlot.slotIndex,
      },
      lockedSlot: {
        slotId: lockedSlot.slotId,
        stableSlotKey: lockedSlot.stableSlotKey || `slot_${lockedSlot.slotIndex}`,
        slotIndex: lockedSlot.slotIndex,
        tierRequired: lockedSlot.tierRequired,
      },
    },
    publishLessonV2,
    getLearnerIslandFromApi,
    getLearnerProgressFromApi,
    postCompleteAttemptDirect,
    putPlacementDirect,
    getAttemptDbCounts,
    setLearnerEnergy,
    getEnergyTransactions,
    postUpgradeIslandDirect,
    getShopItemsFromApi,
    postPurchaseShopItemDirect,
    cleanup,
    verifyCleanup,
  };
}
