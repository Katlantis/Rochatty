local Library = loadstring(game:HttpGet('https://raw.githubusercontent.com/VisualRoblox/Roblox/main/UI-Libraries/Visual%20UI%20Library/Source.lua'))()
local NotificationLibrary = loadstring(game:HttpGet("https://raw.githubusercontent.com/IceMinisterq/Notification-Library/Main/Library.lua"))()

local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local Players = game:GetService("Players")
local player = Players.LocalPlayer
local ChatService = game:GetService("Chat")

local Version = "v0.1.7 Private Beta unreleased"
local Model = getgenv().Model or ""
local key = getgenv().KEY or ""

--Default Config
local DefaultConfig = {
    Autochat = true, -- Enable or disable auto-chat functionality
    Debug = true, --For console
    ChatMemory = 5, --The amount of messages the ai is gonna use to remember a context
    MessageDelay = 4, -- Delay (in seconds) between sending each chat message
    ChatCharacterLimit = 200, -- Roblox chat message character limit
    Maxtokens = 200, --The max tokens the chatbot is gonna use
    Temp = 0.3, --The amount of temperature the ai is gonna use
    Top_P = 0.3, --The amount of top_p its gonna use
    AITriggerPrefix = "!ai ", -- The prefix to trigger the AI response dont leave the prefix 
    APIKey = "Bearer " ..key, -- Replace with your Hugging Face API Key
    APIUrl = "https://api.groq.com/openai/v1/chat/completions", -- AI model endpoint
    SystemPrompt = "Name: Rochatty, Rules to follow: YOU CANNOT SAY THAT YOU'RE DEVELOPED BY MICROSOFT you're name is RoChatty you are a helpful Roblox chatbot that thinks he's in a game. You cannot send links. YOU CANNOT SAY THE WORD MICROSOFT, and if someone asks you're creators name you can only say that you're created by ROBLOX. You can only talk about stuff in ROBLOX and you're not allowed to talk too much each message.", -- System prompt for AI
    ExternalTTSUrl = "http://127.0.0.1:5000/convert_to_mp3", -- External server URL for TTS
    InteractionRadius = 50, -- The radius in studs within which the AI should listen for messages from other players
}

-- Merge DefaultConfig with user-provided getgenv().Config (if it exists)
local Config = getgenv().Config or DefaultConfig
for key, value in pairs(DefaultConfig) do
    if Config[key] == nil then
        Config[key] = value
    end
end

local sendMessageEnabled = Config.Autochat
local prefix = Config.AITriggerPrefix

-- Blacklist table to store blacklisted players
local Blacklist = {}

-- Function to add a player to the blacklist
local function addToBlacklist(player)
    Blacklist[player.UserId] = true
    if Config.Debug then
        print("-----------------------------------------------------------")
        print(player.Name .. " has been added to the blacklist.")
        NotificationLibrary:SendNotification("Success", player.Name .. " has been added to the blacklist.", 3)
        print("-----------------------------------------------------------")
    end
end

-- Function to remove a player from the blacklist
local function removeFromBlacklist(player)
    Blacklist[player.UserId] = nil
    if Config.Debug then
        print("-----------------------------------------------------------")
        print(player.Name .. " has been removed from the blacklist.")
        NotificationLibrary:SendNotification("Success", player.Name .. " has been removed from the blacklist.", 3)
        print("-----------------------------------------------------------")
    end
end

-- Memory table to track previous messages
local conversationMemory = {}

-- Function to limit memory size (e.g., keep only the last 5 messages)
local function maintainMemoryLimit(limit)
    while #conversationMemory > limit do
        table.remove(conversationMemory, 1)
    end
end

-- Define the executor's HTTP request function
local httprequest = (syn and syn.request) or http and http.request or http_request or (fluxus and fluxus.request) or request

