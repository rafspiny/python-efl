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


# TODO: remove me after usage is update to new buffer api
cdef extern from "Python.h":
    int PyObject_AsReadBuffer(obj, void **buffer, Py_ssize_t *buffer_len) except -1


# TODO needed? neem like the frong place to define fill/rotation stuff...
# def image_mask_fill(Image source, Image mask, Image surface, int x_mask, int y_mask, int x_surface, int y_surface):
#     evas_object_image_mask_fill(source.obj, mask.obj, surface.obj,
#                                 x_mask, y_mask, x_surface, y_surface)

cdef int _data_size_get(Evas_Object *obj):
    cdef int stride, h, bpp, cspace, have_alpha
    stride = evas_object_image_stride_get(obj)
    evas_object_image_size_get(obj, NULL, &h)
    cspace = evas_object_image_colorspace_get(obj)
    have_alpha = evas_object_image_alpha_get(obj)
    if cspace == EVAS_COLORSPACE_ARGB8888:
        bpp = 4
    elif cspace == EVAS_COLORSPACE_RGB565_A5P:
        if have_alpha == 0:
            bpp = 2
        else:
            bpp = 3
    else:
        return 0 # XXX not supported.

    return stride * h * bpp


cdef class Image(Object):
    """

    Image from file or buffer.

    .. rubric:: Introduction

    Image will consider the object's :py:func:`geometry<geometry_set()>`
    as the area to paint with tiles as described by :py:func:`fill_set()` and the
    real pixels (image data) will be stored as described by
    :py:func:`image_size<image_size_set()>`. This can be tricky to understand at
    first, but gives flexibility to do everything.

    If an image is loaded from file, it will have
    :py:func:`image_size<image_size_set()>` set to its original size, unless some
    other size was set with :py:func:`load_size_set()`, :py:func:`load_dpi_set()` or
    :py:func:`load_scale_down_set()`.

    Pixels will be scaled to match size specified by :py:func:`fill_set()`
    using either sampled or smooth methods, these can be specified with
    :py:func:`smooth_scale_set()`. The scale will consider borders as specified by
    :py:func:`border_set()` and :py:func:`border_center_fill_set()`, while the former specify
    the border dimensions (top and bottom will scale horizontally, while
    right and left will do vertically, corners are kept unscaled), the latter
    says whenever the center of the image will be used (useful to create
    frames).

    Contents will be tiled using :py::`fill_set()` information in order to paint
    :py:func:`geometry<Object.geometry_set()>`, so if you want an image to be drawn
    just once, you should match every :py:func:`geometry_set(x, y, w, h)` by a call
    to :py:func:`fill_set(0, 0, w, h)`. :py:class:`FilledImage` does that for you.

    .. rubric:: Pixel data and buffer API

    Images implement the Python Buffer API, so it's possible to use it
    where buffers are expected (ie: file.write()). Available data will
    depend on :py:func:`alpha<alpha_set()>`, :py:func:`colorspace<colorspace_set()>` and
    :py:func:`image_size<image_size_set()>`, lines should be considered multiple
    of :py:func:`stride<stride_get()>`, with the following considerations about
    colorspace:

    - **EVAS_COLORSPACE_ARGB8888:** This pixel format is a linear block of
        pixels, starting at the top-left row by row until the bottom right of
        the image or pixel region. All pixels are 32-bit unsigned int's with
        the high-byte being alpha and the low byte being blue in the format
        ARGB. Alpha may or may not be used by evas depending on the alpha flag
        of the image, but if not used, should be set to 0xff anyway.
        This colorspace uses premultiplied alpha. That means that R, G and B
        cannot exceed A in value. The conversion from non-premultiplied
        colorspace is::

            R = (r * a) / 255; G = (g * a) / 255; B = (b * a) / 255;

        So 50% transparent blue will be: 0x80000080. This will not be "dark" -
        just 50% transparent. Values are 0 == black, 255 == solid or full
        red, green or blue.
    - **EVAS_COLORSPACE_RGB565_A5P:** In the process of being implemented in
        1 engine only. This may change. This is a pointer to image data for
        16-bit half-word pixel data in 16bpp RGB 565 format (5 bits red,
        6 bits green, 5 bits blue), with the high-byte containing red and the
        low byte containing blue, per pixel. This data is packed row by row
        from the top-left to the bottom right. If the image has an alpha
        channel enabled there will be an extra alpha plane **after** the color
        pixel plane. If not, then this data will not exist and should not be
        accessed in any way. This plane is a set of pixels with 1 byte per
        pixel defining the alpha values of all pixels in the image from
        the top-left to the bottom right of the image, row by row. Even though
        the values of the alpha pixels can be 0 to 255, only values 0 through
        to 31 are used, 31 being solid and 0 being transparent.
        RGB values can be 0 to 31 for red and blue and 0 to 63 for green, with 0
        being black and 31 or 63 being full red, green or blue respectively.
        This colorspace is also pre-multiplied like EVAS_COLORSPACE_ARGB8888 so::

            R = (r * a) / 32; G = (g * a) / 32; B = (b * a) / 32;

    .. note:: if an image is resized it will **tile** it's contents respecting
        geometry set by :py:func:`fill_set()`, so if you want the contents to be
        **scaled** you need to call :py:func:`fill_set()` with ``x=0, y=0, w=new_width,
        h=new_height``, or you should use :py:class:`FilledImage` instead.

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
    :keyword file: File name
    :type file: string

    """
    def __init__(self, Canvas canvas not None, **kargs):
        self._set_obj(evas_object_image_add(canvas.obj))
        self._set_common_params(**kargs)

    def _set_common_params(self, file=None, **kargs):
        if file:
            if isinstance(file, str):
                file = (file, None)
            self.file_set(*file)
        Object._set_common_params(self, **kargs)

    # TODO:
    # def memfile_set(self, data, size=None, format=None, key=None):
    #     """

    #     Sets the data for an image from memory to be loaded

    #     This is the same as evas_object_image_file_set() but the file to be loaded
    #     may exist at an address in memory (the data for the file, not the filename
    #     itself). The @p data at the address is copied and stored for future use, so
    #     no @p data needs to be kept after this call is made. It will be managed and
    #     freed for you when no longer needed. The @p size is limited to 2 gigabytes
    #     in size, and must be greater than 0. A @c NULL @p data pointer is also
    #     invalid. Set the filename to @c NULL to reset to empty state and have the
    #     image file data freed from memory using evas_object_image_file_set().

    #     The @p format is optional (pass @c NULL if you don't need/use it). It is
    #     used to help Evas guess better which loader to use for the data. It may
    #     simply be the "extension" of the file as it would normally be on disk
    #     such as "jpg" or "png" or "gif" etc.

    #     @param data The image file data address
    #     @param size The size of the image file data in bytes
    #     @param format The format of the file (optional), or @c NULL if not needed
    #     @param key The image key in file, or @c NULL.

    #     """
    #     if isinstance(format, unicode): format = format.encode("UTF-8")
    #     if isinstance(key, unicode): key = key.encode("UTF-8")
    #     evas_object_image_memfile_set(self.obj, data, size,
    #         <char *>format if format is not None else NULL,
    #         <char *>key if key is not None else NULL)

    property file:
        """Set the image to display a file.

        :type: unicode filename or (unicode filename, unicode key)

        :raise EvasLoadError: on load error.

        """
        def __get__(self):
            return self.file_get()

        def __set__(self, value):
            if isinstance(value, str):
                value = (value, None)
            self.file_set(*value)

    cpdef file_set(self, filename, key=None):
        cdef int err
        if isinstance(filename, unicode): filename = filename.encode("UTF-8")
        if isinstance(key, unicode): key = key.encode("UTF-8")
        evas_object_image_file_set(self.obj,
            <const_char *>filename if filename is not None else NULL,
            <const_char *>key if key is not None else NULL)
        err = evas_object_image_load_error_get(self.obj)
        if err != EVAS_LOAD_ERROR_NONE:
            raise EvasLoadError(err, filename, key)

    cpdef file_get(self):
        cdef const_char *file, *key
        evas_object_image_file_get(self.obj, &file, &key)
        return (_ctouni(file), _ctouni(key))

    property border:
        """How much of each border is not to be scaled.

        When rendering, the image may be scaled to fit the size of the
        image object.  This property reflects what area around the border of
        the image is not to be scaled.  This is useful for
        widget theming, where, for example, buttons may be of varying
        sizes, but the border size must remain constant.

        :type: (int **l**, int **r**, int **t**, int **b**)

        """
        def __get__(self):
            return self.border_get()

        def __set__(self, spec):
            self.border_set(*spec)

    cpdef border_get(self):
        cdef int left, right, top, bottom
        evas_object_image_border_get(self.obj, &left, &right, &top, &bottom)
        return (left, right, top, bottom)

    cpdef border_set(self, int left, int right, int top, int bottom):
        evas_object_image_border_set(self.obj, left, right, top, bottom)

    property border_center_fill:
        """If the center part of an image (not the border) should be drawn

        .. seealso:: :py:attr:`border`

        When rendering, the image may be scaled to fit the size of the
        image object.  This property reflects if the center part of the scaled
        image is to be drawn or left completely blank. Very useful for frames
        and decorations.

        :type: bool

        """
        def __get__(self):
            return self.border_center_fill_get()

        def __set__(self, int value):
            self.border_center_fill_set(value)

    cpdef border_center_fill_get(self):
        return bool(evas_object_image_border_center_fill_get(self.obj))

    cpdef border_center_fill_set(self, int value):
        evas_object_image_border_center_fill_set(self.obj, value)

    property filled:
        """Whether the image object's fill property should track the
        object's size.

        If True, then every :py:func:`efl.evas.Object.resize` will
        **automatically** assign a value to :py:attr:`fill`
        with the that new size (and ``0, 0`` as source image's origin),
        so the bound image will fill the whole object's area.

        :type: bool

        .. seealso:: :py:func:`filled_add`

        """
        def __set__(self, value):
            self.filled_set(value)

        def __get__(self):
            return self.filled_get()

    cpdef filled_set(self, setting):
        evas_object_image_filled_set(self.obj, setting)

    cpdef filled_get(self):
        return bool(evas_object_image_filled_get(self.obj))

    property border_scale:
        """The scaling factor (multiplier) for the borders of an image
        object.

        Default is **1.0** - i.e. no scaling

        :type: double

        :see: :py:attr:`border`

        """
        def __set__(self, value):
            self.border_scale_set(value)

        def __get__(self):
            return self.border_scale_get()

    cpdef border_scale_set(self, scale):
        evas_object_image_border_scale_set(self.obj, scale)

    cpdef border_scale_get(self):
        return evas_object_image_border_scale_get(self.obj)

    property fill:
        """The rectangle that the image will be drawn to.

        Note that the image will be **tiled** around this one rectangle.
        To have only one copy of the image drawn, **x** and **y** must be
        0 and **w** and **h** need to be the width and height of the object
        respectively.

        The default values for the fill parameters is **x** = 0, **y** = 0,
        **w** = 1 and **h** = 1.

        :type: (int **x**, int **y**, int **w**, int **h**)

        """
        def __get__(self):
            return self.fill_get()

        def __set__(self, spec):
            self.fill_set(*spec)

    cpdef fill_get(self):
        cdef int x, y, w, h
        evas_object_image_fill_get(self.obj, &x, &y, &w, &h)
        return (x, y, w, h)

    cpdef fill_set(self, int x, int y, int w, int h):
        evas_object_image_fill_set(self.obj, x, y, w, h)

    property fill_spread:
        """The tiling mode for the given evas image object's fill.

        One of EVAS_TEXTURE_REFLECT, EVAS_TEXTURE_REPEAT,
        EVAS_TEXTURE_RESTRICT, or EVAS_TEXTURE_PAD.

        :type: Evas_Fill_Spread

        """
        def __set__(self, value):
            self.fill_spread_set(value)

        def __get__(self):
            return self.fill_spread_get()

    cpdef fill_spread_set(self, spread):
        evas_object_image_fill_spread_set(self.obj, spread)

    cpdef fill_spread_get(self):
        return evas_object_image_fill_spread_get(self.obj)

    property image_size:
        """The size of the image to be displayed.

        Assigning to this property will scale down or crop the image so that it
        is treated as if it were at the given size.
        If the size given is smaller than the image, it will be cropped.
        If the size given is larger, then the image will be treated as if it
        were in the upper left hand corner of a larger image that is
        otherwise transparent.

        This will force pixels to be allocated if they weren't, so
        you should use this before accessing the image as a buffer in order
        to allocate the pixels.

        This will recalculate :py:attr:`stride` based on
        width and the colorspace.

        :type: (int **w**, int **h**)

        """
        def __get__(self):
            return self.image_size_get()

        def __set__(self, spec):
            self.image_size_set(*spec)

    cpdef image_size_get(self):
        cdef int w, h
        evas_object_image_size_get(self.obj, &w, &h)
        return (w, h)

    cpdef image_size_set(self, int w, int h):
        evas_object_image_size_set(self.obj, w, h)

    property stride:
        """Get the row stride (in pixels) being used to draw this image.

        While image have logical dimension of width and height set by
        :py:func:`image_size_set()`, the line can be a bit larger than width to
        improve memory alignment.

        The amount of bytes will change based on colorspace, while using
        ARGB8888 it will be multiple of 4 bytes, with colors being laid
        out interleaved, RGB565_A5P will have the first part being RGB
        data using stride in multiple of 2 bytes and after that an
        alpha plane with data using stride in multiple of 1 byte.

        .. note:: This value can change after :py:func:`image_size_set()`.
        .. note:: Unit is pixels, not bytes.

        :type: int

        """
        def __get__(self):
            return self.stride_get()

    cpdef stride_get(self):
        return evas_object_image_stride_get(self.obj)

    property load_error:
        """The load error.

        :type: int

        """
        def __get__(self):
            return self.load_error_get()

    cpdef load_error_get(self):
        return evas_object_image_load_error_get(self.obj)

    def image_data_set(self, buf):
        """Sets the raw image data.

        The given buffer will be **copied**, so it's safe to give it a
        temporary object.

        .. note:: that the raw data must be of the same size and colorspace
            of the image. If data is None the current image data will be freed.

        :param buf: The buffer
        :type buf: data

        """
        cdef const_void *p_data
        cdef Py_ssize_t size, expected_size

        if buf is None:
            evas_object_image_data_set(self.obj, NULL)
            return

        # TODO: update to new buffer api
        PyObject_AsReadBuffer(buf, &p_data, &size)
        if p_data != NULL:
            expected_size = _data_size_get(self.obj)
            if size < expected_size:
                raise ValueError(("buffer size (%d) is smalled than expected "
                                  "(%d)!") % (size, expected_size))
        evas_object_image_data_set(self.obj,<void *> p_data)

    # TODO: def image_data_get(self):

    # TODO:
    # def image_data_convert(self, to_cspace):
    #     """Converts the raw image data of the given image object to the
    #     specified colorspace.

    #     Note that this function does not modify the raw image data.  If the
    #     requested colorspace is the same as the image colorspace nothing is
    #     done and @c NULL is returned. You should use
    #     evas_object_image_colorspace_get() to check the current image
    #     colorspace.

    #     See @ref evas_object_image_colorspace_get.

    #     @param obj The given image object.
    #     @param to_cspace The colorspace to which the image raw data will be converted.
    #     @return data A newly allocated data in the format specified by to_cspace.

    #     """
    #     void *evas_object_image_data_convert(self.obj, Evas_Colorspace to_cspace) EINA_WARN_UNUSED_RESULT EINA_ARG_NONNULL(1);

    # TODO:
    # def image_data_copy_set(self, data):
    #     """Replaces the raw image data of the given image object.

    #     :param data: The raw data to replace.

    #     This function lets the application replace an image objects
    #     internal pixel buffer with an user-allocated one. For best results,
    #     you should generally first call evas_object_image_size_set() with
    #     the width and height for the new buffer.

    #     This call is best suited for when you will be using image data with
    #     different dimensions than the existing image data, if any. If you
    #     only need to modify the existing image in some fashion, then using
    #     evas_object_image_data_get() is probably what you are after.

    #     Note that the caller is responsible for freeing the buffer when
    #     finished with it, as user-set image data will not be automatically
    #     freed when the image object is deleted.

    #     :see: :py:func:`image_data_get` for more details.

    #     """
    #     evas_object_image_data_copy_set(self.obj, void *data)

    def image_data_update_add(self, x, y, w, h):
        """image_data_update_add(int x, int y, int w, int h)

        Mark a sub-region of the image to be redrawn.

        This function schedules a particular rectangular region
        to be updated (redrawn) at the next render.

        :param x: X coordinate
        :type x: int
        :param y: Y coordinate
        :type y: int
        :param w: Width
        :type w: int
        :param h: Height
        :type h: int

        """
        evas_object_image_data_update_add(self.obj, x, y, w, h)

    property alpha:
        """Enable or disable alpha channel.

        :type: bool

        """
        def __get__(self):
            return self.alpha_get()

        def __set__(self, int value):
            self.alpha_set(value)

    cpdef alpha_get(self):
        return bool(evas_object_image_alpha_get(self.obj))

    cpdef alpha_set(self, value):
        evas_object_image_alpha_set(self.obj, value)

    property smooth_scale:
        """Enable or disable smooth scaling.

        :type: bool

        """
        def __get__(self):
            return self.smooth_scale_get()

        def __set__(self, int value):
            self.smooth_scale_set(value)

    cpdef smooth_scale_get(self):
        return bool(evas_object_image_smooth_scale_get(self.obj))

    cpdef smooth_scale_set(self, value):
        evas_object_image_smooth_scale_set(self.obj, value)

    def preload(self, int cancel=0):
        """preload(bool cancel=False)

        Preload image data asynchronously.

        This will request Evas to create a thread to load image data
        from file, decompress and convert to pre-multiplied format
        used internally.

        This will emit EVAS_CALLBACK_IMAGE_PRELOADED event callback
        when it is done, see on_image_preloaded_add().

        If one calls this function with cancel=True, then preload will
        be canceled and load will happen when image is made visible.

        If image is required before preload is done (ie: pixels are
        retrieved by user or when drawing), then it will be
        automatically canceled and load will be synchronous.

        :param cancel: if True, will cancel preload request.
        :type cancel: bool

        .. seealso: :py:func:`on_image_preloaded_add`

        """
        evas_object_image_preload(self.obj, cancel)


    def reload(self):
        """Force reload of image data."""
        evas_object_image_reload(self.obj)

    def save(self, filename, key=None, flags=None):
        """save(unicode filename, unicode key=None, unicode flags=None)

        Save image to file.

        :param filename: where to save.
        :type filename: unicode
        :param key: some formats may require a key, EET for example.
        :type key: unicode
        :param flags: string of extra flags (separated by space), like
            "quality=85 compress=9".
        :type flags: unicode

        """
        if isinstance(filename, unicode): filename = filename.encode("UTF-8")
        if isinstance(key, unicode): key = key.encode("UTF-8")
        if isinstance(flags, unicode): flags = flags.encode("UTF-8")
        evas_object_image_save(self.obj, filename,
            <const_char *>key if key is not None else NULL,
            <const_char *>flags if flags is not None else NULL)

    # TODO:
    # def image_pixels_import(self, pixels):
    #     """Import pixels from given source to a given canvas image object.

    #     :param pixels: The pixel source to be imported.
    #     :type pixels: Evas_Pixel_Import_Source *
    #     :return: Whether the import was succesful
    #     :rtype: bool

    #     This function imports pixels from a given source to a given canvas image.

    #     """
    #     if not evas_object_image_pixels_import(self.obj, pixels):
    #         raise RuntimeError("Could not import pixels.")

    # TODO:
    # def pixels_get_callback_set(self, func, data):
    #     """Set the callback function to get pixels from a canvas' image.

    #     :param func: The callback function.
    #     :type func: Evas_Object_Image_Pixels_Get_Cb
    #     :param data: The data pointer to be passed to @a func.

    #     This functions sets a function to be the callback function that get
    #     pixes from a image of the canvas.

    #     """
    #     evas_object_image_pixels_get_callback_set(self.obj, func, data)

    property pixels_dirty:
        """Mark or unmark pixels as dirty.

        :type: bool

        """
        def __get__(self):
            return self.pixels_dirty_get()

        def __set__(self, int value):
            self.pixels_dirty_set(value)

    cpdef pixels_dirty_get(self):
        return bool(evas_object_image_pixels_dirty_get(self.obj))

    cpdef pixels_dirty_set(self, value):
        evas_object_image_pixels_dirty_set(self.obj, value)

    property load_dpi:
        """Dots-per-inch to be used at image load time.

        :type: double

        """
        def __get__(self):
            return self.load_dpi_get()

        def __set__(self, int value):
            self.load_dpi_set(value)

    cpdef load_dpi_get(self):
        return evas_object_image_load_dpi_get(self.obj)

    cpdef load_dpi_set(self, double value):
        evas_object_image_load_dpi_set(self.obj, value)

    property load_size:
        """The size you want image loaded.

        Loads image to the desired size, saving memory when loading large
        files.

        :type: (int **w**, int **h**)

        """
        def __get__(self):
            return self.load_size_get()

        def __set__(self, spec):
            self.load_size_set(*spec)

    cpdef load_size_get(self):
        cdef int w, h
        evas_object_image_load_size_get(self.obj, &w, &h)
        return (w, h)

    cpdef load_size_set(self, int w, int h):
        evas_object_image_load_size_set(self.obj, w, h)

    property load_scale_down:
        """Scale down loaded image by the given amount.

        :type: int

        """
        def __get__(self):
            return self.load_scale_down_get()

        def __set__(self, int value):
            self.load_scale_down_set(value)

    cpdef load_scale_down_get(self):
        return evas_object_image_load_scale_down_get(self.obj)

    cpdef load_scale_down_set(self, int value):
        evas_object_image_load_scale_down_set(self.obj, value)

    property load_region:
        """Inform a given image object to load a selective region of its
        source image.

        :type: (int **x**, int **y**, int **w**, int **h**)

        This is useful when one is not showing all of an image's
        area on its image object.

        .. note::

            The image loader for the image format in question has to
            support selective region loading in order to this function to take
            effect.

        """
        def __set__(self, value):
            self.load_region_set(*value)

        def __get__(self):
            return self.load_region_get()

    cpdef load_region_set(self, int x, int y, int w, int h):
        evas_object_image_load_region_set(self.obj, x, y, w, h)

    cpdef load_region_get(self):
        cdef int x, y, w, h
        evas_object_image_load_region_get(self.obj, &x, &y, &w, &h)
        return x, y, w, h

    property load_orientation:
        """Define if the orientation information in the image file should be honored.

        :type: bool

        """
        def __set__(self, value):
            self.load_orientation_set(value)

        def __get__(self):
            return self.load_orientation_get()

    cpdef load_orientation_set(self, enable):
        evas_object_image_load_orientation_set(self.obj, enable)

    cpdef load_orientation_get(self):
        return bool(evas_object_image_load_orientation_get(self.obj))

    property colorspace:
        """The colorspace of image data (pixels).

        May be one of (subject to engine implementation):

        - **EVAS_COLORSPACE_ARGB8888** ARGB 32 bits per pixel, high-byte is
            Alpha, accessed 1 32bit word at a time.
        - **EVAS_COLORSPACE_YCBCR422P601_PL** YCbCr 4:2:2 Planar, ITU.BT-601
            specifications. The data poitned to is just an array of row
            pointer, pointing to the Y rows, then the Cb, then Cr rows.
        - **EVAS_COLORSPACE_YCBCR422P709_PL** YCbCr 4:2:2 Planar, ITU.BT-709
            specifications. The data poitned to is just an array of row
            pointer, pointing to the Y rows, then the Cb, then Cr rows.
        - **EVAS_COLORSPACE_RGB565_A5P** 16bit rgb565 + Alpha plane at end -
            5 bits of the 8 being used per alpha byte.

        :type: Evas_Colorspace

        """
        def __get__(self):
            return self.colorspace_get()

        def __set__(self, int value):
            self.colorspace_set(value)

    cpdef colorspace_get(self):
        return evas_object_image_colorspace_get(self.obj)

    cpdef colorspace_set(self, int value):
        evas_object_image_colorspace_set(self.obj, <Evas_Colorspace>value)

    property region_support:
        """Region support state

        :type: bool

        """
        def __get__(self):
            return self.region_support_get()

    cpdef region_support_get(self):
        return bool(evas_object_image_region_support_get(self.obj))

    # property native_surface:
    #     """The native surface of a given image of the canvas

    #     @param surf The new native surface.

    #     """
    #     def __set__(self, value):
    #         self.native_surface_set(value)

    #     def __get__(self):
    #         return self.native_surface_get()

    # cpdef native_surface_set(self, surf):
    #     evas_object_image_native_surface_set(self.obj, Evas_Native_Surface *surf)

    # cpdef native_surface_get(self):
    #     EAPI Evas_Native_Surface          *evas_object_image_native_surface_get(const Evas_Object *obj) EINA_WARN_UNUSED_RESULT EINA_ARG_NONNULL(1);

    # property video_surface:
    #     """The video surface linked to a given image of the canvas

    #     @param surf The new video surface.

    #     """
    #     def __set__(self, value):
    #         self.video_surface_set(value)

    #     def __get__(self):
    #         return self.video_surface_get()

    # cpdef video_surface_set(self, surf):
    #     evas_object_image_video_surface_set(self.obj, Evas_Video_Surface *surf)

    # cpdef video_surface_get(self):
    #     Evas_Video_Surface *evas_object_image_video_surface_get(self.obj)

    property scale_hint:

        """The scale hint value of the image object in the canvas,
        which will affect how Evas is to cache scaled versions of its
        original source image.

        :type: Evas_Image_Scale_Hint


        """
        def __set__(self, value):
            self.scale_hint_set(value)

        def __get__(self):
            return self.scale_hint_get()

    cpdef scale_hint_set(self, Evas_Image_Scale_Hint hint):
        evas_object_image_scale_hint_set(self.obj, hint)

    cpdef scale_hint_get(self):
        return evas_object_image_scale_hint_get(self.obj)

    property content_hint:
        """The content hint value of the given image of the canvas.

        For example, if you're on the GL engine and your driver implementation
        supports it, setting this hint to ``EVAS_IMAGE_CONTENT_HINT_DYNAMIC`` will
        make it need **zero** copies at texture upload time, which is an "expensive"
        operation.

        :type: Evas_Image_Content_Hint

        """
        def __set__(self, value):
            self.content_hint_set(value)

        def __get__(self):
            return self.content_hint_get()

    cpdef content_hint_set(self, Evas_Image_Content_Hint hint):
        evas_object_image_content_hint_set(self.obj, hint)

    cpdef content_hint_get(self):
        return evas_object_image_content_hint_get(self.obj)

    property alpha_mask:
        """Enable an image to be used as an alpha mask.

        This will set any flags, and discard any excess image data not used as an
        alpha mask.

        .. note::

            There is little point in using a image as alpha mask unless it has
            an alpha channel.

        :type: bool

        """
        def __set__(self, value):
            self.alpha_mask_set(value)

    cpdef alpha_mask_set(self, ismask):
        evas_object_image_alpha_mask_set(self.obj, ismask)

    property image_source:
        """The source object on an image object to used as a @b proxy.

        If an image object is set to behave as a @b proxy, it will mirror
        the rendering contents of a given @b source object in its drawing
        region, without affecting that source in any way. The source must
        be another valid Evas object. Other effects may be applied to the
        proxy, such as a map (see evas_object_map_set()) to create a
        reflection of the original object (for example).

        Any existing source object on @p obj will be removed after this
        call. Setting @p src to @c NULL clears the proxy object (not in
        "proxy state" anymore).

        :type: Object
        :raise RuntimeError: if source could not be (un)set.

        .. warning:: You cannot set a proxy as another proxy's source.

        .. seealso:: :py:attr:`source_visible`

        """
        def __set__(self, value):
            self.source_set(value)

        def __get__(self):
            return self.source_get()

        def __del__(self):
            self.source_unset()

    cpdef source_set(self, Object src):
        if not evas_object_image_source_set(self.obj, src.obj):
            raise RuntimeError("Could not set image source.")

    cpdef source_get(self):
        return object_from_instance(evas_object_image_source_get(self.obj))

    cpdef source_unset(self):
        if not evas_object_image_source_unset(self.obj):
            raise RuntimeError("Could not unset image source.")

    property source_visible:
        """Whether the source object is visible or not.

        If set to False, the source object of the proxy will be invisible.

        This API works differently to :py:func:`show` and :py:func:`hide`.
        Once source object is hidden by :py:func:`hide` then the proxy object will
        be hidden as well. Actually in this case both objects are excluded from the
        Evas internal update circle.

        By this API, instead, one can toggle the visibility of a proxy's source
        object remaining the proxy visibility untouched.

        :type: bool

        .. warning::

            If the all of proxies are deleted, then the source visibility of the
            source object will be cancelled.

        .. seealso:: evas_object_image_source_set()

        @since 1.8

        """
        def __set__(self, value):
            self.source_visible_set(value)

        def __get__(self):
            return self.source_visible_get()

    cpdef source_visible_set(self, visible):
        evas_object_image_source_visible_set(self.obj, visible)

    cpdef source_visible_get(self):
        return bool(evas_object_image_source_visible_get(self.obj))

    property source_events:
        """Whether an Evas object is to repeat events to source.

        If True, it will make events on the object to also be repeated for the
        source object. When the object and source geometries are different, the
        event position will be transformed to the source object's space.

        If False, events occurring on the object will be processed only on it.

        :type: bool

        .. seealso::

            :py:attr:`source`
            :py:attr:`source_visible`

        @since 1.8

        """
        def __set__(self, value):
            self.source_events_set(value)

        def __get__(self):
            return self.source_events_get()

    cpdef source_events_set(self, source):
        evas_object_image_source_events_set(self.obj, source)

    cpdef source_events_get(self):
        return bool(evas_object_image_source_events_get(self.obj))

    property animated:
        """Check if an image object can be animated (have multiple frames)

        :type: bool

        This returns if the image file of an image object is capable of animation
        such as an animated gif file might. This is only useful to be called once
        the image object file has been set.

        Example::

            obj = Image(mycanvas, file="my_animated_file.gif")

            if obj.animated:
                print("This image has %d frames" % (obj.animated_frame_count,))
                print("Frame 1's duration is %f. You had better set object's frame to 2 after this duration using timer." % (obj.animated_frame_duration_get(1, 0)))
                print("Loop count is %d. You had better run loop %d times." % (obj.loop_count, obj.loop_count))

                loop_type = obj.animated_loop_type
                if loop_type == EVAS_IMAGE_ANIMATED_HINT_LOOP:
                    print("You had better set frame like 1->2->3->1->2->3...")
                elif loop_type == EVAS_IMAGE_ANIMATED_HINT_PINGPONG:
                    print("You had better set frame like 1->2->3->2->1->2...")
                else:
                    print("Unknown loop type.")

                obj.animated_frame = 1
                print("You set image objects frame to 1. You can see frame 1.")

        """
        def __get__(self):
            return self.animated_get()

    cpdef animated_get(self):
        return bool(evas_object_image_animated_get(self.obj))

    property animated_frame_count:
        """Get the total number of frames of the image object.

        :type: int

        This returns total number of frames the image object supports (if animated)

        """
        def __get__(self):
            return self.animated_frame_count_get()

    cpdef animated_frame_count_get(self):
        return evas_object_image_animated_frame_count_get(self.obj)

    property animated_loop_type:
        """Get the kind of looping the image object does.

        :type: Evas_Image_Animated_Loop_Hint

        This returns the kind of looping the image object wants to do.

        If it returns EVAS_IMAGE_ANIMATED_HINT_LOOP, you should display frames in a sequence like:
        1->2->3->1->2->3->1...
        If it returns EVAS_IMAGE_ANIMATED_HINT_PINGPONG, it is better to
        display frames in a sequence like: 1->2->3->2->1->2->3->1...

        The default type is EVAS_IMAGE_ANIMATED_HINT_LOOP.

        """
        def __get__(self):
            return self.animated_loop_type_get()

    cpdef animated_loop_type_get(self):
        return evas_object_image_animated_loop_type_get(self.obj)

    property animated_loop_count:
        """Get the number times the animation of the object loops.

        :type: int

        This returns loop count of image. The loop count is the number of times
        the animation will play fully from first to last frame until the animation
        should stop (at the final frame).

        If 0 is returned, then looping should happen indefinitely (no limit to
        the number of times it loops).

        """
        def __get__(self):
            return self.animated_loop_count_get()

    cpdef animated_loop_count_get(self):
        return evas_object_image_animated_loop_count_get(self.obj)

    def animated_frame_duration_get(self, int start_frame, int fram_num):
        """animated_frame_duration_get(int start_frame, int fram_num) -> double

        Get the duration of a sequence of frames.

        :param start_frame: The first frame
        :type start_frame: int
        :param fram_num: Number of frames in the sequence
        :type fram_num: int

        :return: The duration of a sequence of frames.
        :rtype: double

        This returns total duration that the specified sequence of frames should
        take in seconds.

        If you set start_frame to 1 and frame_num 0, you get frame 1's duration
        If you set start_frame to 1 and frame_num 1, you get frame 1's duration +
        frame2's duration

        """
        return evas_object_image_animated_frame_duration_get(self.obj, start_frame, fram_num)

    property animated_frame:
        """Set the frame to current frame of an image object

        :type: int

        This set image object's current frame to frame_num with 1 being the first
        frame.

        """
        def __set__(self, value):
            self.animated_frame_set(value)

    cpdef animated_frame_set(self, int frame_num):
        evas_object_image_animated_frame_set(self.obj, frame_num)



    def __getsegcount__(self, Py_ssize_t *p_len):
        if p_len == NULL:
            return 1

        p_len[0] = _data_size_get(self.obj)
        return 1

    def __getreadbuffer__(self, int segment, void **ptr):
        ptr[0] = evas_object_image_data_get(self.obj, 0)
        if ptr[0] == NULL:
            raise SystemError("image has no allocated buffer.")
        # XXX: keep Evas pixels_checked_out counter to 0 and allow
        # XXX: image to reload and unload its data.
        # XXX: may cause problems if buffer is used after these
        # XXX: functions are called, but buffers aren't expected to
        # XXX: live much.
        evas_object_image_data_set(self.obj, ptr[0])
        return _data_size_get(self.obj)

    def __getwritebuffer__(self, int segment, void **ptr):
        ptr[0] = evas_object_image_data_get(self.obj, 1)
        if ptr[0] == NULL:
            raise SystemError("image has no allocated buffer.")
        # XXX: keep Evas pixels_checked_out counter to 0 and allow
        # XXX: image to reload and unload its data.
        # XXX: may cause problems if buffer is used after these
        # XXX: functions are called, but buffers aren't expected to
        # XXX: live much.
        evas_object_image_data_set(self.obj, ptr[0])
        return _data_size_get(self.obj)

    def __getcharbuffer__(self, int segment, char **ptr):
        ptr[0] = <char *>evas_object_image_data_get(self.obj, 0)
        if ptr[0] == NULL:
            raise SystemError("image has no allocated buffer.")
        # XXX: keep Evas pixels_checked_out counter to 0 and allow
        # XXX: image to reload and unload its data.
        # XXX: may cause problems if buffer is used after these
        # XXX: functions are called, but buffers aren't expected to
        # XXX: live much.
        evas_object_image_data_set(self.obj, ptr[0])
        return _data_size_get(self.obj)



    def on_image_preloaded_add(self, func, *a, **k):
        """Same as event_callback_add(EVAS_CALLBACK_IMAGE_PRELOADED, ...)"""
        self.event_callback_add(EVAS_CALLBACK_IMAGE_PRELOADED, func, *a, **k)

    def on_image_preloaded_del(self, func):
        """Same as event_callback_del(EVAS_CALLBACK_IMAGE_PRELOADED, ...)"""
        self.event_callback_del(EVAS_CALLBACK_IMAGE_PRELOADED, func)

    def on_image_unloaded_add(self, func, *a, **k):
        """Same as event_callback_add(EVAS_CALLBACK_IMAGE_UNLOADED, ...)"""
        self.event_callback_add(EVAS_CALLBACK_IMAGE_UNLOADED, func, *a, **k)

    def on_image_unloaded_del(self, func):
        """Same as event_callback_del(EVAS_CALLBACK_IMAGE_UNLOADED, ...)"""
        self.event_callback_del(EVAS_CALLBACK_IMAGE_UNLOADED, func)


