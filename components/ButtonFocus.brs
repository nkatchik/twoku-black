sub applyButtonFocus(button as Object, background as Object, label as Object, focused as Boolean, selectedScale = 1.1)
    ' Grow around the same center without moving adjacent controls.
    button.scaleRotateCenter = [background.width / 2, background.height / 2]
    scale = selectedScale / 1.1
    background.color = "0x323239FF"
    label.color = "0xFFFFFFFF"
    if focused
        scale = selectedScale
        background.color = "0xF4F4F7FF"
        label.color = "0x111318FF"
    end if
    button.scale = [scale, scale]
end sub
