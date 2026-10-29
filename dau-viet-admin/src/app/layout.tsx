import type { Metadata } from "next";
import { Be_Vietnam_Pro, Noto_Serif, Press_Start_2P } from "next/font/google";
import { Toaster } from "sonner";

import { QueryProvider } from "@/components/query-provider";

import "./globals.css";

const beVietnamPro = Be_Vietnam_Pro({
  subsets: ["vietnamese", "latin"],
  weight: ["400", "500", "600", "700"],
  variable: "--font-sans",
});

const notoSerif = Noto_Serif({
  subsets: ["vietnamese", "latin"],
  weight: ["600", "700"],
  variable: "--font-display",
});

const pressStart2P = Press_Start_2P({
  subsets: ["latin"],
  weight: ["400"],
  variable: "--font-pixel",
});

export const metadata: Metadata = {
  title: "Dấu Việt — Quản trị nội dung",
  description: "Hệ thống quản trị nội dung học lịch sử Dấu Việt",
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="vi" className={`${beVietnamPro.variable} ${notoSerif.variable} ${pressStart2P.variable}`}>
      <body className="font-sans antialiased">
        <QueryProvider>{children}</QueryProvider>
        <Toaster richColors position="top-right" />
      </body>
    </html>
  );
}