_object_mapping_register("Evas_Object_Image", Image)


cdef void _cb_on_filled_image_resize(void *data, Evas *e,
                                     Evas_Object *obj,
                                     void *event_info) with gil:
    cdef int w, h
    evas_object_geometry_get(obj, NULL, NULL, &w, &h)
    evas_object_image_fill_set(obj, 0, 0, w, h)


cdef class FilledImage(Image):

    """

    Image that automatically resize it's contents to fit object size.

    This :py::`Image` subclass already calls :py::`Image.fill_set()` on resize so
    it will match and so be scaled to fill the whole area.

    :param canvas: The evas canvas for this object
    :type canvas: :py:class:`Canvas`
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
    :keyword file: File name
    :type file: string

    """

    def __init__(self, Canvas canvas not None, **kargs):
        Image.__init__(self, canvas, **kargs)
        w, h = self.size_get()
        Image.fill_set(self, 0, 0, w, h)
        evas_object_event_callback_add(self.obj, EVAS_CALLBACK_RESIZE,
                                       _cb_on_filled_image_resize, NULL)

    def fill_set(self, int x, int y, int w, int h):
        """Not available for this class."""
        raise NotImplementedError("FilledImage doesn't support fill_set()")


_object_mapping_register("Evas_Object_FilledImage", FilledImage)

def extension_can_load(filename):
    """extension_can_load(unicode filename) -> bool

    Check if a file extension is supported by :py:class:`Image`.

    :param filename: The file to check
    :type filename: unicode
    :return: ``True`` if we may be able to open it,``False`` if it's unlikely.
    :rtype: bool

    .. note:: This function is threadsafe.

    """
    if isinstance(filename, unicode): filename = filename.encode("UTF-8")
    return bool(evas_object_image_extension_can_load_get(
        <const_char *>filename))

