return {
    name = "login_base",
    root = 1,
    nodes = {
        [1] = {
            type = "SOCK",
            ip = { type = "attr", value = "ip" },
            port = { type = "attr", value = "port" },
            next = 2,
        },
        [2] = {
            type = "REQ",
            cmd_id = "NID_LOGIN_ACCOUNT_LOGIN_REQ",
            inputs = {
                openid = { type = "attr", value = "open_id" },
                session = { type = "string", value = "123456" },
                platform = { type = "number", value = 1 },
                device_id = { type = "attr", value = "device_id" },
            },
            outputs = {
                players = { type = "attr", value = "players" },
                user_id = { type = "attr", value = "user_id" },
            },
            next = 3,
        },
        [3] = {
            type = "COND",
            cond = "#robot.players>0",
            result = {
                success = 4,
                failed = 5,
            },
        },
        [4] = {
            type = "REQ",
            cmd_id = "NID_LOGIN_PALYER_CHOOSE_REQ",
            inputs = {
                user_id = { type = "attr", value = "user_id" },
                player_id = { type = "lua", value = "robot.players[1].player_id" },
            },
            outputs = {
                lobby = { type = "attr", value = "lobby" },
                gate_port = { type = "attr", value = "gate_port" },
                gate_ip = { type = "attr", value = "gate_ip" },
                verify_code = { type = "attr", value = "verify_code" },
                player_id = { type = "attr", value = "player_id" },
            },
            next = 6,
        },
        [5] = {
            type = "REQ",
            cmd_id = "NID_LOGIN_PALYER_CREATE_REQ",
            inputs = {
                user_id = { type = "attr", value = "user_id" },
                name = { type = "string", value = "test_001" },
            },
            after = "table.insert(robot.playes, res.player)",
            next = 4,
        },
        [6] = {
            type = "SOCK",
            ip = { type = "attr", value = "gate_ip" },
            port = { type = "attr", value = "gate_port" },
            after = "",
            next = 12,
        },
        [7] = {
            type = "REQ",
            cmd_id = "NID_LOGIN_PALYER_LOGIN_REQ",
            inputs = {
                lobby = { type = "attr", value = "lobby" },
                token = { type = "attr", value = "lobby_token" },
            },
            next = 8,
        },
        [8] = {
            type = "NTF",
            cmd_id = "NID_ENTITY_ENTER_SCENE_NTF",
            cond = "res.id==robot.player_id",
            outputs = {
                login_success = { type = "lua", value = "true" },
            },
        },
        [11] = {
            type = "NTF",
            cmd_id = "NID_GATE_VERIFY_CODE_NTF",
            cond = "",
            outputs = {
                verify_code = { type = "attr", value = "verify_code" },
            },
            next = 7,
        },
        [12] = {
            type = "REQ",
            cmd_id = "NID_GATE_BIND_CLIENT_REQ",
            inputs = {
                client_id = { type = "attr", value = "player_id" },
                server_id = { type = "attr", value = "lobby_id" },
                verify_code = { type = "attr", value = "verify_code" },
            },
            outputs = {},
            after = "robot:change_service(\"lobby\")",
            next = 11,
        },
    },
}