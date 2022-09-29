--login.lua

return {
    name = "login",
    openid = "test001",
    password = "123456",
    server = "127.0.0.1:20013",
    protocols = {
        {
            id = 10009,
            name = "NID_LOGIN_ROLE_CHOOSE_REQ",
            args = { user_id = 0, role_id = 0 }
        },
        {
            id = 10011,
            name = "NID_LOGIN_ROLE_DELETE_REQ",
            args = { user_id = 0, role_id = 0 }
        }
    }
}