CREATE OR REPLACE
PACKAGE users_pkg IS

TYPE users_list IS TABLE OF USERS%ROWTYPE;
TYPE posts_list IS TABLE OF POSTS%ROWTYPE;

FUNCTION find_users_by_name(
  p_name    USERS.NAME%TYPE)
RETURN users_list
PIPELINED;

FUNCTION find_posts_by_user_id(
  p_user_id POSTS.USER_ID%TYPE)
RETURN posts_list
PIPELINED;

PROCEDURE create_user(
  o_id      OUT USERS.ID%TYPE,
  p_name    IN USERS.NAME%TYPE,
  p_surname IN USERS.SURNAME%TYPE);

PROCEDURE update_user(
  p_id      IN USERS.ID%TYPE,
  p_name    IN USERS.NAME%TYPE,
  p_surname IN USERS.SURNAME%TYPE);

FUNCTION salute(
  p_name    IN VARCHAR2)
RETURN VARCHAR2;

END users_pkg;