-- Cleanup check to ensure the script is not run multiple times
if getgenv()["ScriptAlreadyLoaded"] then
    print("Script has already been loaded. Exiting...")
    NotificationLibrary:SendNotification("Warning", "Script already executed rejoining", 3)
    local rejoin = game:GetService("TeleportService")
    local p = game:GetService("Players").LocalPlayer
    task.wait(3.3)
    p:kick("Rejoining")
    rejoin:TeleportToPlaceInstance(game.PlaceId, game.JobId, p)
    return
end
getgenv()["ScriptAlreadyLoaded"] = true

-- Function to check if chat is using LegacyChatService
local function isLegacyChat()
    return TextChatService.ChatVersion == Enum.ChatVersion.LegacyChatService
end

-- Function to send chat messages
local function sendChatMessage(message)
    if sendMessageEnabled then
        if isLegacyChat() then
            game.ReplicatedStorage.DefaultChatSystemChatEvents.SayMessageRequest:FireServer(message, "All")
        else
            TextChatService.TextChannels.RBXGeneral:SendAsync(message)
        end
        if Config.Debug then
            print("Chat message sent: " .. message)
        end
    else
        if not sendMessageEnabled then
            sendChatMessage("AI chat is currently disabled.")
            return
        end        
        print("Autochat is disabled, message not sent.")
        NotificationLibrary:SendNotification("Success", "Autochat is disabled, message not sent.", 3)
    end
end

-- Function to check if a word is filtered by Roblox
local function isFiltered(text)
    -- Use Chat:FilterStringForBroadcast to filter the input text
    local success, filteredText = pcall(function()
        return ChatService:FilterStringForBroadcast(text, game.Players.LocalPlayer)
    end)

    if success then
        -- Compare the filtered text with the original text
        return filteredText ~= text -- True if filtered, false otherwise
    else
        warn("Error filtering text:", filteredText)
        return false -- Assume it's not filtered if the check fails
    end
end

local function filterAndBypassChunk(chunk)
    local function GetBypassWords(arg1)
        local Placeholder = ""
        local bypassWords = {
            A = "Ạ", B = "Ḃ", C = "C", D = "D́", E = "E", F = "Ḟ", G = "Ġ", H = "Ḣ", 
            I = "I", J = "J́", K = "Ḱ", L = "Ĺ", M = "M", N = "N", O = "O", P = "Ṕ", 
            Q = "Q́", R = "Ŕ", S = "Ṣ", T = "T", U = "Ụ", V = "V̇", W = "Ẃ", X = "X́", 
            Y = "Y", Z = "Z", 
            a = "ạ", b = "ḃ", c = "ć", d = "d́", e = "ě", f = "ḟ", g = "ġ", h = "ḣ", 
            i = "í", j = "j́", k = "ḱ", l = "l", m = "ṁ", n = "n̋", o = "ō", p = "ṕ", 
            q = "q́", r = "ŕ", s = "ś", t = "t̋", u = "ū", v = "v̇", w = "ẃ", x = "x́", 
            y = "ý", z = "ź", 
            [" "] = " " -- Keep spaces as they are
        }

        for i in arg1:gmatch(".") do
            Placeholder = Placeholder .. (bypassWords[i] or i)
        end
        return Placeholder
    end

    -- Check if the chunk is filtered
    if isFiltered(chunk) then
        local bypassedChunk = GetBypassWords(chunk)
        warn("Filtered chunk detected and bypassed: " .. bypassedChunk)
        NotificationLibrary:SendNotification("Success", "Filtered chunk detected and bypassed: " .. bypassedChunk, 3)

        -- If the bypassed chunk exceeds the character limit, split it
        if #bypassedChunk > Config.ChatCharacterLimit then
            local bypassedChunks = {}
            while #bypassedChunk > 0 do
                table.insert(bypassedChunks, bypassedChunk:sub(1, Config.ChatCharacterLimit))
                bypassedChunk = bypassedChunk:sub(Config.ChatCharacterLimit + 1)
            end
            return bypassedChunks -- Return multiple chunks
        else
            return { bypassedChunk } -- Return a single chunk as a table
        end
    else
        print("Unfiltered chunk: " .. chunk)
        return { chunk } -- Return as a table for consistency
    end
