-- TNPSC Group 4 AI Tutor - initial schema, MySQL 8.4 / InnoDB.
-- Run once against a NEW database. Existing tables are never dropped or replaced.
-- DDL implicitly commits in MySQL; this file is not a rollbackable migration.
-- All DATETIME values are UTC. Set time_zone = '+00:00' on application connections.
-- Local activity dates and timezone names are captured separately for daily goals.
-- Published question revisions/test contents and graded attempts are immutable
-- through the application service. See README.md for transaction-level rules.
-- No credentials, sample learners, fabricated results, or payment card data.

CREATE DATABASE IF NOT EXISTS tnpsc_ai_tutor
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
USE tnpsc_ai_tutor;
SET NAMES utf8mb4;
SET time_zone = '+00:00';

-- 1. Accounts and authentication -----------------------------------------------

CREATE TABLE users (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  email VARCHAR(254) COLLATE utf8mb4_0900_bin NULL COMMENT 'Canonical lowercase email',
  phone_e164 VARCHAR(16) CHARACTER SET ascii COLLATE ascii_bin NULL,
  password_hash VARCHAR(255) CHARACTER SET ascii COLLATE ascii_bin NULL,
  display_name VARCHAR(120) NOT NULL,
  city VARCHAR(120) NULL,
  avatar_object_key VARCHAR(512) NULL,
  account_role ENUM('learner','instructor','admin') NOT NULL DEFAULT 'learner',
  account_status ENUM('pending','active','suspended','closed') NOT NULL DEFAULT 'pending',
  email_verified_at DATETIME(6) NULL,
  phone_verified_at DATETIME(6) NULL,
  last_login_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  closed_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_users_email (email),
  UNIQUE KEY uq_users_phone (phone_e164),
  CONSTRAINT ck_users_contact CHECK (email IS NOT NULL OR phone_e164 IS NOT NULL),
  CONSTRAINT ck_users_name CHECK (CHAR_LENGTH(TRIM(display_name)) > 0)
) ENGINE=InnoDB;

