-- Mentor verification gate for the outpass approval workflow.
ALTER TYPE "Role" ADD VALUE IF NOT EXISTS 'MENTOR';
ALTER TYPE "Role" ADD VALUE IF NOT EXISTS 'STUDENT';

ALTER TABLE "Outpass" ADD COLUMN "mentorVerified" BOOLEAN NOT NULL DEFAULT false;
ALTER TABLE "Outpass" ADD COLUMN "mentorId" TEXT;
ALTER TABLE "Outpass" ADD CONSTRAINT "Outpass_mentorId_fkey"
  FOREIGN KEY ("mentorId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
CREATE INDEX "Outpass_mentorVerified_status_requestedAt_idx"
  ON "Outpass"("mentorVerified", "status", "requestedAt");
