# Copyright (C) 2007-2013 various contributors (see AUTHORS)
#
# This file is part of Python-EFL.
#
# Python-EFL is free software; you can redistribute it and/or
# modify it under the terms of the GNU Lesser General Public
# License as published by the Free Software Foundation; either
# version 2.1 of the License, or (at your option) any later version.
#
# Python-EFL is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this Python-EFL.  If not, see <http://www.gnu.org/licenses/>.


cdef class Textblock(Object):

    """A Textblock.

    :param canvas: Evas canvas for this object
    :type canvas: Canvas
    :keyword size: Width and height
    :type size: tuple of ints
    :keyword pos: X and Y
    :type pos: tuple of ints
    :keyword geometry: X, Y, width, height
    :type geometry: tuple of ints
    :keyword color: R, G, B, A
    :type color: tuple of ints
    :keyword name: Object name
    :type name: string
    :keyword text_markup: Markup text
    :type text_markup: string
    :keyword style: The style
    :type style: string

    """

    def __init__(self, Canvas canvas not None, **kwargs):
        self._set_obj(evas_object_textblock_add(canvas.obj))
        self._set_properties_from_keyword_args(kwargs)

    property style:
        """Style

        :type: unicode

        """
        def __get__(self):
            return self.style_get()

        def __set__(self, value):
            self.style_set(value)

    def style_get(self):
        cdef const_Evas_Textblock_Style *style
        style = evas_object_textblock_style_get(self.obj)
        return _ctouni(evas_textblock_style_get(style))

    def style_set(self, value):
        cdef Evas_Textblock_Style *style = evas_textblock_style_new()
        if isinstance(value, unicode): value = PyUnicode_AsUTF8String(value)
        evas_textblock_style_set(style,
            <const_char *>value if value is not None else NULL)
        evas_object_textblock_style_set(self.obj, style)
        evas_textblock_style_free(style)

    property text_markup:
        """Markup text

        :type: unicode

        """
        def __get__(self):
            return self.text_markup_get()

        def __set__(self, value):
            self.text_markup_set(value)

    def text_markup_get(self):
        return _ctouni(evas_object_textblock_text_markup_get(self.obj))

    def text_markup_set(self, value):
        if isinstance(value, unicode): value = PyUnicode_AsUTF8String(value)
        evas_object_textblock_text_markup_set(self.obj,
            <const_char *>value if value is not None else NULL)

    property replace_char:
        """Replacement character

        :type: unicode

        """
        def __get__(self):
            return self.replace_char_get()

        def __set__(self, value):
            self.replace_char_set(value)

    def replace_char_get(self):
        return _ctouni(evas_object_textblock_replace_char_get(self.obj))

    def replace_char_set(self, value):
        if isinstance(value, unicode): value = PyUnicode_AsUTF8String(value)
        evas_object_textblock_replace_char_set(self.obj,
            <const_char *>value if value is not None else NULL)

    def line_number_geometry_get(self, int index):
        """line_number_geometry_get(int index) -> (int x, int y, int w, int h)

        Retrieve position and dimension information of a specific line.

        This function is used to obtain the **x**, **y**, **width** and **height**
        of a the line located at **index** within this object.

        :param index: index of desired line
        :rtype: (int **x**, int **y**, int **w**, int **h**)
        """
        cdef int x, y, w, h, r
        r = evas_object_textblock_line_number_geometry_get(self.obj, index, &x, &y, &w, &h)
        if r == 0:
            return None
        else:
            return (x, y, w, h)

    def clear(self):
        """clear()

        Clear the Textblock

        """
        evas_object_textblock_clear(self.obj)

    property size_formatted:
        """Get the formatted width and height. This calculates the actual size
        after restricting the textblock to the current size of the object. The
        main difference between this and :py:attr:`size_native` is that the
        "native" function does not wrapping into account it just calculates the
        real width of the object if it was placed on an infinite canvas, while
        this function gives the size after wrapping according to the size
        restrictions of the object.

        For example for a textblock containing the text: "You shall not pass!"
        with no margins or padding and assuming a monospace font and a size of
        7x10 char widths (for simplicity) has a native size of 19x1
        and a formatted size of 5x4.

        :type: (int **w**, int **h**)

        :see: :py:attr:`size_native`

        """
        def __get__(self):
            return self.size_formatted_get()

    def size_formatted_get(self):
        cdef int w, h
        evas_object_textblock_size_formatted_get(self.obj, &w, &h)
        return (w, h)

    property size_native:
        """Get the native width and height. This calculates the actual size without
        taking account the current size of the object. The main difference
        between this and :py:attr:`size_formatted` is that the "native" function
        does not take wrapping into account it just calculates the real width of
        the object if it was placed on an infinite canvas, while the "formatted"
        function gives the size after wrapping text according to the size
        restrictions of the object.

        For example for a textblock containing the text: "You shall not pass!"
        with no margins or padding and assuming a monospace font and a size of
        7x10 char widths (for simplicity) has a native size of 19x1
        and a formatted size of 5x4.

        :type: (int **w**, int **h**)

        """
        def __get__(self):
            return self.size_native_get()

    def size_native_get(self):
        cdef int w, h
        evas_object_textblock_size_native_get(self.obj, &w, &h)
        return (w, h)

    property style_insets:
        """Style insets"""
        def __get__(self):
            return self.style_insets_get()

    def style_insets_get(self):
        cdef int l, r, t, b
        evas_object_textblock_style_insets_get(self.obj, &l, &r, &t, &b)
        return (l, r, t, b)


_object_mapping_register("Evas_Textblock", Textblock)