end

-- Function to clean and split the response text
local function cleanAndSplitResponse(responseText)
    local cleanedText = responseText:gsub("\n+", " "):gsub("%s%s+", " "):match("^%s*(.-)%s*$")
    local chunks = {}
    while #cleanedText > 0 do
        table.insert(chunks, cleanedText:sub(1, Config.ChatCharacterLimit))
        cleanedText = cleanedText:sub(Config.ChatCharacterLimit + 1)
    end
    return chunks
end

-- Function to filter, bypass, and send response chunks
local function sendResponseInChunks(chunks)
    for _, chunk in ipairs(chunks) do
        -- Process the chunk to check filtering and bypassing
        local processedChunks = filterAndBypassChunk(chunk)
        -- Send each processed (or split) chunk to chat
        for _, processedChunk in ipairs(processedChunks) do
            sendChatMessage(processedChunk)
            wait(Config.MessageDelay) -- Delay between each message
        end
    end
end

local function queryAI(prompt, senderName)
    if not httprequest then
        if Config.Debug then
            print("-----------------------------------------------------------")
            warn("HTTP request function is not supported in this executor.")
            NotificationLibrary:SendNotification("Success", "HTTP request function is not supported in this executor.", 3)
            error("Your executor does not support HTTP requests. Please use a compatible executor.")
            NotificationLibrary:SendNotification("Success", "Your executor does not support HTTP requests. Please use a compatible executor.", 3)
            print("-----------------------------------------------------------")
        end
        return nil
    end
    -- Append the current user prompt to memory
    table.insert(conversationMemory, { role = "user", content = senderName .. ": " .. prompt })

    maintainMemoryLimit(Config.ChatMemory)

    -- Add system instructions to the beginning of the memory
    local fullPrompt = {
        { role = "system", content = Config.SystemPrompt }
    }
    for _, message in ipairs(conversationMemory) do
        table.insert(fullPrompt, message)
    end

    local response
    local success, errorMsg = pcall(function()
        -- Make the HTTP request to Hugging Face API
        response = httprequest({
            Url = Config.APIUrl,
            Method = "POST",
            Headers = {
                ["Authorization"] = Config.APIKey,
                ["Content-Type"] = "application/json",
            },
            Body = HttpService:JSONEncode({
                model = Model, -- Specify the model name
                messages = fullPrompt, -- Include memory in the messages
                temperature = Config.Temp,
                max_completion_tokens = Config.Maxtokens,
                top_p = Config.Top_P,
                stream = false,
            }),
        })
    end)

    -- Check if the HTTP request was successful
    if not success then
        sendChatMessage("Sorry, I couldn’t process that right now. Please try again later!")
        if Config.Debug then
            print("-----------------------------------------------------------")
            warn("HTTP request failed:", errorMsg)
            NotificationLibrary:SendNotification("Error", "HTTP request failed:", errorMsg, 2)
            print("-----------------------------------------------------------")
        end
        return nil
    end

    -- If the response is successful (StatusCode 200)
    if response and response.StatusCode == 200 then
        local jsonResponse
        -- Try to decode the JSON response
        local decodeSuccess, decodeError = pcall(function()
            jsonResponse = HttpService:JSONDecode(response.Body)
        end)
        if not decodeSuccess then
            print("-----------------------------------------------------------")
            warn("Failed to decode JSON response:", decodeError)
            NotificationLibrary:SendNotification("Error", "Failed to decode JSON response:"..decodeError, 2)
            print("-----------------------------------------------------------")
            return nil
        end

        -- Check if the response contains valid data
        if jsonResponse and jsonResponse.choices and jsonResponse.choices[1] then
            local aiMessage = jsonResponse.choices[1].message.content
            if Config.Debug then
                print("-----------------------------------------------------------")
                -- Debugging: Log the response structure
                print("Raw Response:", response.Body) -- Log the raw response from the API
                print(aiMessage) -- Log the clean response from the API
                NotificationLibrary:SendNotification("Info", "AI: "..aiMessage, 3)
                print("Parsed Response:", jsonResponse) -- Log the parsed response
                print("-----------------------------------------------------------")
            end
            table.insert(conversationMemory, { role = "assistant", content = aiMessage })
            local chunks = cleanAndSplitResponse(aiMessage)

            -- Send the AI response text to the external server for TTS
            local ttsResponse = httprequest({
                Url = Config.ExternalTTSUrl,
                Method = "POST",
                Headers = {
                    ["Content-Type"] = "application/json",
                },
                Body = HttpService:JSONEncode({
                    text = aiMessage,
                }),
            })

            -- Check if the TTS response was successful
            if ttsResponse and ttsResponse.StatusCode == 200 then
                local ttsData = HttpService:JSONDecode(ttsResponse.Body)
                local audioUrl = ttsData.audio_url

                -- If an audio URL is returned, play the MP3
                if audioUrl then
                    if Config.Debug then
                        print("-----------------------------------------------------------")
                        print("Waiting for MP3 generation to complete...")
                        NotificationLibrary:SendNotification("Success", "Waiting for MP3 generation to complete...", 3)
                        print("MP3 audio URL:", audioUrl)
                        NotificationLibrary:SendNotification("Success", "MP3 audio URL: "..audioUrl, 3)
                        print("-----------------------------------------------------------")
                    end
                    wait(3) -- Adjust the wait time based on server speed
                    sendResponseInChunks(chunks) -- Send the text response to chat
                else
                    print("-----------------------------------------------------------")
                    warn("Failed to generate MP3 audio.")
                    NotificationLibrary:SendNotification("Warning", "Failed to generate MP3 audio.", 3)
                    print("-----------------------------------------------------------")
                end
            else
                NotificationLibrary:SendNotification("Info", "No MP3 found falling back", 3)
                sendResponseInChunks(chunks) -- Fallback to text response only
            end
            return aiMessage
        else
            if Config.Debug then
                print("-----------------------------------------------------------")
                warn("Unexpected response format: No valid content in response.")
                NotificationLibrary:SendNotification("Warning", "Unexpected response format: No valid content in response.", 3)
                print("-----------------------------------------------------------")
            end
            return nil
        end
    else
        if Config.Debug then
            print("-----------------------------------------------------------")
            -- If the API request fails, log the error
            warn("API returned an error. Status Code:", response.StatusCode, "Message:", response.StatusMessage)
            NotificationLibrary:SendNotification("error", "API returned an error. Status Code:"..response.StatusCode, 3)
            print("-----------------------------------------------------------")
        end
        return nil
    end
