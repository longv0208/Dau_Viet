import type { Config } from "tailwindcss";

/**
 * Dấu Việt admin design tokens (design/ART_DIRECTION.md §3).
 * Components reference semantic names — never raw hex.
 */
const config: Config = {
  content: ["./src/**/*.{ts,tsx}"],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: "var(--color-brand)",
          press: "var(--color-brand-press)",
        },
        surface: {
          DEFAULT: "var(--color-surface)",
          alt: "var(--color-surface-alt)",
        },
        ink: {
          DEFAULT: "var(--color-ink)",
          muted: "var(--color-ink-muted)",
        },
        border: "var(--color-border)",
        destructive: "var(--color-error)",
        error: "var(--color-error)",
        success: "var(--color-success)",
        warning: "var(--color-warning)",
        card: "var(--color-surface-alt)",
        ring: "var(--color-brand)",
        background: "var(--color-surface)",
        foreground: "var(--color-ink)",
        muted: "var(--color-surface-alt)",
        "muted-foreground": "var(--color-ink-muted)",
      },
      borderRadius: {
        sm: "8px",
        md: "12px",
        lg: "16px",
        xl: "24px",
      },
      fontFamily: {
        sans: ["var(--font-sans)", "system-ui", "sans-serif"],
        display: ["var(--font-display)", "serif"],
      },
    },
  },
  plugins: [require("tailwindcss-animate")],
};

export default config;
