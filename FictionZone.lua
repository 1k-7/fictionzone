-- {"id":1308640001,"ver":"1.0.0","libVer":"1.0.0","author":"Gemini"}

local baseURL = "https://fictionzone.net"
local settings = {} -- THIS IS THE CRITICAL ADDITION

local function shrinkURL(url)
    return url:gsub("^.-fictionzone%.com", "")
end

local function expandURL(url)
    return baseURL .. url
end

--- @param chapterURL string
--- @return string
local function getPassage(chapterURL)
    local document = GETDocument(expandURL(chapterURL))
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
            description = "You can browse novels by going to the 'Browse' tab. To search, tap the search icon in the top right and enter your query."
        }
    end

    local document = GETDocument(expandURL(novelURL))
    local title = document:selectFirst("div.main-content h1.story-title"):text()
    local author = document:selectFirst("div.author-details h4.author-name a"):text()
    local cover = document:selectFirst("div.story-sidebar-left-img img"):attr("src")
    local summaryHtml = document:selectFirst("div.story-main-content div.summary")
    
    summaryHtml:select("br"):prepend("\\n")
    local summary = summaryHtml:wholeText():gsub("\\n", "\n"):gsub('^%s*(.-)%s*$', '%1')

    local genres = map(document:select("div.story-tags a.story-tag"), function(v)
        return v:text()
    end)

    local statusText = document:selectFirst("span.story-status"):text():lower()
    local status = NovelStatus.PUBLISHING
    if statusText == "completed" then
        status = NovelStatus.COMPLETED
    end

    local info = NovelInfo {
        title = title,
        link = novelURL,
        authors = { author },
        imageURL = cover,
        description = summary,
        genres = genres,
        status = status
    }

    if loadChapters then
        local chapters = map(document:select("ul.list-chapters li.chapter-item"), function(v, i)
            local linkElement = v:selectFirst("a")
            local name = linkElement:selectFirst("span.chapter-text"):text()
            local releaseDate = linkElement:selectFirst("span.chapter-update"):text()

            return NovelChapter {
                order = i,
                title = name,
                release = releaseDate,
                link = shrinkURL(linkElement:attr("href"))
            }
        end)
        info:setChapters(AsList(chapters))
    end

    return info
end

local SortByOptions = {
    { name = "Latest", value = "/stories/all/latest/" },
    { name = "Popular", value = "/stories/all/popular/" },
    { name = "Top Rated", value = "/stories/all/top/" }
}

--- @param filters table
--- @return NovelInfo[]
local function search(filters)
    local page = filters[PAGE]
    local query = filters[QUERY]

    if query and query ~= "" then
        local searchUrl = baseURL .. "/search?keyword=" .. query .. "&page=" .. page
        local document = GETDocument(searchUrl)
        return map(document:select("div.story-item"), function(v)
            local link = v:selectFirst("h3.story-title a")
            return Novel {
                title = link:text(),
                link = shrinkURL(link:attr("href")),
                imageURL = v:selectFirst("div.story-cover img"):attr("src")
            }
        end)
    else
        local sortValue = SortByOptions[tonumber(filters[2]) or 1].value
        local browseUrl = baseURL .. sortValue .. page
        local document = GETDocument(browseUrl)
        return map(document:select("div.story-item"), function(v)
            local link = v:selectFirst("h3.story-title a")
            return Novel {
                title = link:text(),
                link = shrinkURL(link:attr("href")),
                imageURL = v:selectFirst("div.story-cover img"):attr("src")
            }
        end)
    end
end

local function searchFilters()
    local sortByNames = {}
    for _, option in ipairs(SortByOptions) do
        table.insert(sortByNames, option.name)
    end

    return {
        DropdownFilter(
            2,
            "Sort By",
            sortByNames
        )
    }
end

return {
    id = 1308640001,
    name = "FictionZone",
    baseURL = baseURL,
    imageURL = "",
    hasCloudFlare = false,
    hasSearch = true,
    chapterType = ChapterType.HTML,

    listings = {
        Listing("Nothing", false, function(data)
            return {
                Novel {
                    title = "How to use FictionZone",
                    link = "how"
                }
            }
        end),
        Listing("Browse", true, function(data)
            return search(data)
        end)
    },
    
    getPassage = getPassage,
    parseNovel = parseNovel,
    search = search,
    searchFilters = searchFilters(),
    
    -- THIS FUNCTION IS NOW CORRECT
    updateSetting = function(id, value)
        settings[id] = value
    end,

    shrinkURL = shrinkURL,
    expandURL = expandURL
}