CREATE TABLE user_preferences (
  user_id BIGINT UNSIGNED NOT NULL,
  theme ENUM('system','light','dark') NOT NULL DEFAULT 'system',
  tutor_language ENUM('ta','en','bilingual') NOT NULL DEFAULT 'bilingual',
  timezone_name VARCHAR(64) NOT NULL DEFAULT 'Asia/Kolkata',
  sidebar_collapsed BOOLEAN NOT NULL DEFAULT FALSE,
  email_notifications_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (user_id),
  CONSTRAINT fk_preferences_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT ck_preferences_flags CHECK (sidebar_collapsed IN (0,1) AND email_notifications_enabled IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE auth_sessions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  refresh_token_hash BINARY(32) NOT NULL COMMENT 'SHA-256 of a random refresh token; never the token',
  user_agent VARCHAR(512) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  expires_at DATETIME(6) NOT NULL,
  last_used_at DATETIME(6) NULL,
  revoked_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_session_token (refresh_token_hash),
  KEY ix_sessions_user_expiry (user_id, expires_at),
  KEY ix_sessions_cleanup (expires_at),
  CONSTRAINT fk_sessions_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT ck_session_expiry CHECK (expires_at > created_at)
) ENGINE=InnoDB;

CREATE TABLE auth_challenges (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NULL,
  purpose ENUM('login','verify_email','verify_phone','reset_password') NOT NULL,
  destination VARCHAR(254) NOT NULL,
  channel ENUM('email','sms') NOT NULL,
  secret_hash BINARY(32) NOT NULL COMMENT 'HMAC of OTP/token using a server-side key',
  failed_attempts SMALLINT UNSIGNED NOT NULL DEFAULT 0,
  max_attempts SMALLINT UNSIGNED NOT NULL DEFAULT 5,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  expires_at DATETIME(6) NOT NULL,
  consumed_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  KEY ix_challenge_destination (destination, purpose, created_at),
  KEY ix_challenge_cleanup (expires_at),
  CONSTRAINT fk_challenge_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT ck_challenge_attempts CHECK (max_attempts > 0 AND failed_attempts <= max_attempts),
  CONSTRAINT ck_challenge_expiry CHECK (expires_at > created_at)
) ENGINE=InnoDB;

-- 2. Versioned curriculum and learner preferences ------------------------------

CREATE TABLE exams (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  name_en VARCHAR(200) NOT NULL,
  name_ta VARCHAR(200) NULL,
  examining_body VARCHAR(160) NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  UNIQUE KEY uq_exam_code (code),
  CONSTRAINT ck_exam_active CHECK (is_active IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE syllabus_versions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  exam_id BIGINT UNSIGNED NOT NULL,
  version_code VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  title VARCHAR(200) NOT NULL,
  publication_status ENUM('draft','published','archived') NOT NULL DEFAULT 'draft',
  paper_code VARCHAR(32) NULL,
  total_questions SMALLINT UNSIGNED NOT NULL,
  total_marks DECIMAL(8,2) NOT NULL,
  duration_seconds INT UNSIGNED NOT NULL,
  source_url VARCHAR(2048) NULL,
  effective_from DATE NULL,
  published_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  UNIQUE KEY uq_syllabus_exam_version (exam_id, version_code),
  KEY ix_syllabus_publication (exam_id, publication_status),
  CONSTRAINT fk_syllabus_exam FOREIGN KEY (exam_id) REFERENCES exams (id),
  CONSTRAINT ck_syllabus_pattern CHECK (total_questions > 0 AND total_marks > 0 AND duration_seconds > 0)
) ENGINE=InnoDB;

CREATE TABLE syllabus_sections (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  syllabus_version_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  title_en VARCHAR(160) NOT NULL,
  title_ta VARCHAR(160) NULL,
  part_code VARCHAR(16) NULL,
  expected_questions SMALLINT UNSIGNED NOT NULL,
  expected_marks DECIMAL(8,2) NULL,
  display_order SMALLINT UNSIGNED NOT NULL COMMENT 'Tamil=1, General Studies=2, Aptitude=3 for this application',
  PRIMARY KEY (id),
  UNIQUE KEY uq_section_code (syllabus_version_id, code),
  UNIQUE KEY uq_section_order (syllabus_version_id, display_order),
  UNIQUE KEY uq_section_version (id, syllabus_version_id),
  CONSTRAINT fk_section_version FOREIGN KEY (syllabus_version_id) REFERENCES syllabus_versions (id),
  CONSTRAINT ck_section_marks CHECK (expected_marks IS NULL OR expected_marks >= 0)
) ENGINE=InnoDB;

CREATE TABLE syllabus_topics (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  syllabus_version_id BIGINT UNSIGNED NOT NULL,
  section_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  title_en VARCHAR(255) NOT NULL,
  title_ta VARCHAR(255) NULL,
  summary_en TEXT NOT NULL,
  summary_ta TEXT NULL,
  expected_questions SMALLINT UNSIGNED NULL,
  display_order SMALLINT UNSIGNED NOT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  PRIMARY KEY (id),
  UNIQUE KEY uq_topic_code (syllabus_version_id, code),
  UNIQUE KEY uq_topic_order (section_id, display_order),
  UNIQUE KEY uq_topic_version (id, syllabus_version_id),
  UNIQUE KEY uq_topic_section (id, section_id),
  CONSTRAINT fk_topic_section_version FOREIGN KEY (section_id, syllabus_version_id) REFERENCES syllabus_sections (id, syllabus_version_id),
  CONSTRAINT ck_topic_active CHECK (is_active IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE user_exam_enrollments (
  user_id BIGINT UNSIGNED NOT NULL,
  syllabus_version_id BIGINT UNSIGNED NOT NULL,
  target_exam_year SMALLINT UNSIGNED NULL,
  target_exam_date DATE NULL,
  target_score DECIMAL(8,2) NULL,
  enrollment_status ENUM('active','paused','completed') NOT NULL DEFAULT 'active',
  enrolled_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (user_id, syllabus_version_id),
  CONSTRAINT fk_enrollment_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT fk_enrollment_version FOREIGN KEY (syllabus_version_id) REFERENCES syllabus_versions (id),
  CONSTRAINT ck_enrollment_target CHECK (target_score IS NULL OR target_score >= 0),
  CONSTRAINT ck_enrollment_year CHECK (target_exam_year IS NULL OR target_exam_year BETWEEN 2000 AND 2200)
) ENGINE=InnoDB;

CREATE TABLE user_learning_goals (
  user_id BIGINT UNSIGNED NOT NULL,
  syllabus_version_id BIGINT UNSIGNED NOT NULL,
  effective_from DATE NOT NULL COMMENT 'Local date; history preserves earlier daily targets',
  daily_goal_minutes SMALLINT UNSIGNED NOT NULL DEFAULT 120,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (user_id, syllabus_version_id, effective_from),
  CONSTRAINT fk_goal_enrollment FOREIGN KEY (user_id, syllabus_version_id) REFERENCES user_exam_enrollments (user_id, syllabus_version_id),
  CONSTRAINT ck_goal_minutes CHECK (daily_goal_minutes BETWEEN 5 AND 480)
) ENGINE=InnoDB;

CREATE TABLE user_section_preferences (
  user_id BIGINT UNSIGNED NOT NULL,
  section_id BIGINT UNSIGNED NOT NULL,
  is_expanded BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (user_id, section_id),
  CONSTRAINT fk_section_pref_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT fk_section_pref_section FOREIGN KEY (section_id) REFERENCES syllabus_sections (id),
  CONSTRAINT ck_section_pref_expanded CHECK (is_expanded IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE user_topic_progress (
  user_id BIGINT UNSIGNED NOT NULL,
  topic_id BIGINT UNSIGNED NOT NULL,
  syllabus_version_id BIGINT UNSIGNED NOT NULL,
  study_status ENUM('not_started','in_progress','studied') NOT NULL DEFAULT 'not_started',
  last_opened_at DATETIME(6) NULL,
  last_studied_at DATETIME(6) NULL,
  next_revision_at DATETIME(6) NULL,
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (user_id, topic_id),
  KEY ix_progress_resume (user_id, last_opened_at),
  KEY ix_progress_revision (user_id, next_revision_at),
  CONSTRAINT fk_progress_enrollment FOREIGN KEY (user_id, syllabus_version_id) REFERENCES user_exam_enrollments (user_id, syllabus_version_id),
  CONSTRAINT fk_progress_topic_version FOREIGN KEY (topic_id, syllabus_version_id) REFERENCES syllabus_topics (id, syllabus_version_id),
  CONSTRAINT ck_progress_studied CHECK (study_status <> 'studied' OR last_studied_at IS NOT NULL)
) ENGINE=InnoDB;

CREATE TABLE topic_study_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  topic_id BIGINT UNSIGNED NOT NULL,
  request_key CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  event_type ENUM('studied','revised','unmarked') NOT NULL,
  activity_date DATE NOT NULL,
  timezone_name VARCHAR(64) NOT NULL,
  occurred_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  UNIQUE KEY uq_topic_event_request (user_id, request_key),
  KEY ix_topic_event_daily (user_id, activity_date, event_type),
  CONSTRAINT fk_topic_event_progress FOREIGN KEY (user_id, topic_id) REFERENCES user_topic_progress (user_id, topic_id)
) ENGINE=InnoDB;

-- 3. Question bank, test definitions, contests and attempts ---------------------

CREATE TABLE questions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  topic_id BIGINT UNSIGNED NOT NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  source_type ENUM('editorial','past_paper','ai_generated') NOT NULL DEFAULT 'editorial',
  source_reference VARCHAR(512) NULL,
  question_status ENUM('draft','active','retired') NOT NULL DEFAULT 'draft',
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  KEY ix_question_topic (topic_id, question_status),
  CONSTRAINT fk_question_topic FOREIGN KEY (topic_id) REFERENCES syllabus_topics (id),
  CONSTRAINT fk_question_author FOREIGN KEY (created_by_user_id) REFERENCES users (id)
) ENGINE=InnoDB;

CREATE TABLE question_revisions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  question_id BIGINT UNSIGNED NOT NULL,
  revision_number SMALLINT UNSIGNED NOT NULL,
  prompt_en TEXT NULL,
  prompt_ta TEXT NULL,
  explanation_en TEXT NULL,
  explanation_ta TEXT NULL,
  difficulty ENUM('easy','medium','hard') NOT NULL DEFAULT 'medium',
  review_status ENUM('draft','approved','rejected') NOT NULL DEFAULT 'draft',
  reviewed_by_user_id BIGINT UNSIGNED NULL,
  reviewed_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  UNIQUE KEY uq_question_revision (question_id, revision_number),
  CONSTRAINT fk_revision_question FOREIGN KEY (question_id) REFERENCES questions (id),
  CONSTRAINT fk_revision_reviewer FOREIGN KEY (reviewed_by_user_id) REFERENCES users (id),
  CONSTRAINT ck_revision_prompt CHECK (prompt_en IS NOT NULL OR prompt_ta IS NOT NULL),
  CONSTRAINT ck_revision_number CHECK (revision_number > 0)
) ENGINE=InnoDB;

CREATE TABLE question_options (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  question_revision_id BIGINT UNSIGNED NOT NULL,
  option_key CHAR(1) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  content_en TEXT NULL,
  content_ta TEXT NULL,
  is_correct BOOLEAN NOT NULL DEFAULT FALSE,
  correct_slot TINYINT GENERATED ALWAYS AS (CASE WHEN is_correct = 1 THEN 1 ELSE NULL END) STORED,
  PRIMARY KEY (id),
  UNIQUE KEY uq_option_key (question_revision_id, option_key),
  UNIQUE KEY uq_option_revision_id (question_revision_id, id),
  UNIQUE KEY uq_one_correct_option (question_revision_id, correct_slot),
  CONSTRAINT fk_option_revision FOREIGN KEY (question_revision_id) REFERENCES question_revisions (id),
  CONSTRAINT ck_option_content CHECK (content_en IS NOT NULL OR content_ta IS NOT NULL),
  CONSTRAINT ck_option_correct CHECK (is_correct IN (0,1)),
  CONSTRAINT ck_option_key CHECK (option_key IN ('A','B','C','D','E','F'))
) ENGINE=InnoDB;

CREATE TABLE test_definitions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  syllabus_version_id BIGINT UNSIGNED NOT NULL,
  section_id BIGINT UNSIGNED NULL COMMENT 'NULL for mixed-subject tests',
  code VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  revision_number SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  title VARCHAR(200) NOT NULL,
  test_kind ENUM('mock','practice','contest') NOT NULL,
  publication_status ENUM('draft','published','retired') NOT NULL DEFAULT 'draft',
  duration_seconds INT UNSIGNED NOT NULL,
  created_by_user_id BIGINT UNSIGNED NULL,
  published_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  UNIQUE KEY uq_test_code_revision (syllabus_version_id, code, revision_number),
  UNIQUE KEY uq_test_kind_version (id, test_kind, syllabus_version_id),
  UNIQUE KEY uq_test_version (id, syllabus_version_id),
  CONSTRAINT fk_test_version FOREIGN KEY (syllabus_version_id) REFERENCES syllabus_versions (id),
  CONSTRAINT fk_test_section FOREIGN KEY (section_id, syllabus_version_id) REFERENCES syllabus_sections (id, syllabus_version_id),
  CONSTRAINT fk_test_author FOREIGN KEY (created_by_user_id) REFERENCES users (id),
  CONSTRAINT ck_test_duration CHECK (duration_seconds > 0 AND revision_number > 0)
) ENGINE=InnoDB;

CREATE TABLE test_questions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  test_id BIGINT UNSIGNED NOT NULL,
  question_revision_id BIGINT UNSIGNED NOT NULL,
  display_order SMALLINT UNSIGNED NOT NULL,
  maximum_marks DECIMAL(8,2) NOT NULL DEFAULT 3.00,
  negative_marks DECIMAL(8,2) NOT NULL DEFAULT 0.00,
  PRIMARY KEY (id),
  UNIQUE KEY uq_test_question_order (test_id, display_order),
  UNIQUE KEY uq_test_question_revision (test_id, question_revision_id),
  UNIQUE KEY uq_test_question_source (test_id, id, question_revision_id),
  CONSTRAINT fk_test_question_test FOREIGN KEY (test_id) REFERENCES test_definitions (id),
  CONSTRAINT fk_test_question_revision FOREIGN KEY (question_revision_id) REFERENCES question_revisions (id),
  CONSTRAINT ck_test_question_marks CHECK (maximum_marks > 0 AND negative_marks BETWEEN 0 AND maximum_marks),
  CONSTRAINT ck_test_question_order CHECK (display_order > 0)
) ENGINE=InnoDB;

CREATE TABLE contests (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  syllabus_version_id BIGINT UNSIGNED NOT NULL,
  code VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  title VARCHAR(200) NOT NULL,
  contest_status ENUM('draft','scheduled','open','closed','published','cancelled') NOT NULL DEFAULT 'draft',
  registration_opens_at DATETIME(6) NOT NULL,
  registration_closes_at DATETIME(6) NOT NULL,
  starts_at DATETIME(6) NOT NULL,
  ends_at DATETIME(6) NOT NULL,
  results_published_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  UNIQUE KEY uq_contest_code (code),
  UNIQUE KEY uq_contest_version (id, syllabus_version_id),
  KEY ix_contest_schedule (contest_status, starts_at),
  CONSTRAINT fk_contest_version FOREIGN KEY (syllabus_version_id) REFERENCES syllabus_versions (id),
  CONSTRAINT ck_contest_dates CHECK (registration_opens_at < registration_closes_at AND registration_closes_at <= ends_at AND starts_at < ends_at),
  CONSTRAINT ck_contest_publication CHECK (results_published_at IS NULL OR results_published_at >= ends_at)
) ENGINE=InnoDB;

CREATE TABLE contest_rounds (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  contest_id BIGINT UNSIGNED NOT NULL,
  syllabus_version_id BIGINT UNSIGNED NOT NULL,
  test_id BIGINT UNSIGNED NOT NULL,
  test_kind ENUM('mock','practice','contest') NOT NULL DEFAULT 'contest',
  title VARCHAR(160) NOT NULL,
  display_order SMALLINT UNSIGNED NOT NULL,
  starts_at DATETIME(6) NOT NULL,
  ends_at DATETIME(6) NOT NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_round_order (contest_id, display_order),
  UNIQUE KEY uq_round_test (contest_id, test_id),
  UNIQUE KEY uq_round_attempt_scope (id, contest_id, test_id),
  CONSTRAINT fk_round_contest FOREIGN KEY (contest_id, syllabus_version_id) REFERENCES contests (id, syllabus_version_id),
  CONSTRAINT fk_round_test FOREIGN KEY (test_id, test_kind, syllabus_version_id) REFERENCES test_definitions (id, test_kind, syllabus_version_id),
  CONSTRAINT ck_round_kind CHECK (test_kind = 'contest'),
  CONSTRAINT ck_round_dates CHECK (starts_at < ends_at AND display_order > 0)
) ENGINE=InnoDB;

CREATE TABLE contest_registrations (
  contest_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL,
  registration_status ENUM('registered','withdrawn','disqualified') NOT NULL DEFAULT 'registered',
  registered_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  status_reason VARCHAR(512) NULL,
  PRIMARY KEY (contest_id, user_id),
  KEY ix_registration_user (user_id, registered_at),
  CONSTRAINT fk_registration_contest FOREIGN KEY (contest_id) REFERENCES contests (id),
  CONSTRAINT fk_registration_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE=InnoDB;

CREATE TABLE test_attempts (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  syllabus_version_id BIGINT UNSIGNED NOT NULL,
  test_id BIGINT UNSIGNED NOT NULL,
  test_kind ENUM('mock','practice','contest') NOT NULL,
  contest_id BIGINT UNSIGNED NULL,
  contest_round_id BIGINT UNSIGNED NULL,
  request_key CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  attempt_number SMALLINT UNSIGNED NOT NULL,
  attempt_status ENUM('in_progress','submitted','graded','abandoned','invalidated') NOT NULL DEFAULT 'in_progress',
  current_question_position SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  active_seconds INT UNSIGNED NOT NULL DEFAULT 0,
  started_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  deadline_at DATETIME(6) NOT NULL,
  last_saved_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  submitted_at DATETIME(6) NULL,
  graded_at DATETIME(6) NULL,
  submitted_local_date DATE NULL,
  timezone_name VARCHAR(64) NOT NULL,
  lock_version INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Optimistic concurrency token for autosave',
  PRIMARY KEY (id),
  UNIQUE KEY uq_attempt_request (user_id, request_key),
  UNIQUE KEY uq_attempt_number (user_id, test_id, attempt_number),
  UNIQUE KEY uq_user_scored_round (user_id, contest_round_id),
  UNIQUE KEY uq_attempt_test (id, test_id),
  UNIQUE KEY uq_attempt_owner (id, user_id),
  UNIQUE KEY uq_attempt_owner_version (id, user_id, syllabus_version_id),
  KEY ix_attempt_resume (user_id, attempt_status, last_saved_at),
  KEY ix_attempt_results (user_id, test_kind, submitted_at),
  KEY ix_attempt_daily (user_id, submitted_local_date, attempt_status),
  CONSTRAINT fk_attempt_enrollment FOREIGN KEY (user_id, syllabus_version_id) REFERENCES user_exam_enrollments (user_id, syllabus_version_id),
  CONSTRAINT fk_attempt_test FOREIGN KEY (test_id, test_kind, syllabus_version_id) REFERENCES test_definitions (id, test_kind, syllabus_version_id),
  CONSTRAINT fk_attempt_round FOREIGN KEY (contest_round_id, contest_id, test_id) REFERENCES contest_rounds (id, contest_id, test_id),
  CONSTRAINT fk_attempt_registration FOREIGN KEY (contest_id, user_id) REFERENCES contest_registrations (contest_id, user_id),
  CONSTRAINT ck_attempt_kind CHECK ((test_kind = 'contest' AND contest_id IS NOT NULL AND contest_round_id IS NOT NULL) OR (test_kind <> 'contest' AND contest_id IS NULL AND contest_round_id IS NULL)),
  CONSTRAINT ck_attempt_position CHECK (attempt_number > 0 AND current_question_position > 0),
  CONSTRAINT ck_attempt_dates CHECK (deadline_at > started_at AND (submitted_at IS NULL OR submitted_at >= started_at) AND (graded_at IS NULL OR (submitted_at IS NOT NULL AND graded_at >= submitted_at))),
  CONSTRAINT ck_attempt_submission CHECK (attempt_status NOT IN ('submitted','graded') OR (submitted_at IS NOT NULL AND submitted_local_date IS NOT NULL)),
  CONSTRAINT ck_attempt_graded CHECK (attempt_status <> 'graded' OR graded_at IS NOT NULL)
) ENGINE=InnoDB;

-- Pre-create one answer row per question at attempt start, including skipped ones.
CREATE TABLE attempt_answers (
  attempt_id BIGINT UNSIGNED NOT NULL,
  test_id BIGINT UNSIGNED NOT NULL,
  test_question_id BIGINT UNSIGNED NOT NULL,
  question_revision_id BIGINT UNSIGNED NOT NULL,
  display_order SMALLINT UNSIGNED NOT NULL,
  maximum_marks_snapshot DECIMAL(8,2) NOT NULL,
  negative_marks_snapshot DECIMAL(8,2) NOT NULL DEFAULT 0.00,
  selected_option_id BIGINT UNSIGNED NULL,
  grading_outcome ENUM('ungraded','correct','incorrect','skipped') NOT NULL DEFAULT 'ungraded',
  awarded_marks DECIMAL(8,2) NULL,
  is_flagged BOOLEAN NOT NULL DEFAULT FALSE,
  active_seconds INT UNSIGNED NOT NULL DEFAULT 0,
  answered_at DATETIME(6) NULL,
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (attempt_id, test_question_id),
  UNIQUE KEY uq_answer_order (attempt_id, display_order),
  KEY ix_answer_question (question_revision_id, grading_outcome),
  CONSTRAINT fk_answer_attempt FOREIGN KEY (attempt_id, test_id) REFERENCES test_attempts (id, test_id),
  CONSTRAINT fk_answer_source FOREIGN KEY (test_id, test_question_id, question_revision_id) REFERENCES test_questions (test_id, id, question_revision_id),
  CONSTRAINT fk_answer_option FOREIGN KEY (question_revision_id, selected_option_id) REFERENCES question_options (question_revision_id, id),
  CONSTRAINT ck_answer_marks CHECK (maximum_marks_snapshot > 0 AND negative_marks_snapshot BETWEEN 0 AND maximum_marks_snapshot),
  CONSTRAINT ck_answer_flags CHECK (is_flagged IN (0,1) AND display_order > 0),
  CONSTRAINT ck_answer_grading CHECK (
    (grading_outcome = 'ungraded' AND awarded_marks IS NULL) OR
    (grading_outcome = 'correct' AND selected_option_id IS NOT NULL AND awarded_marks IS NOT NULL AND awarded_marks = maximum_marks_snapshot) OR
    (grading_outcome = 'incorrect' AND selected_option_id IS NOT NULL AND awarded_marks IS NOT NULL AND awarded_marks = -negative_marks_snapshot) OR
    (grading_outcome = 'skipped' AND selected_option_id IS NULL AND awarded_marks IS NOT NULL AND awarded_marks = 0)
  )
) ENGINE=InnoDB;

-- 4. Tutor, voice assets and active learning time -------------------------------

CREATE TABLE media_assets (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  storage_object_key VARCHAR(512) COLLATE utf8mb4_0900_bin NOT NULL,
  media_kind ENUM('voice_input','voice_output','attachment') NOT NULL,
  mime_type VARCHAR(100) NOT NULL,
  byte_size BIGINT UNSIGNED NOT NULL,
  duration_ms INT UNSIGNED NULL,
  processing_status ENUM('pending','ready','failed','deleted') NOT NULL DEFAULT 'pending',
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  expires_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_media_object (storage_object_key),
  UNIQUE KEY uq_media_owner (id, user_id),
  KEY ix_media_expiry (expires_at),
  CONSTRAINT fk_media_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT ck_media_size CHECK (byte_size > 0)
) ENGINE=InnoDB;

CREATE TABLE tutor_conversations (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  syllabus_version_id BIGINT UNSIGNED NOT NULL,
  scope_type ENUM('general','section','topic','attempt_review') NOT NULL,
  section_id BIGINT UNSIGNED NULL,
  topic_id BIGINT UNSIGNED NULL,
  review_attempt_id BIGINT UNSIGNED NULL,
  title VARCHAR(255) NOT NULL,
  tutor_language ENUM('ta','en','bilingual') NOT NULL DEFAULT 'bilingual',
  draft_text TEXT NULL,
  conversation_status ENUM('active','archived') NOT NULL DEFAULT 'active',
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  last_message_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_conversation_owner (id, user_id),
  UNIQUE KEY uq_conversation_owner_version (id, user_id, syllabus_version_id),
  KEY ix_conversation_topic (user_id, topic_id, updated_at),
  KEY ix_conversation_recent (user_id, conversation_status, updated_at),
  CONSTRAINT fk_conversation_enrollment FOREIGN KEY (user_id, syllabus_version_id) REFERENCES user_exam_enrollments (user_id, syllabus_version_id),
  CONSTRAINT fk_conversation_section FOREIGN KEY (section_id, syllabus_version_id) REFERENCES syllabus_sections (id, syllabus_version_id),
  CONSTRAINT fk_conversation_topic FOREIGN KEY (topic_id, section_id) REFERENCES syllabus_topics (id, section_id),
  CONSTRAINT fk_conversation_review FOREIGN KEY (review_attempt_id, user_id, syllabus_version_id) REFERENCES test_attempts (id, user_id, syllabus_version_id),
  CONSTRAINT ck_conversation_scope CHECK (
    (scope_type = 'general' AND section_id IS NULL AND topic_id IS NULL AND review_attempt_id IS NULL) OR
    (scope_type = 'section' AND section_id IS NOT NULL AND topic_id IS NULL AND review_attempt_id IS NULL) OR
    (scope_type = 'topic' AND section_id IS NOT NULL AND topic_id IS NOT NULL AND review_attempt_id IS NULL) OR
    (scope_type = 'attempt_review' AND section_id IS NULL AND topic_id IS NULL AND review_attempt_id IS NOT NULL)
  )
) ENGINE=InnoDB;

CREATE TABLE tutor_messages (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  conversation_id BIGINT UNSIGNED NOT NULL,
  user_id BIGINT UNSIGNED NOT NULL COMMENT 'Conversation owner, including assistant messages',
  request_key CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  sequence_number INT UNSIGNED NOT NULL,
  message_role ENUM('user','assistant','system','tool') NOT NULL,
  content_text MEDIUMTEXT NULL COMMENT 'Text or speech transcript',
  input_mode ENUM('text','voice','generated') NOT NULL DEFAULT 'text',
  media_asset_id BIGINT UNSIGNED NULL,
  reply_to_message_id BIGINT UNSIGNED NULL,
  message_status ENUM('pending','streaming','completed','failed','cancelled') NOT NULL DEFAULT 'pending',
  model_provider VARCHAR(64) NULL,
  model_name VARCHAR(120) NULL,
  provider_request_id VARCHAR(191) CHARACTER SET ascii COLLATE ascii_bin NULL,
  input_tokens INT UNSIGNED NULL,
  output_tokens INT UNSIGNED NULL,
  latency_ms INT UNSIGNED NULL,
  error_code VARCHAR(80) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  completed_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_message_sequence (conversation_id, sequence_number),
  UNIQUE KEY uq_message_request (conversation_id, request_key),
  UNIQUE KEY uq_message_conversation (id, conversation_id),
  CONSTRAINT fk_message_conversation FOREIGN KEY (conversation_id, user_id) REFERENCES tutor_conversations (id, user_id),
  CONSTRAINT fk_message_media FOREIGN KEY (media_asset_id, user_id) REFERENCES media_assets (id, user_id),
  CONSTRAINT fk_message_reply FOREIGN KEY (reply_to_message_id, conversation_id) REFERENCES tutor_messages (id, conversation_id),
  CONSTRAINT ck_message_sequence CHECK (sequence_number > 0),
  CONSTRAINT ck_message_content CHECK (message_status <> 'completed' OR content_text IS NOT NULL OR media_asset_id IS NOT NULL),
  CONSTRAINT ck_message_voice CHECK (input_mode <> 'voice' OR media_asset_id IS NOT NULL)
) ENGINE=InnoDB;

CREATE TABLE study_sessions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  syllabus_version_id BIGINT UNSIGNED NOT NULL,
  request_key CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  topic_id BIGINT UNSIGNED NULL,
  conversation_id BIGINT UNSIGNED NULL,
  attempt_id BIGINT UNSIGNED NULL,
  session_kind ENUM('tutor','test','reading') NOT NULL,
  activity_date DATE NOT NULL COMMENT 'Split at local midnight; do not derive using UTC DATE()',
  timezone_name VARCHAR(64) NOT NULL,
  started_at DATETIME(6) NOT NULL,
  last_heartbeat_at DATETIME(6) NOT NULL,
  ended_at DATETIME(6) NULL,
  active_seconds INT UNSIGNED NOT NULL DEFAULT 0 COMMENT 'Server-validated focused, non-idle time only',
  PRIMARY KEY (id),
  UNIQUE KEY uq_study_request (user_id, request_key),
  KEY ix_study_daily (user_id, activity_date),
  KEY ix_study_version_daily (user_id, syllabus_version_id, activity_date),
  CONSTRAINT fk_study_enrollment FOREIGN KEY (user_id, syllabus_version_id) REFERENCES user_exam_enrollments (user_id, syllabus_version_id),
  CONSTRAINT fk_study_topic FOREIGN KEY (topic_id, syllabus_version_id) REFERENCES syllabus_topics (id, syllabus_version_id),
  CONSTRAINT fk_study_conversation FOREIGN KEY (conversation_id, user_id, syllabus_version_id) REFERENCES tutor_conversations (id, user_id, syllabus_version_id),
  CONSTRAINT fk_study_attempt FOREIGN KEY (attempt_id, user_id, syllabus_version_id) REFERENCES test_attempts (id, user_id, syllabus_version_id),
  CONSTRAINT ck_study_kind CHECK (
    (session_kind = 'tutor' AND conversation_id IS NOT NULL AND attempt_id IS NULL) OR
    (session_kind = 'test' AND attempt_id IS NOT NULL AND conversation_id IS NULL) OR
    (session_kind = 'reading' AND topic_id IS NOT NULL AND attempt_id IS NULL AND conversation_id IS NULL)
  ),
  CONSTRAINT ck_study_time CHECK (last_heartbeat_at >= started_at AND (ended_at IS NULL OR ended_at >= last_heartbeat_at) AND active_seconds <= TIMESTAMPDIFF(SECOND, started_at, COALESCE(ended_at, last_heartbeat_at)))
) ENGINE=InnoDB;

-- 5. Plans, subscriptions and provider-backed payments -------------------------

CREATE TABLE billing_plans (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  code VARCHAR(64) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  title VARCHAR(120) NOT NULL,
  description TEXT NULL,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  display_order SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  UNIQUE KEY uq_plan_code (code),
  CONSTRAINT ck_plan_active CHECK (is_active IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE plan_features (
  plan_id BIGINT UNSIGNED NOT NULL,
  feature_code VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  usage_limit INT UNSIGNED NULL COMMENT 'NULL means unlimited when enabled',
  reset_period ENUM('none','day','week','month') NOT NULL DEFAULT 'none',
  PRIMARY KEY (plan_id, feature_code),
  CONSTRAINT fk_feature_plan FOREIGN KEY (plan_id) REFERENCES billing_plans (id),
  CONSTRAINT ck_feature_enabled CHECK (is_enabled IN (0,1))
) ENGINE=InnoDB;

CREATE TABLE plan_prices (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  plan_id BIGINT UNSIGNED NOT NULL,
  currency CHAR(3) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'INR',
  amount_minor BIGINT UNSIGNED NOT NULL COMMENT 'Paise for INR; never floating point',
  billing_interval ENUM('month','year','one_time') NOT NULL,
  interval_count SMALLINT UNSIGNED NOT NULL DEFAULT 1,
  valid_from DATETIME(6) NOT NULL,
  valid_until DATETIME(6) NULL,
  provider VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NULL,
  provider_price_id VARCHAR(191) CHARACTER SET ascii COLLATE ascii_bin NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_provider_price (provider, provider_price_id),
  UNIQUE KEY uq_price_currency (id, currency),
  KEY ix_price_plan (plan_id, currency, valid_from),
  CONSTRAINT fk_price_plan FOREIGN KEY (plan_id) REFERENCES billing_plans (id),
  CONSTRAINT ck_price_interval CHECK (interval_count > 0 AND (valid_until IS NULL OR valid_until > valid_from)),
  CONSTRAINT ck_price_provider CHECK ((provider IS NULL AND provider_price_id IS NULL) OR (provider IS NOT NULL AND provider_price_id IS NOT NULL))
) ENGINE=InnoDB;

CREATE TABLE subscriptions (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  plan_price_id BIGINT UNSIGNED NOT NULL,
  subscription_status ENUM('pending','trialing','active','past_due','cancelled','expired') NOT NULL DEFAULT 'pending',
  provider VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NULL,
  provider_subscription_id VARCHAR(191) CHARACTER SET ascii COLLATE ascii_bin NULL,
  started_at DATETIME(6) NOT NULL,
  current_period_start DATETIME(6) NOT NULL,
  current_period_end DATETIME(6) NOT NULL,
  trial_ends_at DATETIME(6) NULL,
  cancel_at_period_end BOOLEAN NOT NULL DEFAULT FALSE,
  cancelled_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  updated_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6) ON UPDATE CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  UNIQUE KEY uq_provider_subscription (provider, provider_subscription_id),
  UNIQUE KEY uq_subscription_owner (id, user_id),
  KEY ix_subscription_entitlement (user_id, subscription_status, current_period_end),
  CONSTRAINT fk_subscription_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT fk_subscription_price FOREIGN KEY (plan_price_id) REFERENCES plan_prices (id),
  CONSTRAINT ck_subscription_dates CHECK (current_period_start >= started_at AND current_period_end > current_period_start),
  CONSTRAINT ck_subscription_cancel CHECK (cancel_at_period_end IN (0,1)),
  CONSTRAINT ck_subscription_provider CHECK ((provider IS NULL AND provider_subscription_id IS NULL) OR (provider IS NOT NULL AND provider_subscription_id IS NOT NULL))
) ENGINE=InnoDB;

CREATE TABLE invoices (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  subscription_id BIGINT UNSIGNED NULL,
  invoice_number VARCHAR(80) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  description VARCHAR(255) NOT NULL COMMENT 'Immutable purchased-plan/billing-period snapshot',
  currency CHAR(3) CHARACTER SET ascii COLLATE ascii_bin NOT NULL DEFAULT 'INR',
  subtotal_minor BIGINT UNSIGNED NOT NULL,
  discount_minor BIGINT UNSIGNED NOT NULL DEFAULT 0,
  tax_minor BIGINT UNSIGNED NOT NULL DEFAULT 0,
  total_minor BIGINT UNSIGNED NOT NULL,
  invoice_status ENUM('draft','open','paid','void','uncollectible') NOT NULL DEFAULT 'draft',
  issued_at DATETIME(6) NULL,
  due_at DATETIME(6) NULL,
  paid_at DATETIME(6) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  UNIQUE KEY uq_invoice_number (invoice_number),
  UNIQUE KEY uq_invoice_payment_scope (id, user_id, currency),
  KEY ix_invoice_user (user_id, created_at),
  CONSTRAINT fk_invoice_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT fk_invoice_subscription FOREIGN KEY (subscription_id, user_id) REFERENCES subscriptions (id, user_id),
  CONSTRAINT ck_invoice_total CHECK (discount_minor <= subtotal_minor AND total_minor = subtotal_minor - discount_minor + tax_minor)
) ENGINE=InnoDB;

CREATE TABLE payments (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  invoice_id BIGINT UNSIGNED NOT NULL,
  currency CHAR(3) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  amount_minor BIGINT UNSIGNED NOT NULL,
  provider VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  provider_order_id VARCHAR(191) CHARACTER SET ascii COLLATE ascii_bin NULL,
  provider_payment_id VARCHAR(191) CHARACTER SET ascii COLLATE ascii_bin NULL,
  idempotency_key CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  payment_status ENUM('created','authorized','captured','failed','cancelled') NOT NULL DEFAULT 'created',
  payment_method ENUM('card','upi','netbanking','wallet','other') NULL,
  failure_code VARCHAR(80) NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  captured_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_payment_provider (provider, provider_payment_id),
  UNIQUE KEY uq_payment_idempotency (provider, idempotency_key),
  KEY ix_payment_invoice (invoice_id, payment_status),
  CONSTRAINT fk_payment_invoice FOREIGN KEY (invoice_id, user_id, currency) REFERENCES invoices (id, user_id, currency),
  CONSTRAINT ck_payment_amount CHECK (amount_minor > 0),
  CONSTRAINT ck_payment_capture CHECK (payment_status <> 'captured' OR (captured_at IS NOT NULL AND provider_payment_id IS NOT NULL))
) ENGINE=InnoDB;

CREATE TABLE payment_refunds (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  payment_id BIGINT UNSIGNED NOT NULL,
  amount_minor BIGINT UNSIGNED NOT NULL,
  idempotency_key CHAR(36) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  provider_refund_id VARCHAR(191) CHARACTER SET ascii COLLATE ascii_bin NULL,
  refund_status ENUM('requested','processed','failed') NOT NULL DEFAULT 'requested',
  reason VARCHAR(512) NULL,
  requested_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  processed_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_refund_request (payment_id, idempotency_key),
  UNIQUE KEY uq_refund_provider (payment_id, provider_refund_id),
  CONSTRAINT fk_refund_payment FOREIGN KEY (payment_id) REFERENCES payments (id),
  CONSTRAINT ck_refund_amount CHECK (amount_minor > 0)
) ENGINE=InnoDB;

CREATE TABLE payment_webhook_events (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  provider VARCHAR(32) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  provider_event_id VARCHAR(191) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  event_type VARCHAR(100) NOT NULL,
  payment_id BIGINT UNSIGNED NULL,
  sanitized_payload JSON NOT NULL COMMENT 'No PAN, CVV, OTP, credentials, or raw authorization tokens',
  processing_status ENUM('received','processed','failed') NOT NULL DEFAULT 'received',
  received_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  processed_at DATETIME(6) NULL,
  failure_reason VARCHAR(512) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_webhook_event (provider, provider_event_id),
  KEY ix_webhook_processing (processing_status, received_at),
  CONSTRAINT fk_webhook_payment FOREIGN KEY (payment_id) REFERENCES payments (id)
) ENGINE=InnoDB;

CREATE TABLE institute_enquiries (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NULL,
  organization_name VARCHAR(200) NOT NULL,
  contact_name VARCHAR(120) NOT NULL,
  contact_email VARCHAR(254) NOT NULL,
  expected_learners INT UNSIGNED NULL,
  message TEXT NULL,
  enquiry_status ENUM('new','contacted','closed') NOT NULL DEFAULT 'new',
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  PRIMARY KEY (id),
  KEY ix_enquiry_queue (enquiry_status, created_at),
  CONSTRAINT fk_enquiry_user FOREIGN KEY (user_id) REFERENCES users (id)
) ENGINE=InnoDB;

-- 6. Notification inbox -------------------------------------------------------

CREATE TABLE notifications (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  user_id BIGINT UNSIGNED NOT NULL,
  deduplication_key VARCHAR(191) CHARACTER SET ascii COLLATE ascii_bin NOT NULL,
  category ENUM('study','revision','test','contest','billing','account') NOT NULL,
  title VARCHAR(200) NOT NULL,
  body TEXT NOT NULL,
  topic_id BIGINT UNSIGNED NULL,
  attempt_id BIGINT UNSIGNED NULL,
  contest_id BIGINT UNSIGNED NULL,
  subscription_id BIGINT UNSIGNED NULL,
  created_at DATETIME(6) NOT NULL DEFAULT CURRENT_TIMESTAMP(6),
  read_at DATETIME(6) NULL,
  dismissed_at DATETIME(6) NULL,
  expires_at DATETIME(6) NULL,
  PRIMARY KEY (id),
  UNIQUE KEY uq_notification_dedup (user_id, deduplication_key),
  KEY ix_notification_inbox (user_id, dismissed_at, read_at, created_at),
  CONSTRAINT fk_notification_user FOREIGN KEY (user_id) REFERENCES users (id),
  CONSTRAINT fk_notification_topic FOREIGN KEY (topic_id) REFERENCES syllabus_topics (id),
  CONSTRAINT fk_notification_attempt FOREIGN KEY (attempt_id, user_id) REFERENCES test_attempts (id, user_id),
  CONSTRAINT fk_notification_contest FOREIGN KEY (contest_id) REFERENCES contests (id),
  CONSTRAINT fk_notification_subscription FOREIGN KEY (subscription_id, user_id) REFERENCES subscriptions (id, user_id)
) ENGINE=InnoDB;

-- 7. Derived reporting: no duplicated dashboard or leaderboard score tables -----

CREATE SQL SECURITY INVOKER VIEW v_attempt_results AS
SELECT a.id AS attempt_id, a.user_id, a.syllabus_version_id, a.test_id,
       a.test_kind, a.contest_id, a.contest_round_id,
       a.submitted_at, a.submitted_local_date, a.active_seconds,
       COUNT(*) AS question_count,
       SUM(ans.selected_option_id IS NOT NULL) AS answered_count,
       SUM(ans.grading_outcome = 'correct') AS correct_count,
       SUM(ans.grading_outcome = 'incorrect') AS incorrect_count,
       SUM(ans.grading_outcome = 'skipped') AS skipped_count,
       SUM(ans.maximum_marks_snapshot) AS maximum_marks,
       SUM(ans.awarded_marks) AS scored_marks,
       ROUND(100.0 * SUM(ans.awarded_marks) / NULLIF(SUM(ans.maximum_marks_snapshot), 0), 2) AS score_percentage,
       ROUND(100.0 * SUM(ans.grading_outcome = 'correct') / NULLIF(SUM(ans.selected_option_id IS NOT NULL), 0), 2) AS accuracy_percentage
FROM test_attempts a
JOIN attempt_answers ans ON ans.attempt_id = a.id
WHERE a.attempt_status = 'graded'
GROUP BY a.id, a.user_id, a.syllabus_version_id, a.test_id, a.test_kind,
         a.contest_id, a.contest_round_id, a.submitted_at,
         a.submitted_local_date, a.active_seconds
HAVING SUM(ans.grading_outcome = 'ungraded') = 0
   AND COUNT(*) = (SELECT COUNT(*) FROM test_questions tq WHERE tq.test_id = a.test_id);

CREATE SQL SECURITY INVOKER VIEW v_subject_practice_accuracy AS
SELECT a.user_id, t.syllabus_version_id, t.section_id,
       COUNT(*) AS questions_presented,
       SUM(ans.selected_option_id IS NOT NULL) AS questions_answered,
       SUM(ans.grading_outcome = 'correct') AS correct_answers,
       ROUND(100.0 * SUM(ans.grading_outcome = 'correct') / NULLIF(SUM(ans.selected_option_id IS NOT NULL), 0), 2) AS accuracy_percentage
FROM v_attempt_results a
JOIN attempt_answers ans ON ans.attempt_id = a.attempt_id
JOIN question_revisions qr ON qr.id = ans.question_revision_id
JOIN questions q ON q.id = qr.question_id
JOIN syllabus_topics t ON t.id = q.topic_id
GROUP BY a.user_id, t.syllabus_version_id, t.section_id;

CREATE SQL SECURITY INVOKER VIEW v_daily_learning_activity AS
SELECT user_id, syllabus_version_id, activity_date,
       SUM(active_seconds) AS active_seconds,
       SUM(topic_completions) AS topic_completions,
       SUM(tests_submitted) AS tests_submitted
FROM (
  SELECT user_id, syllabus_version_id, activity_date,
         SUM(active_seconds) AS active_seconds, 0 AS topic_completions, 0 AS tests_submitted
  FROM study_sessions
  GROUP BY user_id, syllabus_version_id, activity_date
  UNION ALL
  SELECT e.user_id, p.syllabus_version_id, e.activity_date,
         0, COUNT(*), 0
  FROM topic_study_events e
  JOIN user_topic_progress p ON p.user_id = e.user_id AND p.topic_id = e.topic_id
  WHERE e.event_type IN ('studied','revised')
  GROUP BY e.user_id, p.syllabus_version_id, e.activity_date
  UNION ALL
  SELECT user_id, syllabus_version_id, submitted_local_date, 0, 0, COUNT(*)
  FROM v_attempt_results
  GROUP BY user_id, syllabus_version_id, submitted_local_date
) daily
GROUP BY user_id, syllabus_version_id, activity_date;

CREATE SQL SECURITY INVOKER VIEW v_latest_question_outcomes AS
SELECT ranked.*
FROM (
  SELECT a.user_id, a.syllabus_version_id, a.attempt_id, a.submitted_at,
         q.id AS question_id, q.topic_id, ans.test_question_id,
         ans.grading_outcome, ans.selected_option_id,
         ROW_NUMBER() OVER (PARTITION BY a.user_id, q.id ORDER BY a.submitted_at DESC, a.attempt_id DESC) AS recency,
         SUM(ans.grading_outcome IN ('incorrect','skipped')) OVER (PARTITION BY a.user_id, q.id) AS total_misses
  FROM v_attempt_results a
  JOIN attempt_answers ans ON ans.attempt_id = a.attempt_id
  JOIN question_revisions qr ON qr.id = ans.question_revision_id
  JOIN questions q ON q.id = qr.question_id
) ranked
WHERE recency = 1;

-- Published results only; all contest rounds must have a valid graded attempt.
-- Ties share rank when both total marks and active time match.
CREATE SQL SECURITY INVOKER VIEW v_contest_leaderboard AS
SELECT totals.*,
       RANK() OVER (PARTITION BY contest_id ORDER BY scored_marks DESC, active_seconds ASC) AS contest_rank,
       ROUND(100.0 * CUME_DIST() OVER (PARTITION BY contest_id ORDER BY scored_marks ASC, active_seconds DESC), 2) AS percentile
FROM (
  SELECT c.id AS contest_id, r.user_id,
         COUNT(*) AS completed_rounds,
         SUM(a.scored_marks) AS scored_marks,
         SUM(a.maximum_marks) AS maximum_marks,
         SUM(a.active_seconds) AS active_seconds
  FROM contests c
  JOIN contest_registrations r ON r.contest_id = c.id AND r.registration_status = 'registered'
  JOIN v_attempt_results a ON a.contest_id = c.id AND a.user_id = r.user_id AND a.test_kind = 'contest'
  WHERE c.contest_status = 'published' AND c.results_published_at <= UTC_TIMESTAMP(6)
  GROUP BY c.id, r.user_id
  HAVING COUNT(*) = (SELECT COUNT(*) FROM contest_rounds cr WHERE cr.contest_id = c.id)
) totals;
