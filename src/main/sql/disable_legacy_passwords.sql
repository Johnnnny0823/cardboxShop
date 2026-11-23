-- MySQL 8.4. Apply to an existing database after arranging secure account recovery.
-- The disabled marker cannot authenticate. Valid PBKDF2 credentials are preserved.
UPDATE member
SET password = '!'
WHERE password <> '!'
  AND NOT REGEXP_LIKE(password, '^pbkdf2-sha256[$][A-Za-z0-9+/]{22}==[$][A-Za-z0-9+/]{43}=$', 'c');
