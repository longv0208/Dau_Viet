/** Mirrors com.dauviet.user.api.dto.UserProfileDto. */

export type UserRole = "LEARNER" | "CONTENT_ADMIN";

export interface UserProfileDto {
  id: string;
  email: string;
  displayName: string;
  role: UserRole;
  status: string;
  emailVerifiedAt: string | null;
  createdAt: string;
}
