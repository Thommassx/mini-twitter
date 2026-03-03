-- Projeto: Rede Social Simplificada (mini-twitter)
-- Etapa 2 (DDL) + Etapa 3 (Triggers)

DROP DATABASE IF EXISTS social_db;
CREATE DATABASE social_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE social_db;

-- ============================
-- TABELAS
-- ============================

CREATE TABLE users (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(120) NOT NULL,
    email VARCHAR(160) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    bio VARCHAR(255) NULL,
    is_active TINYINT(1) NOT NULL DEFAULT 1,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

CREATE TABLE posts (
    id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    visibility ENUM('public', 'private') NOT NULL DEFAULT 'public',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_posts_user FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE comments (
    id INT PRIMARY KEY AUTO_INCREMENT,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_comments_post FOREIGN KEY (post_id) REFERENCES posts(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_comments_user FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE likes (
    user_id INT NOT NULL,
    post_id INT NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, post_id),
    CONSTRAINT fk_likes_user FOREIGN KEY (user_id) REFERENCES users(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,
    CONSTRAINT fk_likes_post FOREIGN KEY (post_id) REFERENCES posts(id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
);

CREATE TABLE audit_log (
    id BIGINT PRIMARY KEY AUTO_INCREMENT,
    table_name VARCHAR(64) NOT NULL,
    operation ENUM('INSERT', 'UPDATE', 'DELETE') NOT NULL,
    record_id BIGINT NOT NULL,
    changed_by_user_id INT NULL,
    details JSON NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- Índices auxiliares para consultas
CREATE INDEX idx_posts_user_created_at ON posts(user_id, created_at);
CREATE INDEX idx_comments_post_created_at ON comments(post_id, created_at);
CREATE INDEX idx_likes_post_created_at ON likes(post_id, created_at);

-- ============================
-- TRIGGERS DE VALIDAÇÃO
-- ============================

DELIMITER $$

CREATE TRIGGER trg_users_bi_validate_email
BEFORE INSERT ON users
FOR EACH ROW
BEGIN
    IF NEW.email IS NULL OR TRIM(NEW.email) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'E-mail não pode ser vazio.';
    END IF;
END $$

CREATE TRIGGER trg_users_bu_validate_email
BEFORE UPDATE ON users
FOR EACH ROW
BEGIN
    IF NEW.email IS NULL OR TRIM(NEW.email) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'E-mail não pode ser vazio.';
    END IF;
END $$

CREATE TRIGGER trg_posts_bi_validate_content
BEFORE INSERT ON posts
FOR EACH ROW
BEGIN
    IF NEW.content IS NULL OR CHAR_LENGTH(TRIM(NEW.content)) < 3 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Conteúdo do post não pode ser vazio ou muito curto.';
    END IF;
END $$

CREATE TRIGGER trg_posts_bu_validate_content
BEFORE UPDATE ON posts
FOR EACH ROW
BEGIN
    IF NEW.content IS NULL OR CHAR_LENGTH(TRIM(NEW.content)) < 3 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Conteúdo do post não pode ser vazio ou muito curto.';
    END IF;
END $$

CREATE TRIGGER trg_comments_bi_validate_content
BEFORE INSERT ON comments
FOR EACH ROW
BEGIN
    IF NEW.content IS NULL OR TRIM(NEW.content) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Comentário não pode ser vazio.';
    END IF;
END $$

CREATE TRIGGER trg_comments_bu_validate_content
BEFORE UPDATE ON comments
FOR EACH ROW
BEGIN
    IF NEW.content IS NULL OR TRIM(NEW.content) = '' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Comentário não pode ser vazio.';
    END IF;
END $$

-- Reforço para like duplicado (além da PK composta)
CREATE TRIGGER trg_likes_bi_no_duplicate
BEFORE INSERT ON likes
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1
        FROM likes l
        WHERE l.user_id = NEW.user_id
          AND l.post_id = NEW.post_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Like duplicado não permitido.';
    END IF;
END $$

-- ============================
-- TRIGGERS DE AUDITORIA
-- ============================

CREATE TRIGGER trg_users_ai_audit
AFTER INSERT ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, record_id, changed_by_user_id, details)
    VALUES (
        'users',
        'INSERT',
        NEW.id,
        NEW.id,
        JSON_OBJECT('name', NEW.name, 'email', NEW.email, 'is_active', NEW.is_active)
    );
END $$

CREATE TRIGGER trg_users_au_audit
AFTER UPDATE ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, record_id, changed_by_user_id, details)
    VALUES (
        'users',
        'UPDATE',
        NEW.id,
        NEW.id,
        JSON_OBJECT(
            'old_name', OLD.name,
            'new_name', NEW.name,
            'old_email', OLD.email,
            'new_email', NEW.email,
            'old_is_active', OLD.is_active,
            'new_is_active', NEW.is_active
        )
    );
END $$

CREATE TRIGGER trg_users_ad_audit
AFTER DELETE ON users
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, record_id, changed_by_user_id, details)
    VALUES (
        'users',
        'DELETE',
        OLD.id,
        OLD.id,
        JSON_OBJECT('name', OLD.name, 'email', OLD.email)
    );
END $$

CREATE TRIGGER trg_posts_ai_audit
AFTER INSERT ON posts
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, record_id, changed_by_user_id, details)
    VALUES (
        'posts',
        'INSERT',
        NEW.id,
        NEW.user_id,
        JSON_OBJECT('visibility', NEW.visibility, 'content', NEW.content)
    );
END $$

CREATE TRIGGER trg_posts_au_audit
AFTER UPDATE ON posts
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, record_id, changed_by_user_id, details)
    VALUES (
        'posts',
        'UPDATE',
        NEW.id,
        NEW.user_id,
        JSON_OBJECT(
            'old_content', OLD.content,
            'new_content', NEW.content,
            'old_visibility', OLD.visibility,
            'new_visibility', NEW.visibility
        )
    );
END $$

CREATE TRIGGER trg_posts_ad_audit
AFTER DELETE ON posts
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, record_id, changed_by_user_id, details)
    VALUES (
        'posts',
        'DELETE',
        OLD.id,
        OLD.user_id,
        JSON_OBJECT('visibility', OLD.visibility, 'content', OLD.content)
    );
