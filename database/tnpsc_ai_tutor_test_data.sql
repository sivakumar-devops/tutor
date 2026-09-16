-- DEVELOPMENT / DEMO DATA ONLY. MySQL 8.4; run AFTER tnpsc_ai_tutor.sql.
-- Inserts into all 37 tables. Reporting views derive their data automatically.
-- Requires an EMPTY database, CREATE ROUTINE, EXECUTE and ALTER ROUTINE rights.
-- Run with no other writers and outside an existing transaction.
-- All names, prices, provider IDs and results are fictional. This is not an
-- official syllabus import, full-length exam, payment integration or login setup.
-- No passwords are supplied. Authentication fixtures are expired/revoked.
-- Audio rows describe placeholder objects, not playable files.
-- Every insert is in one transaction; any error rolls back the entire seed.
-- Reruns reject nonempty tables rather than overwrite or duplicate existing data.

USE tnpsc_ai_tutor;
SET NAMES utf8mb4;
SET time_zone = '+00:00';

DELIMITER $$
DROP PROCEDURE IF EXISTS seed_tnpsc_test_data$$
CREATE PROCEDURE seed_tnpsc_test_data()
BEGIN
  DECLARE finished BOOLEAN DEFAULT FALSE;
  DECLARE table_name_value VARCHAR(64);
  DECLARE error_text VARCHAR(128);
  DECLARE table_cursor CURSOR FOR
    SELECT table_name FROM information_schema.tables
    WHERE table_schema = 'tnpsc_ai_tutor' AND table_type = 'BASE TABLE'
    ORDER BY table_name;
  DECLARE CONTINUE HANDLER FOR NOT FOUND SET finished = TRUE;
  DECLARE EXIT HANDLER FOR SQLEXCEPTION
  BEGIN
    ROLLBACK;
    RESIGNAL;
  END;

  START TRANSACTION;
  OPEN table_cursor;
  empty_check: LOOP
    FETCH table_cursor INTO table_name_value;
    IF finished THEN LEAVE empty_check; END IF;
    SET @seed_check_sql = CONCAT('SELECT EXISTS(SELECT 1 FROM `tnpsc_ai_tutor`.`',
      REPLACE(table_name_value, '`', '``'), '` LIMIT 1) INTO @seed_has_rows');
    PREPARE seed_check_statement FROM @seed_check_sql;
    EXECUTE seed_check_statement;
    DEALLOCATE PREPARE seed_check_statement;
    IF @seed_has_rows THEN
      SET error_text = CONCAT('Seed requires empty tables; found data in ', table_name_value);
      SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = error_text;
    END IF;
  END LOOP;
  CLOSE table_cursor;

  SET @seed_now = UTC_TIMESTAMP(6);
  -- Stable daytime anchor yesterday; historical sessions never cross IST midnight.
  SET @seed_day = TIMESTAMP(UTC_DATE() - INTERVAL 1 DAY, '08:00:00');
  SET @seed_created = @seed_day - INTERVAL 30 DAY;

  -- 1. Accounts: two returning learners, one new learner, instructor and admin.
  INSERT INTO users
    (id,email,display_name,city,account_role,account_status,email_verified_at,
     last_login_at,created_at,updated_at)
  VALUES
    (1,'kavya@example.test','Kavya Demo','Chennai','learner','active',@seed_created,@seed_now,@seed_created,@seed_now),
    (2,'arun@example.test','Arun Demo','Madurai','learner','active',@seed_created,@seed_day,@seed_created,@seed_day),
    (3,'meena@example.test','Meena Demo','Coimbatore','learner','active',@seed_now,@seed_now,@seed_now,@seed_now),
    (4,'teacher@example.test','Teacher Demo','Salem','instructor','active',@seed_created,@seed_day,@seed_created,@seed_day),
    (5,'admin@example.test','Admin Demo','Chennai','admin','active',@seed_created,@seed_day,@seed_created,@seed_day);

  INSERT INTO user_preferences (user_id,theme,tutor_language,sidebar_collapsed,email_notifications_enabled)
  VALUES (1,'dark','bilingual',0,1),(2,'light','en',1,0),(3,'system','ta',0,1),
         (4,'light','bilingual',0,1),(5,'dark','en',0,0);

  INSERT INTO auth_sessions
    (id,user_id,refresh_token_hash,user_agent,created_at,expires_at,last_used_at,revoked_at)
  VALUES
    (1,1,UNHEX(SHA2('EXPIRED-DEMO-SESSION-1',256)),'Demo browser - not a real session',
     @seed_day-INTERVAL 3 DAY,@seed_day-INTERVAL 2 DAY,@seed_day-INTERVAL 3 DAY,@seed_day-INTERVAL 2 DAY),
    (2,2,UNHEX(SHA2('EXPIRED-DEMO-SESSION-2',256)),'Demo mobile - not a real session',
     @seed_day-INTERVAL 2 DAY,@seed_day-INTERVAL 1 DAY,@seed_day-INTERVAL 2 DAY,@seed_day-INTERVAL 1 DAY);

  INSERT INTO auth_challenges
    (id,user_id,purpose,destination,channel,secret_hash,failed_attempts,created_at,expires_at,consumed_at)
  VALUES
    (1,1,'login','kavya@example.test','email',UNHEX(SHA2('NOT-A-VALID-HMAC-1',256)),0,
     @seed_day-INTERVAL 1 DAY,@seed_day-INTERVAL 1 DAY+INTERVAL 5 MINUTE,@seed_day-INTERVAL 1 DAY+INTERVAL 1 MINUTE),
    (2,2,'reset_password','arun@example.test','email',UNHEX(SHA2('NOT-A-VALID-HMAC-2',256)),5,
     @seed_day-INTERVAL 1 DAY,@seed_day-INTERVAL 1 DAY+INTERVAL 5 MINUTE,NULL);

  -- 2. Prototype curriculum. Topic allocation mirrors the HTML, not an official notice.
  INSERT INTO exams (id,code,name_en,examining_body,created_at)
  VALUES (1,'TNPSC-GROUP-4-DEMO','TNPSC Group 4 - Demo','TNPSC (prototype fixture)',@seed_created);
  INSERT INTO syllabus_versions
    (id,exam_id,version_code,title,publication_status,total_questions,total_marks,
     duration_seconds,effective_from,published_at,created_at)
  VALUES (1,1,'DEMO-V1','Group 4 prototype syllabus - verify before production',
          'published',200,300,10800,DATE(@seed_created),@seed_created,@seed_created);
  INSERT INTO syllabus_sections
    (id,syllabus_version_id,code,title_en,part_code,expected_questions,expected_marks,display_order)
  VALUES (1,1,'tamil','Tamil','C',100,150,1),
         (2,1,'general-studies','General Studies','A',75,112.5,2),
         (3,1,'aptitude','Aptitude','B',25,37.5,3);
  INSERT INTO syllabus_topics
    (id,syllabus_version_id,section_id,code,title_en,summary_en,expected_questions,display_order)
  VALUES
    (1,1,1,'tamil-grammar','Tamil Grammar','Letters, vowels, consonants, word forms and spelling.',25,1),
    (2,1,1,'tamil-vocabulary','Tamil Vocabulary','Meanings, synonyms, antonyms and word formation.',15,2),
    (3,1,1,'writing','Writing Skills','Sentence order, punctuation and correct usage.',15,3),
    (4,1,1,'technical-terms','Technical Terms','Tamil terminology in science, education and technology.',10,4),
    (5,1,1,'comprehension','Reading Comprehension','Passages, idioms, proverbs and documents.',15,5),
    (6,1,1,'translation','Simple Translation','Common words and documents in translation.',5,6),
    (7,1,1,'literature','Literature, Tamil Scholars, and Tamil Service','Thirukkural, moral literature and literary contributors.',15,7),
    (8,1,2,'science','General Science','Physics, chemistry, biology and environment.',5,1),
    (9,1,2,'geography','Geography','Climate, rivers, resources and disaster management.',5,2),
    (10,1,2,'indian-history','History, Culture of India, and National Movement','Indian history, freedom movements and leaders.',10,3),
    (11,1,2,'polity','Indian Polity','Constitution, governments, rights and duties.',15,4),
    (12,1,2,'economy','Indian Economy and Development Administration in Tamil Nadu','Economy, welfare, social justice, health and education.',20,5),
    (13,1,2,'tn-history','Tamil Nadu History, Culture, Heritage, and Socio-Political Movements','Tamil society, heritage and reform movements.',20,6),
    (14,1,3,'arithmetic','Aptitude','Percentage, ratios, interest, area, volume and time and work.',15,1),
    (15,1,3,'reasoning','Reasoning','Logic, puzzles and number series.',10,2);

  INSERT INTO user_exam_enrollments
    (user_id,syllabus_version_id,target_exam_year,target_score,enrolled_at)
  VALUES (1,1,YEAR(@seed_now)+1,255,@seed_created),
         (2,1,YEAR(@seed_now)+1,240,@seed_created),(3,1,YEAR(@seed_now)+1,225,@seed_now);
  INSERT INTO user_learning_goals (user_id,syllabus_version_id,effective_from,daily_goal_minutes,created_at)
  VALUES (1,1,DATE(@seed_created),60,@seed_created),(1,1,DATE(@seed_day-INTERVAL 3 DAY),90,@seed_day-INTERVAL 3 DAY),
         (2,1,DATE(@seed_created),45,@seed_created),(3,1,DATE(@seed_now+INTERVAL 330 MINUTE),30,@seed_now);
  INSERT INTO user_section_preferences (user_id,section_id,is_expanded)
  SELECT u.user_id,s.id,IF(u.user_id=1 AND s.id=1,1,0)
  FROM user_exam_enrollments u JOIN syllabus_sections s ON s.syllabus_version_id=u.syllabus_version_id;
  INSERT INTO user_topic_progress (user_id,topic_id,syllabus_version_id)
  SELECT e.user_id,t.id,t.syllabus_version_id FROM user_exam_enrollments e
  JOIN syllabus_topics t ON t.syllabus_version_id=e.syllabus_version_id;
  UPDATE user_topic_progress SET study_status='studied',
    last_opened_at=@seed_day-INTERVAL 1 DAY,last_studied_at=@seed_day-INTERVAL 1 DAY+INTERVAL 20 MINUTE,
    next_revision_at=@seed_day,updated_at=@seed_day-INTERVAL 1 DAY+INTERVAL 20 MINUTE
  WHERE user_id=1 AND topic_id=1;
  UPDATE user_topic_progress SET study_status='in_progress',last_opened_at=@seed_day,
    updated_at=@seed_day WHERE user_id=1 AND topic_id=8;
  UPDATE user_topic_progress SET study_status='studied',last_opened_at=@seed_day-INTERVAL 1 DAY,
    last_studied_at=@seed_day-INTERVAL 1 DAY+INTERVAL 15 MINUTE,
    next_revision_at=@seed_day+INTERVAL 2 DAY,updated_at=@seed_day-INTERVAL 1 DAY+INTERVAL 15 MINUTE
  WHERE user_id=2 AND topic_id=14;
  INSERT INTO topic_study_events
    (id,user_id,topic_id,request_key,event_type,activity_date,timezone_name,occurred_at)
  VALUES
    (1,1,1,'demo-topic-studied-1','studied',DATE(@seed_day-INTERVAL 1 DAY),'Asia/Kolkata',@seed_day-INTERVAL 1 DAY+INTERVAL 20 MINUTE),
    (2,2,14,'demo-topic-studied-2','studied',DATE(@seed_day-INTERVAL 1 DAY),'Asia/Kolkata',@seed_day-INTERVAL 1 DAY+INTERVAL 15 MINUTE);

  -- 3. Six small editorial fixture questions, four options each.
  INSERT INTO questions (id,topic_id,created_by_user_id,source_type,source_reference,question_status,created_at)
  VALUES (1,1,4,'editorial','Demo question, not a past paper','active',@seed_created),
         (2,2,4,'editorial','Demo question, not a past paper','active',@seed_created),
         (3,8,4,'editorial','Demo question, not a past paper','active',@seed_created),
         (4,9,4,'editorial','Demo question, not a past paper','active',@seed_created),
         (5,14,4,'editorial','Demo question, not a past paper','active',@seed_created),
         (6,15,4,'editorial','Demo question, not a past paper','active',@seed_created);
  INSERT INTO question_revisions
    (id,question_id,revision_number,prompt_en,explanation_en,difficulty,review_status,reviewed_by_user_id,reviewed_at,created_at)
  VALUES
    (1,1,1,'How many vowels (uyir eluthukkal) are in the Tamil alphabet?','Tamil has 12 vowels.','easy','approved',4,@seed_created,@seed_created),
    (2,2,1,'What does the Tamil word neer mean in English?','Neer means water.','easy','approved',4,@seed_created,@seed_created),
    (3,3,1,'Which gas do plants absorb during photosynthesis?','Plants absorb carbon dioxide during photosynthesis.','easy','approved',4,@seed_created,@seed_created),
    (4,4,1,'Which is the largest ocean on Earth?','The Pacific is the largest ocean.','easy','approved',4,@seed_created,@seed_created),
    (5,5,1,'What is 25 percent of 360?','One fourth of 360 is 90.','easy','approved',4,@seed_created,@seed_created),
    (6,6,1,'Complete the series: 3, 6, 12, 24, ...','Each term doubles; the next term is 48.','easy','approved',4,@seed_created,@seed_created);
  -- IDs follow revision*10 + option position; option A is correct in these fixtures.
  INSERT INTO question_options (id,question_revision_id,option_key,content_en,is_correct)
  VALUES (11,1,'A','12',1),(12,1,'B','18',0),(13,1,'C','6',0),(14,1,'D','24',0),
         (21,2,'A','Water',1),(22,2,'B','Fire',0),(23,2,'C','Earth',0),(24,2,'D','Air',0),
         (31,3,'A','Carbon dioxide',1),(32,3,'B','Oxygen',0),(33,3,'C','Hydrogen',0),(34,3,'D','Helium',0),
         (41,4,'A','Pacific',1),(42,4,'B','Atlantic',0),(43,4,'C','Indian',0),(44,4,'D','Arctic',0),
         (51,5,'A','90',1),(52,5,'B','80',0),(53,5,'C','70',0),(54,5,'D','120',0),
         (61,6,'A','48',1),(62,6,'B','30',0),(63,6,'C','36',0),(64,6,'D','54',0);
  INSERT INTO test_definitions
    (id,syllabus_version_id,section_id,code,title,test_kind,publication_status,duration_seconds,created_by_user_id,published_at,created_at)
  VALUES
    (1,1,NULL,'DEMO-MOCK','Mixed-subject mini mock','mock','published',600,4,@seed_created,@seed_created),
    (2,1,1,'DEMO-TAMIL','Tamil quick practice','practice','published',300,4,@seed_created,@seed_created),
    (3,1,NULL,'DEMO-ROUND-1','Weekly contest - round 1','contest','published',600,4,@seed_created,@seed_created),
    (4,1,NULL,'DEMO-ROUND-2','Weekly contest - round 2','contest','published',600,4,@seed_created,@seed_created);
  INSERT INTO test_questions (id,test_id,question_revision_id,display_order,maximum_marks,negative_marks)
  VALUES (1,1,1,1,1.5,0),(2,1,2,2,1.5,0),(3,1,3,3,1.5,0),
         (4,1,4,4,1.5,0),(5,1,5,5,1.5,0),(6,1,6,6,1.5,0),
         (7,2,1,1,1.5,0),(8,2,2,2,1.5,0),
         (9,3,1,1,1.5,0),(10,3,3,2,1.5,0),(11,3,5,3,1.5,0),
         (12,4,2,1,1.5,0),(13,4,4,2,1.5,0),(14,4,6,3,1.5,0);

  INSERT INTO contests
    (id,syllabus_version_id,code,title,contest_status,registration_opens_at,registration_closes_at,
     starts_at,ends_at,results_published_at,created_at)
  VALUES
    (1,1,'DEMO-WEEK-PAST','Weekly Challenge - completed demo','published',
     @seed_day-INTERVAL 10 DAY,@seed_day-INTERVAL 4 DAY,@seed_day-INTERVAL 4 DAY,
     @seed_day-INTERVAL 4 DAY+INTERVAL 1 HOUR,@seed_day-INTERVAL 3 DAY,@seed_created),
    (2,1,'DEMO-WEEK-NEXT','Weekly Challenge - upcoming demo','scheduled',
     @seed_day-INTERVAL 1 DAY,@seed_day+INTERVAL 5 DAY,@seed_day+INTERVAL 5 DAY,
     @seed_day+INTERVAL 5 DAY+INTERVAL 1 HOUR,NULL,@seed_day-INTERVAL 1 DAY);
  INSERT INTO contest_rounds
    (id,contest_id,syllabus_version_id,test_id,title,display_order,starts_at,ends_at)
  VALUES
    (1,1,1,3,'Round 1',1,@seed_day-INTERVAL 4 DAY,@seed_day-INTERVAL 4 DAY+INTERVAL 20 MINUTE),
    (2,1,1,4,'Round 2',2,@seed_day-INTERVAL 4 DAY+INTERVAL 30 MINUTE,@seed_day-INTERVAL 4 DAY+INTERVAL 50 MINUTE),
    (3,2,1,3,'Round 1',1,@seed_day+INTERVAL 5 DAY,@seed_day+INTERVAL 5 DAY+INTERVAL 20 MINUTE),
    (4,2,1,4,'Round 2',2,@seed_day+INTERVAL 5 DAY+INTERVAL 30 MINUTE,@seed_day+INTERVAL 5 DAY+INTERVAL 50 MINUTE);
  INSERT INTO contest_registrations (contest_id,user_id,registered_at)
  VALUES (1,1,@seed_day-INTERVAL 6 DAY),(1,2,@seed_day-INTERVAL 6 DAY),
         (2,1,@seed_now),(2,3,@seed_now);

  -- Insert attempts, then derive answer snapshots and grades from fixture choices.
  INSERT INTO test_attempts
    (id,user_id,syllabus_version_id,test_id,test_kind,contest_id,contest_round_id,
     request_key,attempt_number,attempt_status,active_seconds,started_at,deadline_at,
     last_saved_at,submitted_at,graded_at,submitted_local_date,timezone_name)
  VALUES
    (1,1,1,1,'mock',NULL,NULL,'demo-attempt-1',1,'graded',360,
     @seed_day-INTERVAL 6 DAY,@seed_day-INTERVAL 6 DAY+INTERVAL 10 MINUTE,
     @seed_day-INTERVAL 6 DAY+INTERVAL 6 MINUTE,@seed_day-INTERVAL 6 DAY+INTERVAL 6 MINUTE,
     @seed_day-INTERVAL 6 DAY+INTERVAL 7 MINUTE,DATE(@seed_day-INTERVAL 6 DAY),'Asia/Kolkata'),
    (2,1,1,1,'mock',NULL,NULL,'demo-attempt-2',2,'graded',300,
     @seed_day-INTERVAL 2 DAY,@seed_day-INTERVAL 2 DAY+INTERVAL 10 MINUTE,
     @seed_day-INTERVAL 2 DAY+INTERVAL 5 MINUTE,@seed_day-INTERVAL 2 DAY+INTERVAL 5 MINUTE,
     @seed_day-INTERVAL 2 DAY+INTERVAL 6 MINUTE,DATE(@seed_day-INTERVAL 2 DAY),'Asia/Kolkata'),
    (3,2,1,1,'mock',NULL,NULL,'demo-attempt-3',1,'graded',420,
     @seed_day-INTERVAL 2 DAY,@seed_day-INTERVAL 2 DAY+INTERVAL 10 MINUTE,
     @seed_day-INTERVAL 2 DAY+INTERVAL 7 MINUTE,@seed_day-INTERVAL 2 DAY+INTERVAL 7 MINUTE,
     @seed_day-INTERVAL 2 DAY+INTERVAL 8 MINUTE,DATE(@seed_day-INTERVAL 2 DAY),'Asia/Kolkata'),
    (4,1,1,2,'practice',NULL,NULL,'demo-attempt-4',1,'in_progress',0,
     @seed_now,@seed_now+INTERVAL 5 MINUTE,@seed_now,NULL,NULL,NULL,'Asia/Kolkata'),
    (5,2,1,2,'practice',NULL,NULL,'demo-attempt-5',1,'graded',60,
     @seed_day-INTERVAL 2 DAY+INTERVAL 1 HOUR,@seed_day-INTERVAL 2 DAY+INTERVAL 65 MINUTE,
     @seed_day-INTERVAL 2 DAY+INTERVAL 61 MINUTE,@seed_day-INTERVAL 2 DAY+INTERVAL 61 MINUTE,
     @seed_day-INTERVAL 2 DAY+INTERVAL 62 MINUTE,DATE(@seed_day-INTERVAL 2 DAY),'Asia/Kolkata'),
    (6,1,1,3,'contest',1,1,'demo-attempt-6',1,'graded',180,
     @seed_day-INTERVAL 4 DAY,@seed_day-INTERVAL 4 DAY+INTERVAL 10 MINUTE,
     @seed_day-INTERVAL 4 DAY+INTERVAL 3 MINUTE,@seed_day-INTERVAL 4 DAY+INTERVAL 3 MINUTE,
     @seed_day-INTERVAL 4 DAY+INTERVAL 4 MINUTE,DATE(@seed_day-INTERVAL 4 DAY),'Asia/Kolkata'),
    (7,1,1,4,'contest',1,2,'demo-attempt-7',1,'graded',180,
     @seed_day-INTERVAL 4 DAY+INTERVAL 30 MINUTE,@seed_day-INTERVAL 4 DAY+INTERVAL 40 MINUTE,
     @seed_day-INTERVAL 4 DAY+INTERVAL 33 MINUTE,@seed_day-INTERVAL 4 DAY+INTERVAL 33 MINUTE,
     @seed_day-INTERVAL 4 DAY+INTERVAL 34 MINUTE,DATE(@seed_day-INTERVAL 4 DAY),'Asia/Kolkata'),
    (8,2,1,3,'contest',1,1,'demo-attempt-8',1,'graded',240,
     @seed_day-INTERVAL 4 DAY,@seed_day-INTERVAL 4 DAY+INTERVAL 10 MINUTE,
     @seed_day-INTERVAL 4 DAY+INTERVAL 4 MINUTE,@seed_day-INTERVAL 4 DAY+INTERVAL 4 MINUTE,
     @seed_day-INTERVAL 4 DAY+INTERVAL 5 MINUTE,DATE(@seed_day-INTERVAL 4 DAY),'Asia/Kolkata'),
    (9,2,1,4,'contest',1,2,'demo-attempt-9',1,'graded',240,
     @seed_day-INTERVAL 4 DAY+INTERVAL 30 MINUTE,@seed_day-INTERVAL 4 DAY+INTERVAL 40 MINUTE,
     @seed_day-INTERVAL 4 DAY+INTERVAL 34 MINUTE,@seed_day-INTERVAL 4 DAY+INTERVAL 34 MINUTE,
     @seed_day-INTERVAL 4 DAY+INTERVAL 35 MINUTE,DATE(@seed_day-INTERVAL 4 DAY),'Asia/Kolkata');

  INSERT INTO attempt_answers
    (attempt_id,test_id,test_question_id,question_revision_id,display_order,
     maximum_marks_snapshot,negative_marks_snapshot,selected_option_id,active_seconds,answered_at)
  SELECT a.id,a.test_id,q.id,q.question_revision_id,q.display_order,q.maximum_marks,q.negative_marks,
    CASE
      WHEN a.id IN (4,5) THEN NULL
      WHEN a.id=1 AND q.display_order=6 THEN NULL
      WHEN (a.id=1 AND q.display_order>3) OR (a.id=2 AND q.display_order=6)
        OR (a.id=3 AND q.display_order>4) OR (a.id IN (8,9) AND q.display_order=3)
        THEN q.question_revision_id*10+2
      ELSE q.question_revision_id*10+1
    END,
    CASE WHEN a.id=4 THEN 0 WHEN a.id=1 THEN 60 WHEN a.id=2 THEN 50
      WHEN a.id=3 THEN 70 WHEN a.id=5 THEN 30 WHEN a.id IN (6,7) THEN 60 ELSE 80 END,
    CASE WHEN a.id IN (4,5) OR (a.id=1 AND q.display_order=6) THEN NULL ELSE a.submitted_at END
  FROM test_attempts a JOIN test_questions q ON q.test_id=a.test_id;
  UPDATE attempt_answers ans
  JOIN test_attempts a ON a.id=ans.attempt_id
  LEFT JOIN question_options o ON o.id=ans.selected_option_id
  SET ans.grading_outcome=CASE WHEN o.id IS NULL THEN 'skipped' WHEN o.is_correct THEN 'correct' ELSE 'incorrect' END,
      ans.awarded_marks=CASE WHEN o.id IS NULL THEN 0 WHEN o.is_correct THEN ans.maximum_marks_snapshot ELSE -ans.negative_marks_snapshot END
  WHERE a.attempt_status='graded';

  -- 4. Topic console, section welcome, general chat, review, text and voice.
  INSERT INTO media_assets
    (id,user_id,storage_object_key,media_kind,mime_type,byte_size,duration_ms,processing_status,created_at)
  VALUES (1,1,'demo/1/voice-input.webm','voice_input','audio/webm',24000,5000,'ready',@seed_day+INTERVAL 1 MINUTE),
         (2,1,'demo/1/voice-output.mp3','voice_output','audio/mpeg',64000,8000,'ready',@seed_day+INTERVAL 2 MINUTE);
  INSERT INTO tutor_conversations
    (id,user_id,syllabus_version_id,scope_type,section_id,topic_id,review_attempt_id,
     title,tutor_language,draft_text,conversation_status,created_at,updated_at,last_message_at)
  VALUES
    (1,1,1,'topic',2,8,NULL,'General Science: photosynthesis','en','Can we try a practice question?',
     'active',@seed_day,@seed_day+INTERVAL 2 MINUTE,@seed_day+INTERVAL 2 MINUTE),
    (2,1,1,'section',1,NULL,NULL,'Tamil tutor','bilingual',NULL,'active',@seed_day+INTERVAL 1 HOUR,@seed_day+INTERVAL 1 HOUR,@seed_day+INTERVAL 1 HOUR),
    (3,2,1,'general',NULL,NULL,NULL,'Weekly study plan','en',NULL,'active',@seed_day,@seed_day+INTERVAL 1 MINUTE,@seed_day+INTERVAL 1 MINUTE),
    (4,1,1,'attempt_review',NULL,NULL,2,'Review: mixed-subject mini mock','en',NULL,'archived',@seed_day-INTERVAL 2 DAY+INTERVAL 1 HOUR,@seed_day-INTERVAL 2 DAY+INTERVAL 1 HOUR,@seed_day-INTERVAL 2 DAY+INTERVAL 1 HOUR);
  INSERT INTO tutor_messages
    (id,conversation_id,user_id,request_key,sequence_number,message_role,content_text,
     input_mode,media_asset_id,message_status,created_at,completed_at)
  VALUES
    (1,1,1,'demo-message-1',1,'assistant','Welcome to General Science. What would you like to explore?',
     'generated',NULL,'completed',@seed_day,@seed_day),
    (2,1,1,'demo-message-2',2,'user','Explain photosynthesis in simple terms.',
     'voice',1,'completed',@seed_day+INTERVAL 1 MINUTE,@seed_day+INTERVAL 1 MINUTE),
    (4,2,1,'demo-message-4',1,'assistant','Welcome to your Tamil tutor. Which topic shall we practise?',
     'generated',NULL,'completed',@seed_day+INTERVAL 1 HOUR,@seed_day+INTERVAL 1 HOUR),
    (5,3,2,'demo-message-5',1,'user','Help me plan a 45-minute study session.',
     'text',NULL,'completed',@seed_day,@seed_day),
    (7,4,1,'demo-message-7',1,'assistant','You answered 5 of 6 correctly. Let us review the number series question.',
     'generated',NULL,'completed',@seed_day-INTERVAL 2 DAY+INTERVAL 1 HOUR,@seed_day-INTERVAL 2 DAY+INTERVAL 1 HOUR);
  INSERT INTO tutor_messages
    (id,conversation_id,user_id,request_key,sequence_number,message_role,content_text,input_mode,
     media_asset_id,reply_to_message_id,message_status,model_provider,model_name,input_tokens,
     output_tokens,latency_ms,created_at,completed_at)
  VALUES
    (3,1,1,'demo-message-3',3,'assistant','Plants use light energy to turn water and carbon dioxide into sugars, releasing oxygen.',
     'generated',2,2,'completed','demo','fixture-model',24,28,950,@seed_day+INTERVAL 2 MINUTE,@seed_day+INTERVAL 2 MINUTE),
    (6,3,2,'demo-message-6',2,'assistant','Spend 20 minutes on Tamil, 15 on General Studies and 10 on aptitude.',
     'generated',NULL,5,'completed','demo','fixture-model',20,24,700,@seed_day+INTERVAL 1 MINUTE,@seed_day+INTERVAL 1 MINUTE);

  INSERT INTO study_sessions
    (id,user_id,syllabus_version_id,request_key,attempt_id,session_kind,activity_date,
     timezone_name,started_at,last_heartbeat_at,ended_at,active_seconds)
  SELECT a.id,a.user_id,a.syllabus_version_id,CONCAT('demo-study-attempt-',a.id),a.id,'test',
    DATE(a.started_at+INTERVAL 330 MINUTE),'Asia/Kolkata',a.started_at,
    COALESCE(a.submitted_at,a.started_at),a.submitted_at,a.active_seconds
  FROM test_attempts a;
  INSERT INTO study_sessions
    (id,user_id,syllabus_version_id,request_key,topic_id,conversation_id,session_kind,
     activity_date,timezone_name,started_at,last_heartbeat_at,ended_at,active_seconds)
  VALUES
    (10,1,1,'demo-reading-1',1,NULL,'reading',DATE(@seed_day-INTERVAL 1 DAY),'Asia/Kolkata',
     @seed_day-INTERVAL 1 DAY,@seed_day-INTERVAL 1 DAY+INTERVAL 20 MINUTE,@seed_day-INTERVAL 1 DAY+INTERVAL 20 MINUTE,1200),
    (11,2,1,'demo-reading-2',14,NULL,'reading',DATE(@seed_day-INTERVAL 1 DAY),'Asia/Kolkata',
     @seed_day-INTERVAL 1 DAY,@seed_day-INTERVAL 1 DAY+INTERVAL 15 MINUTE,@seed_day-INTERVAL 1 DAY+INTERVAL 15 MINUTE,900),
    (12,1,1,'demo-tutor-1',8,1,'tutor',DATE(@seed_day),'Asia/Kolkata',@seed_day,@seed_day+INTERVAL 15 MINUTE,@seed_day+INTERVAL 15 MINUTE,720),
    (13,2,1,'demo-tutor-2',NULL,3,'tutor',DATE(@seed_day),'Asia/Kolkata',@seed_day,@seed_day+INTERVAL 5 MINUTE,@seed_day+INTERVAL 5 MINUTE,240),
    (14,1,1,'demo-review-1',NULL,4,'tutor',DATE(@seed_day-INTERVAL 2 DAY),'Asia/Kolkata',
     @seed_day-INTERVAL 2 DAY+INTERVAL 1 HOUR,@seed_day-INTERVAL 2 DAY+INTERVAL 65 MINUTE,@seed_day-INTERVAL 2 DAY+INTERVAL 65 MINUTE,300);

  -- 5. Fictional prices in paise. Provider 'demo' never calls a payment service.
  INSERT INTO billing_plans (id,code,title,description,display_order,created_at)
  VALUES (1,'DEMO-FREE','Starter','Demo free plan',1,@seed_created),
         (2,'DEMO-PLUS','Plus','Demo individual subscription',2,@seed_created),
         (3,'DEMO-INSTITUTE','Institute','Demo batch access enquiry',3,@seed_created);
  INSERT INTO plan_features (plan_id,feature_code,is_enabled,usage_limit,reset_period)
  VALUES (1,'tutor_messages',1,10,'day'),(1,'voice',0,0,'none'),(1,'mock_tests',1,1,'week'),
         (1,'weekly_contests',1,NULL,'none'),(2,'tutor_messages',1,200,'day'),
         (2,'voice',1,60,'day'),(2,'mock_tests',1,NULL,'none'),(2,'weekly_contests',1,NULL,'none'),
         (3,'learner_seats',1,50,'none'),(3,'tutor_messages',1,200,'day'),(3,'voice',1,60,'day');
  INSERT INTO plan_prices
    (id,plan_id,currency,amount_minor,billing_interval,valid_from,provider,provider_price_id)
  VALUES (1,1,'INR',0,'month',@seed_created,NULL,NULL),
         (2,2,'INR',29900,'month',@seed_created,'demo','price_demo_month'),
         (3,2,'INR',299900,'year',@seed_created,'demo','price_demo_year');
  INSERT INTO subscriptions
    (id,user_id,plan_price_id,subscription_status,provider,provider_subscription_id,
     started_at,current_period_start,current_period_end,trial_ends_at,created_at)
  VALUES
    (1,1,2,'active','demo','sub_demo_kavya',@seed_day-INTERVAL 7 DAY,@seed_day-INTERVAL 7 DAY,@seed_day-INTERVAL 7 DAY+INTERVAL 1 MONTH,NULL,@seed_day-INTERVAL 7 DAY),
    (2,2,2,'past_due','demo','sub_demo_arun',@seed_day-INTERVAL 1 DAY,@seed_day-INTERVAL 1 DAY,@seed_day-INTERVAL 1 DAY+INTERVAL 1 MONTH,NULL,@seed_day-INTERVAL 1 DAY),
    (3,3,2,'trialing','demo','sub_demo_meena',@seed_now,@seed_now,@seed_now+INTERVAL 7 DAY,@seed_now+INTERVAL 7 DAY,@seed_now);
  INSERT INTO invoices
    (id,user_id,subscription_id,invoice_number,description,currency,subtotal_minor,
     discount_minor,tax_minor,total_minor,invoice_status,issued_at,due_at,paid_at,created_at)
  VALUES
    (1,1,1,'DEMO-INV-001','Plus monthly - fictional test purchase','INR',29900,0,0,29900,'paid',
     @seed_day-INTERVAL 7 DAY,@seed_day-INTERVAL 7 DAY,@seed_day-INTERVAL 7 DAY+INTERVAL 2 MINUTE,@seed_day-INTERVAL 7 DAY),
    (2,2,2,'DEMO-INV-002','Plus monthly - fictional failed purchase','INR',29900,0,0,29900,'open',
     @seed_day-INTERVAL 1 DAY,@seed_day,NULL,@seed_day-INTERVAL 1 DAY);
  INSERT INTO payments
    (id,user_id,invoice_id,currency,amount_minor,provider,provider_order_id,provider_payment_id,
     idempotency_key,payment_status,payment_method,failure_code,created_at,captured_at)
  VALUES
    (1,1,1,'INR',29900,'demo','order_demo_1','pay_demo_1','demo-payment-1','captured','upi',NULL,
     @seed_day-INTERVAL 7 DAY+INTERVAL 1 MINUTE,@seed_day-INTERVAL 7 DAY+INTERVAL 2 MINUTE),
    (2,2,2,'INR',29900,'demo','order_demo_2','pay_demo_2','demo-payment-2','failed','card','DEMO_DECLINED',
     @seed_day-INTERVAL 1 DAY+INTERVAL 1 MINUTE,NULL);
  INSERT INTO payment_refunds
    (id,payment_id,amount_minor,idempotency_key,provider_refund_id,refund_status,reason,requested_at,processed_at)
  VALUES (1,1,5000,'demo-refund-1','refund_demo_1','processed','Fictional partial goodwill refund',
          @seed_day-INTERVAL 5 DAY,@seed_day-INTERVAL 5 DAY+INTERVAL 5 MINUTE);
  INSERT INTO payment_webhook_events
    (id,provider,provider_event_id,event_type,payment_id,sanitized_payload,processing_status,received_at,processed_at)
  VALUES
    (1,'demo','evt_demo_1','payment.captured',1,JSON_OBJECT('demo',TRUE,'payment_id','pay_demo_1','amount_minor',29900,'currency','INR'),
     'processed',@seed_day-INTERVAL 7 DAY+INTERVAL 2 MINUTE,@seed_day-INTERVAL 7 DAY+INTERVAL 3 MINUTE),
    (2,'demo','evt_demo_2','payment.failed',2,JSON_OBJECT('demo',TRUE,'payment_id','pay_demo_2','reason','DEMO_DECLINED'),
     'processed',@seed_day-INTERVAL 1 DAY+INTERVAL 2 MINUTE,@seed_day-INTERVAL 1 DAY+INTERVAL 3 MINUTE),
    (3,'demo','evt_demo_3','refund.processed',1,JSON_OBJECT('demo',TRUE,'refund_id','refund_demo_1','amount_minor',5000),
     'processed',@seed_day-INTERVAL 5 DAY+INTERVAL 5 MINUTE,@seed_day-INTERVAL 5 DAY+INTERVAL 6 MINUTE);
  INSERT INTO institute_enquiries
    (id,user_id,organization_name,contact_name,contact_email,expected_learners,message,enquiry_status,created_at)
  VALUES (1,4,'Sample Learning Centre','Teacher Demo','teacher@example.test',50,
          'Please arrange a demo of batch access. This enquiry is fictional.','new',@seed_day),
         (2,NULL,'Example Study Circle','Coordinator Demo','coordinator@example.test',25,
          'Fictional enquiry for a weekend study group.','contacted',@seed_day-INTERVAL 2 DAY);

  -- 6. Notification inbox: linked destinations and read/unread states.
  INSERT INTO notifications
    (id,user_id,deduplication_key,category,title,body,topic_id,attempt_id,contest_id,
     subscription_id,created_at,read_at,expires_at)
  VALUES
    (1,1,'demo-revision-1','revision','Tamil Grammar is due for revision','Revisit the topic from your last study session.',1,NULL,NULL,NULL,@seed_day,NULL,NULL),
    (2,1,'demo-result-2','test','Your mock result is ready','You scored 7.5 out of 9 in the mini mock.',NULL,2,NULL,NULL,@seed_day-INTERVAL 2 DAY+INTERVAL 6 MINUTE,@seed_day-INTERVAL 2 DAY+INTERVAL 1 HOUR,NULL),
    (3,1,'demo-contest-1','contest','Weekly Challenge results','You finished first in this demo contest.',NULL,NULL,1,NULL,@seed_day-INTERVAL 3 DAY,NULL,NULL),
    (4,1,'demo-billing-1','billing','Plus subscription activated','Your demo subscription is active.',NULL,NULL,NULL,1,@seed_day-INTERVAL 7 DAY+INTERVAL 3 MINUTE,@seed_day-INTERVAL 6 DAY,NULL),
    (5,2,'demo-billing-2','billing','Payment was unsuccessful','The fictional payment was declined.',NULL,NULL,NULL,2,@seed_day-INTERVAL 1 DAY+INTERVAL 3 MINUTE,NULL,NULL),
    (6,3,'demo-welcome-3','account','Welcome, Meena','Your learning profile is ready.',NULL,NULL,NULL,NULL,@seed_now,NULL,NULL),
    (7,1,'demo-contest-2','contest','Next Weekly Challenge','Your registration is confirmed.',NULL,NULL,2,NULL,@seed_now,NULL,@seed_day+INTERVAL 5 DAY);

  COMMIT;
END$$
CALL seed_tnpsc_test_data()$$
DROP PROCEDURE seed_tnpsc_test_data$$
DELIMITER ;

SELECT 'Demo data inserted into all 37 tables' AS seed_status, @seed_now AS seeded_at_utc;
SELECT user_id,scored_marks,maximum_marks,contest_rank,percentile
FROM v_contest_leaderboard WHERE contest_id=1 ORDER BY contest_rank;
