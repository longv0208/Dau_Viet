import { setupServer } from "msw/node";

import { handlers } from "./handlers";

/** Shared MSW server for all Vitest suites. */
export const server = setupServer(...handlers);