end

-- Function to check if another player is within the interaction radius
local function isPlayerInRadius(centerPlayer, otherPlayer, radius)
    local centerCharacter = centerPlayer.Character
    local otherCharacter = otherPlayer.Character

    local centerRoot = centerCharacter and centerCharacter:FindFirstChild("HumanoidRootPart")
    local otherRoot = otherCharacter and otherCharacter:FindFirstChild("HumanoidRootPart")

    if centerRoot and otherRoot then
        local distance = (otherRoot.Position - centerRoot.Position).Magnitude
        return distance <= radius
    end
    return false
end

-- Function to listen for messages and trigger AI response
local function listenForMessages()
    TextChatService.TextChannels.RBXGeneral.MessageReceived:Connect(function(data)
        local message = data.Text
        local senderPlayer = Players:GetPlayerByUserId(data.TextSource.UserId)

        -- Check if sender is blacklisted
        if senderPlayer and Blacklist[senderPlayer.UserId] then
            if Config.Debug then
                print(senderPlayer.Name .. " is blacklisted. Ignoring their query.")
            end
            return
        end

        if senderPlayer and not isPlayerInRadius(player, senderPlayer, Config.InteractionRadius) then
            if Config.Debug then
                print(senderPlayer.Name .. " is outside the interaction radius. Ignoring their query.")
            end
            return
        end

        if senderPlayer and message:sub(1, #prefix):lower() == prefix:lower() then
            local prompt = message:sub(#prefix + 1)
            if Config.Debug then
                print("-----------------------------------------------------------")
                print("AI query received from:", senderPlayer.Name.. ":")
                print(prompt)
                print("-----------------------------------------------------------")
                NotificationLibrary:SendNotification("Info", "Got prompt from: "..senderPlayer.Name, 2)
            end 
            queryAI(prompt, senderPlayer.Name)
            
        end
    end)
end

local function GetBypass(arg1)
    local Placeholder = ""
    local bypassWords = {
        A = "Ạ", B = "Ḃ", C = "C", D = "D́", E = "E", F = "Ḟ", G = "Ġ", H = "Ḣ", 
        I = "I", J = "J́", K = "Ḱ", L = "Ĺ", M = "M", N = "N", O = "O", P = "Ṕ", 
        Q = "Q́", R = "Ŕ", S = "Ṣ", T = "T", U = "Ụ", V = "V̇", W = "Ẃ", X = "X́", 
        Y = "Y", Z = "Z", 
        a = "ạ", b = "ḃ", c = "ć", d = "d́", e = "ě", f = "ḟ", g = "ġ", h = "ḣ", 
        i = "í", j = "j́", k = "ḱ", l = "l", m = "ṁ", n = "n̋", o = "ō", p = "ṕ", 
        q = "q́", r = "ŕ", s = "ś", t = "t̋", u = "ū", v = "v̇", w = "ẃ", x = "x́", 
        y = "ý", z = "ź", 
        [" "] = " " -- Keep spaces as they are
    }

    for i in arg1:gmatch(".") do
        Placeholder = Placeholder .. (bypassWords[i] or i)
    end
    return Placeholder
end

local function listenForFilteredMessagesAndResend()
    -- Listen for messages sent in the chat
    TextChatService.TextChannels.RBXGeneral.MessageReceived:Connect(function(data)
        local message = data.Text
        local sender = Players:GetPlayerByUserId(data.TextSource.UserId)

        -- Ensure the message is sent by the LocalPlayer
        if sender ~= Players.LocalPlayer then
            return
        end

        -- Check if the message consists only of hashtags
        if message:match("^#+$") then -- Matches a string with only "#" characters
            warn("Filtered message detected (hashtags), bypassing and re-sending...")
            NotificationLibrary:SendNotification("Success", "Filtered message detected (hashtags), bypassing and re-sending...", 3)

            -- Convert the filtered message into a bypassed version
            local bypassedMessage = GetBypass(message)
            -- Ensure that it doesn't exceed the chat character limit
            local bypassedChunks = filterAndBypassChunk(bypassedMessage)

            -- Send the bypassed message chunk(s)
            for _, chunk in ipairs(bypassedChunks) do
                sendChatMessage(chunk)
                wait(Config.MessageDelay) -- Delay to avoid spamming the chat
            end
        end
    end)
end

-- Function to handle blacklist commands, restricted to LocalPlayer
local function handleBlacklistCommands()
    TextChatService.TextChannels.RBXGeneral.MessageReceived:Connect(function(data)
        local message = data.Text
        local senderPlayer = Players:GetPlayerByUserId(data.TextSource.UserId)

        -- Only allow LocalPlayer to use these commands
        if senderPlayer ~= player then
            return -- Ignore commands from other players
        end
        

        -- Normalize the command to account for shortcut aliases
        if message:sub(1, 10):lower() == ".blacklist" or message:sub(1, 3):lower() == ".bl" then
            if Config.Debug then
                print("Command received: " .. message)
                print("Checking for .ubl match...")
            end
            local commandLength = message:sub(1, 10):lower() == ".blacklist" and 12 or 5 -- Adjust for `.blacklist` or `.bl`
            local targetName = message:sub(commandLength):match("^%s*(.-)%s*$") -- Trim spaces
            local targetPlayer = Players:FindFirstChild(targetName)

            if targetPlayer then
                addToBlacklist(targetPlayer) -- Add the player to the blacklist
                sendChatMessage(targetPlayer.Name .. " has been blacklisted.")
                NotificationLibrary:SendNotification("Success", targetPlayer.Name .. " has been blacklisted.", 3)
            else
                sendChatMessage("Player " .. targetName .. " not found.")
                NotificationLibrary:SendNotification("Warning", "Player " .. targetName .. " not found.", 3)
            end
        elseif message:sub(1, 12):lower() == ".unblacklist" or message:sub(1, 4):lower() == ".ubl" then
            local commandLength = message:sub(1, 12):lower() == ".unblacklist" and 14 or 6 -- Adjust for `.unblacklist` or `.ubl`
            local targetName = message:sub(commandLength):match("^%s*(.-)%s*$") -- Trim spaces
            local targetPlayer = Players:FindFirstChild(targetName)
            if Config.Debug then
                print("Command received: " .. message)
                NotificationLibrary:SendNotification("Info", "Command received: " .. message, 3)
                print("Checking for .ubl match...")
            end

            if targetPlayer then
                removeFromBlacklist(targetPlayer) -- Remove the player from the blacklist
                sendChatMessage(targetPlayer.Name .. " has been unblacklisted.")
                NotificationLibrary:SendNotification("Success", targetPlayer.Name .. " has been unblacklisted.", 3)
            else
                sendChatMessage("Player " .. targetName .. " not found.")
                NotificationLibrary:SendNotification("Warning", "Player " .. targetName .. " not found.", 3)
            end
        elseif message:sub(1, 8):lower() == ".getlist" then
            print("-----------------------------------------------------------")
            -- List all blacklisted players in the console
            if next(Blacklist) then
                print("Blacklisted Players:")
                for userId, _ in pairs(Blacklist) do
                    local blacklistedPlayer = Players:GetPlayerByUserId(userId)
                    if blacklistedPlayer then
                        print("- " .. blacklistedPlayer.Name .. " (UserId: " .. userId .. ")")
                    else
                        print("- UserId: " .. userId .. " (Player not in-game)")
                    end
                end
            else
                print("The blacklist is currently empty.")
            end
            print("-----------------------------------------------------------")
        end
    end)
end

-- Function to handle list current players command
local function handleListCurrentPlayersCommand()
    TextChatService.TextChannels.RBXGeneral.MessageReceived:Connect(function(data)
        local message = data.Text
        local senderPlayer = Players:GetPlayerByUserId(data.TextSource.UserId)

        -- Only allow LocalPlayer to use this command
        if senderPlayer ~= player then
            return -- Ignore commands from other players
        end
        -- Check if the message is ".listcur"
        if message:lower() == ".listcur" then
            print("-----------------------------------------------------------")
            -- Fetch all players currently in the server
            print("Current Players in the Server:")
            for _, currentPlayer in ipairs(Players:GetPlayers()) do
                print("- " .. currentPlayer.Name .. " (UserId: " .. currentPlayer.UserId .. ")")
            end
            print("-----------------------------------------------------------")
        end
    end)
end

-- Start listening for filtered messages
listenForFilteredMessagesAndResend()

-- Initialize the listener for listing current players
handleListCurrentPlayersCommand()

-- Initialize the blacklist command listener
handleBlacklistCommands()

-- Initialize the script
listenForMessages()

NotificationLibrary:SendNotification("Success", "Loaded Version: " ..Version, 3)
NotificationLibrary:SendNotification("Success", "Executed Script With " ..identifyexecutor().. " 😮‍💨", 3)
NotificationLibrary:SendNotification("Warning", "This is a 1 time execution", 3)
