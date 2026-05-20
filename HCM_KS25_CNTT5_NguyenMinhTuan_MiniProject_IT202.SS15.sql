DROP DATABASE IF EXISTS SocialNetworkDB;
CREATE DATABASE SocialNetworkDB;
USE SocialNetworkDB;

SET SQL_SAFE_UPDATES = 0;

CREATE TABLE users (
    user_id INT PRIMARY KEY AUTO_INCREMENT,
    username VARCHAR(50) NOT NULL UNIQUE,
    password VARCHAR(255) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE posts (
    post_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    like_count INT NOT NULL DEFAULT 0,
    comment_count INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_posts_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
);

CREATE TABLE comments (
    comment_id INT PRIMARY KEY AUTO_INCREMENT,
    post_id INT NOT NULL,
    user_id INT NOT NULL,
    content TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_comments_post
        FOREIGN KEY (post_id)
        REFERENCES posts(post_id),
    CONSTRAINT fk_comments_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id)
);

CREATE TABLE friends (
    friendship_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    friend_id INT NOT NULL,
    status ENUM('pending', 'accepted', 'rejected') NOT NULL DEFAULT 'pending',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_friends_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id),
    CONSTRAINT fk_friends_friend
        FOREIGN KEY (friend_id)
        REFERENCES users(user_id),
    CONSTRAINT chk_friend_not_same
        CHECK (user_id <> friend_id)
);

CREATE TABLE likes (
    like_id INT PRIMARY KEY AUTO_INCREMENT,
    user_id INT NOT NULL,
    post_id INT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_likes_user
        FOREIGN KEY (user_id)
        REFERENCES users(user_id),
    CONSTRAINT fk_likes_post
        FOREIGN KEY (post_id)
        REFERENCES posts(post_id),
    CONSTRAINT uq_user_post UNIQUE(user_id, post_id)
);

INSERT INTO users(username, password, email)
VALUES
('an_nguyen', SHA1('matkhau123'), 'an@gmail.com'),
('binh_tran', SHA1('binh456'), 'binh@gmail.com'),
('chi_le', SHA1('chi789'), 'chi@gmail.com'),
('duy_pham', SHA1('duy321'), 'duy@gmail.com'),
('hoa_vo', SHA1('hoa654'), 'hoa@gmail.com');

INSERT INTO posts(user_id, content)
VALUES
(1, 'Hôm nay trời đẹp quá, đi cà phê thôi!'),
(2, 'Đang học thiết kế cơ sở dữ liệu MySQL.'),
(3, 'Code frontend xong muốn đi ngủ luôn.'),
(4, 'Vừa hoàn thành project backend đầu tiên.'),
(5, 'Cố gắng học fullstack mỗi ngày.');

INSERT INTO comments(post_id, user_id, content)
VALUES
(1, 2, 'Đi cà phê nhớ rủ nha.'),
(1, 3, 'Thời tiết hôm nay đúng chill thật.'),
(2, 1, 'MySQL học càng nhiều càng lú.'),
(3, 5, 'Frontend nhiều lỗi vặt khó chịu thật.'),
(5, 4, 'Cố lên rồi sẽ thành công.');

INSERT INTO friends(user_id, friend_id, status)
VALUES
(1, 2, 'accepted'),
(1, 3, 'accepted'),
(2, 4, 'pending'),
(3, 5, 'accepted'),
(4, 5, 'accepted');

INSERT INTO likes(user_id, post_id)
VALUES
(2,1),
(3,1),
(1,2),
(4,2),
(5,2);

UPDATE posts p
SET
    like_count = (
        SELECT COUNT(*)
        FROM likes l
        WHERE l.post_id = p.post_id
    ),
    comment_count = (
        SELECT COUNT(*)
        FROM comments c
        WHERE c.post_id = p.post_id
    );

DELIMITER //

CREATE TRIGGER trg_after_like
AFTER INSERT ON likes
FOR EACH ROW
BEGIN
    UPDATE posts
    SET like_count = like_count + 1
    WHERE post_id = NEW.post_id;
END //

CREATE TRIGGER trg_after_unlike
AFTER DELETE ON likes
FOR EACH ROW
BEGIN
    UPDATE posts
    SET like_count =
        CASE
            WHEN like_count > 0 THEN like_count - 1
            ELSE 0
        END
    WHERE post_id = OLD.post_id;
END //

CREATE TRIGGER trg_after_comment
AFTER INSERT ON comments
FOR EACH ROW
BEGIN
    UPDATE posts
    SET comment_count = comment_count + 1
    WHERE post_id = NEW.post_id;
END //

CREATE TRIGGER trg_after_delete_comment
AFTER DELETE ON comments
FOR EACH ROW
BEGIN
    UPDATE posts
    SET comment_count =
        CASE
            WHEN comment_count > 0 THEN comment_count - 1
            ELSE 0
        END
    WHERE post_id = OLD.post_id;
END //

