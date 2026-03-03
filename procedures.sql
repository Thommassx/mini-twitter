USE social_db;

DELIMITER $$

-- ==========================================
-- USERS
-- ==========================================

CREATE PROCEDURE sp_user_create (
    IN p_name VARCHAR(120),
    IN p_email VARCHAR(160),
    IN p_password_hash VARCHAR(255),
    IN p_bio VARCHAR(255)
)
BEGIN
    INSERT INTO users (name, email, password_hash, bio)
    VALUES (p_name, p_email, p_password_hash, p_bio);

    SELECT LAST_INSERT_ID() AS user_id;
END $$

CREATE PROCEDURE sp_user_update (
    IN p_user_id INT,
    IN p_name VARCHAR(120),
    IN p_email VARCHAR(160),
    IN p_password_hash VARCHAR(255),
    IN p_bio VARCHAR(255),
    IN p_is_active TINYINT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.id = p_user_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Usuário não encontrado.';
    END IF;

    UPDATE users
    SET name = COALESCE(p_name, name),
        email = COALESCE(p_email, email),
        password_hash = COALESCE(p_password_hash, password_hash),
        bio = p_bio,
        is_active = COALESCE(p_is_active, is_active)
    WHERE id = p_user_id;

    SELECT ROW_COUNT() AS rows_affected;
END $$

CREATE PROCEDURE sp_user_delete (
    IN p_user_id INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.id = p_user_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Usuário não encontrado.';
    END IF;

    DELETE FROM users WHERE id = p_user_id;

    SELECT ROW_COUNT() AS rows_affected;
END $$

-- ==========================================
-- POSTS
-- ==========================================

CREATE PROCEDURE sp_post_create (
    IN p_user_id INT,
    IN p_content TEXT,
    IN p_visibility ENUM('public', 'private')
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.id = p_user_id AND u.is_active = 1) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Usuário inválido ou inativo.';
    END IF;

    INSERT INTO posts (user_id, content, visibility)
    VALUES (p_user_id, p_content, COALESCE(p_visibility, 'public'));

    SELECT LAST_INSERT_ID() AS post_id;
END $$

CREATE PROCEDURE sp_post_update (
    IN p_post_id INT,
    IN p_actor_user_id INT,
    IN p_content TEXT,
    IN p_visibility ENUM('public', 'private')
)
BEGIN
    DECLARE v_owner_id INT;

    SELECT user_id INTO v_owner_id
    FROM posts
    WHERE id = p_post_id;

    IF v_owner_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Post não encontrado.';
    END IF;

    IF v_owner_id <> p_actor_user_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Apenas o autor pode atualizar o post.';
    END IF;

    UPDATE posts
    SET content = COALESCE(p_content, content),
        visibility = COALESCE(p_visibility, visibility)
    WHERE id = p_post_id;

    SELECT ROW_COUNT() AS rows_affected;
END $$

CREATE PROCEDURE sp_post_delete (
    IN p_post_id INT,
    IN p_actor_user_id INT
)
BEGIN
    DECLARE v_owner_id INT;

    SELECT user_id INTO v_owner_id
    FROM posts
    WHERE id = p_post_id;

    IF v_owner_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Post não encontrado.';
    END IF;

    IF v_owner_id <> p_actor_user_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Apenas o autor pode excluir o post.';
    END IF;

    DELETE FROM posts WHERE id = p_post_id;

    SELECT ROW_COUNT() AS rows_affected;
END $$

-- ==========================================
-- COMMENTS
-- ==========================================

CREATE PROCEDURE sp_comment_create (
    IN p_post_id INT,
    IN p_user_id INT,
    IN p_content TEXT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM posts p WHERE p.id = p_post_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Post não encontrado.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.id = p_user_id AND u.is_active = 1) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Usuário inválido ou inativo.';
    END IF;

    INSERT INTO comments (post_id, user_id, content)
    VALUES (p_post_id, p_user_id, p_content);

    SELECT LAST_INSERT_ID() AS comment_id;
END $$

CREATE PROCEDURE sp_comment_delete (
    IN p_comment_id INT,
    IN p_actor_user_id INT
)
BEGIN
    DECLARE v_owner_id INT;

    SELECT user_id INTO v_owner_id
    FROM comments
    WHERE id = p_comment_id;

    IF v_owner_id IS NULL THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Comentário não encontrado.';
    END IF;

    IF v_owner_id <> p_actor_user_id THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Apenas o autor pode excluir o comentário.';
    END IF;

    DELETE FROM comments WHERE id = p_comment_id;

    SELECT ROW_COUNT() AS rows_affected;
END $$

-- ==========================================
-- LIKES
-- ==========================================

CREATE PROCEDURE sp_like_add (
    IN p_user_id INT,
    IN p_post_id INT
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM users u WHERE u.id = p_user_id AND u.is_active = 1) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Usuário inválido ou inativo.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM posts p WHERE p.id = p_post_id) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Post não encontrado.';
    END IF;

    INSERT INTO likes (user_id, post_id)
    VALUES (p_user_id, p_post_id);

    SELECT ROW_COUNT() AS rows_affected;
END $$

CREATE PROCEDURE sp_like_remove (
    IN p_user_id INT,
    IN p_post_id INT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM likes l
        WHERE l.user_id = p_user_id
          AND l.post_id = p_post_id
    ) THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Like não encontrado.';
    END IF;

    DELETE FROM likes
    WHERE user_id = p_user_id
      AND post_id = p_post_id;

    SELECT ROW_COUNT() AS rows_affected;
END $$

DELIMITER ;
