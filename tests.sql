USE social_db;

-- ==========================================
-- Carga inicial com procedures
-- ==========================================

CALL sp_user_create('Ana', 'ana@email.com', 'hash_ana', 'Dev backend');
CALL sp_user_create('Bruno', 'bruno@email.com', 'hash_bruno', 'DBA');
CALL sp_user_create('Carla', 'carla@email.com', 'hash_carla', 'Fullstack');

CALL sp_post_create(1, 'Primeiro post da Ana!', 'public');
CALL sp_post_create(1, 'Segundo post da Ana', 'public');
CALL sp_post_create(2, 'Post do Bruno sobre SQL', 'public');
CALL sp_post_create(3, 'Post privado da Carla', 'private');

CALL sp_comment_create(1, 2, 'Boa postagem!');
CALL sp_comment_create(1, 3, 'Curti demais.');
CALL sp_comment_create(3, 1, 'Ótimo conteúdo técnico.');

CALL sp_like_add(2, 1);
CALL sp_like_add(3, 1);
CALL sp_like_add(1, 3);
CALL sp_like_add(3, 3);

-- ==========================================
-- Testes de falhas controladas (com handlers)
-- ==========================================

DELIMITER $$

DROP PROCEDURE IF EXISTS sp_run_controlled_failures $$
CREATE PROCEDURE sp_run_controlled_failures()
BEGIN
    DECLARE CONTINUE HANDLER FOR SQLEXCEPTION
    BEGIN
        -- apenas continua para registrar cada cenário
        SELECT 'Falha capturada com sucesso.' AS handled_error;
    END;

    -- 1) e-mail vazio (trigger users)
    INSERT INTO users(name, email, password_hash) VALUES ('Invalido', '   ', 'hash_x');

    -- 2) post muito curto (trigger posts)
    CALL sp_post_create(1, 'x', 'public');

    -- 3) comentário vazio (trigger comments)
    CALL sp_comment_create(1, 2, '    ');

    -- 4) like duplicado (PK + trigger)
    CALL sp_like_add(2, 1);
END $$

DELIMITER ;

CALL sp_run_controlled_failures();

-- ==========================================
-- ETAPA 5 - Consultas de processamento
-- ==========================================

-- 1) Top 5 posts com mais likes
SELECT
    p.id AS post_id,
    p.content,
    u.name AS author,
    COUNT(l.user_id) AS total_likes
FROM posts p
JOIN users u ON u.id = p.user_id
LEFT JOIN likes l ON l.post_id = p.id
GROUP BY p.id, p.content, u.name
ORDER BY total_likes DESC, p.id ASC
LIMIT 5;

-- 2) Top 5 usuários que mais postaram
SELECT
    u.id AS user_id,
    u.name,
    COUNT(p.id) AS total_posts
FROM users u
LEFT JOIN posts p ON p.user_id = u.id
GROUP BY u.id, u.name
ORDER BY total_posts DESC, u.id ASC
LIMIT 5;

-- 3) Posts com maior número de comentários
SELECT
    p.id AS post_id,
    p.content,
    COUNT(c.id) AS total_comments
FROM posts p
LEFT JOIN comments c ON c.post_id = p.id
GROUP BY p.id, p.content
ORDER BY total_comments DESC, p.id ASC;

-- 4) Quantidade de posts por dia (últimos 7 dias)
SELECT
    DATE(p.created_at) AS post_date,
    COUNT(*) AS total_posts
FROM posts p
WHERE p.created_at >= DATE_SUB(CURRENT_DATE(), INTERVAL 6 DAY)
GROUP BY DATE(p.created_at)
ORDER BY post_date ASC;

-- 5) Feed completo com total de likes e comentários
SELECT
    p.id AS post_id,
    u.name AS author,
    p.content,
    p.visibility,
    p.created_at,
    COUNT(DISTINCT l.user_id) AS total_likes,
    COUNT(DISTINCT c.id) AS total_comments
FROM posts p
JOIN users u ON u.id = p.user_id
LEFT JOIN likes l ON l.post_id = p.id
LEFT JOIN comments c ON c.post_id = p.id
GROUP BY p.id, u.name, p.content, p.visibility, p.created_at
ORDER BY p.created_at DESC, p.id DESC;

-- Auditoria (amostra)
SELECT *
FROM audit_log
ORDER BY id DESC
LIMIT 20;