END $$

CREATE TRIGGER trg_comments_ai_audit
AFTER INSERT ON comments
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, record_id, changed_by_user_id, details)
    VALUES (
        'comments',
        'INSERT',
        NEW.id,
        NEW.user_id,
        JSON_OBJECT('post_id', NEW.post_id, 'content', NEW.content)
    );
END $$

CREATE TRIGGER trg_comments_au_audit
AFTER UPDATE ON comments
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, record_id, changed_by_user_id, details)
    VALUES (
        'comments',
        'UPDATE',
        NEW.id,
        NEW.user_id,
        JSON_OBJECT('old_content', OLD.content, 'new_content', NEW.content)
    );
END $$

CREATE TRIGGER trg_comments_ad_audit
AFTER DELETE ON comments
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, record_id, changed_by_user_id, details)
    VALUES (
        'comments',
        'DELETE',
        OLD.id,
        OLD.user_id,
        JSON_OBJECT('post_id', OLD.post_id, 'content', OLD.content)
    );
END $$

CREATE TRIGGER trg_likes_ai_audit
AFTER INSERT ON likes
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, record_id, changed_by_user_id, details)
    VALUES (
        'likes',
        'INSERT',
        NEW.post_id,
        NEW.user_id,
        JSON_OBJECT('user_id', NEW.user_id, 'post_id', NEW.post_id)
    );
END $$

CREATE TRIGGER trg_likes_ad_audit
AFTER DELETE ON likes
FOR EACH ROW
BEGIN
    INSERT INTO audit_log (table_name, operation, record_id, changed_by_user_id, details)
    VALUES (
        'likes',
        'DELETE',
        OLD.post_id,
        OLD.user_id,
        JSON_OBJECT('user_id', OLD.user_id, 'post_id', OLD.post_id)
    );
END $$

DELIMITER ;
