import { redirect } from "next/navigation";

/** Root route: enter the admin area; middleware redirects to /login if unauthenticated. */
export default function Home() {
  redirect("/dashboard");
}
