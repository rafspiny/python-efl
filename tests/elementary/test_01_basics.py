#!/usr/bin/env python

import unittest

from efl.eo import Eo
from efl import elementary
from efl.elementary.window import Window, ELM_WIN_BASIC
from efl.elementary.button import Button


def cb1(*args):
    pass

def cb2(*args):
    pass


class TestElmBasics(unittest.TestCase):

    def setUp(self):
        self.o = Window("t", ELM_WIN_BASIC)

    def tearDown(self):
        self.o.delete()

    def testParentGet2(self):
        o = Button(self.o)
        self.assertEqual(Eo.parent_get(o), self.o)
        o.delete()

    def testCallbacks1(self):
        self.o.callback_iconified_add(cb1)
        self.o.callback_iconified_del(cb1)

    def testCallbacks2(self):
        self.o.callback_iconified_add(cb1)
        self.o.callback_iconified_add(cb2)
        self.o.callback_iconified_del(cb1)
        self.o.callback_iconified_del(cb2)

    def testCallbacks3(self):
        self.o.callback_iconified_add(cb1)
        self.o.callback_fullscreen_add(cb1)
        self.o.callback_iconified_del(cb1)
        self.o.callback_fullscreen_del(cb1)

    def testCallbacks4(self):
        self.o.callback_iconified_add(cb1)
        self.o.callback_fullscreen_add(cb2)
        self.assertRaises(ValueError, self.o.callback_iconified_del, cb2)
        self.assertRaises(ValueError, self.o.callback_fullscreen_del, cb1)


if __name__ == '__main__':
    unittest.main(verbosity=2)
