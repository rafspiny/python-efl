#!/usr/bin/env python
# encoding: utf-8

from efl import evas
from efl import elementary
from efl.elementary.window import Window
from efl.elementary.background import Background
from efl.elementary.box import Box
from efl.elementary.icon import Icon
from efl.elementary.radio import Radio


def radio_clicked(obj):
    win = Window("radio", elementary.ELM_WIN_BASIC)
    win.title_set("Radio test")
    win.autodel_set(True)
    if obj is None:
        win.callback_delete_request_add(lambda o: elementary.exit())

    bg = Background(win)
    win.resize_object_add(bg)
    bg.size_hint_weight_set(evas.EVAS_HINT_EXPAND, evas.EVAS_HINT_EXPAND)
    bg.show()

    bx = Box(win)
    bx.size_hint_weight_set(evas.EVAS_HINT_EXPAND, evas.EVAS_HINT_EXPAND)
    win.resize_object_add(bx)
    bx.show()

    ic = Icon(win)
    ic.file_set('images/logo_small.png')
    ic.size_hint_aspect_set(evas.EVAS_ASPECT_CONTROL_VERTICAL, 1, 1)
    rd = Radio(win)
    rd.state_value_set(0)
    rd.size_hint_weight_set(evas.EVAS_HINT_EXPAND, evas.EVAS_HINT_EXPAND)
    rd.size_hint_align_set(evas.EVAS_HINT_FILL, 0.5)
    rd.text_set("Icon sized to radio")
    rd.content_set(ic)
    bx.pack_end(rd)
    rd.show()
    ic.show()
    rdg = rd

    ic = Icon(win)
    ic.file_set('images/logo_small.png')
    ic.resizable_set(0, 0)
    rd = Radio(win)
    rd.state_value_set(1)
    rd.group_add(rdg)
    rd.text_set("Icon no scale")
    rd.content_set(ic)
    bx.pack_end(rd)
    rd.show()
    ic.show()

    rd = Radio(win)
    rd.state_value_set(2)
    rd.group_add(rdg)
    rd.text_set("Label Only")
    bx.pack_end(rd)
    rd.show()

    rd = Radio(win)
    rd.state_value_set(3)
    rd.group_add(rdg)
    rd.text_set("Disabled")
    rd.disabled_set(True)
    bx.pack_end(rd)
    rd.show()

    ic = Icon(win)
    ic.file_set('images/logo_small.png')
    ic.resizable_set(0, 0)
    rd = Radio(win)
    rd.state_value_set(4)
    rd.group_add(rdg)
    rd.content_set(ic)
    bx.pack_end(rd)
    rd.show()
    ic.show()

    ic = Icon(win)
    ic.file_set('images/logo_small.png')
    ic.resizable_set(0, 0)
    rd = Radio(win)
    rd.state_value_set(5)
    rd.group_add(rdg)
    rd.content_set(ic)
    rd.disabled_set(True)
    bx.pack_end(rd)
    rd.show()
    ic.show()

    rdg.value_set(2)

    win.show()


if __name__ == "__main__":
    elementary.init()

    radio_clicked(None)

    elementary.run()
    elementary.shutdown()
