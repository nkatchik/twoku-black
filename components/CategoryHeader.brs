sub onContentChanged()
    if m.content <> invalid
        for each field in ["title", "description", "HDPosterUrl"]
            m.content.unobserveField(field)
        end for
    end if
    m.content = m.top.content
    if m.content <> invalid
        for each field in ["title", "description", "HDPosterUrl"]
            m.content.observeField(field, "renderHeader")
        end for
    end if
    renderHeader()
end sub

sub renderHeader()
    if m.content = invalid then return
    m.top.findNode("name").text = m.content.Title
    m.top.findNode("description").text = m.content.Description
    m.top.findNode("cover").uri = m.content.HDPosterUrl
end sub
