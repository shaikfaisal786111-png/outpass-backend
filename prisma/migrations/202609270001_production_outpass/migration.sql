-- Back up the production database before applying this migration.
-- Existing records did not contain a request timestamp; requestedAt is initialized
-- when this migration runs, so historic monthly counts start from this release.
CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TYPE "Role" AS ENUM ('HOD', 'GUARD');
CREATE TYPE "OutpassStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'EXITED', 'EXPIRED', 'CANCELLED');

CREATE TABLE "User" (
  "id" TEXT NOT NULL,
  "email" TEXT NOT NULL,
  "passwordHash" TEXT NOT NULL,
  "role" "Role" NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "User_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "User_email_key" ON "User"("email");

CREATE TABLE "Student" (
  "id" TEXT NOT NULL,
  "rollNo" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "Student_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "Student_rollNo_key" ON "Student"("rollNo");

ALTER TABLE "Outpass" ADD COLUMN "studentId" TEXT;
ALTER TABLE "Outpass" ADD COLUMN "leaveAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "Outpass" ADD COLUMN "returnAt" TIMESTAMP(3) NOT NULL DEFAULT (CURRENT_TIMESTAMP + INTERVAL '8 hours');
ALTER TABLE "Outpass" ADD COLUMN "requestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "Outpass" ADD COLUMN "approvedAt" TIMESTAMP(3);
ALTER TABLE "Outpass" ADD COLUMN "approvedById" TEXT;
ALTER TABLE "Outpass" ADD COLUMN "rejectedAt" TIMESTAMP(3);
ALTER TABLE "Outpass" ADD COLUMN "rejectNote" TEXT;
ALTER TABLE "Outpass" ADD COLUMN "exitedAt" TIMESTAMP(3);
ALTER TABLE "Outpass" ADD COLUMN "expiresAt" TIMESTAMP(3);
ALTER TABLE "Outpass" ADD COLUMN "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
ALTER TABLE "Outpass" ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

INSERT INTO "Student" ("id", "rollNo", "name", "createdAt", "updatedAt")
SELECT gen_random_uuid()::text, UPPER(TRIM("rollNo")), MAX("name"), CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
FROM "Outpass"
GROUP BY UPPER(TRIM("rollNo"));

UPDATE "Outpass" AS o SET "studentId" = s."id"
FROM "Student" AS s WHERE s."rollNo" = UPPER(TRIM(o."rollNo"));
ALTER TABLE "Outpass" ALTER COLUMN "studentId" SET NOT NULL;

ALTER TABLE "Outpass" ALTER COLUMN "status" DROP DEFAULT;
ALTER TABLE "Outpass" ALTER COLUMN "status" TYPE "OutpassStatus" USING (
  CASE "status"
    WHEN 'Pending' THEN 'PENDING'::"OutpassStatus"
    WHEN 'Approved' THEN 'APPROVED'::"OutpassStatus"
    WHEN 'Used' THEN 'EXITED'::"OutpassStatus"
    WHEN 'Rejected' THEN 'REJECTED'::"OutpassStatus"
    ELSE 'PENDING'::"OutpassStatus"
  END
);
ALTER TABLE "Outpass" ALTER COLUMN "status" SET DEFAULT 'PENDING';
ALTER TABLE "Outpass" ADD CONSTRAINT "Outpass_studentId_fkey" FOREIGN KEY ("studentId") REFERENCES "Student"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "Outpass" ADD CONSTRAINT "Outpass_approvedById_fkey" FOREIGN KEY ("approvedById") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
CREATE INDEX "Outpass_studentId_requestedAt_idx" ON "Outpass"("studentId", "requestedAt");
CREATE INDEX "Outpass_status_requestedAt_idx" ON "Outpass"("status", "requestedAt");
CREATE UNIQUE INDEX "one_active_outpass_per_student" ON "Outpass"("studentId") WHERE "status" IN ('PENDING', 'APPROVED');

CREATE TABLE "AuditLog" (
  "id" TEXT NOT NULL,
  "action" TEXT NOT NULL,
  "metadata" JSONB,
  "outpassId" TEXT,
  "actorId" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "AuditLog_pkey" PRIMARY KEY ("id")
);
ALTER TABLE "AuditLog" ADD CONSTRAINT "AuditLog_outpassId_fkey" FOREIGN KEY ("outpassId") REFERENCES "Outpass"("id") ON DELETE SET NULL ON UPDATE CASCADE;
ALTER TABLE "AuditLog" ADD CONSTRAINT "AuditLog_actorId_fkey" FOREIGN KEY ("actorId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
CREATE INDEX "AuditLog_outpassId_createdAt_idx" ON "AuditLog"("outpassId", "createdAt");
