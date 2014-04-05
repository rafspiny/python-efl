from efl.evas cimport Eina_Bool, Evas_Object, Evas_Coord

cdef extern from "Elementary.h":
    Evas_Object *           elm_fileselector_button_add(Evas_Object *parent)
    void                    elm_fileselector_button_window_title_set(Evas_Object *obj, const char *title)
    const char *            elm_fileselector_button_window_title_get(Evas_Object *obj)
    void                    elm_fileselector_button_window_size_set(Evas_Object *obj, Evas_Coord width, Evas_Coord height)
    void                    elm_fileselector_button_window_size_get(Evas_Object *obj, Evas_Coord *width, Evas_Coord *height)
    void                    elm_fileselector_button_inwin_mode_set(Evas_Object *obj, Eina_Bool value)
    Eina_Bool               elm_fileselector_button_inwin_mode_get(Evas_Object *obj)
