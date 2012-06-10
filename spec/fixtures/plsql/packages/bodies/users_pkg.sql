CREATE OR REPLACE
PACKAGE BODY users_pkg IS

FUNCTION find_users_by_name(
  p_name    USERS.NAME%TYPE)
RETURN users_list
PIPELINED
IS
BEGIN
  FOR l_user IN (
    SELECT *
    FROM   users
    WHERE  name = p_name)
  LOOP
    PIPE ROW(l_user);
  END LOOP;
END FIND_USERS_BY_NAME;

FUNCTION find_posts_by_user_id(
  p_user_id POSTS.USER_ID%TYPE)
RETURN posts_list
PIPELINED
IS
BEGIN
  FOR l_post IN (
    SELECT *
    FROM   posts
    WHERE  user_id = p_user_id)
  LOOP
    PIPE ROW(l_post);
  END LOOP;
END find_posts_by_user_id;

PROCEDURE create_user(
  o_id      OUT USERS.ID%TYPE,
  p_name    IN USERS.NAME%TYPE,
  p_surname IN USERS.SURNAME%TYPE)
IS
BEGIN
  SELECT NVL(MAX(id), 0) + 1
  INTO   o_id
  FROM   users;

  INSERT INTO users(id, name, surname)
  VALUES(o_id, initcap(p_name), initcap(p_surname));
END create_user;

PROCEDURE update_user(
  p_id      IN USERS.ID%TYPE,
  p_name    IN USERS.NAME%TYPE,
  p_surname IN USERS.SURNAME%TYPE)
IS
BEGIN
  UPDATE users
  SET    name = initcap(p_name),
         surname = initcap(p_surname)
  WHERE  id = p_id;
END update_user;

FUNCTION salute(
  p_name    IN VARCHAR2)
RETURN VARCHAR2
IS
BEGIN
  RETURN 'Hello, ' || p_name || '!';
END salute;

END users_pkg;