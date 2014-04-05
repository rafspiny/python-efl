from efl.evas cimport Eina_Bool, Evas_Object

cdef extern from "Elementary.h":
    Evas_Object             *elm_plug_add(Evas_Object *parent)
    Eina_Bool                elm_plug_connect(Evas_Object *obj, const char *svcname, int svcnum, Eina_Bool svcsys)
    Evas_Object             *elm_plug_image_object_get(Evas_Object *obj)