CREATE TRIGGER trg_check_friend_request
BEFORE INSERT ON friends
FOR EACH ROW
BEGIN
    DECLARE existing_count INT;

    IF NEW.user_id = NEW.friend_id THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Không thể kết bạn với chính mình';
    END IF;

    SELECT COUNT(*)
    INTO existing_count
    FROM friends
    WHERE
        (user_id = NEW.user_id AND friend_id = NEW.friend_id)
        OR
        (user_id = NEW.friend_id AND friend_id = NEW.user_id);

    IF existing_count > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Lời mời kết bạn đã tồn tại';
    END IF;
END //

DELIMITER ;

DROP PROCEDURE IF EXISTS create_account_social;

DELIMITER //

CREATE PROCEDURE create_account_social(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255),
    IN p_email VARCHAR(100)
)
BEGIN
    IF EXISTS (
        SELECT 1
        FROM users
        WHERE username = p_username
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Username đã tồn tại';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM users
        WHERE email = p_email
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Email đã tồn tại';
    END IF;

    INSERT INTO users(username, password, email)
    VALUES(
        p_username,
        SHA1(p_password),
        p_email
    );

    SELECT 'Tạo tài khoản thành công' AS message;
END //

DELIMITER ;

DROP PROCEDURE IF EXISTS create_post;

DELIMITER //

CREATE PROCEDURE create_post(
    IN p_user_id INT,
    IN p_content TEXT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE user_id = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User không tồn tại';
    END IF;

    IF p_content IS NULL OR TRIM(p_content) = '' THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Nội dung bài viết không hợp lệ';
    END IF;

    INSERT INTO posts(user_id, content)
    VALUES(p_user_id, p_content);

    SELECT 'Tạo bài viết thành công' AS message;
END //

DELIMITER ;

DROP PROCEDURE IF EXISTS toggle_like_post;

DELIMITER //

CREATE PROCEDURE toggle_like_post(
    IN p_user_id INT,
    IN p_post_id INT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE user_id = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User không tồn tại';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM posts
        WHERE post_id = p_post_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Bài viết không tồn tại';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM likes
        WHERE user_id = p_user_id
        AND post_id = p_post_id
    ) THEN

        DELETE FROM likes
        WHERE user_id = p_user_id
        AND post_id = p_post_id;

        SELECT 'Đã bỏ thích bài viết' AS message;

    ELSE

        INSERT INTO likes(user_id, post_id)
        VALUES(p_user_id, p_post_id);

        SELECT 'Đã thích bài viết' AS message;

    END IF;
END //

DELIMITER ;

DROP PROCEDURE IF EXISTS send_friend_request;

DELIMITER //

CREATE PROCEDURE send_friend_request(
    IN p_user_id INT,
    IN p_friend_id INT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE user_id = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User gửi không tồn tại';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE user_id = p_friend_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User nhận không tồn tại';
    END IF;

    INSERT INTO friends(user_id, friend_id, status)
    VALUES(p_user_id, p_friend_id, 'pending');

    SELECT 'Gửi lời mời kết bạn thành công' AS message;
END //

DELIMITER ;

DROP PROCEDURE IF EXISTS manage_friendship;

DELIMITER //

CREATE PROCEDURE manage_friendship(
    IN p_user_id INT,
    IN p_friend_id INT,
    IN p_action VARCHAR(20)
)
BEGIN
    IF p_action = 'accept' THEN

        UPDATE friends
        SET status = 'accepted'
        WHERE
            user_id = p_friend_id
            AND friend_id = p_user_id
            AND status = 'pending';

        SELECT 'Đã chấp nhận lời mời kết bạn' AS message;

    ELSEIF p_action = 'reject' THEN

        UPDATE friends
        SET status = 'rejected'
        WHERE
            user_id = p_friend_id
            AND friend_id = p_user_id
            AND status = 'pending';

        SELECT 'Đã từ chối lời mời kết bạn' AS message;

    ELSEIF p_action = 'cancel' THEN

        DELETE FROM friends
        WHERE
            (user_id = p_user_id AND friend_id = p_friend_id)
            OR
            (user_id = p_friend_id AND friend_id = p_user_id);

        SELECT 'Đã hủy kết bạn' AS message;

    ELSE

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Hành động không hợp lệ';

    END IF;
END //

DELIMITER ;

DROP VIEW IF EXISTS user_profile_view;

CREATE VIEW user_profile_view AS
SELECT
    u.user_id,
    u.username,
    u.email,
    u.created_at,
    COUNT(DISTINCT p.post_id) AS total_posts,
    COALESCE(SUM(p.like_count), 0) AS total_likes_received,
    COALESCE(SUM(p.comment_count), 0) AS total_comments_received
FROM users u
LEFT JOIN posts p
    ON u.user_id = p.user_id
GROUP BY
    u.user_id,
    u.username,
    u.email,
    u.created_at;

DROP PROCEDURE IF EXISTS search_posts;

DELIMITER //

CREATE PROCEDURE search_posts(
    IN p_keyword VARCHAR(100)
)
BEGIN
    SELECT
        p.post_id,
        u.username,
        p.content,
        p.like_count,
        p.comment_count,
        p.created_at
    FROM posts p
    INNER JOIN users u
        ON p.user_id = u.user_id
    WHERE p.content LIKE CONCAT('%', p_keyword, '%')
    ORDER BY p.created_at DESC;
END //

DELIMITER ;

DROP PROCEDURE IF EXISTS report_user_activity;

DELIMITER //

CREATE PROCEDURE report_user_activity(
    IN p_user_id INT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE user_id = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User không tồn tại';
    END IF;

    SELECT
        u.user_id,
        u.username,
        COUNT(DISTINCT p.post_id) AS total_posts,
        COALESCE(SUM(p.like_count), 0) AS total_likes_received,
        COALESCE(SUM(p.comment_count), 0) AS total_comments_received
    FROM users u
    LEFT JOIN posts p
        ON u.user_id = p.user_id
    WHERE u.user_id = p_user_id
    GROUP BY u.user_id, u.username;
END //

DELIMITER ;

DROP PROCEDURE IF EXISTS sp_suggest_friends;

DELIMITER //

CREATE PROCEDURE sp_suggest_friends(
    IN p_user_id INT
)
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE user_id = p_user_id
    ) THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User không tồn tại';
    END IF;

    WITH my_friends AS (
        SELECT
            CASE
                WHEN user_id = p_user_id THEN friend_id
                ELSE user_id
            END AS friend_user_id
        FROM friends
        WHERE
            (user_id = p_user_id OR friend_id = p_user_id)
            AND status = 'accepted'
    ),
    friends_of_friends AS (
        SELECT
            CASE
                WHEN f.user_id = mf.friend_user_id THEN f.friend_id
                ELSE f.user_id
            END AS suggested_user_id,
            mf.friend_user_id AS mutual_friend_id
        FROM friends f
        INNER JOIN my_friends mf
            ON f.user_id = mf.friend_user_id
            OR f.friend_id = mf.friend_user_id
        WHERE f.status = 'accepted'
    )
    SELECT
        u.user_id,
        u.username,
        COUNT(DISTINCT fof.mutual_friend_id) AS mutual_friend_count
    FROM friends_of_friends fof
    INNER JOIN users u
        ON u.user_id = fof.suggested_user_id
    WHERE fof.suggested_user_id <> p_user_id
    AND fof.suggested_user_id NOT IN (
        SELECT friend_user_id
        FROM my_friends
    )
    GROUP BY u.user_id, u.username
    ORDER BY mutual_friend_count DESC, u.username ASC;
END //

DELIMITER ;

DROP PROCEDURE IF EXISTS delete_post;

DELIMITER //

CREATE PROCEDURE delete_post(
    IN p_post_id INT,
    IN p_user_id INT
)
BEGIN
    DECLARE v_owner_id INT;

    START TRANSACTION;

    SELECT user_id
    INTO v_owner_id
    FROM posts
    WHERE post_id = p_post_id;

    IF v_owner_id IS NULL THEN

        ROLLBACK;

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Bài viết không tồn tại';

    END IF;

    IF v_owner_id <> p_user_id THEN

        ROLLBACK;

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Bạn không có quyền xóa bài viết này';

    END IF;

    DELETE FROM likes
    WHERE post_id = p_post_id;

    DELETE FROM comments
    WHERE post_id = p_post_id;

    DELETE FROM posts
    WHERE post_id = p_post_id;

    COMMIT;

    SELECT 'Xóa bài viết thành công' AS message;
END //

DELIMITER ;

DROP PROCEDURE IF EXISTS delete_user;

DELIMITER //

CREATE PROCEDURE delete_user(
    IN p_user_id INT
)
BEGIN
    START TRANSACTION;

    IF NOT EXISTS (
        SELECT 1
        FROM users
        WHERE user_id = p_user_id
    ) THEN

        ROLLBACK;

        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'User không tồn tại';

    END IF;

    DELETE FROM likes
    WHERE user_id = p_user_id;

    DELETE FROM comments
    WHERE user_id = p_user_id;

    DELETE FROM friends
    WHERE user_id = p_user_id
    OR friend_id = p_user_id;

    DELETE FROM likes
    WHERE post_id IN (
        SELECT post_id
        FROM posts
        WHERE user_id = p_user_id
    );

    DELETE FROM comments
    WHERE post_id IN (
        SELECT post_id
        FROM posts
        WHERE user_id = p_user_id
    );

    DELETE FROM posts
    WHERE user_id = p_user_id;

    DELETE FROM users
    WHERE user_id = p_user_id;

    COMMIT;

    SELECT 'Xóa người dùng thành công' AS message;
END //

DELIMITER ;

CALL create_account_social('minhtuan', '123456', 'minhtuan@gmail.com');

CALL create_post(1, 'Hello social network');

CALL toggle_like_post(1, 3);

CALL toggle_like_post(1, 3);

CALL send_friend_request(2, 5);

CALL manage_friendship(5, 2, 'accept');

CALL search_posts('MySQL');

CALL report_user_activity(1);

CALL sp_suggest_friends(1);

SELECT * FROM user_profile_view;
