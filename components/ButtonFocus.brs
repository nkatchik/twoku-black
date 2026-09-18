sub applyButtonFocus(button as Object, background as Object, label as Object, focused as Boolean, selectedScale = 1.1)
    ' Grow around the same center without moving adjacent controls.
    button.scaleRotateCenter = [background.width / 2, background.height / 2]
    scale = selectedScale / 1.1
    if focused then scale = selectedScale
    button.scale = [scale, scale]
    applyButtonColors(background, label, focused)
end sub

sub applyButtonColors(background as Object, label as Object, focused as Boolean)
    background.color = "0x323239FF"
    label.color = "0xFFFFFFFF"
    if focused
        background.color = "0xF4F4F7FF"
        label.color = "0x111318FF"
    end if
end sub
