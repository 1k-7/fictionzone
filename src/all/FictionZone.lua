-- {"id":1308640001,"ver":"1.1.0","libVer":"1.0.0","author":"Gemini"}

local baseURL = "https://fictionzone.net"
local settings = {
    username = "",
    password = ""
}
local sessionCookie = nil

-- This function performs the login and stores the session cookie
local function login()
    if settings.username == "" or settings.password == "" then
        return false
    end

    local loginUrl = baseURL .. "/login"

    -- First, get the login page to extract the CSRF token
    local initialResponse = Request(GET(loginUrl))
    local document = Document(initialResponse:body():string())
    local csrfToken = document:selectFirst("input[name=\"_token\"]"):attr("value")

    if csrfToken == nil then
        return false -- Failed to get CSRF token
    end

    -- Build the login request
    local formBody = FormBodyBuilder()
        :add("_token", csrfToken)
        :add("email", settings.username)
        :add("password", settings.password)
        :build()

    local request = POST(loginUrl, nil, formBody)
    local response = Request(request)

    -- Extract and store the session cookie
    local cookies = response:headers("Set-Cookie")
    for i = 0, cookies:size() - 1 do
        local cookie = cookies:get(i)
        if cookie:match("fictionzone_session") then
            sessionCookie = cookie
            return true -- Login successful
        end
    end

    return false -- Login failed
end

-- Custom request function that uses the login cookie
local function GETDocumentWithSession(url)
    if sessionCookie == nil then
        login() -- Attempt to log in if we don't have a cookie
    end

    local headersBuilder = HeadersBuilder()
        :add("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/109.0.0.0 Safari/537.36")
    
    if sessionCookie ~= nil then
        headersBuilder:add("Cookie", sessionCookie)
    end
    
    local request = GET(url, headersBuilder:build())
    return RequestDocument(request)
end


local function shrinkURL(url)
    return url:gsub("^.-fictionzone%.com", "")
end

local function expandURL(url)
    return baseURL .. url
end

--- @param chapterURL string
--- @return string
local function getPassage(chapterURL)
    local document = GETDocumentWithSession(expandURL(chapterURL))
    local content = document:selectFirst("#chapter-content")
    content = tostring(content):gsub('<p', '<p'):gsub('</p', '</p'):gsub('<br>', '</p><p>')
    content = Document(content):selectFirst('body')
    return pageOfElem(content, true)
end

--- @param novelURL string
--- @param loadChapters boolean
--- @return NovelInfo
local function parseNovel(novelURL, loadChapters)
    if novelURL == "how" then
        return NovelInfo {
            title = "How to use FictionZone",
            description = "To read chapters beyond the free limit, please enter your FictionZone username (email) and password in the extension settings."
        }
    end

    local document = GETDocumentWithSession(expandURL(novelURL))
    -- (The rest of the parsing logic is the same)
    local title = document:selectFirst("div.main-content h1.story-title"):text()
    local author = document:selectFirst("div.author-details h4.author-name a"):text()
    local cover = document:selectFirst("div.story-sidebar-left-img img"):attr("src")
    local summaryHtml = document:selectFirst("div.story-main-content div.summary")
    summaryHtml:select("br"):prepend("\\n")
    local summary = summaryHtml:wholeText():gsub("\\n", "\n"):gsub('^%s*(.-)%s*$', '%1')
    local genres = map(document:select("div.story-tags a.story-tag"), function(v) return v:text() end)
    local statusText = document:selectFirst("span.story-status"):text():lower()
    local status = NovelStatus.PUBLISHING
    if statusText == "completed" then
        status = NovelStatus.COMPLETED
    end

    local info = NovelInfo {
        title = title, link = novelURL, authors = { author }, imageURL = cover,
        description = summary, genres = genres, status = status
    }

    if loadChapters then
        local chapters = map(document:select("ul.list-chapters li.chapter-item"), function(v, i)
            local linkElement = v:selectFirst("a")
            local name = linkElement:selectFirst("span.chapter-text"):text()
            local releaseDate = linkElement:selectFirst("span.chapter-update"):text()
            return NovelChapter {
                order = i, title = name, release = releaseDate,
                link = shrinkURL(linkElement:attr("href"))
            }
        end)
        info:setChapters(AsList(chapters))
    end
    return info
end

--- @param filters table
--- @return NovelInfo[]
local function search(filters)
    local page = filters[PAGE]
    local query = filters[QUERY]
    local url
    if query and query ~= "" then
        url = baseURL .. "/search?keyword=" .. query .. "&page=" .. page
    else
        local sortValue = SortByOptions[tonumber(filters[2]) or 1].value
        url = baseURL .. sortValue .. page
    end
    local document = GETDocumentWithSession(url)
    return map(document:select("div.story-item"), function(v)
        local link = v:selectFirst("h3.story-title a")
        return Novel {
            title = link:text(), link = shrinkURL(link:attr("href")),
            imageURL = v:selectFirst("div.story-cover img"):attr("src")
        }
    end)
end

-- (searchFilters, SortByOptions, and the main return table are structured as before)
local SortByOptions = {
    { name = "Latest", value = "/stories/all/latest/" },
    { name = "Popular", value = "/stories/all/popular/" },
    { name = "Top Rated", value = "/stories/all/top/" }
}
local function searchFilters()
    local sortByNames = {}
    for _, option in ipairs(SortByOptions) do table.insert(sortByNames, option.name) end
    return { DropdownFilter(2, "Sort By", sortByNames) }
end

return {
    id = 1308640001, name = "FictionZone", baseURL = baseURL, imageURL = "",
    hasCloudFlare = true, hasSearch = true, chapterType = ChapterType.HTML,

    listings = {
        Listing("Nothing", false, function(data)
            return { Novel { title = "How to use FictionZone", link = "how" } }
        end),
        Listing("Browse", true, function(data) return search(data) end)
    },
    
    settings = {
        TextFilter(1, "Username (Email)"),
        TextFilter(2, "Password")
    },
    
    getPassage = getPassage, parseNovel = parseNovel, search = search,
    searchFilters = searchFilters(),
    
    updateSetting = function(id, value)
        if id == "1" then settings.username = value
        elseif id == "2" then settings.password = value end
    end,

    shrinkURL = shrinkURL, expandURL = expandURL
}
